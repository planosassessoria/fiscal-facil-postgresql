-- =============================================================================
-- FUNCTION: xml.fn_destructure_xml_to_nota_fiscal_record
-- SCHEMA:   xml
-- VERSION:  v4
-- DESCRIPTION:
--   Desestrutura um XML de NF-e/NFC-e armazenado em xml.xml_storage, extraindo
--   todos os grupos fiscais e persistindo-os nas tabelas normalizadas do schema
--   nota_fiscal. Mantém ordinalidade dos itens e impostos via xpath relativo.
--
-- Parameters:
--   _xml_id            — BIGINT referenciando xml.xml_storage.xml_id.
--   _replace_if_exists — Se TRUE, deleta (CASCADE) o registro existente antes
--                         de reprocessar. Default: FALSE (retorna SKIPPED).
--
-- Fluxo de execução:
--   1. Valida existência do XML em xml.xml_storage.
--   2. Extrai e valida a chave de acesso (44 dígitos numéricos).
--   3. Verifica idempotência (duplicidade) e aplica substituição se solicitado.
--   4. Insere os registros nas tabelas do schema nota_fiscal em hierarquia:
--      NV0: b01_ide (raiz)
--      NV1: ba01_nf_ref, c01_emit_c05_ender, e01_dest_e05_ender, d01_avulsa,
--           i01_prod, w02_icms_tot, w17_issqn_tot, w23_ret_trib,
--           z01_inf_adic, pr03_inf_prot, y07_dup, ya01_pag
--      NV2: n01_icms, o01_ipi, p01_ii, q01_pis_s01_cofins,
--           ua01_imposto_devol_ua03_ipi, na01_icms_uf_dest, ub01_is,
--           ub12_ibs_cbs, z04_obs_cont, z07_obs_fisco, ya01a_det_pag
--      NV3: ya04_card
--
-- Returns JSONB:
--   Success → { "success": true, "ch_nf": "...", "has_dest": bool,
--               "has_avulsa": bool, "has_nf_ref": bool,
--               "items_processed": int, "processing_time_ms": numeric }
--   Skipped → { "success": true, "status": "SKIPPED", "ch_nf": "...", "message": "..." }
--   Failure → { "success": false, "step": "...", "error_code": "...",
--               "message": "...", "xml_id": bigint, "ch_nf": text }
--
-- Validações:
--   - XML não encontrado      → error: XML_NOT_FOUND
--   - Chave inválida (!=44d)  → error: INVALID_CH_NF
--   - Duplicidade sem replace → status: SKIPPED
--
-- Observabilidade:
--   Em caso de exceção, emite RAISE WARNING com step, xml_id, ch_nf, SQLSTATE
--   e SQLERRM antes de retornar o JSON de erro.
--
-- Dependências:
--   - Leitura: xml.xml_storage
--   - Escrita: nota_fiscal.b01_ide (CASCADE para todas as filhas)
--   - Namespace XML: http://www.portalfiscal.inf.br/nfe
-- =============================================================================

CREATE OR REPLACE FUNCTION xml.fn_destructure_xml_to_nota_fiscal_record(
    _xml_id           BIGINT,
    _replace_if_exists BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    -- Controle de execução
    _start_time  TIMESTAMPTZ  := clock_timestamp();
    _ch_nf       VARCHAR(44);
    _xml_content XML;
    _ns          TEXT[][]     := ARRAY[ARRAY['nfe', 'http://www.portalfiscal.inf.br/nfe']];
    _step        VARCHAR(50);

    -- Flags de presença de grupos opcionais
    _has_dest    BOOLEAN;
    _has_avulsa  BOOLEAN;
    _has_nf_ref  BOOLEAN;

    -- Identificadores de tabelas pai (módulos futuros)
    _id_inf_adic BIGINT;
    _id_pag      BIGINT;
    _id_det_pag  BIGINT;

    -- Records para iterações (um por contexto de loop)
    _r_nf_ref    RECORD;  -- loop de NFref
    _r_det       RECORD;  -- loop de itens (det)
    _r_obs       RECORD;  -- loop de observações (cont/fisco)
    _r_dup       RECORD;  -- loop de duplicatas
    _r_det_pag   RECORD;  -- loop de detPag
    -- Variáveis para evitar repetição de COALESCE
    _emitente_cpf_cnpj      VARCHAR(14);
    _destinatario_cpf_cnpj  VARCHAR(14);
    -- Cache de campos da ide (evita xpath repetido no loop de itens)
    _num_doc     INTEGER;
    _ser         TEXT;
    _cod_mod     TEXT;
    -- Contador de itens processados
    _item_count  INTEGER := 0;
BEGIN
    -- =========================================================================
    -- 1. Valida existência do XML
    -- =========================================================================
    _step := 'INITIAL_CHECK';

    SELECT xml_content INTO _xml_content
    FROM xml.xml_storage
    WHERE xml_id = _xml_id;

    IF _xml_content IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error',   'XML_NOT_FOUND',
            'message', 'Registro não encontrado em xml.xml_storage para xml_id: ' || _xml_id
        );
    END IF;

    -- =========================================================================
    -- 2. Extrai e valida a Chave de Acesso (44 dígitos)
    -- =========================================================================
    _ch_nf := (xpath('//nfe:infNFe/@Id', _xml_content, _ns))[1]::text;
    _ch_nf := regexp_replace(_ch_nf, '[^0-9]', '', 'g');

    IF _ch_nf IS NULL OR length(_ch_nf) != 44 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error',   'INVALID_CH_NF',
            'message', 'Chave de acesso inválida ou não encontrada no XML',
            'xml_id',  _xml_id
        );
    END IF;

    -- =========================================================================
    -- 2b. Atribui CPF/CNPJ do emitente e destinatário (evita xpath repetido)
    -- =========================================================================
    _emitente_cpf_cnpj := COALESCE(
        (xpath('//nfe:emit/nfe:CNPJ/text()', _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:CPF/text()',  _xml_content, _ns))[1]::text
    );

    _destinatario_cpf_cnpj := COALESCE(
        (xpath('//nfe:dest/nfe:CNPJ/text()', _xml_content, _ns))[1]::text,
        (xpath('//nfe:dest/nfe:CPF/text()',  _xml_content, _ns))[1]::text
    );

    -- =========================================================================
    -- 3. Idempotência: verifica duplicidade e gerencia substituição
    -- =========================================================================
    IF EXISTS (SELECT 1 FROM nota_fiscal.b01_ide WHERE ch_nf = _ch_nf) THEN
        IF _replace_if_exists THEN
            -- Deleção em cascata propaga para todas as tabelas filhas
            DELETE FROM nota_fiscal.b01_ide WHERE ch_nf = _ch_nf;
        ELSE
            RETURN jsonb_build_object(
                'success', true,
                'status',  'SKIPPED',
                'ch_nf',   _ch_nf,
                'message', 'Documento já processado. Use _replace_if_exists=true para substituir.'
            );
        END IF;
    END IF;

    -- =========================================================================
    -- NV0 | b01_ide — Tabela raiz: identificação completa da NF-e
    -- Mapeia todos os campos do grupo B (ide) + emitente + destinatário resumido
    -- =========================================================================
    _step := 'B01_IDE';

    WITH ide_data AS (
        SELECT
            -- Grupo B: ide
            (xpath('//nfe:ide/nfe:cUF/text()',      _xml_content, _ns))[1]::text::integer     AS cod_uf,
            (xpath('//nfe:ide/nfe:natOp/text()',    _xml_content, _ns))[1]::text              AS nat_oper,
            (xpath('//nfe:ide/nfe:mod/text()',      _xml_content, _ns))[1]::text              AS cod_mod,
            (xpath('//nfe:ide/nfe:serie/text()',    _xml_content, _ns))[1]::text              AS ser,
            (xpath('//nfe:ide/nfe:nNF/text()',      _xml_content, _ns))[1]::text::integer     AS num_doc,
            (xpath('//nfe:ide/nfe:dhEmi/text()',    _xml_content, _ns))[1]::text::timestamptz AS dh_emi,
            (xpath('//nfe:ide/nfe:dhSaiEnt/text()', _xml_content, _ns))[1]::text::timestamptz AS dh_sai_ent,
            (xpath('//nfe:ide/nfe:tpNF/text()',     _xml_content, _ns))[1]::text::integer     AS tp_nf,
            (xpath('//nfe:ide/nfe:idDest/text()',   _xml_content, _ns))[1]::text::integer     AS id_dest,
            (xpath('//nfe:ide/nfe:cMunFG/text()',   _xml_content, _ns))[1]::text              AS cod_mun,
            (xpath('//nfe:ide/nfe:tpImp/text()',    _xml_content, _ns))[1]::text::integer     AS tp_imp,
            (xpath('//nfe:ide/nfe:tpEmis/text()',   _xml_content, _ns))[1]::text::integer     AS tp_emis,
            (xpath('//nfe:ide/nfe:cDV/text()',      _xml_content, _ns))[1]::text::integer     AS c_dv,
            (xpath('//nfe:ide/nfe:tpAmb/text()',    _xml_content, _ns))[1]::text::integer     AS tp_amb,
            (xpath('//nfe:ide/nfe:finNFe/text()',   _xml_content, _ns))[1]::text::integer     AS fin_nfe,
            (xpath('//nfe:ide/nfe:indFinal/text()', _xml_content, _ns))[1]::text::integer     AS ind_final,
            (xpath('//nfe:ide/nfe:indPres/text()',  _xml_content, _ns))[1]::text::integer     AS ind_pres,
            (xpath('//nfe:ide/nfe:procEmi/text()',  _xml_content, _ns))[1]::text::integer     AS proc_emi,
            (xpath('//nfe:ide/nfe:verProc/text()',  _xml_content, _ns))[1]::text              AS ver_proc,
            -- ind_pag: removido no leiaute 4.0 (NT2016.002), mantido para retrocompatibilidade
            (xpath('//nfe:ide/nfe:indPag/text()',   _xml_content, _ns))[1]::text::integer     AS ind_pag,
            -- Campos de contingência (opcionais)
            (xpath('//nfe:ide/nfe:dhCont/text()',   _xml_content, _ns))[1]::text::timestamptz AS dh_cont,
            (xpath('//nfe:ide/nfe:xJust/text()',    _xml_content, _ns))[1]::text              AS x_just,
            -- Emitente (resumo em b01_ide; detalhes em c01_emit_c05_ender)
            (xpath('//nfe:emit/nfe:CNPJ/text()',    _xml_content, _ns))[1]::text              AS emit_cnpj,
            (xpath('//nfe:emit/nfe:CPF/text()',     _xml_content, _ns))[1]::text              AS emit_cpf,
            (xpath('//nfe:emit/nfe:IE/text()',      _xml_content, _ns))[1]::text              AS emit_ie,
            -- Destinatário (resumo em b01_ide; detalhes em e01_dest_e05_ender)
            (xpath('//nfe:dest/nfe:CNPJ/text()',    _xml_content, _ns))[1]::text              AS dest_cnpj,
            (xpath('//nfe:dest/nfe:CPF/text()',     _xml_content, _ns))[1]::text              AS dest_cpf,
            (xpath('//nfe:dest/nfe:IE/text()',      _xml_content, _ns))[1]::text              AS dest_ie
    )
    INSERT INTO nota_fiscal.b01_ide (
        xml_id,
        ch_nf,
        cod_uf,
        nat_oper,
        cod_mod,
        ser,
        num_doc,
        dh_emi,
        dh_sai_ent,
        dt_doc,
        dt_e_s,
        tp_nf,
        id_dest,
        cod_mun,
        tp_imp,
        tp_emis,
        c_dv,
        tp_amb,
        fin_nfe,
        ind_final,
        ind_pres,
        proc_emi,
        ver_proc,
        ind_pag,
        dh_cont,
        x_just,
        cpf_cnpj,
        ie,
        dest_cpf_cnpj,
        dest_ie
    )
    SELECT
        _xml_id,
        _ch_nf,
        cod_uf,
        nat_oper,
        cod_mod,
        ser,
        num_doc,
        dh_emi,
        dh_sai_ent,
        dh_emi::date,
        dh_sai_ent::date,
        tp_nf,
        id_dest,
        cod_mun,
        tp_imp,
        tp_emis,
        c_dv,
        tp_amb,
        fin_nfe,
        ind_final,
        ind_pres,
        proc_emi,
        ver_proc,
        ind_pag,
        dh_cont,
        x_just,
        _emitente_cpf_cnpj,
        emit_ie,
        _destinatario_cpf_cnpj,
        dest_ie
    FROM ide_data;

    -- =========================================================================
    -- NV1 | ba01_nf_ref — Referências a documentos fiscais relacionados (condicional)
    -- =========================================================================
    _step := 'BA01_NF_REF';

    _has_nf_ref := (xpath('//nfe:ide/nfe:NFref', _xml_content, _ns))[1] IS NOT NULL;

    -- Extrai todos os nós NFref (pode haver 0-500)
    FOR _r_nf_ref IN
        SELECT unnest(xpath('//nfe:ide/nfe:NFref', _xml_content, _ns)) AS nfref_node
    LOOP
        -- refNFe (NF-e/NFC-e)
        IF (xpath('nfe:refNFe/text()', _r_nf_ref.nfref_node, _ns))[1] IS NOT NULL THEN
            INSERT INTO nota_fiscal.ba01_nf_ref (
                ch_nf,
                ref_nfe
            ) VALUES (
                _ch_nf,
                (xpath('nfe:refNFe/text()', _r_nf_ref.nfref_node, _ns))[1]::text
            );
        END IF;
        -- refCTe
        IF (xpath('nfe:refCTe/text()', _r_nf_ref.nfref_node, _ns))[1] IS NOT NULL THEN
            INSERT INTO nota_fiscal.ba01_nf_ref (
                ch_nf,
                ref_cte
            ) VALUES (
                _ch_nf,
                (xpath('nfe:refCTe/text()', _r_nf_ref.nfref_node, _ns))[1]::text
            );
        END IF;
        -- refNF (modelo 1/1A)
        IF (xpath('nfe:refNF', _r_nf_ref.nfref_node, _ns))[1] IS NOT NULL THEN
            INSERT INTO nota_fiscal.ba01_nf_ref (
                ch_nf,
                c_uf,
                aamm,
                cnpj,
                mod,
                serie,
                n_nf
            ) VALUES (
                _ch_nf,
                (xpath('nfe:refNF/nfe:cUF/text()',   _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNF/nfe:AAMM/text()',  _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNF/nfe:CNPJ/text()',  _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNF/nfe:mod/text()',   _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNF/nfe:serie/text()', _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNF/nfe:nNF/text()',   _r_nf_ref.nfref_node, _ns))[1]::text
            );
        END IF;
        -- refNFP (produtor rural)
        IF (xpath('nfe:refNFP', _r_nf_ref.nfref_node, _ns))[1] IS NOT NULL THEN
            INSERT INTO nota_fiscal.ba01_nf_ref (
                ch_nf,
                c_uf,
                aamm,
                cnpj,
                cpf,
                ie,
                mod,
                serie,
                n_nf
            ) VALUES (
                _ch_nf,
                (xpath('nfe:refNFP/nfe:cUF/text()',   _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:AAMM/text()',  _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:CNPJ/text()',  _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:CPF/text()',   _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:IE/text()',    _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:mod/text()',   _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:serie/text()', _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refNFP/nfe:nNF/text()',   _r_nf_ref.nfref_node, _ns))[1]::text
            );
        END IF;
        -- refECF (cupom fiscal)
        IF (xpath('nfe:refECF', _r_nf_ref.nfref_node, _ns))[1] IS NOT NULL THEN
            INSERT INTO nota_fiscal.ba01_nf_ref (
                ch_nf,
                mod,
                n_ecf,
                n_coo
            ) VALUES (
                _ch_nf,
                (xpath('nfe:refECF/nfe:mod/text()',  _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refECF/nfe:nECF/text()', _r_nf_ref.nfref_node, _ns))[1]::text,
                (xpath('nfe:refECF/nfe:nCOO/text()', _r_nf_ref.nfref_node, _ns))[1]::text
            );
        END IF;
    END LOOP;

    -- =========================================================================
    -- NV1 | c01_emit_c05_ender — Emitente e endereço completo
    -- =========================================================================
    _step := 'C01_EMIT';

    INSERT INTO nota_fiscal.c01_emit_c05_ender (
        ch_nf,
        cpf_cnpj,
        ie,
        nome,
        fantasia,
        iest,
        im,
        cnae,
        crt,
        "end",
        num,
        compl,
        bairro,
        cod_mun,
        descr_mun,
        uf,
        cep,
        cod_pais,
        descr_pais,
        fone
    )
    SELECT
        _ch_nf,
        _emitente_cpf_cnpj,
        COALESCE((xpath('//nfe:emit/nfe:IE/text()', _xml_content, _ns))[1]::text, ''),
        (xpath('//nfe:emit/nfe:xNome/text()',      _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:xFant/text()',      _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:IEST/text()',       _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:IM/text()',         _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:CNAE/text()',       _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:CRT/text()',        _xml_content, _ns))[1]::text::integer,
        COALESCE((xpath('//nfe:emit/nfe:enderEmit/nfe:xLgr/text()', _xml_content, _ns))[1]::text, ''),
        (xpath('//nfe:emit/nfe:enderEmit/nfe:nro/text()',          _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:enderEmit/nfe:xCpl/text()',         _xml_content, _ns))[1]::text,
        COALESCE((xpath('//nfe:emit/nfe:enderEmit/nfe:xBairro/text()', _xml_content, _ns))[1]::text, ''),
        (xpath('//nfe:emit/nfe:enderEmit/nfe:cMun/text()',         _xml_content, _ns))[1]::text::integer,
        COALESCE((xpath('//nfe:emit/nfe:enderEmit/nfe:xMun/text()', _xml_content, _ns))[1]::text, ''),
        COALESCE((xpath('//nfe:emit/nfe:enderEmit/nfe:UF/text()',   _xml_content, _ns))[1]::text, ''),
        COALESCE((xpath('//nfe:emit/nfe:enderEmit/nfe:CEP/text()',  _xml_content, _ns))[1]::text, ''),
        (xpath('//nfe:emit/nfe:enderEmit/nfe:cPais/text()',        _xml_content, _ns))[1]::text::integer,
        (xpath('//nfe:emit/nfe:enderEmit/nfe:xPais/text()',        _xml_content, _ns))[1]::text,
        (xpath('//nfe:emit/nfe:enderEmit/nfe:fone/text()',         _xml_content, _ns))[1]::text;

    -- =========================================================================
    -- NV1 | e01_dest_e05_ender — Destinatário e endereço (condicional)
    -- Omitido quando não há CPF/CNPJ do destinatário (ex.: NFC-e sem identificação)
    -- =========================================================================
    _step := 'E01_DEST';

    _has_dest :=
        (xpath('//nfe:dest/nfe:CNPJ/text()', _xml_content, _ns))[1] IS NOT NULL OR
        (xpath('//nfe:dest/nfe:CPF/text()',  _xml_content, _ns))[1] IS NOT NULL;

    IF _has_dest THEN
        INSERT INTO nota_fiscal.e01_dest_e05_ender (
            ch_nf,
            cpf_cnpj,
            ie,
            nome,
            fantasia,
            id_estrangeiro,
            ind_ie_dest,
            isuf,
            im,
            email,
            "end",
            num,
            compl,
            bairro,
            cod_mun,
            descr_mun,
            uf,
            cep,
            cod_pais,
            descr_pais,
            fone
        )
        SELECT
            _ch_nf,
            _destinatario_cpf_cnpj,
            COALESCE((xpath('//nfe:dest/nfe:IE/text()', _xml_content, _ns))[1]::text, ''),
            COALESCE((xpath('//nfe:dest/nfe:xNome/text()', _xml_content, _ns))[1]::text, ''),
            (xpath('//nfe:dest/nfe:xFant/text()',         _xml_content, _ns))[1]::text,
            (xpath('//nfe:dest/nfe:idEstrangeiro/text()', _xml_content, _ns))[1]::text,
            COALESCE((xpath('//nfe:dest/nfe:indIEDest/text()', _xml_content, _ns))[1]::text::integer, 9),
            (xpath('//nfe:dest/nfe:ISUF/text()',          _xml_content, _ns))[1]::text,
            (xpath('//nfe:dest/nfe:IM/text()',            _xml_content, _ns))[1]::text,
            (xpath('//nfe:dest/nfe:email/text()',         _xml_content, _ns))[1]::text,
            COALESCE((xpath('//nfe:dest/nfe:enderDest/nfe:xLgr/text()', _xml_content, _ns))[1]::text, ''),
            (xpath('//nfe:dest/nfe:enderDest/nfe:nro/text()',          _xml_content, _ns))[1]::text,
            (xpath('//nfe:dest/nfe:enderDest/nfe:xCpl/text()',         _xml_content, _ns))[1]::text,
            COALESCE((xpath('//nfe:dest/nfe:enderDest/nfe:xBairro/text()', _xml_content, _ns))[1]::text, ''),
            (xpath('//nfe:dest/nfe:enderDest/nfe:cMun/text()',         _xml_content, _ns))[1]::text::integer,
            COALESCE((xpath('//nfe:dest/nfe:enderDest/nfe:xMun/text()', _xml_content, _ns))[1]::text, ''),
            COALESCE((xpath('//nfe:dest/nfe:enderDest/nfe:UF/text()',   _xml_content, _ns))[1]::text, ''),
            COALESCE((xpath('//nfe:dest/nfe:enderDest/nfe:CEP/text()',  _xml_content, _ns))[1]::text, ''),
            (xpath('//nfe:dest/nfe:enderDest/nfe:cPais/text()',        _xml_content, _ns))[1]::text::integer,
            (xpath('//nfe:dest/nfe:enderDest/nfe:xPais/text()',        _xml_content, _ns))[1]::text,
            (xpath('//nfe:dest/nfe:enderDest/nfe:fone/text()',         _xml_content, _ns))[1]::text;
    END IF;

    -- =========================================================================
    -- NV1 | d01_avulsa — NF-e avulsa emitida por órgão da Fazenda (condicional)
    -- =========================================================================
    _step := 'D01_AVULSA';

    _has_avulsa :=
        (xpath('//nfe:avulsa/nfe:CNPJ/text()', _xml_content, _ns))[1] IS NOT NULL;

    IF _has_avulsa THEN
        INSERT INTO nota_fiscal.d01_avulsa (
            ch_nf,
            cnpj,
            descr_orgao,
            matr,
            descr_agente,
            fone,
            uf,
            n_dar,
            dt_doc,
            v_dar,
            rep_emi,
            dt_pag
        )
        SELECT
            _ch_nf,
            (xpath('//nfe:avulsa/nfe:CNPJ/text()',    _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:xOrgao/text()',  _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:matr/text()',    _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:xAgente/text()', _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:fone/text()',    _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:UF/text()',      _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:nDAR/text()',    _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:dEmi/text()',    _xml_content, _ns))[1]::text::date,
            (xpath('//nfe:avulsa/nfe:vDAR/text()',    _xml_content, _ns))[1]::text::numeric(15,2),
            (xpath('//nfe:avulsa/nfe:repEmi/text()',  _xml_content, _ns))[1]::text,
            (xpath('//nfe:avulsa/nfe:dPag/text()',    _xml_content, _ns))[1]::text::date;
    END IF;

    -- =========================================================================
    -- NV1 | i01_prod — Itens da NF-e (loop completo com impostos)
    -- =========================================================================
    _step := 'I01_PROD';

    -- Cache de campos fixos da ide (evita xpath a cada iteração)
    _num_doc := (xpath('//nfe:ide/nfe:nNF/text()', _xml_content, _ns))[1]::text::integer;
    _ser     := (xpath('//nfe:ide/nfe:serie/text()', _xml_content, _ns))[1]::text;
    _cod_mod := (xpath('//nfe:ide/nfe:mod/text()', _xml_content, _ns))[1]::text;

    FOR _r_det IN
        SELECT
            det_node                                                                 AS det_node,
            COALESCE(
                (xpath('@nItem', det_node))[1]::text,
                (xpath('nfe:prod/nfe:nItem/text()', det_node, _ns))[1]::text
            )                                                                       AS num_item,
            (xpath('nfe:prod/nfe:cProd/text()',      det_node, _ns))[1]::text       AS cod_item,
            (xpath('nfe:prod/nfe:xProd/text()',      det_node, _ns))[1]::text       AS descr_item,
            (xpath('nfe:prod/nfe:NCM/text()',        det_node, _ns))[1]::text       AS cod_ncm,
            (xpath('nfe:prod/nfe:EXTIPI/text()',     det_node, _ns))[1]::text       AS ex_ipi,
            (xpath('nfe:prod/nfe:CFOP/text()',       det_node, _ns))[1]::text       AS cfop,
            (xpath('nfe:prod/nfe:uCom/text()',       det_node, _ns))[1]::text       AS unid,
            (xpath('nfe:prod/nfe:vProd/text()',      det_node, _ns))[1]::text       AS v_item,
            (xpath('nfe:prod/nfe:uTrib/text()',      det_node, _ns))[1]::text       AS unid_trib,
            (xpath('nfe:prod/nfe:vFrete/text()',     det_node, _ns))[1]::text       AS v_frt,
            (xpath('nfe:prod/nfe:vSeg/text()',       det_node, _ns))[1]::text       AS v_seg,
            (xpath('nfe:prod/nfe:vDesc/text()',      det_node, _ns))[1]::text       AS v_desc,
            (xpath('nfe:prod/nfe:vOutro/text()',     det_node, _ns))[1]::text       AS v_outro,
            (xpath('nfe:prod/nfe:indTot/text()',     det_node, _ns))[1]::text       AS ind_tot,
            (xpath('nfe:prod/nfe:xPed/text()',       det_node, _ns))[1]::text       AS x_ped,
            (xpath('nfe:prod/nfe:nItemPed/text()',   det_node, _ns))[1]::text       AS num_item_ped,
            (xpath('nfe:prod/nfe:vUnCom/text()',     det_node, _ns))[1]::text       AS v_unit,
            (xpath('nfe:prod/nfe:vUnTrib/text()',    det_node, _ns))[1]::text       AS v_unit_trib,
            (xpath('nfe:prod/nfe:qCom/text()',       det_node, _ns))[1]::text       AS qtd,
            (xpath('nfe:prod/nfe:qTrib/text()',      det_node, _ns))[1]::text       AS qtd_trib,
            (xpath('nfe:prod/nfe:nFCI/text()',       det_node, _ns))[1]::text       AS n_fci,
            (xpath('nfe:prod/nfe:NVE/text()',        det_node, _ns))[1]::text       AS nve,
            (xpath('nfe:prod/nfe:CEST/text()',       det_node, _ns))[1]::text       AS cest,
            (xpath('nfe:prod/nfe:cEAN/text()',       det_node, _ns))[1]::text       AS cod_barra,
            (xpath('nfe:prod/nfe:cBarra/text()',     det_node, _ns))[1]::text       AS cod_barra_not_gtin,
            (xpath('nfe:prod/nfe:cEANTrib/text()',   det_node, _ns))[1]::text       AS cod_barra_trib,
            (xpath('nfe:prod/nfe:cBarraTrib/text()', det_node, _ns))[1]::text       AS cod_barra_trib_not_gtin,
            (xpath('nfe:infAdProd/text()',            det_node, _ns))[1]::text       AS inf_ad_prod,
            (xpath('nfe:prod/nfe:indEscala/text()',  det_node, _ns))[1]::text       AS ind_escala,
            (xpath('nfe:prod/nfe:CNPJFab/text()',    det_node, _ns))[1]::text       AS cnpj_fab,
            (xpath('nfe:prod/nfe:cBenef/text()',     det_node, _ns))[1]::text       AS c_benef,
            (xpath('nfe:imposto/nfe:vTotTrib/text()', det_node, _ns))[1]::text      AS v_tot_trib
        FROM unnest(xpath('//nfe:det', _xml_content, _ns)) AS det_node
    LOOP
        IF _r_det.cod_item IS NULL THEN
            CONTINUE;
        END IF;

        -- Validação de segurança: num_item deve conter apenas dígitos
        IF _r_det.num_item IS NULL OR _r_det.num_item !~ '^\d+$' THEN
            CONTINUE;
        END IF;

        _item_count := _item_count + 1;

        -- =================================================================
        -- INSERT i01_prod
        -- =================================================================
        INSERT INTO nota_fiscal.i01_prod (
            ch_nf,
            num_item,
            cod_item,
            num_doc,
            ser,
            cod_mod,
            descr_item,
            cod_ncm,
            ex_ipi,
            cfop,
            unid,
            v_item,
            unid_trib,
            v_frt,
            v_seg,
            v_desc,
            v_outro,
            ind_tot,
            x_ped,
            num_item_ped,
            v_unit,
            v_unit_trib,
            qtd,
            qtd_trib,
            n_fci,
            nve,
            cest,
            cod_barra,
            cod_barra_not_gtin,
            cod_barra_trib,
            cod_barra_trib_not_gtin,
            inf_ad_prod,
            ind_escala,
            cnpj_fab,
            c_benef,
            v_tot_trib
        ) VALUES (
            _ch_nf,
            _r_det.num_item,
            _r_det.cod_item,
            _num_doc,
            _ser,
            _cod_mod,
            _r_det.descr_item,
            COALESCE(_r_det.cod_ncm, ''),
            COALESCE(_r_det.ex_ipi, ''),
            _r_det.cfop,
            _r_det.unid,
            _r_det.v_item::numeric,
            _r_det.unid_trib,
            COALESCE(_r_det.v_frt::numeric, 0.00),
            COALESCE(_r_det.v_seg::numeric, 0.00),
            COALESCE(_r_det.v_desc::numeric, 0.00),
            COALESCE(_r_det.v_outro::numeric, 0.00),
            _r_det.ind_tot::integer,
            _r_det.x_ped,
            _r_det.num_item_ped,
            _r_det.v_unit,
            COALESCE(_r_det.v_unit_trib::numeric, 0.00),
            _r_det.qtd::numeric,
            COALESCE(_r_det.qtd_trib::numeric, 0.00),
            COALESCE(_r_det.n_fci, ''),
            COALESCE(_r_det.nve, ''),
            _r_det.cest,
            CASE WHEN _r_det.cod_barra = 'SEM GTIN' OR _r_det.cod_barra IS NULL THEN '' ELSE _r_det.cod_barra END,
            _r_det.cod_barra_not_gtin,
            CASE WHEN _r_det.cod_barra_trib = 'SEM GTIN' OR _r_det.cod_barra_trib IS NULL THEN '' ELSE _r_det.cod_barra_trib END,
            _r_det.cod_barra_trib_not_gtin,
            _r_det.inf_ad_prod,
            _r_det.ind_escala,
            _r_det.cnpj_fab,
            _r_det.c_benef,
            _r_det.v_tot_trib::numeric
        );

        -- =================================================================
        -- NV2 | n01_icms — ICMS por item
        -- =================================================================
        INSERT INTO nota_fiscal.n01_icms (
            ch_nf,
            num_item,
            orig,
            cst,
            cso_sn,
            p_cred_sn,
            v_cred_icms_sn,
            mod_bc,
            mod_bc_st,
            p_red_bc,
            p_red_bc_st,
            p_mva_st,
            v_bc,
            v_bc_st,
            v_bc_st_ret,
            p_icms,
            v_icms,
            p_icms_st,
            v_icms_st,
            v_icms_st_ret,
            mot_des_icms,
            p_bc_op,
            v_icms_deson,
            v_icms_op,
            p_dif,
            v_icms_dif,
            p_st,
            uf_st,
            v_bc_st_dest,
            v_icms_st_dest,
            v_bc_fcp,
            p_fcp,
            v_bc_fcp_st,
            p_fcp_st,
            v_fcp_st,
            v_bc_fcp_st_ret,
            p_fcp_st_ret,
            v_fcp_st_ret,
            v_fcp,
            v_icms_substituto,
            p_red_bc_efet,
            v_bc_efet,
            p_icms_efet,
            v_icms_efet
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            ((xpath('nfe:imposto/nfe:ICMS/*/nfe:orig/text()', _r_det.det_node, _ns))[1]::text)::int,
            LPAD((xpath('nfe:imposto/nfe:ICMS/*/nfe:CST/text()', _r_det.det_node, _ns))[1]::text, 3, '0'),
            LPAD((xpath('nfe:imposto/nfe:ICMS/*/nfe:CSOSN/text()', _r_det.det_node, _ns))[1]::text, 3, '0'),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pCredSN/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vCredICMSSN/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:ICMS/*/nfe:modBC/text()', _r_det.det_node, _ns))[1]::text)::int,
            ((xpath('nfe:imposto/nfe:ICMS/*/nfe:modBCST/text()', _r_det.det_node, _ns))[1]::text)::int,
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pRedBC/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pRedBCST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pMVAST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCSTRet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pICMS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pICMSST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSSTRet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:ICMS/*/nfe:motDesICMS/text()', _r_det.det_node, _ns))[1]::text)::int,
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pBCOp/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSDeson/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSOp/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pDif/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSDif/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            (xpath('nfe:imposto/nfe:ICMS/*/nfe:UFST/text()', _r_det.det_node, _ns))[1]::text,
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCSTDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSSTDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCFCP/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pFCP/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCFCPST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pFCPST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vFCPST/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCFCPSTRet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pFCPSTRet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vFCPSTRet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vFCP/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSSubstituto/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pRedBCEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vBCEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:pICMSEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMS/*/nfe:vICMSEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0)
        WHERE
            (xpath('nfe:imposto/nfe:ICMS/*/nfe:orig/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | o01_ipi — IPI por item
        -- =================================================================
        INSERT INTO nota_fiscal.o01_ipi (
            ch_nf,
            num_item,
            v_bc,
            p_ipi,
            q_unid,
            v_unid,
            v_ipi,
            cl_enq,
            cnpj_prod,
            c_selo,
            q_selo,
            c_enq
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            COALESCE(((xpath('nfe:imposto/nfe:IPI/*/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IPI/*/nfe:pIPI/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IPI/*/nfe:qUnid/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IPI/*/nfe:vUnid/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IPI/*/nfe:vIPI/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            (xpath('nfe:imposto/nfe:IPI/*/nfe:clEnq/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IPI/*/nfe:CNPJProd/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IPI/*/nfe:cSelo/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IPI/*/nfe:qSelo/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IPI/*/nfe:cEnq/text()', _r_det.det_node, _ns))[1]::text
        WHERE
            (xpath('nfe:imposto/nfe:IPI/*/nfe:CST/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | p01_ii — II por item
        -- =================================================================
        INSERT INTO nota_fiscal.p01_ii (
            ch_nf,
            num_item,
            v_bc,
            v_desp_adu,
            v_ii,
            v_iof
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            COALESCE(((xpath('nfe:imposto/nfe:II/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:II/nfe:vDespAdu/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:II/nfe:vII/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:II/nfe:vIOF/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0)
        WHERE
            (xpath('nfe:imposto/nfe:II/nfe:vBC/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | q01_pis_s01_cofins — PIS/COFINS por item
        -- =================================================================
        INSERT INTO nota_fiscal.q01_pis_s01_cofins (
            ch_nf,
            num_item,
            cst_pis,
            quant_bc_pis,
            aliq_pis_quant,
            v_bc_pis,
            aliq_pis,
            v_pis,
            cst_cofins,
            quant_bc_cofins,
            aliq_cofins_quant,
            v_bc_cofins,
            aliq_cofins,
            v_cofins
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            (xpath('nfe:imposto/nfe:PIS/*/nfe:CST/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:PIS/*/nfe:qBCProd/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:PIS/*/nfe:vAliqProd/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:PIS/*/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:PIS/*/nfe:pPIS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:PIS/*/nfe:vPIS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            (xpath('nfe:imposto/nfe:COFINS/*/nfe:CST/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:COFINS/*/nfe:qBCProd/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:COFINS/*/nfe:vAliqProd/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:COFINS/*/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:COFINS/*/nfe:pCOFINS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:COFINS/*/nfe:vCOFINS/text()', _r_det.det_node, _ns))[1]::text)::numeric
        WHERE
            (xpath('nfe:imposto/nfe:PIS/*/nfe:CST/text()', _r_det.det_node, _ns))[1] IS NOT NULL
            OR (xpath('nfe:imposto/nfe:COFINS/*/nfe:CST/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | ua01_imposto_devol_ua03_ipi — Imposto devolvido por item
        -- =================================================================
        INSERT INTO nota_fiscal.ua01_imposto_devol_ua03_ipi (
            ch_nf,
            num_item,
            p_devol,
            v_ipi_devol
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            COALESCE(((xpath('nfe:impostoDevol/nfe:pDevol/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:impostoDevol/nfe:IPI/nfe:vIPIDevol/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0)
        WHERE
            (xpath('nfe:impostoDevol/nfe:pDevol/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | na01_icms_uf_dest — ICMS interestadual por item
        -- =================================================================
        INSERT INTO nota_fiscal.na01_icms_uf_dest (
            ch_nf,
            num_item,
            v_bc_uf_dest,
            p_fcp_uf_dest,
            p_icms_uf_dest,
            p_icms_inter,
            p_icms_inter_part,
            v_fcp_uf_dest,
            v_icms_uf_dest,
            v_icms_uf_remet
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:vBCUFDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:pFCPUFDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:pICMSUFDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:pICMSInter/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:pICMSInterPart/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:vFCPUFDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:vICMSUFDest/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:ICMSUFDest/nfe:vICMSUFRemet/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0)
        WHERE
            (xpath('nfe:imposto/nfe:ICMSUFDest/nfe:vBCUFDest/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | ub01_is — Imposto Seletivo por item (Reforma Tributária)
        -- =================================================================
        INSERT INTO nota_fiscal.ub01_is (
            ch_nf,
            num_item,
            cst_is,
            c_class_trib_is,
            v_bc_is,
            p_is,
            p_is_espec,
            u_trib,
            q_trib,
            v_is
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            (xpath('nfe:imposto/nfe:IS/nfe:CSTIS/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IS/nfe:cClassTribIS/text()', _r_det.det_node, _ns))[1]::text,
            COALESCE(((xpath('nfe:imposto/nfe:IS/nfe:vBCIS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IS/nfe:pIS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:IS/nfe:pISEspec/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            (xpath('nfe:imposto/nfe:IS/nfe:uTrib/text()', _r_det.det_node, _ns))[1]::text,
            COALESCE(((xpath('nfe:imposto/nfe:IS/nfe:qTrib/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IS/nfe:vIS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0)
        WHERE
            (xpath('nfe:imposto/nfe:IS/nfe:CSTIS/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

        -- =================================================================
        -- NV2 | ub12_ibs_cbs — IBS/CBS por item (Reforma Tributária)
        -- =================================================================
        INSERT INTO nota_fiscal.ub12_ibs_cbs (
            ch_nf,
            num_item,
            cst,
            c_class_trib,
            ind_doacao,
            v_bc,
            -- gIBSUF
            p_ibs_uf,
            p_dif_ibs,
            v_dif_ibs,
            v_dev_trib_ibs,
            p_red_aliq_ibs,
            p_aliq_efet_ibs,
            v_ibs_uf,
            -- gIBSMun
            p_ibs_mun,
            p_dif_ibs_mun,
            v_dif_ibs_mun,
            v_dev_trib_ibs_mun,
            p_red_aliq_ibs_mun,
            p_aliq_efet_ibs_mun,
            v_ibs_mun,
            v_ibs,
            -- gCBS
            p_cbs,
            p_dif_cbs,
            v_dif_cbs,
            v_dev_trib_cbs,
            p_red_aliq_cbs,
            p_aliq_efet_cbs,
            v_cbs,
            -- Regime específico
            cst_reg,
            c_class_trib_reg,
            p_aliq_efet_reg_ibs_uf,
            v_trib_reg_ibs_uf,
            p_aliq_efet_reg_ibs_mun,
            v_trib_reg_ibs_mun,
            p_aliq_efet_reg_cbs,
            v_trib_reg_cbs,
            -- Alíquotas e valores tributados (geral)
            p_aliq_ibs_uf,
            v_trib_ibs_uf,
            p_aliq_ibs_mun,
            v_trib_ibs_mun,
            p_aliq_cbs,
            v_trib_cbs,
            -- Monofásico
            q_bc_mono,
            ad_rem_ibs,
            ad_rem_cbs,
            v_ibs_mono,
            v_cbs_mono,
            -- Monofásico retenção
            q_bc_mono_reten,
            ad_rem_ibs_reten,
            v_ibs_mono_reten,
            ad_rem_cbs_reten,
            v_cbs_mono_reten,
            -- Monofásico retido
            q_bc_mono_ret,
            ad_rem_ibs_ret,
            v_ibs_mono_ret,
            ad_rem_cbs_ret,
            v_cbs_mono_ret,
            -- Monofásico diferimento
            p_dif_ibs_mono,
            v_ibs_mono_dif,
            p_dif_cbs_mono,
            v_cbs_mono_dif,
            -- Totais monofásico item
            v_tot_ibs_mono_item,
            v_tot_cbs_mono_item,
            -- Transferência de crédito
            v_ibs_trans_cred,
            v_cbs_trans_cred,
            -- Ajuste de competência
            compet_apur_ajuste_compet,
            v_ibs_ajuste_compet,
            v_cbs_ajuste_compet,
            -- Estorno de crédito
            v_ibs_est_cred,
            v_cbs_est_cred,
            -- Crédito presumido
            v_bc_cred_pres,
            c_cred_pres,
            p_cred_pres_ibs,
            v_cred_pres_ibs,
            v_cred_pres_cond_sus_ibs,
            p_cred_pres_cbs,
            v_cred_pres_cbs,
            v_cred_pres_cond_sus_cbs,
            -- ZFM
            compet_apur_ibs_zfm,
            tp_cred_pres_ibs_zfm,
            v_cred_pres_ibs_zfm
        )
        SELECT
            _ch_nf,
            _r_det.num_item,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:CST/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:cClassTrib/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:indDoacao/text()', _r_det.det_node, _ns))[1]::text,
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vBC/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            -- gIBSUF
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:pIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:gDif/nfe:pDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:gDif/nfe:vDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:gDevTrib/nfe:vDevTrib/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:gRed/nfe:pRedAliq/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:pAliqEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSUF/nfe:vIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            -- gIBSMun
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:pIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:gDif/nfe:pDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:gDif/nfe:vDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:gDevTrib/nfe:vDevTrib/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:gRed/nfe:pRedAliq/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:pAliqEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSMun/nfe:vIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vIBS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            -- gCBS
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:pCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:gDif/nfe:pDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:gDif/nfe:vDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:gDevTrib/nfe:vDevTrib/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:gRed/nfe:pRedAliq/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:pAliqEfet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            COALESCE(((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCBS/nfe:vCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric, 0),
            -- Regime específico
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:CSTReg/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:cClassTribReg/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:pAliqEfetRegIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:vTribRegIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:pAliqEfetRegIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:vTribRegIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:pAliqEfetRegCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gRegEspec/nfe:vTribRegCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Alíquotas e valores tributados (geral)
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:pAliqIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vTribIBSUF/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:pAliqIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vTribIBSMun/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:pAliqCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vTribCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Monofásico
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMono/nfe:qBCMono/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMono/nfe:adRemIBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMono/nfe:adRemCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMono/nfe:vIBSMono/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMono/nfe:vCBSMono/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Monofásico retenção
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoReten/nfe:qBCMonoReten/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoReten/nfe:adRemIBSReten/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoReten/nfe:vIBSMonoReten/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoReten/nfe:adRemCBSReten/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoReten/nfe:vCBSMonoReten/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Monofásico retido
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoRet/nfe:qBCMonoRet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoRet/nfe:adRemIBSRet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoRet/nfe:vIBSMonoRet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoRet/nfe:adRemCBSRet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoRet/nfe:vCBSMonoRet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Monofásico diferimento
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoDif/nfe:pDifIBSMono/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoDif/nfe:vIBSMonoDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoDif/nfe:pDifCBSMono/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gMonoDif/nfe:vCBSMonoDif/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Totais monofásico item
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vTotIBSMonoItem/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:vTotCBSMonoItem/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Transferência de crédito
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gTransCred/nfe:vIBSTransCred/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gTransCred/nfe:vCBSTransCred/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Ajuste de competência
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gAjusteCompet/nfe:competApurAjusteCompet/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gAjusteCompet/nfe:vIBSAjusteCompet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gAjusteCompet/nfe:vCBSAjusteCompet/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Estorno de crédito
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gEstCred/nfe:vIBSEstCred/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gEstCred/nfe:vCBSEstCred/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- Crédito presumido
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:vBCCredPres/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:cCredPres/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:pCredPresIBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:vCredPresIBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:vCredPresCondSusIBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:pCredPresCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:vCredPresCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gCredPres/nfe:vCredPresCondSusCBS/text()', _r_det.det_node, _ns))[1]::text)::numeric,
            -- ZFM
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSZFM/nfe:competApurIBSZFM/text()', _r_det.det_node, _ns))[1]::text,
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSZFM/nfe:tpCredPresIBSZFM/text()', _r_det.det_node, _ns))[1]::text,
            ((xpath('nfe:imposto/nfe:IBSCBSg/nfe:gIBSZFM/nfe:vCredPresIBSZFM/text()', _r_det.det_node, _ns))[1]::text)::numeric
        WHERE
            (xpath('nfe:imposto/nfe:IBSCBSg/nfe:CST/text()', _r_det.det_node, _ns))[1] IS NOT NULL;

    END LOOP;
    -- FIM LOOP i01_prod

    -- =========================================================================
    -- NV1 | w02_icms_tot — Totais ICMS da NF-e
    -- =========================================================================
    _step := 'W02_ICMS_TOT';

    INSERT INTO nota_fiscal.w02_icms_tot (
        ch_nf,
        v_bc,
        v_icms,
        v_bc_st,
        v_st,
        v_prod,
        v_frete,
        v_seg,
        v_desc,
        v_ii,
        v_ipi,
        v_pis,
        v_cofins,
        v_outro,
        v_nf,
        v_tot_trib,
        v_icms_deson,
        v_fcp_uf_dest,
        v_icms_uf_dest,
        v_icms_uf_remet,
        v_fcp,
        v_fcp_st,
        v_fcp_st_ret,
        v_ipi_devol
    )
    SELECT
        _ch_nf,
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vBC/text()',          _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vICMS/text()',        _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vBCST/text()',        _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vST/text()',          _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vProd/text()',        _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vFrete/text()',       _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vSeg/text()',         _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vDesc/text()',        _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vII/text()',          _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vIPI/text()',         _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vPIS/text()',         _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vCOFINS/text()',      _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vOutro/text()',       _xml_content, _ns))[1]::text)::numeric, 0),
        COALESCE(((xpath('//nfe:total/nfe:ICMSTot/nfe:vNF/text()',          _xml_content, _ns))[1]::text)::numeric, 0),
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vTotTrib/text()',              _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vICMSDeson/text()',            _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vFCPUFDest/text()',            _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vICMSUFDest/text()',           _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vICMSUFRemet/text()',          _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vFCP/text()',                  _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vFCPST/text()',                _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vFCPSTRet/text()',             _xml_content, _ns))[1]::text)::numeric,
        ((xpath('//nfe:total/nfe:ICMSTot/nfe:vIPIDevol/text()',             _xml_content, _ns))[1]::text)::numeric;

    -- =========================================================================
    -- NV1 | w17_issqn_tot — Totais ISSQN (condicional: somente se dt_compet existe)
    -- =========================================================================
    _step := 'W17_ISSQN_TOT';

    IF (xpath('//nfe:total/nfe:ISSQNtot/nfe:dCompet/text()', _xml_content, _ns))[1] IS NOT NULL THEN
        INSERT INTO nota_fiscal.w17_issqn_tot (
            ch_nf,
            v_serv,
            v_bc,
            v_iss,
            v_pis,
            v_cofins,
            dt_compet,
            v_deducao,
            v_outro,
            v_desc_incond,
            v_desc_cond,
            v_iss_ret,
            c_reg_trib
        )
        SELECT
            _ch_nf,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vServ/text()',        _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vBC/text()',          _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vISS/text()',         _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vPIS/text()',         _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vCOFINS/text()',      _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:dCompet/text()',      _xml_content, _ns))[1]::text)::date,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vDeducao/text()',     _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vOutro/text()',       _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vDescIncond/text()',  _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vDescCond/text()',    _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:vISSRet/text()',      _xml_content, _ns))[1]::text)::numeric,
            ((xpath('//nfe:total/nfe:ISSQNtot/nfe:cRegTrib/text()',     _xml_content, _ns))[1]::text)::integer;
    END IF;

    -- =========================================================================
    -- NV1 | w23_ret_trib — Retenções de tributos federais (condicional)
    -- =========================================================================
    _step := 'W23_RET_TRIB';

    IF (xpath('//nfe:total/nfe:retTrib/nfe:vRetPIS/text()', _xml_content, _ns))[1] IS NOT NULL
       OR (xpath('//nfe:total/nfe:retTrib/nfe:vRetCOFINS/text()', _xml_content, _ns))[1] IS NOT NULL
       OR (xpath('//nfe:total/nfe:retTrib/nfe:vRetCSLL/text()', _xml_content, _ns))[1] IS NOT NULL
       OR (xpath('//nfe:total/nfe:retTrib/nfe:vIRRF/text()', _xml_content, _ns))[1] IS NOT NULL
    THEN
        INSERT INTO nota_fiscal.w23_ret_trib (
            ch_nf,
            v_ret_pis,
            v_ret_cofins,
            v_ret_csll,
            v_bc_irrf,
            v_irrf,
            v_bc_ret_prev,
            v_ret_prev
        )
        SELECT
            _ch_nf,
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vRetPIS/text()',    _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vRetCOFINS/text()', _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vRetCSLL/text()',   _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vBCIRRF/text()',    _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vIRRF/text()',      _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vBCRetPrev/text()', _xml_content, _ns))[1]::text)::numeric, 0),
            COALESCE(((xpath('//nfe:total/nfe:retTrib/nfe:vRetPrev/text()',   _xml_content, _ns))[1]::text)::numeric, 0);
    END IF;

    -- =========================================================================
    -- NV1 | z01_inf_adic — Informações adicionais (condicional)
    --   NV2 | z04_obs_cont  — Observações do contribuinte
    --   NV2 | z07_obs_fisco — Observações do fisco
    -- =========================================================================
    _step := 'Z01_INF_ADIC';

    IF (xpath('//nfe:infAdic/nfe:infAdFisco/text()', _xml_content, _ns))[1] IS NOT NULL
       OR (xpath('//nfe:infAdic/nfe:infCpl/text()', _xml_content, _ns))[1] IS NOT NULL
    THEN
        INSERT INTO nota_fiscal.z01_inf_adic (
            ch_nf,
            inf_ad_fisco,
            inf_cpl
        )
        VALUES (
            _ch_nf,
            (xpath('//nfe:infAdic/nfe:infAdFisco/text()', _xml_content, _ns))[1]::text,
            (xpath('//nfe:infAdic/nfe:infCpl/text()',     _xml_content, _ns))[1]::text
        )
        RETURNING id_inf_adic INTO _id_inf_adic;

        -- z04_obs_cont — Observações do contribuinte
        IF _id_inf_adic IS NOT NULL THEN
            FOR _r_obs IN
                SELECT
                    unnest(xpath('//nfe:infAdic/nfe:obsCont/@xCampo', _xml_content, _ns))::text AS x_campo,
                    unnest(xpath('//nfe:infAdic/nfe:obsCont/nfe:xTexto/text()', _xml_content, _ns))::text AS x_texto
            LOOP
                IF _r_obs.x_texto IS NOT NULL THEN
                    INSERT INTO nota_fiscal.z04_obs_cont (
                        ch_nf,
                        id_inf_adic,
                        x_campo,
                        x_texto
                    ) VALUES (
                        _ch_nf,
                        _id_inf_adic,
                        _r_obs.x_campo,
                        _r_obs.x_texto
                    )
                    ON CONFLICT (ch_nf, x_texto) DO NOTHING;
                END IF;
            END LOOP;

            -- z07_obs_fisco — Observações do fisco
            FOR _r_obs IN
                SELECT
                    unnest(xpath('//nfe:infAdic/nfe:obsFisco/@xCampo', _xml_content, _ns))::text AS x_campo,
                    unnest(xpath('//nfe:infAdic/nfe:obsFisco/nfe:xTexto/text()', _xml_content, _ns))::text AS x_texto
            LOOP
                IF _r_obs.x_texto IS NOT NULL THEN
                    INSERT INTO nota_fiscal.z07_obs_fisco (
                        ch_nf,
                        id_inf_adic,
                        x_campo,
                        x_texto
                    ) VALUES (
                        _ch_nf,
                        _id_inf_adic,
                        _r_obs.x_campo,
                        _r_obs.x_texto
                    )
                    ON CONFLICT (ch_nf, x_campo) DO NOTHING;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- =========================================================================
    -- NV1 | pr03_inf_prot — Protocolo de autorização SEFAZ (condicional)
    -- =========================================================================
    _step := 'PR03_INF_PROT';

    IF (xpath('//nfe:protNFe/nfe:infProt/nfe:cStat/text()', _xml_content, _ns))[1] IS NOT NULL THEN
        INSERT INTO nota_fiscal.pr03_inf_prot (
            ch_nf,
            tp_amb,
            ch_nfe,
            dh_recbto,
            n_prot,
            dig_val,
            c_stat,
            x_motivo
        )
        SELECT
            _ch_nf,
            ((xpath('//nfe:protNFe/nfe:infProt/nfe:tpAmb/text()',    _xml_content, _ns))[1]::text)::integer,
            (xpath('//nfe:protNFe/nfe:infProt/nfe:chNFe/text()',     _xml_content, _ns))[1]::text,
            ((xpath('//nfe:protNFe/nfe:infProt/nfe:dhRecbto/text()', _xml_content, _ns))[1]::text)::timestamptz,
            (xpath('//nfe:protNFe/nfe:infProt/nfe:nProt/text()',     _xml_content, _ns))[1]::text,
            (xpath('//nfe:protNFe/nfe:infProt/nfe:digVal/text()',    _xml_content, _ns))[1]::text,
            ((xpath('//nfe:protNFe/nfe:infProt/nfe:cStat/text()',    _xml_content, _ns))[1]::text)::integer,
            (xpath('//nfe:protNFe/nfe:infProt/nfe:xMotivo/text()',   _xml_content, _ns))[1]::text;
    END IF;

    -- =========================================================================
    -- NV1 | y07_dup — Duplicatas de cobrança (condicional, múltiplas)
    -- =========================================================================
    _step := 'Y07_DUP';

    FOR _r_dup IN
        SELECT unnest(xpath('//nfe:cobr/nfe:dup', _xml_content, _ns)) AS dup_node
    LOOP
        INSERT INTO nota_fiscal.y07_dup (
            ch_nf,
            n_dup,
            dt_venc,
            v_dup
        )
        SELECT
            _ch_nf,
            (xpath('nfe:nDup/text()',  _r_dup.dup_node, _ns))[1]::text,
            ((xpath('nfe:dVenc/text()', _r_dup.dup_node, _ns))[1]::text)::date,
            ((xpath('nfe:vDup/text()',  _r_dup.dup_node, _ns))[1]::text)::numeric
        WHERE
            (xpath('nfe:vDup/text()', _r_dup.dup_node, _ns))[1] IS NOT NULL;
    END LOOP;

    -- =========================================================================
    -- NV1 | ya01_pag — Grupo de pagamento (header)
    --   NV2 | ya01a_det_pag — Detalhamento de cada forma de pagamento
    --   NV3 | ya04_card     — Dados de cartão de crédito/débito
    -- Hierarquia: pag → detPag → card (com IDs surrogate para manter relação)
    -- =========================================================================
    _step := 'YA01_PAG';

    -- Inserir header do pagamento e obter id_pag
    IF (xpath('//nfe:pag', _xml_content, _ns))[1] IS NOT NULL THEN
        INSERT INTO nota_fiscal.ya01_pag (
            ch_nf,
            cnpj_pag,
            uf_pag,
            v_troco
        )
        VALUES (
            _ch_nf,
            (xpath('//nfe:pag/nfe:CNPJPag/text()', _xml_content, _ns))[1]::text,
            (xpath('//nfe:pag/nfe:UFPag/text()',   _xml_content, _ns))[1]::text,
            ((xpath('//nfe:pag/nfe:vTroco/text()', _xml_content, _ns))[1]::text)::numeric
        )
        RETURNING id_pag INTO _id_pag;

        -- Loop em cada detPag dentro do grupo pag
        FOR _r_det_pag IN
            SELECT unnest(xpath('//nfe:pag/nfe:detPag', _xml_content, _ns)) AS det_pag_node
        LOOP
            -- Inserir detalhamento de pagamento
            INSERT INTO nota_fiscal.ya01a_det_pag (
                id_pag,
                ch_nf,
                ind_pag,
                t_pag,
                x_pag,
                v_pag,
                dt_pag
            )
            SELECT
                _id_pag,
                _ch_nf,
                ((xpath('nfe:indPag/text()', _r_det_pag.det_pag_node, _ns))[1]::text)::integer,
                COALESCE((xpath('nfe:tPag/text()', _r_det_pag.det_pag_node, _ns))[1]::text, '90'),
                (xpath('nfe:xPag/text()',  _r_det_pag.det_pag_node, _ns))[1]::text,
                ((xpath('nfe:vPag/text()', _r_det_pag.det_pag_node, _ns))[1]::text)::numeric,
                ((xpath('nfe:dPag/text()', _r_det_pag.det_pag_node, _ns))[1]::text)::date
            WHERE
                (xpath('nfe:vPag/text()', _r_det_pag.det_pag_node, _ns))[1] IS NOT NULL
            RETURNING id_det_pag INTO _id_det_pag;

            -- Inserir dados de cartão se existirem (NV3)
            IF _id_det_pag IS NOT NULL
               AND (xpath('nfe:card/nfe:tpIntegra/text()', _r_det_pag.det_pag_node, _ns))[1] IS NOT NULL
            THEN
                INSERT INTO nota_fiscal.ya04_card (
                    id_det_pag,
                    ch_nf,
                    tp_integra,
                    cnpj,
                    t_band,
                    c_aut,
                    cnpj_receb,
                    id_term_pag
                )
                VALUES (
                    _id_det_pag,
                    _ch_nf,
                    ((xpath('nfe:card/nfe:tpIntegra/text()',  _r_det_pag.det_pag_node, _ns))[1]::text)::integer,
                    (xpath('nfe:card/nfe:CNPJ/text()',        _r_det_pag.det_pag_node, _ns))[1]::text,
                    (xpath('nfe:card/nfe:tBand/text()',       _r_det_pag.det_pag_node, _ns))[1]::text,
                    (xpath('nfe:card/nfe:cAut/text()',        _r_det_pag.det_pag_node, _ns))[1]::text,
                    (xpath('nfe:card/nfe:CNPJReceb/text()',   _r_det_pag.det_pag_node, _ns))[1]::text,
                    (xpath('nfe:card/nfe:idTermPag/text()',   _r_det_pag.det_pag_node, _ns))[1]::text
                );
            END IF;
        END LOOP;
    END IF;

    _step := 'FINALIZING';

    RETURN jsonb_build_object(
        'success',            true,
        'ch_nf',              _ch_nf,
        'has_dest',           _has_dest,
        'has_avulsa',         _has_avulsa,
        'has_nf_ref',         _has_nf_ref,
        'items_processed',    _item_count,
        'processing_time_ms', ROUND(EXTRACT(epoch FROM (clock_timestamp() - _start_time)) * 1000, 2)
    );

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[fn_destructure_xml] Step=%, xml_id=%, ch_nf=%, SQLSTATE=%, SQLERRM=%',
        _step, _xml_id, _ch_nf, SQLSTATE, SQLERRM;

    RETURN jsonb_build_object(
        'success',    false,
        'step',       _step,
        'error_code', SQLSTATE,
        'message',    SQLERRM,
        'xml_id',     _xml_id,
        'ch_nf',      _ch_nf
    );
END;
$$;

COMMENT ON FUNCTION xml.fn_destructure_xml_to_nota_fiscal_record(bigint, boolean)
IS 'Desestrutura NF-e/NFC-e de xml.xml_storage para o schema nota_fiscal. '
   'v4: xpath relativo por item (performance), validação de num_item, cache de ide, '
   'RAISE WARNING em erros. Cobre b01_ide, ba01_nf_ref, c01_emit_c05_ender, '
   'e01_dest_e05_ender, d01_avulsa, i01_prod (n01_icms, o01_ipi, p01_ii, '
   'q01_pis_s01_cofins, ua01_imposto_devol_ua03_ipi, na01_icms_uf_dest, ub01_is, '
   'ub12_ibs_cbs), w02_icms_tot, w17_issqn_tot, w23_ret_trib, z01_inf_adic '
   '(z04_obs_cont, z07_obs_fisco), pr03_inf_prot, y07_dup, ya01_pag '
   '(ya01a_det_pag, ya04_card). '
   'Fonte: xml.xml_storage.xml_content. Namespace: http://www.portalfiscal.inf.br/nfe.';