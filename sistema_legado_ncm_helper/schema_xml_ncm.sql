--
-- PostgreSQL database dump
--

-- Dumped from database version 13.16 (Ubuntu 13.16-1.pgdg24.04+1)
-- Dumped by pg_dump version 17.5

-- Started on 2026-09-09 18:14:14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 290 (class 2615 OID 527855992)
-- Name: xml; Type: SCHEMA; Schema: -; Owner: dorcilio
--

CREATE SCHEMA xml;


ALTER SCHEMA xml OWNER TO dorcilio;

--
-- TOC entry 3659 (class 1255 OID 534943074)
-- Name: desestruturar_all_xml(); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.desestruturar_all_xml() RETURNS void
    LANGUAGE plpgsql
    AS $$
/*
===================================================================================
FUNÇÃO: xml.desestruturar_all_xml
===================================================================================
Objetivo:
    Processa TODOS os XMLs em xml.nfe_nfce que ainda não foram desestruturados
    (não existem em nfe.raiz_nfe).

Uso:
    BEGIN;
    SELECT * FROM xml.desestruturar_all_xml();
    COMMIT;

CORREÇÃO 2026-08-27: Removida referência a protocolo_id (sistema migrado para import_job).
===================================================================================
*/
DECLARE
    r_nfe_nfce RECORD;
BEGIN
    FOR r_nfe_nfce IN
    (
        SELECT
            a.xml_id,
            a.ch_nf,
            a.import_job_id,
            a.criado_em
        FROM
        (
            SELECT
                a.xml_id,
                ch_nf,
                SUBSTRING(ch_nf, 7, 14)::VARCHAR(14) AS cpf_cnpj,
                (SUBSTRING(ch_nf, 26, 9)::VARCHAR(9))::INTEGER AS n_nf,
                ((SUBSTRING(ch_nf, 23, 3)::VARCHAR(3))::INTEGER)::VARCHAR(3) AS ser,
                SUBSTRING(ch_nf, 21, 2)::VARCHAR(2) AS mod,
                import_job_id,
                criado_em
            FROM xml.nfe_nfce a
            LEFT JOIN nfe.raiz_nfe b ON a.ch_nf = b.inf_nfe
            WHERE b.id_nfe IS NULL
        ) AS a
        LEFT JOIN nfe.raiz_nfe b USING(cpf_cnpj, n_nf, ser, mod)
        WHERE b.id_nfe IS NULL
        ORDER BY criado_em ASC
    ) LOOP
        RAISE NOTICE 'DESESTRUTURANDO |ID|CHAVE|JOB|DATA| - |%|%|%|%|', 
            r_nfe_nfce.xml_id, 
            r_nfe_nfce.ch_nf, 
            COALESCE(r_nfe_nfce.import_job_id::TEXT, 'N/A'), 
            to_char(r_nfe_nfce.criado_em, 'DD/MM/YYYY HH24:MI:SS');
        
        PERFORM xml.desestruturar_xml_nfe_nfce(r_nfe_nfce.xml_id, FALSE);
    END LOOP;
END;
$$;


ALTER FUNCTION xml.desestruturar_all_xml() OWNER TO dorcilio;

--
-- TOC entry 12186 (class 0 OID 0)
-- Dependencies: 3659
-- Name: FUNCTION desestruturar_all_xml(); Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON FUNCTION xml.desestruturar_all_xml() IS 'Processa TODOS os XMLs pendentes em xml.nfe_nfce que não existem em nfe.raiz_nfe.
CORREÇÃO 2026-08-27: Migrado de protocolo_id para import_job_id.';


--
-- TOC entry 3690 (class 1255 OID 562291825)
-- Name: desestruturar_all_xml_sefaz(integer, date, date); Type: FUNCTION; Schema: xml; Owner: celismar
--

CREATE FUNCTION xml.desestruturar_all_xml_sefaz(empresa integer, dt_inicial date, dt_final date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
/*
===================================================================================
FUNÇÃO: xml.desestruturar_all_xml_sefaz
===================================================================================
Objetivo:
    Processa XMLs de uma empresa específica dentro de um período, baseado nas
    tabelas livros.consulta_nfe_sefaz e consulta_nfe_sefaz_saida.

Parâmetros:
    empresa     INTEGER  id_empresa da tabela livros
    dt_inicial  DATE     Data inicial (d_emi >=)
    dt_final    DATE     Data final (d_emi <=)

Uso:
    BEGIN;
    SELECT * FROM xml.desestruturar_all_xml_sefaz(2275, '2026-04-01', '2026-04-30');
    COMMIT;

CORREÇÃO 2026-08-27: Removida referência a protocolo_id (sistema migrado para import_job).
===================================================================================
*/
DECLARE
    sefaz_nfe_nfce RECORD;
BEGIN
    FOR sefaz_nfe_nfce IN
    (
        SELECT
            a.xml_id,
            a.ch_nf,
            a.import_job_id,
            a.criado_em
        FROM
        (
            -- XMLs de entrada (consulta_nfe_sefaz)
            SELECT
                a.xml_id,
                ch_nf,
                SUBSTRING(ch_nf, 7, 14)::VARCHAR(14) AS cpf_cnpj,
                (SUBSTRING(ch_nf, 26, 9)::VARCHAR(9))::INTEGER AS n_nf,
                ((SUBSTRING(ch_nf, 23, 3)::VARCHAR(3))::INTEGER)::VARCHAR(3) AS ser,
                SUBSTRING(ch_nf, 21, 2)::VARCHAR(2) AS mod,
                import_job_id,
                a.criado_em
            FROM xml.nfe_nfce AS a
            JOIN livros.consulta_nfe_sefaz AS b ON a.ch_nf = b.inf_nfe
            LEFT JOIN nfe.raiz_nfe AS c ON a.ch_nf = c.inf_nfe
            WHERE b.id_empresa = $1 
              AND b.d_emi BETWEEN $2 AND $3 
              AND c.id_nfe IS NULL
            
            UNION
            
            -- XMLs de saída (consulta_nfe_sefaz_saida)
            SELECT
                a.xml_id,
                ch_nf,
                SUBSTRING(ch_nf, 7, 14)::VARCHAR(14) AS cpf_cnpj,
                (SUBSTRING(ch_nf, 26, 9)::VARCHAR(9))::INTEGER AS n_nf,
                ((SUBSTRING(ch_nf, 23, 3)::VARCHAR(3))::INTEGER)::VARCHAR(3) AS ser,
                SUBSTRING(ch_nf, 21, 2)::VARCHAR(2) AS mod,
                import_job_id,
                a.criado_em
            FROM xml.nfe_nfce AS a
            JOIN livros.consulta_nfe_sefaz_saida AS b ON a.ch_nf = b.inf_nfe
            LEFT JOIN nfe.raiz_nfe AS c ON a.ch_nf = c.inf_nfe
            WHERE b.id_empresa = $1 
              AND b.d_emi BETWEEN $2 AND $3 
              AND c.id_nfe IS NULL
        ) AS a
        LEFT JOIN nfe.raiz_nfe AS b USING(cpf_cnpj, n_nf, ser, mod)
        WHERE b.id_nfe IS NULL
        ORDER BY criado_em ASC
    ) LOOP
        RAISE NOTICE 'DESESTRUTURANDO |ID|CHAVE|JOB|DATA| - |%|%|%|%|', 
            sefaz_nfe_nfce.xml_id, 
            sefaz_nfe_nfce.ch_nf, 
            COALESCE(sefaz_nfe_nfce.import_job_id::TEXT, 'N/A'), 
            to_char(sefaz_nfe_nfce.criado_em, 'DD/MM/YYYY HH24:MI:SS');
        
        PERFORM xml.desestruturar_xml_nfe_nfce(sefaz_nfe_nfce.xml_id, FALSE);
    END LOOP;
END;
$_$;


ALTER FUNCTION xml.desestruturar_all_xml_sefaz(empresa integer, dt_inicial date, dt_final date) OWNER TO celismar;

--
-- TOC entry 12187 (class 0 OID 0)
-- Dependencies: 3690
-- Name: FUNCTION desestruturar_all_xml_sefaz(empresa integer, dt_inicial date, dt_final date); Type: COMMENT; Schema: xml; Owner: celismar
--

COMMENT ON FUNCTION xml.desestruturar_all_xml_sefaz(empresa integer, dt_inicial date, dt_final date) IS 'Processa XMLs de uma empresa em um período específico baseado nas tabelas SEFAZ.
CORREÇÃO 2026-08-27: Migrado de protocolo_id para import_job_id.';


--
-- TOC entry 3748 (class 1255 OID 607981401)
-- Name: desestruturar_by_import_job(uuid); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.desestruturar_by_import_job(_import_job_id uuid) RETURNS TABLE(xml_id bigint, ch_nf character varying, sucesso boolean, mensagem text)
    LANGUAGE plpgsql
    AS $$
/*
===================================================================================
FUNÇÃO: xml.desestruturar_by_import_job
===================================================================================
Objetivo:
    Processa todos os XMLs de um import_job específico que ainda não foram
    desestruturados (não existem em nfe.raiz_nfe).

Parâmetros:
    _import_job_id  UUID  ID do job de importação (xml.import_job.job_id)

Uso:
    SELECT * FROM xml.desestruturar_by_import_job('uuid-do-job');
===================================================================================
*/
DECLARE
    r_nfe_nfce RECORD;
    _result JSONB;
    _count_total INTEGER := 0;
    _count_success INTEGER := 0;
    _count_error INTEGER := 0;
BEGIN
    -- Valida se o job existe
    IF NOT EXISTS (SELECT 1 FROM xml.import_job WHERE job_id = _import_job_id) THEN
        RETURN QUERY SELECT 
            NULL::BIGINT, 
            NULL::VARCHAR(44), 
            FALSE, 
            'import_job_id não encontrado: ' || _import_job_id::TEXT;
        RETURN;
    END IF;

    -- Processa XMLs do job que ainda não estão em nfe.raiz_nfe
    FOR r_nfe_nfce IN
    (
        SELECT
            a.xml_id,
            a.ch_nf,
            a.criado_em
        FROM xml.nfe_nfce a
        LEFT JOIN nfe.raiz_nfe b ON a.ch_nf = b.inf_nfe
        WHERE a.import_job_id = _import_job_id
          AND b.id_nfe IS NULL
        ORDER BY a.criado_em ASC
    ) LOOP
        _count_total := _count_total + 1;
        
        RAISE NOTICE 'DESESTRUTURANDO |ID|CHAVE|JOB|DATA| - |%|%|%|%|', 
            r_nfe_nfce.xml_id, 
            r_nfe_nfce.ch_nf, 
            _import_job_id, 
            to_char(r_nfe_nfce.criado_em, 'DD/MM/YYYY HH24:MI:SS');
        
        BEGIN
            _result := xml.desestruturar_xml_nfe_nfce(r_nfe_nfce.xml_id, FALSE);
            
            IF (_result->>'success')::BOOLEAN THEN
                _count_success := _count_success + 1;
                xml_id := r_nfe_nfce.xml_id;
                ch_nf := r_nfe_nfce.ch_nf;
                sucesso := TRUE;
                mensagem := 'Processado com sucesso';
                RETURN NEXT;
            ELSE
                _count_error := _count_error + 1;
                xml_id := r_nfe_nfce.xml_id;
                ch_nf := r_nfe_nfce.ch_nf;
                sucesso := FALSE;
                mensagem := COALESCE(_result->>'message', 'Erro desconhecido');
                RETURN NEXT;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            _count_error := _count_error + 1;
            xml_id := r_nfe_nfce.xml_id;
            ch_nf := r_nfe_nfce.ch_nf;
            sucesso := FALSE;
            mensagem := SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
    
    RAISE NOTICE 'RESUMO: Total=% | Sucesso=% | Erro=%', _count_total, _count_success, _count_error;
END;
$$;


ALTER FUNCTION xml.desestruturar_by_import_job(_import_job_id uuid) OWNER TO dorcilio;

--
-- TOC entry 12188 (class 0 OID 0)
-- Dependencies: 3748
-- Name: FUNCTION desestruturar_by_import_job(_import_job_id uuid); Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON FUNCTION xml.desestruturar_by_import_job(_import_job_id uuid) IS 'Processa XMLs pendentes de um import_job específico. Substitui a antiga desestruturar_by_protocolo.
Retorna tabela com xml_id, ch_nf, sucesso (bool) e mensagem de cada XML processado.';


--
-- TOC entry 3707 (class 1255 OID 586515711)
-- Name: desestruturar_xml_nfe_nfce(bigint, boolean); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.desestruturar_xml_nfe_nfce(_xml_id bigint, substituir boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
	-- variáveis de controle
	_ch_nf VARCHAR(44);
	_id_nfe BIGINT;
	_id_emit BIGINT;
	has_dest BOOLEAN;
	_id_dest BIGINT;
	_id_prod BIGINT;
	r_i01_prod RECORD;
	r_ya01_pag RECORD;
	_id_imposto_devol BIGINT;
	has_icms_uf_dest BOOLEAN;
	_id_inf_adic BIGINT;
	xml_det_pag XML;
	_id_pag BIGINT;
	ind_pag INT;
	cnpj_card VARCHAR(14);
	
	-- variáveis de otimização
	_xml_content XML;
	_xml_exists BOOLEAN := FALSE;
	_nfe_namespaces TEXT[][] := ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']];
	_nfe_header RECORD;
	_result JSONB;
	_step_name VARCHAR(100);
	_records_processed INTEGER;
	_start_time TIMESTAMPTZ := NOW();
	has_nf_ref INTEGER := 0;
	
	-- _header_data reservado (não utilizado)
	_header_data RECORD;
begin
/*
 * Desestrutura o XML de NF-e/NFC-e armazenado em xml.nfe_nfce e popula
 * as tabelas do schema nfe (raiz_nfe, b01_ide, c01_emit, i01_prod,
 * icms_filhos, ub12_ibs_cbs, etc.).
 *
 * O XML é carregado uma única vez em memória (_xml_content) e os
 * namespaces são fixados em _nfe_namespaces para evitar recomputações.
 *
 * Parâmetros:
 *   _xml_id    - PK de xml.nfe_nfce
 *   substituir - TRUE: remove raiz_nfe (cascade) e reprocessa do zero;
 *                FALSE (padrão): se a NF-e já existir, atualiza xml_id e retorna.
 */

	-- validações iniciais
	_step_name := 'validation_initial';
	RAISE INFO '[%] Iniciando processamento XML ID: %', _step_name, _xml_id;
	
	-- Verificar se o XML existe e carregar conteúdo uma única vez
	SELECT EXISTS(SELECT 1 FROM xml.nfe_nfce WHERE xml_id = _xml_id) INTO _xml_exists;
	
	IF NOT _xml_exists THEN
		_result := jsonb_build_object(
			'success', false,
			'message', 'XML não encontrado',
			'error_code', 'XML_NOT_FOUND',
			'xml_id', _xml_id
		);
		RAISE WARNING '[%] XML ID % não encontrado', _step_name, _xml_id;
		RETURN _result;
	END IF;
	
	-- carrega XML da tabela (uma única vez em memória)
	_step_name := 'load_xml_content';
	SELECT xml_file, ch_nf INTO _xml_content, _ch_nf 
	FROM xml.nfe_nfce 
	WHERE xml_id = _xml_id;
	
	IF _xml_content IS NULL THEN
		_result := jsonb_build_object(
			'success', false,
			'message', 'Conteúdo XML inválido',
			'error_code', 'XML_CONTENT_NULL',
			'xml_id', _xml_id
		);
		RAISE WARNING '[%] Conteúdo XML nulo para ID %', _step_name, _xml_id;
		RETURN _result;
	END IF;
	
	-- extrai dados do cabeçalho (emitente, destinatário, modelo, série, data)
	_step_name := 'extract_header_data';
	SELECT * INTO _nfe_header FROM (
		SELECT 
			regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', _xml_content, _nfe_namespaces))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS n_nf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS serie,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj_dest,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf_dest,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj_emit,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf_emit,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS mod,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS dh_emi
	) AS header_data;
	
	-- Usar dados do header ao invés da chave original
	_ch_nf := COALESCE(_nfe_header.ch_nf, _ch_nf);

/* verifica duplicata pela chave da NF-e */
_step_name := 'check_duplicates';
SELECT id_nfe INTO _id_nfe FROM nfe.raiz_nfe WHERE inf_nfe = _ch_nf LIMIT 1;

IF _id_nfe IS NOT NULL THEN
	IF substituir IS TRUE THEN
		-- Remoção completa para reprocessamento (cascata remove todos os registros filhos)
		DELETE FROM nfe.raiz_nfe WHERE id_nfe = _id_nfe;
		GET DIAGNOSTICS _records_processed = ROW_COUNT;
		_id_nfe := NULL;
	ELSE
		-- ✅ Atualizando xml_id sem reprocessar dados
		UPDATE nfe.raiz_nfe SET xml_id = _xml_id WHERE id_nfe = _id_nfe;
		GET DIAGNOSTICS _records_processed = ROW_COUNT;
		
		_result := jsonb_build_object(
			'success', true,
			'message', 'XML_ID atualizado sem reprocessamento',
			'action', 'update_xml_id',
			'nfe_id', _id_nfe,
			'xml_id', _xml_id,
			'processing_time_ms', EXTRACT(EPOCH FROM (NOW() - _start_time)) * 1000
		);
		
		RETURN _result;
	END IF;
END IF;

/* INSERT nfe.raiz_nfe */
_step_name := 'insert_raiz_nfe';
INSERT INTO nfe.raiz_nfe(
	inf_nfe, n_nf, serie, cpf_cnpj, mod, ser, dest_cpf_cnpj, 
	cnpj_chave, d_emi, ch_nfe, xml_id
) VALUES (
	_ch_nf,
	_nfe_header.n_nf::INT,
	_nfe_header.serie::INT,
	COALESCE(_nfe_header.cnpj_emit, _nfe_header.cpf_emit, ''),
	_nfe_header.mod,
	_nfe_header.serie::INT,
	COALESCE(_nfe_header.cnpj_dest, _nfe_header.cpf_dest, ''),
	SUBSTRING(_ch_nf, 7, 14),
	_nfe_header.dh_emi::DATE,
	_ch_nf,
	_xml_id
) ON CONFLICT ON CONSTRAINT unica_nota DO UPDATE SET
	xml_id = EXCLUDED.xml_id
RETURNING id_nfe INTO _id_nfe;

GET DIAGNOSTICS _records_processed = ROW_COUNT;

/* INSERT nfe.b01_ide */
_step_name := 'insert_b01_ide';
INSERT INTO nfe.b01_ide(
	id_nfe, c_uf, nat_op, ind_pag, mod, serie, n_nf, d_emi, d_sai_ent, h_sai_ent, 
	tp_nf, c_mun_fg, tp_imp, tp_emis, c_dv, tp_amb, fin_nfe, proc_emi, ver_proc, 
	dh_cont, x_just, c_nf, dh_emi, dh_sai_ent, id_dest, ind_final, ind_pres
) SELECT
	_id_nfe AS id_nfe,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cUF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_uf,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:natOp/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS nat_op,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag//new:detPag/new:indPag/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS ind_pag,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(2) AS mod,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS serie,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::BIGINT AS n_nf,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', _xml_content, _nfe_namespaces))[1]::TEXT::DATE AS d_emi,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', _xml_content, _nfe_namespaces))[1]::TEXT, _nfe_header.dh_emi)::DATE AS d_sai_ent,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', _xml_content, _nfe_namespaces))[1]::TEXT, _nfe_header.dh_emi)::TIMESTAMP::TIME AS h_sai_ent,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpNF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS tp_nf,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cMunFG/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun_fg,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpImp/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS tp_imp,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpEmis/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS tp_emis,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cDV/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_dv,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpAmb/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS tp_amb,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:finNFe/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS fin_nfe,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:procEmi/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS proc_emi,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:verProc/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(20) AS ver_proc,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhCont/text()', _xml_content, _nfe_namespaces))[1]::TEXT::TIMESTAMP AS dh_cont,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:xJust/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_just,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cNF/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(9) AS c_nf,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', _xml_content, _nfe_namespaces))[1]::TEXT::TIMESTAMP AS dh_emi,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', _xml_content, _nfe_namespaces))[1]::TEXT, _nfe_header.dh_emi)::TIMESTAMP AS dh_sai_ent,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:idDest/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS id_dest,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indFinal/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS ind_final,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indPres/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS ind_pres
WHERE NOT EXISTS (SELECT 1 FROM nfe.b01_ide WHERE id_nfe = _id_nfe);

GET DIAGNOSTICS _records_processed = ROW_COUNT;

/* NF referenciada (NFref) */
_step_name := 'check_nf_ref';
SELECT COALESCE(array_length((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/node()', _xml_content, _nfe_namespaces)), 1), 0) INTO has_nf_ref;

IF has_nf_ref > 0 THEN
	INSERT INTO nfe.b12a_nf_ref(id_nfe, ref_nfe, ref_cte)
	SELECT
		_id_nfe AS id_nfe,
		unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refNFe/text()', _xml_content, _nfe_namespaces))::VARCHAR(44) AS ref_nfe,
		unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refCTe/text()', _xml_content, _nfe_namespaces))::VARCHAR(44) AS ref_cte;
	
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
END IF;

/* INSERT nfe.c01_emit */
_step_name := 'insert_c01_emit';
INSERT INTO nfe.c01_emit(
	id_nfe, cnpj, cpf, x_nome, x_fant, ie, iest, im, cnae, crt, cpf_cnpj
) SELECT
	_id_nfe AS id_nfe,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS cnpj,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(11) AS cpf,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xNome/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_nome,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xFant/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_fant,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(14) AS ie,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IEST/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS iest,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IM/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(15) AS im,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNAE/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(7) AS cnae,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CRT/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS crt,
	COALESCE(_nfe_header.cnpj_emit, _nfe_header.cpf_emit)::VARCHAR(14) AS cpf_cnpj
RETURNING id INTO _id_emit;

GET DIAGNOSTICS _records_processed = ROW_COUNT;

/* INSERT nfe.c05_ender_emit */
_step_name := 'insert_c05_ender_emit';
INSERT INTO nfe.c05_ender_emit(
	id_nfe, id_emit, x_lgr, nro, x_cpl, x_bairro, c_mun, x_mun, uf, cep, c_pais, x_pais, fone
) SELECT
	_id_nfe AS id_nfe,
	_id_emit AS id_emit,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS nro,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xCpl/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_cpl,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_bairro,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_mun,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(2) AS uf,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(8) AS cep,
	COALESCE(NULLIF(regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '[^0-9]', '', 'g'), ''), '1058')::INT AS c_pais,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_pais,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS fone;

GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* destinatário (opcional em NFC-e) */
_step_name := 'check_destinatario';
SELECT (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/node()', _xml_content, _nfe_namespaces))[1] IS NOT NULL INTO has_dest;

IF has_dest IS TRUE THEN
	/* INSERT nfe.e01_dest */
	_step_name := 'insert_e01_dest';
	INSERT INTO nfe.e01_dest(
		id_nfe, cnpj, cpf, ie, isuf, email, cpf_cnpj, id_estrangeiro, ind_ie_dest, im, x_nome
	) SELECT
		_id_nfe AS id_nfe,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS cnpj,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(11) AS cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(14) AS ie,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:isuf/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(9) AS isuf,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:email/text()', _xml_content, _nfe_namespaces))[1]::TEXT,'')::VARCHAR(60) AS email,
		COALESCE(_nfe_header.cnpj_dest, _nfe_header.cpf_dest)::VARCHAR(14) AS cpf_cnpj,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:idEstrangeiro/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(20) AS id_estrangeiro,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:indIEDest/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS ind_ie_dest,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IM/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(15) AS im,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xNome/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_nome
	RETURNING id INTO _id_dest;

	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.e01_dest */

	/* INSERT nfe.e05_ender_dest */
	_step_name := 'insert_e05_ender_dest';
	INSERT INTO nfe.e05_ender_dest(
		id_nfe, id_dest, x_lgr, nro, x_cpl, x_bairro, c_mun, x_mun, uf, cep, c_pais, x_pais, fone
	) SELECT
		_id_nfe AS id_nfe,
		_id_dest AS id_dest,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS nro,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xCpl/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_cpl,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_bairro,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_mun,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(2) AS uf,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(8) AS cep,
		COALESCE(NULLIF(regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '[^0-9]', '', 'g'), ''), '1058')::INT AS c_pais,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_pais,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS fone;

	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.e05_ender_dest */
END IF;

/* INSERT public.participante */
_step_name := 'insert_participante';
INSERT INTO public.participante(
	cpf_cnpj, nome, suframa, telefone, email, cod_pais, cidade, uf, cep, logradouro, bairro, numero, cod_mun, fantasia
)
(
	SELECT
		a.cpf_cnpj, a.x_nome, a.isuf, a.fone, a.email, a.c_pais, a.x_mun, a.uf, a.cep, a.x_lgr, a.x_bairro, a.nro, a.c_mun, a.x_fant
	FROM
	(	
		SELECT
			COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
			a.x_nome, a.isuf,
			COALESCE(a.fone, '')::VARCHAR(14) AS fone,
			a.email,
			CASE WHEN a.c_pais = 'Brasil' THEN 1058::INTEGER 
				ELSE COALESCE(a.c_pais, '1058')::INT END AS c_pais,
			COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
			COALESCE(a.uf, '')::VARCHAR(2) AS uf,
			COALESCE(a.cep, '')::VARCHAR(8) AS cep,
			a.x_lgr,
			COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
			COALESCE(a.nro, '')::VARCHAR(60) AS nro,
			a.c_mun,
			COALESCE(a.x_fant, '')::VARCHAR(60) AS x_fant
		FROM
		(
			-- Emitente (usando _xml_content)
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xNome/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_nome,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:isuf/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(9) AS isuf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS fone,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:email/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS email,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS c_pais,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS uf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cep,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_bairro,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS nro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xFant/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_fant

			UNION

			-- Destinatário (usando _xml_content)
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xNome/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_nome,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:isuf/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(9) AS isuf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS fone,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:email/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS email,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS c_pais,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS uf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cep,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_bairro,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS nro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xFant/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_fant
		)AS a
	 	WHERE COALESCE(a.cnpj, a.cpf) IS NOT NULL
	) a
	LEFT JOIN
		public.participante b ON a.cpf_cnpj = b.cpf_cnpj
	WHERE
		b.cpf_cnpj IS NULL AND a.x_nome IS NOT NULL
);
GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* FIM INSERT public.participante */

/* INSERT public.participante_ie */
_step_name := 'insert_participante_ie';
-- Só processa se NÃO for modelo 65 (NFCe)
IF _nfe_header.mod <> '65' THEN
	WITH encontrados AS
	(
		-- Emitente (usando _xml_content)
		SELECT
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_mun,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS uf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cep,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_bairro,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS nro,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS ie,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IEST/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS iest

		UNION

		-- Destinatário (usando _xml_content)
		SELECT
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cnpj,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cpf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_mun,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS uf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS cep,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_lgr,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_bairro,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS nro,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_mun,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS ie,
			null AS iest
	)
INSERT INTO
	public.participante_ie(
		cpf_cnpj,
		ie,
		logradouro,
		numero,
		bairro,
		cidade,
		cep,
		uf,
		ie_substituicao,
		cod_mun
	)
	(
		SELECT
			a.cpf_cnpj,
			a.ie,
			a.x_lgr,
			a.nro,
			a.x_bairro,
			a.x_mun,
			a.cep,
			a.uf,
			a.ie_substituicao,
			a.c_mun
		FROM
		(
			SELECT
				COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
				case when a.ie <> '' then a.ie else ''::text end as ie,
				a.x_lgr,
				COALESCE(a.nro, '')::VARCHAR(60) AS nro,
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
				COALESCE(a.cep, '')::VARCHAR(8) AS cep,
				COALESCE(a.uf, '')::VARCHAR(2) AS uf,
				FALSE AS ie_substituicao,
				a.c_mun
			FROM
				encontrados a
			WHERE
				COALESCE(a.cnpj, a.cpf) IS NOT NULL AND a.iest IS NULL
			
			UNION
			
			SELECT
				COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
				--a.iest AS ie,
				case when a.iest <> '' then a.iest else ''::text end as ie,
				a.x_lgr,
				COALESCE(a.nro, '')::VARCHAR(60) AS nro,
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
				COALESCE(a.cep, '')::VARCHAR(8) AS cep,
				COALESCE(a.uf, '')::VARCHAR(2) AS uf,
				TRUE AS ie_substituicao,
				a.c_mun
			FROM
				encontrados a
			WHERE
				COALESCE(a.cnpj, a.cpf) IS NOT NULL AND a.iest IS NOT NULL
		) a
		LEFT JOIN
			public.participante_ie b ON (a.cpf_cnpj, a.ie) = (b.cpf_cnpj, b.ie)
		WHERE
			b.cpf_cnpj IS NULL
	);
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* FIM INSERT public.participante_ie */
END IF; -- fim mod <> '65'

/* INSERT nfe.d01_avulsa */
_step_name := 'insert_d01_avulsa';
INSERT INTO nfe.d01_avulsa(
	id_nfe, cnpj, x_orgao, matr, x_agente, fone, uf, n_dar, d_emi, v_dar, rep_emi, d_pag
)
SELECT
	_id_nfe AS id_nfe,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:CNPJ/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(14) AS cnpj,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xOrgao/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_orgao,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:matr/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS matr,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xAgente/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS x_agente,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:fone/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(14) AS fone,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:UF/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(2) AS uf,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:nDAR/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS n_dar,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dEmi/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::DATE AS d_emi,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:vDAR/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15, 2) AS v_dar,
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:repEmi/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(60) AS rep_emi,
	((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dPag/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::DATE AS d_pag
WHERE
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xOrgao/text()', _xml_content, _nfe_namespaces))[1] IS NOT NULL;
GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* FIM INSERT nfe.d01_avulsa */

/* LOOP: itens da NF-e (det) */
_step_name := 'loop_i01_prod';
RAISE INFO '[%] Processando produtos/impostos da NFe ID: %', _step_name, _id_nfe;
FOR r_i01_prod IN
(
	-- extrai os nós <det> do XML já carregado em memória
	WITH xml_extract AS (
	    SELECT 
			_ch_nf AS ch_nf,
	        _xml_id AS xml_id,
	        xpath('/new:nfeProc/new:NFe/new:infNFe/new:det', _xml_content, _nfe_namespaces) AS dets
	),
	det_positions AS (
	    SELECT 
			ch_nf,
	        xml_id,
	        generate_subscripts(dets, 1) AS position,
	        dets[generate_subscripts(dets, 1)] AS det_node
	    FROM xml_extract
	)
	SELECT
		a.det_node,
		a.c_prod,
		a.x_prod,
		a.ncm,
		a.ex_tipi,
		a.cfop,
		a.u_com,
		a.v_prod,
		a.u_trib,
		a.v_frete,
		a.v_seg,
		a.v_desc,
		a.v_outro,
		a.ind_tot,
		a.x_ped,
		a.n_item_ped,
		a.v_un_com,
		a.v_un_trib,
		a.q_com,
		a.q_trib,
		a.n_fci,
		a.nve,
		a.cest,
		a.c_ean,
		a.c_ean_trib,
		a.n_item,
		a.inf_ad_prod,
		a.ind_escala,
		/*a.cnpj_emit,
		a.cpf_emit,
		a.n_nf,
		a.mod,
		a.serie,
		a.d_emi,*/
		case when (a.cnpj_emit = '' or  a.cnpj_emit is null) and length(b.cpf_cnpj) = 14
			then b.cpf_cnpj
		else a.cnpj_emit
		end as cnpj_emit,
		case when (a.cpf_emit = '' or  a.cpf_emit is null) and length(b.cpf_cnpj) = 11
			then b.cpf_cnpj
		else a.cpf_emit
		end as cpf_emit,
		coalesce(a.n_nf,b.n_nf) as n_nf,
		coalesce(a.mod,b.mod) as mod,
		coalesce(a.serie,b.serie) as serie,
		case when (a.d_emi = '' or  a.d_emi is null)
			then b.d_emi 
		else a.d_emi::date end as d_emi,
		a.vl_st_apurado, 
		a.vl_pobreza_apurado, 
		a.vl_difal, 
		a.vl_bc_difal,
		a.aliq_difal
	FROM
	(
		SELECT
			ch_nf,
		    xml_id,
		    position,
		    (xpath('/new:det/new:prod/new:cProd/text()', det_node, _nfe_namespaces)::TEXT[])[1] AS c_prod,
		    (xpath('/new:det/new:prod/new:xProd/text()', det_node, _nfe_namespaces)::TEXT[])[1] AS x_prod,
			(xpath('/new:det/new:prod/new:NCM/text()', det_node, _nfe_namespaces)::VARCHAR(10)[])[1] AS ncm,
			(xpath('/new:det/new:prod/new:EXTIPI/text()', det_node, _nfe_namespaces)::VARCHAR(3)[])[1] AS ex_tipi,
			((xpath('/new:det/new:prod/new:CFOP/text()', det_node, _nfe_namespaces))[1]::TEXT)::INTEGER AS cfop,
			(xpath('/new:det/new:prod/new:uCom/text()', det_node, _nfe_namespaces))[1]::VARCHAR(10) AS u_com,
			((xpath('/new:det/new:prod/new:vProd/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS v_prod,
			(xpath('/new:det/new:prod/new:uTrib/text()', det_node, _nfe_namespaces))[1]::VARCHAR(10) AS u_trib,
			((xpath('/new:det/new:prod/new:vFrete/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS v_frete,
			((xpath('/new:det/new:prod/new:vSeg/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS v_seg,
			((xpath('/new:det/new:prod/new:vDesc/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS v_desc,
			((xpath('/new:det/new:prod/new:vOutro/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS v_outro,
			((xpath('/new:det/new:prod/new:indTot/text()', det_node, _nfe_namespaces))[1]::TEXT)::INTEGER AS ind_tot,
			(xpath('/new:det/new:prod/new:xPed/text()', det_node, _nfe_namespaces))[1]::VARCHAR(15) AS x_ped,
			(xpath('/new:det/new:prod/new:nItemPed/text()', det_node, _nfe_namespaces))[1]::VARCHAR(15) AS n_item_ped,
			(xpath('/new:det/new:prod/new:vUnCom/text()', det_node, _nfe_namespaces))[1]::TEXT AS v_un_com,
			(xpath('/new:det/new:prod/new:vUnTrib/text()', det_node, _nfe_namespaces))[1]::TEXT AS v_un_trib,
			((xpath('/new:det/new:prod/new:qCom/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS q_com,
			((xpath('/new:det/new:prod/new:qTrib/text()', det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC AS q_trib,
			(xpath('/new:det/new:prod/new:nFCI/text()', det_node, _nfe_namespaces))[1]::TEXT AS n_fci,
			(xpath('/new:det/new:prod/new:NVE/text()', det_node, _nfe_namespaces))[1]::VARCHAR(10) AS nve,
			((xpath('/new:det/new:prod/new:CEST/text()', det_node, _nfe_namespaces))[1]::TEXT)::BIGINT AS cest,
			(xpath('/new:det/new:prod/new:cEAN/text()', det_node, _nfe_namespaces))[1]::VARCHAR(14) AS c_ean,
			(xpath('/new:det/new:prod/new:cEANTrib/text()', det_node, _nfe_namespaces))[1]::VARCHAR(14) AS c_ean_trib,
			COALESCE(
				(xpath('/new:det/@nItem', det_node, _nfe_namespaces)::TEXT[])[1],
				(xpath('/new:det/new:nItem/text()', det_node, _nfe_namespaces)::TEXT[])[1]
			)::INTEGER AS n_item,
			det_node,
			(xpath('/new:det/new:infAdProd/text()', det_node, _nfe_namespaces))[1]::VARCHAR(500) AS inf_ad_prod,
			(xpath('/new:det/new:prod/new:indEscala/text()', det_node, _nfe_namespaces))[1]::VARCHAR(1) AS ind_escala,
			-- dados do cabeçalho reutilizados de _nfe_header (extraído uma única vez)
			_nfe_header.cnpj_emit AS cnpj_emit,
			_nfe_header.cpf_emit AS cpf_emit,
			_nfe_header.n_nf::INTEGER AS n_nf,
			_nfe_header.mod AS mod,
			_nfe_header.serie::INTEGER AS serie,
			_nfe_header.dh_emi::TEXT AS d_emi,
			0.00::NUMERIC(18,2) as vl_st_apurado, 
			0.00::NUMERIC(18,2) as vl_pobreza_apurado, 
			0.00::NUMERIC(18,2) as vl_difal, 
			0.00::NUMERIC(18,2) as vl_bc_difal,
			0.00::NUMERIC(18,2) AS aliq_difal
		FROM det_positions
		ORDER BY xml_id, position
	) a
	join nfe.raiz_nfe as b on a.ch_nf = b.inf_nfe
	WHERE
		c_prod IS NOT NULL
) LOOP
	/* INSERT TABLE nfe.i01_prod */
	INSERT INTO
	nfe.i01_prod(
		id_nfe,
		c_prod,
		x_prod,
		ncm,
		ex_tipi,
		cfop,
		u_com,
		v_prod,
		u_trib,
		v_frete,
		v_seg,
		v_desc,
		v_outro,
		ind_tot,
		x_ped,
		n_item_ped,
		v_un_com,
		v_un_trib,
		q_com,
		q_trib,
		n_fci,
		nve,
		cest,
		c_ean,
		c_ean_trib,
		n_item,
		inf_ad_prod,
		ind_escala,
		cpf_cnpj,
		n_nf,
		mod,
		serie,
		d_emi,
		vl_st_apurado,
		vl_pobreza_apurado,
		vl_difal,
		vl_bc_difal,
		aliq_difal
	)
	(
		SELECT
			_id_nfe,
			r_i01_prod.c_prod,
			r_i01_prod.x_prod,
			COALESCE(r_i01_prod.ncm, '')::VARCHAR(8) AS ncm,
			COALESCE(r_i01_prod.ex_tipi, '') AS ex_tipi,
			r_i01_prod.cfop,
			r_i01_prod.u_com,
			r_i01_prod.v_prod,
			r_i01_prod.u_trib,
			COALESCE(r_i01_prod.v_frete::NUMERIC, 0.00)::NUMERIC(18,2) AS v_frete,
			COALESCE(r_i01_prod.v_seg::NUMERIC, 0.00)::NUMERIC(18,2) AS v_seg,
			COALESCE(r_i01_prod.v_desc::NUMERIC(18,2), 0.00)::NUMERIC(18,2) AS v_desc,
			COALESCE(r_i01_prod.v_outro::NUMERIC, 0.00)::NUMERIC(18,2) AS v_outro,
			r_i01_prod.ind_tot,
			r_i01_prod.x_ped,
			r_i01_prod.n_item_ped,
			r_i01_prod.v_un_com,
			COALESCE(r_i01_prod.v_un_trib::NUMERIC, 0.00)::NUMERIC(18,2) AS v_un_trib,
			r_i01_prod.q_com,
			COALESCE(r_i01_prod.q_trib::NUMERIC, 0.00)::numeric(18,3) AS q_trib,
			COALESCE(r_i01_prod.n_fci, '') AS n_fci,
			COALESCE(r_i01_prod.nve, '') AS nve,
			r_i01_prod.cest,
			CASE WHEN r_i01_prod.c_ean = 'SEM GTIN' OR r_i01_prod.c_ean IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean
			END AS c_ean,
			CASE WHEN r_i01_prod.c_ean_trib = 'SEM GTIN' OR r_i01_prod.c_ean_trib IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean_trib
			END AS c_ean_trib,
			r_i01_prod.n_item,
			r_i01_prod.inf_ad_prod,
			r_i01_prod.ind_escala,
			COALESCE(r_i01_prod.cnpj_emit, r_i01_prod.cpf_emit, '') AS cpf_cnpj,
			r_i01_prod.n_nf,
			r_i01_prod.mod,
			r_i01_prod.serie,
			r_i01_prod.d_emi::DATE,
			r_i01_prod.vl_st_apurado,
			r_i01_prod.vl_pobreza_apurado,
			r_i01_prod.vl_difal,
			r_i01_prod.vl_bc_difal,
			r_i01_prod.aliq_difal
	) RETURNING id INTO _id_prod;
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.i01_prod */

	/* INSERT TABLE nfe.m01_imposto */
	INSERT INTO 
	nfe.m01_imposto(
		id_nfe,
		id_prod,
		v_tot_trib
	)
	(                                                                          
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			COALESCE(
				((xpath('/new:det/new:imposto/new:vTotTrib/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2),
				0.00
			) AS v_tot_trib
	);
	/* FIM INSERT nfe.m01_imposto */

	/* IMPOSTO ICMS em icms_filhos */
	WITH todos_icms AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:orig/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::INT AS orig,
			(xpath('/new:det/new:imposto/new:ICMS/new:*/new:CST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT AS cst,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:modBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::INT AS mod_bc,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pICMS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_icms,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:modBCST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::INT AS mod_bc_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pMVAST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_mva_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pRedBCST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pICMSST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_icms_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pRedBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSDeson/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_deson,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:motDesICMS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::INT AS mot_des_icms,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSOp/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_op,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pDif/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSDif/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_dif,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCSTRet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_ret,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSSTRet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_ret,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pBCOp/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_bc_op,
			(xpath('/new:det/new:imposto/new:ICMS/new:*/new:UFST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(2) AS uf_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCSTDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_dest,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSSTDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_dest,
			(xpath('/new:det/new:imposto/new:ICMS/new:*/new:CSOSN/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(3) AS cso_sn,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pCredSN/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cred_sn,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vCredICMSSN/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_icms_sn,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCFCP/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pFCP/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_fcp,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vFCP/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCFCPST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pFCPST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vFCPST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCFCPSTRet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st_ret,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pFCPSTRet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st_ret,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vFCPSTRet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st_ret,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSSubstituto/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_substituto,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pRedBCEfet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_efet,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vBCEfet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_efet,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:pICMSEfet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_icms_efet,
			((xpath('/new:det/new:imposto/new:ICMS/new:*/new:vICMSEfet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_efet
		FROM (SELECT 1) AS _dummy
	)
	INSERT INTO
	nfe.icms_filhos(
		id_nfe,
		id_prod,
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
		p_st, uf_st,
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
	(
		SELECT
			id_nfe,
			id_prod,
			orig,
			LPAD(cst, 3, '0') AS cst,
			COALESCE(LPAD(cso_sn, 3, '0'),'') AS cso_sn,
			COALESCE(p_cred_sn, 0.0000) AS p_cred_sn,
			COALESCE(v_cred_icms_sn, 0.00) AS v_cred_icms_sn,
			mod_bc,
			mod_bc_st,
			COALESCE(p_red_bc, 0.0000) AS p_red_bc,
			COALESCE(p_red_bc_st, 0.0000) AS p_red_bc_st,
			COALESCE(p_mva_st, 0.0000) AS p_mva_st,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(v_bc_st, 0.00) AS v_bc_st,
			COALESCE(v_bc_st_ret, 0.00) AS v_bc_st_ret,
			COALESCE(p_icms, 0.0000) AS p_icms,
			COALESCE(v_icms, 0.00) AS v_icms,
			COALESCE(p_icms_st, 0.0000) AS p_icms_st,
			COALESCE(v_icms_st, 0.00) AS v_icms_st,
			COALESCE(v_icms_st_ret, 0.00) AS v_icms_st_ret,
			mot_des_icms,
			COALESCE(p_bc_op, 0.0000) AS p_bc_op,
			COALESCE(v_icms_deson, 0.00) AS v_icms_deson,
			COALESCE(v_icms_op, 0.00) AS v_icms_op,
			COALESCE(p_dif, 0.0000) AS p_dif,
			COALESCE(v_icms_dif, 0.00) AS v_icms_dif,
			COALESCE(p_st, 0.0000) AS p_st,
			uf_st,
			COALESCE(v_bc_st_dest, 0.00) AS v_bc_st_dest,
			COALESCE(v_icms_st_dest, 0.00) AS v_icms_st_dest,
			COALESCE(v_bc_fcp, 0.00) AS v_bc_fcp,
			COALESCE(p_fcp, 0.0000) AS p_fcp,
			COALESCE(v_bc_fcp_st, 0.00) AS v_bc_fcp_st,
			COALESCE(p_fcp_st, 0.0000) AS p_fcp_st,
			COALESCE(v_fcp_st, 0.00) AS v_fcp_st,
			COALESCE(v_bc_fcp_st_ret, 0.00) AS v_bc_fcp_st_ret,
			COALESCE(p_fcp_st_ret, 0.0000) AS p_fcp_st_ret,
			COALESCE(v_fcp_st_ret, 0.00) AS v_fcp_st_ret,
			COALESCE(v_fcp, 0.00) AS v_fcp,
			COALESCE(v_icms_substituto, 0.00) AS v_icms_substituto,
			COALESCE(p_red_bc_efet, 0.0000) AS p_red_bc_efet,
			COALESCE(v_bc_efet, 0.00) AS v_bc_efet,
			COALESCE(p_icms_efet, 0.0000) AS p_icms_efet,
			COALESCE(v_icms_efet, 0.00) AS v_icms_efet
		FROM
			todos_icms
		WHERE
			orig IS NOT NULL
	);
	/* FIM IMPOSTO ICMS */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* IMPOSTO IPI em ipi_filhos */
	WITH todos_ipi AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:clEnq/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(5) AS cl_enq,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:CNPJProd/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(14) AS cnpj_prod,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:cSelo/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(60) AS c_selo,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:qSelo/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(12) AS q_selo,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:cEnq/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(3) AS c_enq,
			(xpath('/new:det/new:imposto/new:IPI/new:*/new:CST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(2) AS cst,
			((xpath('/new:det/new:imposto/new:IPI/new:*/new:vBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:det/new:imposto/new:IPI/new:*/new:pIPI/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_ipi,
			((xpath('/new:det/new:imposto/new:IPI/new:*/new:vIPI/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ipi,
			((xpath('/new:det/new:imposto/new:IPI/new:*/new:qUnid/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(16,4) AS q_unid,
			((xpath('/new:det/new:imposto/new:IPI/new:*/new:vUnid/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS v_unid
		FROM (SELECT 1) AS _dummy
	)
	INSERT INTO 
	nfe.ipi_filhos(
		id_nfe,
		id_prod,
		cst,
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
	(
		SELECT
			id_nfe,
			id_prod, 
			cst, 
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(p_ipi, 0.00) AS p_ipi, 
			COALESCE(q_unid, 0.0000) AS q_unid, 
			COALESCE(v_unid, 0.0000) AS v_unid, 
			COALESCE(v_ipi, 0.00) AS v_ipi,
			cl_enq, 
			cnpj_prod, 
			c_selo, 
			q_selo, 
			c_enq
		FROM
			todos_ipi
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO IPI */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* INSERT TABLE nfe.p01_ii */
	INSERT INTO 
	nfe.p01_ii(
		id_nfe,
		id_prod, 
		v_bc, 
		v_desp_adu, 
		v_ii, 
		v_iof
	)
	(
		SELECT
			id_nfe,
			id_prod,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(v_desp_adu, 0.00) AS v_desp_adu, 
			COALESCE(v_ii, 0.00) AS v_ii, 
			COALESCE(v_iof, 0.00) AS v_iof
		FROM
		(
			SELECT
				_id_nfe AS id_nfe,
				_id_prod AS id_prod,
				((xpath('/new:det/new:imposto/new:II/new:vBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:det/new:imposto/new:II/new:vDespAdu/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_desp_adu,
				((xpath('/new:det/new:imposto/new:II/new:vII/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ii,
				((xpath('/new:det/new:imposto/new:II/new:vIOF/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_iof
			FROM (SELECT 1) AS _dummy
		) AS a
		WHERE
			a.v_bc IS NOT NULL
	);
	/* FIM INSERT nfe.p01_ii */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* IMPOSTO PIS em pis_filhos */
	WITH todos_pis AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:det/new:imposto/new:PIS/new:*/new:CST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT AS cst,
			((xpath('/new:det/new:imposto/new:PIS/new:*/new:vBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:det/new:imposto/new:PIS/new:*/new:pPIS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_pis,
			((xpath('/new:det/new:imposto/new:PIS/new:*/new:vPIS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
			((xpath('/new:det/new:imposto/new:PIS/new:*/new:qBCProd/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(16,4) AS q_bc_prod,
			((xpath('/new:det/new:imposto/new:PIS/new:*/new:vAliqProd/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS v_aliq_prod
		FROM (SELECT 1) AS _dummy
	)
	INSERT INTO
	nfe.pis_filhos(
		id_nfe, 
		id_prod, 
		cst, 
		q_bc_prod, 
		v_aliq_prod, 
		v_bc,
		p_pis, 
		v_pis
	)
	(		
		SELECT
			id_nfe,
			id_prod, 
			cst, 
			COALESCE(q_bc_prod, 0.0000) AS q_bc_prod,
			COALESCE(v_aliq_prod, 0.0000) AS v_aliq_prod, 
			COALESCE(v_bc, 0.00) AS v_bc, 
			COALESCE(p_pis, 0.00) AS p_pis, 
			COALESCE(v_pis, 0.00) AS v_pis
		FROM
			todos_pis
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO PIS */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* IMPOSTO PIS em cofins_filhos */
	WITH todos_cofins AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:det/new:imposto/new:COFINS/new:*/new:CST/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(2) AS cst,
			((xpath('/new:det/new:imposto/new:COFINS/new:*/new:vBC/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:det/new:imposto/new:COFINS/new:*/new:pCOFINS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_cofins,
			((xpath('/new:det/new:imposto/new:COFINS/new:*/new:vCOFINS/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
			((xpath('/new:det/new:imposto/new:COFINS/new:*/new:qBCProd/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(16,4) AS q_bc_prod,
			((xpath('/new:det/new:imposto/new:COFINS/new:*/new:vAliqProd/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS v_aliq_prod
		FROM (SELECT 1) AS _dummy
	)
	INSERT INTO
	nfe.cofins_filhos(
		id_nfe, 
		id_prod, 
		cst, 
		q_bc_prod,
		v_aliq_prod, 
		v_bc,
		p_cofins, 		
		v_cofins
	)
	(		
		SELECT
			id_nfe,
			id_prod, 
			cst,
			COALESCE(q_bc_prod, 0.0000) AS q_bc_prod,
			COALESCE(v_aliq_prod, 0.0000) AS v_aliq_prod,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(p_cofins, 0.00) AS p_cofins,
			COALESCE(v_cofins, 0.00) AS v_cofins
		FROM
			todos_cofins
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO COFINS */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* INSERT TABLE nfe.ua01_imposto_devol */	
	INSERT INTO 
	nfe.ua01_imposto_devol(
		id_nfe,
		id_prod,
		p_devol
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod, 
			COALESCE(a.p_devol, 0.00) AS p_devol
		FROM
		(
			SELECT
				((xpath('/new:det/new:impostoDevol/new:pDevol/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_devol
			FROM (SELECT 1) AS _dummy
		)AS a
		WHERE
			a.p_devol IS NOT NULL
	) RETURNING id INTO _id_imposto_devol;

	/* INSERT TABLE nfe.ua04_ipi */
	IF _id_imposto_devol IS NOT NULL THEN	
		INSERT INTO
		nfe.ua04_ipi(
			id_nfe,
			id_imposto_devol,
			v_ipi_devol
		)
		(
			SELECT
				_id_nfe AS id_nfe,
				_id_imposto_devol AS id_imposto_devol, 
				COALESCE(v_ipi_devol, 0.00) AS v_ipi_devol
			FROM
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_imposto_devol AS id_imposto_devol,
					((xpath('/new:det/new:impostoDevol/new:IPI/new:vIPIDevol/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ipi_devol
				FROM (SELECT 1) AS _dummy
			) AS a
		);
	END IF;
	/* FIM INSERT nfe.ua04_ipi */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* VERIFICAR SE POSSUÍ ICMS NO DESTINATÁRIO */
	has_icms_uf_dest := (xpath('/new:det/new:imposto/new:ICMSUFDest/node()', r_i01_prod.det_node, _nfe_namespaces))[1] IS NOT NULL;

	/* INSERT TABLE nfe.na01_icms_uf_dest */
	IF has_icms_uf_dest IS TRUE THEN
		INSERT INTO 
		nfe.na01_icms_uf_dest(
			id_nfe, 
			id_prod, 
			v_bc_uf_dest, 
			p_fcp_uf_dest, 
			p_icms_uf_dest, 
			p_icms_inter, 
			p_icms_inter_part, 
			v_fcp_uf_dest, 
			v_icms_uf_dest, 
			v_icms_uf_remet
		)
		(
			SELECT
				_id_nfe AS id_nfe, 
				_id_prod AS id_prod, 
				COALESCE(a.v_bc_uf_dest, 0.00) AS v_bc_uf_dest, 
				COALESCE(a.p_fcp_uf_dest, 0.00) AS p_fcp_uf_dest,  
				COALESCE(a.p_icms_uf_dest, 0.00) AS p_icms_uf_dest,  
				COALESCE(a.p_icms_inter, 0.00) AS p_icms_inter, 
				COALESCE(a.p_icms_inter_part, 0.00) AS p_icms_inter_part, 
				COALESCE(a.v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest, 
				COALESCE(a.v_icms_uf_dest, 0.00) AS v_icms_uf_dest, 
				COALESCE(a.v_icms_uf_remet, 0.00) AS v_icms_uf_remet
			FROM
			(
				SELECT
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:vBCUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:vBCFCPUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:pFCPUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_fcp_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:pICMSUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_icms_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:pICMSInter/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:pICMSInterPart/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter_part,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:vFCPUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:vICMSUFDest/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_dest,
					((xpath('/new:det/new:imposto/new:ICMSUFDest/new:vICMSUFRemet/text()', r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_remet
				FROM (SELECT 1) AS _dummy
			) AS a
		);
	END IF;
	/* FIM INSERT nfe.na01_icms_uf_dest */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* INSERT TABLE nfe.ub12_ibs_cbs */
	INSERT INTO nfe.ub12_ibs_cbs (
		id_nfe,
		id_i01_prod,
		cst,
		c_class_trib,
		ind_doacao,
		v_bc,
		p_ibs_uf,
		p_dif_ibs,
		v_dif_ibs,
		v_dev_trib_ibs,
		p_red_aliq_ibs,
		p_aliq_efet_ibs,
		v_ibs_uf,
		p_ibs_mun,
		p_dif_ibs_mun,
		v_dif_ibs_mun,
		v_dev_trib_ibs_mun,
		p_red_aliq_ibs_mun,
		p_aliq_efet_ibs_mun,
		v_ibs_mun,
		v_ibs,
		p_cbs,
		p_dif_cbs,
		v_dif_cbs,
		v_dev_trib_cbs,
		p_red_aliq_cbs,
		p_aliq_efet_cbs,
		v_cbs,
		cst_reg,
		c_class_trib_reg,
		p_aliq_efet_reg_ibs_uf,
		v_trib_reg_ibs_uf,
		p_aliq_efet_reg_ibs_mun,
		v_trib_reg_ibs_mun,
		p_aliq_efet_reg_cbs,
		v_trib_reg_cbs,
		p_aliq_ibs_uf,
		v_trib_ibs_uf,
		p_aliq_ibs_mun,
		v_trib_ibs_mun,
		p_aliq_cbs,
		v_trib_cbs,
		q_bc_mono,
		ad_rem_ibs,
		ad_rem_cbs,
		v_ibs_mono,
		v_cbs_mono,
		q_bc_mono_reten,
		ad_rem_ibs_reten,
		v_ibs_mono_reten,
		ad_rem_cbs_reten,
		v_cbs_mono_reten,
		q_bc_mono_ret,
		ad_rem_ibs_ret,
		v_ibs_mono_ret,
		ad_rem_cbs_ret,
		v_cbs_mono_ret,
		p_dif_ibs_mono,
		v_ibs_mono_dif,
		p_dif_cbs_mono,
		v_cbs_mono_dif,
		v_tot_ibs_mono_item,
		v_tot_cbs_mono_item,
		v_ibs_trans_cred,
		v_cbs_trans_cred,
		compet_apur_ajuste_compet,
		v_ibs_ajuste_compet,
		v_cbs_ajuste_compet,
		v_ibs_est_cred,
		v_cbs_est_cred,
		v_bc_cred_pres,
		c_cred_pres,
		p_cred_pres_ibs,
		v_cred_pres_ibs,
		v_cred_pres_cond_sus_ibs,
		p_cred_pres_cbs,
		v_cred_pres_cbs,
		v_cred_pres_cond_sus_cbs,
		compet_apur_ibs_zfm,
		tp_cred_pres_ibs_zfm,
		v_cred_pres_ibs_zfm
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			a.cst,
			a.c_class_trib,
			a.ind_doacao,
			COALESCE(a.v_bc, 0.00) AS v_bc,
			COALESCE(a.p_ibs_uf, 0.0000) AS p_ibs_uf,
			COALESCE(a.p_dif_ibs, 0.0000) AS p_dif_ibs,
			COALESCE(a.v_dif_ibs, 0.00) AS v_dif_ibs,
			COALESCE(a.v_dev_trib_ibs, 0.00) AS v_dev_trib_ibs,
			COALESCE(a.p_red_aliq_ibs, 0.0000) AS p_red_aliq_ibs,
			COALESCE(a.p_aliq_efet_ibs, 0.0000) AS p_aliq_efet_ibs,
			COALESCE(a.v_ibs_uf, 0.00) AS v_ibs_uf,
			COALESCE(a.p_ibs_mun, 0.0000) AS p_ibs_mun,
			COALESCE(a.p_dif_ibs_mun, 0.0000) AS p_dif_ibs_mun,
			COALESCE(a.v_dif_ibs_mun, 0.00) AS v_dif_ibs_mun,
			COALESCE(a.v_dev_trib_ibs_mun, 0.00) AS v_dev_trib_ibs_mun,
			COALESCE(a.p_red_aliq_ibs_mun, 0.0000) AS p_red_aliq_ibs_mun,
			COALESCE(a.p_aliq_efet_ibs_mun, 0.0000) AS p_aliq_efet_ibs_mun,
			COALESCE(a.v_ibs_mun, 0.00) AS v_ibs_mun,
			COALESCE(a.v_ibs, 0.00) AS v_ibs,
			COALESCE(a.p_cbs, 0.0000) AS p_cbs,
			COALESCE(a.p_dif_cbs, 0.0000) AS p_dif_cbs,
			COALESCE(a.v_dif_cbs, 0.00) AS v_dif_cbs,
			COALESCE(a.v_dev_trib_cbs, 0.00) AS v_dev_trib_cbs,
			COALESCE(a.p_red_aliq_cbs, 0.00) AS p_red_aliq_cbs,
			COALESCE(a.p_aliq_efet_cbs, 0.0000) AS p_aliq_efet_cbs,
			COALESCE(a.v_cbs, 0.00) AS v_cbs,
			a.cst_reg,
			a.c_class_trib_reg,
			COALESCE(a.p_aliq_efet_reg_ibs_uf, 0.0000) AS p_aliq_efet_reg_ibs_uf,
			COALESCE(a.v_trib_reg_ibs_uf, 0.00) AS v_trib_reg_ibs_uf,
			COALESCE(a.p_aliq_efet_reg_ibs_mun, 0.0000) AS p_aliq_efet_reg_ibs_mun,
			COALESCE(a.v_trib_reg_ibs_mun, 0.00) AS v_trib_reg_ibs_mun,
			COALESCE(a.p_aliq_efet_reg_cbs, 0.0000) AS p_aliq_efet_reg_cbs,
			COALESCE(a.v_trib_reg_cbs, 0.00) AS v_trib_reg_cbs,
			COALESCE(a.p_aliq_ibs_uf, 0.0000) AS p_aliq_ibs_uf,
			COALESCE(a.v_trib_ibs_uf, 0.00) AS v_trib_ibs_uf,
			COALESCE(a.p_aliq_ibs_mun, 0.0000) AS p_aliq_ibs_mun,
			COALESCE(a.v_trib_ibs_mun, 0.00) AS v_trib_ibs_mun,
			COALESCE(a.p_aliq_cbs, 0.0000) AS p_aliq_cbs,
			COALESCE(a.v_trib_cbs, 0.00) AS v_trib_cbs,
			COALESCE(a.q_bc_mono, 0.0000) AS q_bc_mono,
			COALESCE(a.ad_rem_ibs, 0.0000) AS ad_rem_ibs,
			COALESCE(a.ad_rem_cbs, 0.0000) AS ad_rem_cbs,
			COALESCE(a.v_ibs_mono, 0.00) AS v_ibs_mono,
			COALESCE(a.v_cbs_mono, 0.00) AS v_cbs_mono,
			COALESCE(a.q_bc_mono_reten, 0.0000) AS q_bc_mono_reten,
			COALESCE(a.ad_rem_ibs_reten, 0.0000) AS ad_rem_ibs_reten,
			COALESCE(a.v_ibs_mono_reten, 0.00) AS v_ibs_mono_reten,
			COALESCE(a.ad_rem_cbs_reten, 0.0000) AS ad_rem_cbs_reten,
			COALESCE(a.v_cbs_mono_reten, 0.00) AS v_cbs_mono_reten,
			COALESCE(a.q_bc_mono_ret, 0.0000) AS q_bc_mono_ret,
			COALESCE(a.ad_rem_ibs_ret, 0.0000) AS ad_rem_ibs_ret,
			COALESCE(a.v_ibs_mono_ret, 0.00) AS v_ibs_mono_ret,
			COALESCE(a.ad_rem_cbs_ret, 0.0000) AS ad_rem_cbs_ret,
			COALESCE(a.v_cbs_mono_ret, 0.00) AS v_cbs_mono_ret,
			COALESCE(a.p_dif_ibs_mono, 0.0000) AS p_dif_ibs_mono,
			COALESCE(a.v_ibs_mono_dif, 0.00) AS v_ibs_mono_dif,
			COALESCE(a.p_dif_cbs_mono, 0.0000) AS p_dif_cbs_mono,
			COALESCE(a.v_cbs_mono_dif, 0.00) AS v_cbs_mono_dif,
			COALESCE(a.v_tot_ibs_mono_item, 0.00) AS v_tot_ibs_mono_item,
			COALESCE(a.v_tot_cbs_mono_item, 0.00) AS v_tot_cbs_mono_item,
			COALESCE(a.v_ibs_trans_cred, 0.00) AS v_ibs_trans_cred,
			COALESCE(a.v_cbs_trans_cred, 0.00) AS v_cbs_trans_cred,
			a.compet_apur_ajuste_compet,
			COALESCE(a.v_ibs_ajuste_compet, 0.00) AS v_ibs_ajuste_compet,
			COALESCE(a.v_cbs_ajuste_compet, 0.00) AS v_cbs_ajuste_compet,
			COALESCE(a.v_ibs_est_cred, 0.00) AS v_ibs_est_cred,
			COALESCE(a.v_cbs_est_cred, 0.00) AS v_cbs_est_cred,
			COALESCE(a.v_bc_cred_pres, 0.00) AS v_bc_cred_pres,
			a.c_cred_pres,
			COALESCE(a.p_cred_pres_ibs, 0.0000) AS p_cred_pres_ibs,
			COALESCE(a.v_cred_pres_ibs, 0.00) AS v_cred_pres_ibs,
			COALESCE(a.v_cred_pres_cond_sus_ibs, 0.00) AS v_cred_pres_cond_sus_ibs,
			COALESCE(a.p_cred_pres_cbs, 0.0000) AS p_cred_pres_cbs,
			COALESCE(a.v_cred_pres_cbs, 0.00) AS v_cred_pres_cbs,
			COALESCE(a.v_cred_pres_cond_sus_cbs, 0.00) AS v_cred_pres_cond_sus_cbs,
			a.compet_apur_ibs_zfm,
			a.tp_cred_pres_ibs_zfm,
			COALESCE(a.v_cred_pres_ibs_zfm, 0.00) AS v_cred_pres_ibs_zfm
		FROM
		(
			SELECT
			    -- UB13 - CST (Código de Situação Tributária do IBS e CBS)
			    -- CORREÇÃO 2026-07-05: trocado _xml_content por r_i01_prod.det_node
			    -- Causa: xpath avaliado na raiz da NFe nunca encontrava <det>, cst sempre NULL
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:CST/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(3) AS cst,
			    -- UB14 - cClassTrib (Código de Classificação Tributária do IBS e CBS)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:cClassTrib/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(6) AS c_class_trib,
			    -- UB14a - indDoacao (Indica natureza da operação de doação)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:indDoacao/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(1) AS ind_doacao,
			    -- UB16 - vBC (Base de cálculo do IBS e CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:vBC/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			    -- UB18 - pIBSUF (Alíquota do IBS de competência das UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:pIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_uf,
			    -- UB22/UB23 - Grupo Diferimento IBS UF (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:pDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:vDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs,
			    -- UB25 - vDevTrib (Valor do tributo devolvido - IBS UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDevTrib/new:vDevTrib/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs,
			    -- UB27/UB28 - Grupo Redução de Alíquota IBS UF (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pRedAliq/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pAliqEfet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs,
			    -- UB35 - vIBSUF (Valor do IBS de competência da UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:vIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_uf,
			    -- UB37 - pIBSMun (Alíquota do IBS de competência do Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:pIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_mun,
			    -- UB41/UB42 - Grupo Diferimento IBS Município (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:pDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:vDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs_mun,
			    -- UB44 - vDevTrib (Valor do tributo devolvido - IBS Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDevTrib/new:vDevTrib/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs_mun,
			    -- UB46/UB47 - Grupo Redução de Alíquota IBS Município (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pRedAliq/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pAliqEfet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs_mun,
			    -- UB54 - vIBSMun (Valor do IBS de competência do Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:vIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mun,
			    -- UB54a - vIBS (Valor total do IBS - soma de vIBSUF e vIBSMun)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:vIBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs,
			    -- UB56 - pCBS (Alíquota da CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:pCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cbs,
			    -- UB60/UB61 - Grupo Diferimento CBS (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:pDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:vDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_cbs,
			    -- UB63 - vDevTrib (Valor do tributo devolvido - CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDevTrib/new:vDevTrib/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_cbs,
			    -- UB65/UB66 - Grupo Redução de Alíquota CBS (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pRedAliq/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS p_red_aliq_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pAliqEfet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_cbs,
			    -- UB67 - vCBS (Valor da CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:vCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs,
			    -- UB69/UB70 - Grupo Tributação Regular (gTribRegular)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:CSTReg/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(3) AS cst_reg,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:cClassTribReg/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(6) AS c_class_trib_reg,
			    -- UB71/UB72 - Tributação Regular IBS UF
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_uf,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_uf,
			    -- UB72a/UB72b - Tributação Regular IBS Município
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_mun,
			    -- UB72c/UB72d - Tributação Regular CBS
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_cbs,
			    -- UB82b/UB82c - Grupo Tributação Compra Governamental IBS UF (gTribCompraGov)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_uf,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSUF/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_uf,
			    -- UB82d/UB82e - Grupo Tributação Compra Governamental IBS Município
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSMun/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_mun,
			    -- UB82f/UB82g - Grupo Tributação Compra Governamental CBS
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_cbs,
			    -- UB85/UB86/UB87 - Grupo Monofásica Padrão (gMonoPadrao)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:qBCMono/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemIBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs,
			    -- UB88/UB89 - Valores Monofásica Padrão
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vIBSMono/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vCBSMono/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono,
			    -- UB91/UB92/UB93/UB93a/UB93b - Grupo Monofásica Retenção (gMonoReten)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:qBCMonoReten/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemIBSReten/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vIBSMonoReten/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemCBSReten/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vCBSMonoReten/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_reten,
			    -- UB95/UB96/UB97/UB98/UB98a - Grupo Monofásica Retida Anteriormente (gMonoRet)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:qBCMonoRet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemIBSRet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vIBSMonoRet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemCBSRet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vCBSMonoRet/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_ret,
			    -- UB100/UB101/UB102/UB103 - Grupo Diferimento Monofásica (gMonoDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifIBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vIBSMonoDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_dif,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vCBSMonoDif/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_dif,
			    -- UB104/UB105 - Totais Monofásica
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotIBSMonoItem/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_tot_ibs_mono_item,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotCBSMonoItem/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_tot_cbs_mono_item,
			    -- UB107/UB108 - Grupo Transferências de Crédito (gTransfCred)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gTransfCred/new:vIBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_trans_cred,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gTransfCred/new:vCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_trans_cred,
			    -- UB113/UB114/UB115 - Grupo Ajuste de Competência (gAjusteCompet)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:competApur/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(7) AS compet_apur_ajuste_compet,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vIBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_ajuste_compet,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vCBS/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_ajuste_compet,
			    -- UB117/UB118 - Grupo Estorno de Crédito (gEstornoCred)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gEstornoCred/new:vIBSEstCred/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_est_cred,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gEstornoCred/new:vCBSEstCred/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_est_cred,
			    -- UB121/UB122 - Grupo Crédito Presumido da Operação (gCredPresOper)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:vBCCredPres/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_cred_pres,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:cCredPres/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(2) AS c_cred_pres,
			    -- UB124/UB125/UB126 - Grupo Crédito Presumido IBS (gIBSCredPres)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:pCredPres/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPres/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPresCondSus/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_ibs,
			    -- UB128/UB129/UB130 - Grupo Crédito Presumido CBS (gCBSCredPres)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:pCredPres/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPres/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPresCondSus/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_cbs,
			    -- UB132/UB133/UB134 - Grupo Crédito Presumido IBS ZFM (gCredPresIBSZFM)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:competApur/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(7) AS compet_apur_ibs_zfm,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:tpCredPresIBSZFM/text()',
			           r_i01_prod.det_node, _nfe_namespaces))[1]::VARCHAR(1) AS tp_cred_pres_ibs_zfm,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:vCredPresIBSZFM/text()',
			            r_i01_prod.det_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs_zfm
			FROM (SELECT 1) AS _dummy
		) AS a
		WHERE
			a.cst IS NOT NULL
	);
	/* FIM INSERT nfe.ub12_ibs_cbs */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;

	/* INSERT TABLE ncm_helper.cad_produtos */
	INSERT INTO
	ncm_helper.cad_produtos(
		id_empresa,
		codg_produto,
		codg_barra,
		descricao,
		ncm,
		cest
	)
	(
		SELECT
			b.id_empresa,
			r_i01_prod.c_prod,
			CASE WHEN r_i01_prod.c_ean = 'SEM GTIN' OR r_i01_prod.c_ean IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean
			END AS c_ean,
			r_i01_prod.x_prod,
			COALESCE(r_i01_prod.ncm, '')::VARCHAR(8) AS ncm,
			r_i01_prod.cest
		FROM (SELECT 1) AS _dummy
		JOIN
			ncm_helper.cad_empresas b ON COALESCE(_nfe_header.cnpj_emit, _nfe_header.cpf_emit, '') = b.cpf_cnpj
	) ON CONFLICT DO NOTHING;
	/* FIM INSERT ncm_helper.cad_produtos */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
END LOOP;
/* FIM LOOP TABLE i01_prod */

/* INSERT TABLE nfe.w02_icms_tot */	
_step_name := 'insert_w02_icms_tot';
INSERT INTO 
	nfe.w02_icms_tot(
		id_nfe, 
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
	(		
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_bc, 0.00) AS v_bc, 
			COALESCE(a.v_icms, 0.00) AS v_icms,  
			COALESCE(a.v_bc_st, 0.00) AS v_bc_st,
			COALESCE(a.v_st, 0.00) AS v_st,
			COALESCE(a.v_prod, 0.00) AS v_prod,
			COALESCE(a.v_frete, 0.00) AS v_frete,
			COALESCE(a.v_seg, 0.00) AS v_seg,
			COALESCE(a.v_desc, 0.00) AS v_desc,
			COALESCE(a.v_ii, 0.00) AS v_ii,
			COALESCE(a.v_ipi, 0.00) AS v_ipi,
			COALESCE(a.v_pis, 0.00) AS v_pis,
			COALESCE(a.v_cofins, 0.00) AS v_cofins,
			COALESCE(a.v_outro, 0.00) AS v_outro,
			COALESCE(a.v_nf, 0.00) AS v_nf,
			COALESCE(a.v_tot_trib, 0.00) AS v_tot_trib,
			COALESCE(a.v_icms_deson, 0.00) AS v_icms_deson,
			COALESCE(a.v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest,
			COALESCE(a.v_icms_uf_dest, 0.00) AS v_icms_uf_dest,
			COALESCE(a.v_icms_uf_remet, 0.00) AS v_icms_uf_remet,
			COALESCE(a.v_fcp, 0.00) AS v_fcp,
			COALESCE(a.v_fcp_st, 0.00) AS v_fcp_st,
			COALESCE(a.v_fcp_st_ret, 0.00) AS v_fcp_st_ret,
			COALESCE(a.v_ipi_devol, 0.00) AS v_ipi_devol
		FROM
		(			
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vBC/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSDeson/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(18,2) AS v_icms_deson,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCP/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vBCST/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vST/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPST/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPSTRet/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st_ret,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vProd/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_prod,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFrete/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_frete,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vSeg/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_seg,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vDesc/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_desc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vII/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ii,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vIPI/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ipi,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vIPIDevol/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ipi_devol, 
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vPIS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vCOFINS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vOutro/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_outro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vNF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_nf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPUFDest/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_uf_dest,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSUFDest/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_dest,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSUFRemet/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_remet,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vTotTrib/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_tot_trib
			FROM (SELECT 1) AS _dummy
		)AS a
	);
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.w02_icms_tot */

/* INSERT TABLE nfe.w17_issqn_tot */
_step_name := 'insert_w17_issqn_tot';
INSERT INTO
	nfe.w17_issqn_tot(
		id_nfe,
		v_serv,
		v_bc,
		v_iss,
		v_pis,
		v_cofins,
		d_compet,
		v_deducao,
		v_outro,
		v_desc_incond,
		v_desc_cond,
		v_iss_ret,
		c_reg_trib
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_serv, 0.00) AS v_serv, 
			COALESCE(a.v_bc, 0.00) AS v_bc,  
			COALESCE(a.v_iss, 0.00) AS v_iss,
			COALESCE(a.v_pis, 0.00) AS v_pis,
			COALESCE(a.v_cofins, 0.00) AS v_cofins,
			a.d_compet::DATE,
			COALESCE(a.v_deducao, 0.00) AS v_deducao,
			COALESCE(a.v_outro, 0.00) AS v_outro,
			COALESCE(a.v_desc_incond, 0.00) AS v_desc_incond,
			COALESCE(a.v_desc_cond, 0.00) AS v_desc_cond,
			COALESCE(a.v_iss_ret, 0.00) AS v_iss_ret,
			a.c_reg_trib
		FROM
		(			
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vServ/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_serv,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vBC/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vISS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_iss,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vPIS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vCOFINS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:dCompet/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS d_compet,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDeducao/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_deducao,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vOutro/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_outro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDescIncond/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_desc_incond,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDescCond/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_desc_cond,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vISSRet/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_iss_ret,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:cRegTrib/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_reg_trib
			FROM (SELECT 1) AS _dummy
		) AS a
		WHERE
			a.d_compet IS NOT NULL
	);
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.w17_issqn_tot */

/* INSERT TABLE nfe.w23_ret_trib */
_step_name := 'insert_w23_ret_trib';
INSERT INTO
	nfe.w23_ret_trib(
		id_nfe,
		v_ret_pis,
		v_ret_cofins,
		v_ret_csll,
		v_bc_irrf,
		v_irrf,
		v_bc_ret_prev,
		v_ret_prev
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_ret_pis, 0.00) AS v_ret_pis, 
			COALESCE(a.v_ret_cofins, 0.00) AS v_ret_cofins,  
			COALESCE(a.v_ret_csll, 0.00) AS v_ret_csll,
			COALESCE(a.v_bc_irrf, 0.00) AS v_bc_irrf,
			COALESCE(a.v_irrf, 0.00) AS v_irrf,
			COALESCE(a.v_bc_ret_prev, 0.00) AS v_bc_ret_prev,
			COALESCE(a.v_ret_prev, 0.00) AS v_ret_prev
		FROM
		(
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetPIS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ret_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetCOFINS/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ret_cofins,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetCSLL/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ret_csll,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vBCIRRF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_irrf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vIRRF/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_irrf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vBCRetPrev/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_ret_prev,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetPrev/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ret_prev
			FROM (SELECT 1) AS _dummy
		) a
		WHERE
			a.v_ret_pis IS NOT NULL OR a.v_ret_cofins IS NOT NULL OR a.v_ret_csll IS NOT NULL OR a.v_irrf IS NOT NULL
	);
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.w23_ret_trib */

/* INSERT TABLE nfe.z01_inf_adic */
_step_name := 'insert_z01_inf_adic';
INSERT INTO
	nfe.z01_inf_adic(
		id_nfe,
		inf_ad_fisco,
		inf_cpl
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.inf_ad_fisco,
			a.inf_cpl
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infAdFisco/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(2000) AS inf_ad_fisco,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infCpl/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(2000) AS inf_cpl
			FROM (SELECT 1) AS _dummy
		) a
		WHERE
			a.inf_ad_fisco IS NOT NULL OR a.inf_cpl IS NOT NULL
	) RETURNING id INTO _id_inf_adic;
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.z01_inf_adic */

	IF _id_inf_adic IS NOT NULL THEN
		/* INSERT TABLE nfe.z04_obs_cont */
		INSERT INTO
			nfe.z04_obs_cont(
				id_nfe,
				id_inf_adic,
				x_campo,
				x_texto
			)
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_inf_adic AS id_inf_adic,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/new:xCampo/text()', _xml_content, _nfe_namespaces))::VARCHAR(20) AS x_campo,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/new:xTexto/text()', _xml_content, _nfe_namespaces))::VARCHAR(60) AS x_texto
				FROM (SELECT 1) AS _dummy
			);
		/* FIM INSERT nfe.z04_obs_cont */

		/* INSERT TABLE nfe.z07_obs_fisco */
		INSERT INTO
			nfe.z07_obs_fisco(
				id_nfe,
				id_inf_adic,
				x_campo,
				x_texto
			)
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_inf_adic AS id_inf_adic,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/new:xCampo/text()', _xml_content, _nfe_namespaces))::VARCHAR(20) AS x_campo,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/new:xTexto/text()', _xml_content, _nfe_namespaces))::VARCHAR(60) AS x_texto
				FROM (SELECT 1) AS _dummy
			);
		/* FIM INSERT nfe.z07_obs_fisco */
	END IF;

/* INSERT TABLE nfe.pr03_inf_prot */
_step_name := 'insert_pr03_inf_prot';
INSERT INTO
	nfe.pr03_inf_prot(
		id_nfe,
		ch_nfe,
		dh_recbto,
		n_prot,
		dig_val,
		c_stat,
		x_motivo
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.ch_nfe,
			a.dh_recbto::TIMESTAMP,
			a.n_prot,
			a.dig_val,
			a.c_stat,
			a.x_motivo
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:chNFe/text()', _xml_content, _nfe_namespaces))[1]::VARCHAR(44) AS ch_nfe,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:dhRecbto/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS dh_recbto,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:nProt/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS n_prot,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:digVal/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS dig_val,
				((xpath('/new:nfeProc/new:protNFe/new:infProt/new:cStat/text()', _xml_content, _nfe_namespaces))[1]::TEXT)::INT AS c_stat,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:xMotivo/text()', _xml_content, _nfe_namespaces))[1]::TEXT AS x_motivo
			FROM (SELECT 1) AS _dummy
		) a
		WHERE 
			a.c_stat IS NOT NULL
	);
GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* FIM INSERT nfe.pr03_inf_prot */

/* INSERT TABLE nfe.y07_dup */
_step_name := 'insert_y07_dup';
INSERT INTO
	nfe.y07_dup(
		id_nfe,
		n_dup,
		d_venc,
		v_dup
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.n_dup,
			a.d_venc::DATE,
			a.v_dup
		FROM
		(
			SELECT
				UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:nDup/text()', _xml_content, _nfe_namespaces))::VARCHAR(60) AS n_dup,
				UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:dVenc/text()', _xml_content, _nfe_namespaces))::TEXT AS d_venc,
				(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:vDup/text()', _xml_content, _nfe_namespaces))::TEXT)::NUMERIC(15, 2) AS v_dup
			FROM (SELECT 1) AS _dummy
		) a
		WHERE
			a.v_dup IS NOT NULL
	);
GET DIAGNOSTICS _records_processed = ROW_COUNT;
/* FIM INSERT nfe.y07_dup */

/* INÍCIO LOOP nfe.ya01_pag */
_step_name := 'loop_ya01_pag';
IF EXISTS (SELECT 1 FROM nfe.ya01_pag WHERE id_nfe = _id_nfe) THEN
ELSE
FOR r_ya01_pag IN
(
	WITH pag_nodes AS (
		SELECT
			generate_subscripts(
				xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag', _xml_content, _nfe_namespaces),
				1
			) AS position,
			unnest(
				xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag', _xml_content, _nfe_namespaces)
			) AS pag_node
	)
	SELECT
		position AS idx_pag,
		(xpath('/new:detPag/new:tPag/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(2) AS t_pag,
		((xpath('/new:detPag/new:vPag/text()', pag_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_pag,
		((xpath('/new:detPag/new:vTroco/text()', pag_node, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_troco,
		((xpath('/new:detPag/new:indPag/text()', pag_node, _nfe_namespaces))[1]::TEXT)::INT AS ind_pag,
		(xpath('/new:detPag/new:xPag/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(60) AS x_pag,
		((xpath('/new:detPag/new:dPag/text()', pag_node, _nfe_namespaces))[1]::TEXT)::DATE AS d_pag,
		(xpath('/new:detPag/new:CNPJPag/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(14) AS cnpj_pag,
		(xpath('/new:detPag/new:UFPag/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(2) AS uf_pag,
		-- Dados cartão (ya04_card)
		((xpath('/new:detPag/new:card/new:tpIntegra/text()', pag_node, _nfe_namespaces))[1]::TEXT)::INT AS tp_integra,
		(xpath('/new:detPag/new:card/new:CNPJ/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(14) AS cnpj_card,
		(xpath('/new:detPag/new:card/new:tBand/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(2) AS t_band,
		(xpath('/new:detPag/new:card/new:cAut/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(128) AS c_aut,
		(xpath('/new:detPag/new:card/new:CNPJReceb/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(14) AS cnpj_receb,
		(xpath('/new:detPag/new:card/new:idTermPag/text()', pag_node, _nfe_namespaces))[1]::VARCHAR(40) AS id_term_pag
	FROM pag_nodes
	WHERE (xpath('/new:detPag/new:tPag/text()', pag_node, _nfe_namespaces))[1] IS NOT NULL
	ORDER BY position
) LOOP
	/* INSERT TABLE nfe.ya01_pag */
	INSERT INTO nfe.ya01_pag(
		id_nfe,
		t_pag,
		v_pag,
		v_troco,
		ind_pag,
		x_pag,
		d_pag,
		cnpj_pag,
		uf_pag
	)
	SELECT
		_id_nfe,
		r_ya01_pag.t_pag,
		COALESCE(r_ya01_pag.v_pag, 0.00),
		r_ya01_pag.v_troco,
		r_ya01_pag.ind_pag,
		r_ya01_pag.x_pag,
		r_ya01_pag.d_pag,
		r_ya01_pag.cnpj_pag,
		r_ya01_pag.uf_pag
	RETURNING id_pag INTO _id_pag;
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.ya01_pag */

	/* INSERT TABLE nfe.ya04_card */
	INSERT INTO nfe.ya04_card(
		id_nfe,
		id_pag,
		tp_integra,
		cnpj,
		t_band,
		c_aut,
		cnpj_receb,
		id_term_pag
	)
	SELECT
		_id_nfe,
		_id_pag,
		r_ya01_pag.tp_integra,
		r_ya01_pag.cnpj_card,
		r_ya01_pag.t_band,
		r_ya01_pag.c_aut,
		r_ya01_pag.cnpj_receb,
		r_ya01_pag.id_term_pag
	WHERE r_ya01_pag.tp_integra IS NOT NULL;
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	/* FIM INSERT nfe.ya04_card */
END LOOP;
END IF; -- fim guard ya01_pag
/* FIM LOOP TABLE ya01_pag */

/* INSERT TABLE ncm_helper.cad_produtos */
_step_name := 'insert_ncm_cad_produtos';
insert into ncm_helper.cad_produtos (id_empresa, codg_produto, codg_barra, ncm, cest, descricao)
(
	select
		a.id_empresa,
		a.c_prod,
		a.c_ean,
		a.ncm,
		a.cest,
		(select * from ncm_helper.sem_acentos(upper(a.descricao)))as descricao
	from
	(
		select
			a.id_empresa,
			c.c_prod,
			case when c.c_ean = 'SEM GTIN' then ''::text 
			when (c.c_ean is null or c.c_ean = '') then ''::text 
			when c.c_ean = c.c_ean_trib then c.c_ean
			when c.c_ean <> c.c_ean_trib then c.c_ean_trib
			else c.c_ean end as c_ean,
			case when length(c.ncm) = 8 then
			trim(c.ncm) else ''::text end as ncm,
			case when c.cest = 0 then ''::varchar(7)
			when c.cest is null then ''::varchar(7)
			else lpad(c.cest::text, 7,'0')::varchar(7) end as cest,
			to_char(b.d_emi,'yyyy-mm-01')::date as dt_ocorrencia,
			upper(trim(c.x_prod))::varchar(255) as descricao,
			upper(trim(c.u_com)) as unid
		from ncm_helper.cad_empresas as a
		join nfe.raiz_nfe as b using(cpf_cnpj)
		join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
		where b.inf_nfe = _ch_nf 
	)as a
	left join ncm_helper.cad_produtos as b on (a.id_empresa, a.c_prod) = (b.id_empresa, b.codg_produto)
	where b.id_empresa is null	
)on conflict do nothing;
/* FIM TABLE ncm_helper.cad_produtos */	
GET DIAGNOSTICS _records_processed = ROW_COUNT;

/* INSERT TABLE ncm_helper.cad_produtos_ocorrencia */
_step_name := 'insert_ncm_cad_produtos_ocorrencia';
	INSERT INTO ncm_helper.cad_produtos_ocorrencia (id_empresa, codg_produto, dt_ocorrencia, cst_icms, descricao, ncm, unid, codg_barra, cest) 
	(
		SELECT
			DISTINCT ON(a.id_empresa, a.dt_ocorrencia, a.c_prod)
			a.id_empresa,
			a.c_prod,
			a.dt_ocorrencia,
			'060'::VARCHAR(3) AS cst_icms,
			(select * from ncm_helper.sem_acentos(upper(a.descricao)))as descricao,		
			a.ncm,
			a.unid,
			a.c_ean,
			a.cest
		FROM
		(
			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = 8 THEN
				TRIM(c.ncm) ELSE ''::text END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.i01_prod AS c USING(cpf_cnpj, n_nf, serie, mod)
			WHERE b.inf_nfe = _ch_nf and c.c_ean = c.c_ean_trib

			UNION

			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = 8 THEN
				c.ncm ELSE ''::text	END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.i01_prod AS c USING(cpf_cnpj, n_nf, serie, mod)
			WHERE b.inf_nfe = _ch_nf and c.c_ean <> c.c_ean_trib

			UNION

			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = 8 THEN
				c.ncm ELSE ''::text	END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.c01_emit AS d USING(id_nfe, ie)
			JOIN nfe.i01_prod AS c ON(a.cpf_cnpj, b.n_nf, b.serie, b.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			WHERE b.inf_nfe = _ch_nf
		)AS a
		LEFT JOIN ncm_helper.cad_produtos_ocorrencia AS b ON (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		WHERE b.id_empresa IS NULL
	)ON  CONFLICT DO NOTHING;
/* FIM TABLE ncm_helper.cad_produtos_ocorrencia */	

/* INSERT TABLE sf.resumo_nota_propria */
	insert into sf.resumo_nota_propria(cpf_cnpj, num_doc, ser, cod_mod, chv_nfe, cfop, cst_icms, aliquota, vl_opr, vl_bc_icms, vl_icms, vl_bc_icms_st, vl_icms_st, vl_frt, vl_seg, vl_desc, vl_out_da, vl_doc, vl_ipi, vl_merc, operacao, dt_doc2, aliq_icms, dt_ini2, cod_sit, vl_red_bc)
	(
		select
			a.cpf_cnpj, 
			a.num_doc, 
			a.ser, 
			a.cod_mod, 
			a.chv_nfe, 
			a.cfop, 
			a.cst_icms, 
			a.aliquota, 
			a.vl_opr, 
			a.vl_bc_icms,
			a.vl_icms,
			a.vl_bc_icms_st,
			a.vl_icms_st,
			a.vl_frt, 
			a.vl_seg, 
			a.vl_desc, 
			a.vl_out_da, 
			a.vl_doc, 
			a.vl_ipi, 
			a.vl_merc, 
			a.operacao, 
			a.dt_doc2, 
			a.aliq_icms, 
			a.dt_ini2, 
			a.cod_sit, 
			a.vl_red_bc
		from
		(
			select
				a.cpf_cnpj, 
				a.num_doc, 
				a.ser, 
				a.cod_mod, 
				a.chv_nfe, 
				a.cfop, 
				a.cst_icms, 
				a.aliquota::numeric(18,3) as aliquota, 
				sum(a.vl_opr)::numeric(18,2) as vl_opr, 
				sum(a.vl_bc_icms)::numeric(18,2) as vl_bc_icms,
				sum(a.vl_icms)::numeric(18,2) as vl_icms,
				sum(a.vl_bc_icms_st)::numeric(18,2) as vl_bc_icms_st,
				sum(a.vl_icms_st)::numeric(18,2) as vl_icms_st,
				sum(a.vl_frt)::numeric(18,2) as vl_frt, 
				sum(a.vl_seg)::numeric(18,2) as vl_seg, 
				sum(a.vl_desc)::numeric(18,2) as vl_desc, 
				sum(a.vl_out_da)::numeric(18,2) as vl_out_da, 
				a.vl_doc, 
				sum(a.vl_ipi)::numeric(18,2) as vl_ipi, 
				a.vl_merc, 
				a.operacao, 
				a.dt_doc2, 
				a.aliq_icms::numeric(18,3) as aliq_icms, 
				a.dt_ini2, 
				a.cod_sit, 
				sum(a.vl_red_bc)::numeric(18,2) as vl_red_bc
			from
			(
				select
					a.cpf_cnpj, 
					a.num_doc, 
					a.ser, 
					a.cod_mod, 
					a.chv_nfe, 
					a.cfop, 
					a.cst_icms, 
					a.aliquota, 
					a.vl_opr, 
					a.vl_bc_icms, 
					a.vl_icms, 
					a.vl_bc_icms_st, 
					a.vl_icms_st, 
					a.vl_frt, 
					a.vl_seg, 
					a.vl_desc, 
					a.vl_out_da, 
					a.vl_doc, 
					a.vl_ipi, 
					a.vl_merc, 
					a.operacao, 
					a.dt_doc2, 
					a.aliq_icms, 
					a.dt_ini2, 
					a.cod_sit, 
					case when a.cst_icms = '020' and (a.vl_opr - a.vl_bc_icms) > 0.00 then (a.vl_opr - a.vl_bc_icms)::numeric(18,2)
					when a.cst_icms = '070' and (a.vl_opr - a.vl_bc_icms_st) > 0.00 then (a.vl_opr - a.vl_bc_icms_st)::numeric(18,2)
					when a.cst_icms = any(array['070','020']) and (a.vl_bc_icms + a.vl_bc_icms_st) = 0.00 then 0.01::numeric(18,2)
					else 0.00::numeric(18,2) end as vl_red_bc
				from
				(
					select
						a.cpf_cnpj,	a.num_doc, a.ser, a.cod_mod, a.chv_nfe, a.dt_ini2,
						a.cod_sit, a.dt_doc2,
						a.vl_merc, a.vl_doc,
						case when d.cso_sn <> '' then trim(lpad(d.cso_sn, 3, '0'))
						else trim(lpad(d.cst, 3, '0'))  end as cst_icms,
						b.cfop,
						case when d.p_icms > 0 then d.p_icms else 0.00::numeric(18,2) end aliquota,
						case when d.p_icms > 0 then d.p_icms else null::numeric(18,2) end aliq_icms,
						(b.v_prod + coalesce(b.v_frete, .0)::numeric(18, 2) + coalesce(b.v_seg, .0)::numeric(18, 2) + coalesce(e.v_ipi, .0)::numeric(18, 2) + coalesce(b.v_outro, .0)::numeric(15, 2) - coalesce(b.v_desc, .0)::numeric(18, 2))::decimal(18, 2) as vl_opr,
						coalesce(d.v_bc, 0.00) as vl_bc_icms,
						coalesce(d.v_icms, 0.00) as vl_icms,
						coalesce(d.v_bc_st, 0.00) as vl_bc_icms_st,
						coalesce(d.v_icms_st, 0.00) as vl_icms_st,	
						coalesce(b.v_frete, .0)::numeric(18, 2 ) as vl_frt,
						coalesce(b.v_seg, .0)::numeric(18, 2 ) as vl_seg,
						coalesce(e.v_ipi, .0)::numeric(18, 2) as vl_ipi,
						coalesce(b.v_outro, .0)::numeric(15, 2) as vl_out_da,
						coalesce(b.v_desc, .0)::numeric(18, 2 ) as vl_desc,
						c.operacao
					from
					(
						select
							a.cpf_cnpj,	a.n_nf, a.serie, a.mod,
							a.n_nf as num_doc,
							a.ser, 
							a.mod as cod_mod, 
							a.inf_nfe as chv_nfe,
							to_char(a.d_emi,'yyyy-mm-01')::date as dt_ini2,
							a.cod_sit,
							a.d_emi as dt_doc2,
							b.v_prod as vl_merc,
							b.v_nf as vl_doc
						from nfe.raiz_nfe as a
						join nfe.w02_icms_tot as b using(id_nfe)
						where a.id_nfe = _id_nfe
					)as a
					join nfe.i01_prod as b using(cpf_cnpj, n_nf, serie, mod)
					join ncm_helper.cad_cfop as c using(cfop)
					join nfe.icms_filhos as d on (b.id_nfe, b.id) = (d.id_nfe, d.id_prod)
					left join nfe.ipi_filhos as e on (b.id_nfe, b.id) = (e.id_nfe, e.id_prod)
				)as a
			)as a
			group by a.cpf_cnpj, a.num_doc, a.ser, a.cod_mod, a.chv_nfe, a.cfop, a.cst_icms, a.aliquota, a.vl_doc, a.vl_merc, a.operacao, a.dt_doc2, a.aliq_icms, a.dt_ini2, a.cod_sit
		)as a
		left join sf.resumo_nota_propria as b using(cpf_cnpj, num_doc, ser, cod_mod, chv_nfe, cfop, cst_icms, aliquota)
		where b.cpf_cnpj is null
	)on conflict do nothing;
/* FIM TABLE sf.resumo_nota_propria */
GET DIAGNOSTICS _records_processed = ROW_COUNT;

/* UPDATE COD_CTA nfe.i01_prod */
_step_name := 'update_cod_cta_mod65';
	update nfe.i01_prod as a
	set cod_cta = b.cod_cta,
		x_prod = b.descr_item
	from
	(
		select
			b.id_nfe, b.id,
			(select * from ncm_helper.sem_acentos(upper(b.x_prod)))as descr_item,
			'4101010004'::varchar(60) as cod_cta
		from nfe.raiz_nfe as a
		join nfe.i01_prod as b using(cpf_cnpj, n_nf, serie, mod)
		where a.id_nfe = _id_nfe and a.mod = '65'
		and (b.cod_cta = '' or b.cod_cta is null)
	)as b
	where (a.id_nfe, a.id) = (b.id_nfe, b.id);
GET DIAGNOSTICS _records_processed = ROW_COUNT;

_step_name := 'update_cod_cta_mod55';
	update nfe.i01_prod as a
	set cod_cta = b.cod_cta,
		x_prod = b.descr_item
	from
	(
		select
			c.id_nfe, c.id, 
			(select * from ncm_helper.sem_acentos(upper(c.x_prod)))as descr_item,
			d.cod_cta
		from ncm_helper.cad_empresas as a
		join nfe.raiz_nfe as b using(cpf_cnpj)
		join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
		join contabil.plano_conta_padrao_has_cfop as d on c.cfop = d.cfop
		where b.id_nfe = _id_nfe 
		and b.mod = '55' and d.cod_cta <> '4101010004'
		and (c.cod_cta = '' or c.cod_cta is null)
	)as b
	where (a.id_nfe, a.id) = (b.id_nfe, b.id);
GET DIAGNOSTICS _records_processed = ROW_COUNT;
	
/* FIM TABLE nfe.i01_prod */

	-- ✅ CONCLUSÃO COM SUCESSO
	_step_name := 'process_completed';
	
	_result := jsonb_build_object(
		'success', true,
		'message', 'XML desestruturado com sucesso',
		'data', jsonb_build_object(
			'xml_id', _xml_id,
			'nfe_id', _id_nfe,
			'ch_nfe', _ch_nf,
			'n_nf', _nfe_header.n_nf,
			'serie', _nfe_header.serie,
			'modelo', _nfe_header.mod,
			'emit_cnpj', COALESCE(_nfe_header.cnpj_emit, _nfe_header.cpf_emit),
			'dest_cnpj', COALESCE(_nfe_header.cnpj_dest, _nfe_header.cpf_dest)
		),
		'performance', jsonb_build_object(
			'processing_time_ms', ROUND((EXTRACT(EPOCH FROM (NOW() - _start_time)) * 1000)::NUMERIC, 2),
			'start_time', _start_time,
			'end_time', NOW()
		)
	);
	
	RAISE INFO '[%] Processamento concluído com sucesso: XML ID % -> NFe ID %', 
		_step_name, _xml_id, _id_nfe;
	
	RETURN _result;

EXCEPTION
	WHEN OTHERS THEN
		_result := jsonb_build_object(
			'success', false,
			'message', 'Erro durante desestruturação do XML',
			'error', jsonb_build_object(
				'code', SQLSTATE,
				'message', SQLERRM,
				'step', COALESCE(_step_name, 'unknown'),
				'xml_id', _xml_id,
				'nfe_id', _id_nfe
			),
			'performance', jsonb_build_object(
				'processing_time_ms', ROUND((EXTRACT(EPOCH FROM (NOW() - _start_time)) * 1000)::NUMERIC, 2)
			)
		);
		
		RAISE WARNING '[ERRO] XML ID %: % - %', _xml_id, SQLSTATE, SQLERRM;
		
		RETURN _result;
END;
$$;


ALTER FUNCTION xml.desestruturar_xml_nfe_nfce(_xml_id bigint, substituir boolean) OWNER TO dorcilio;

--
-- TOC entry 3706 (class 1255 OID 586515560)
-- Name: desestruturar_xml_nfe_nfce_old(bigint, boolean); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.desestruturar_xml_nfe_nfce_old(_xml_id bigint, substituir boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	_ch_nf VARCHAR(44);
	_id_nfe BIGINT;
	has_nf_ref INTEGER := 0;
	_id_emit BIGINT;
	has_dest BOOLEAN;
	_id_dest BIGINT;
	_id_prod BIGINT;
	r_i01_prod RECORD;
	_id_imposto_devol BIGINT;
	has_icms_uf_dest BOOLEAN;
	_id_inf_adic BIGINT;
	xml_det_pag XML;
	_id_pag BIGINT;
	ind_pag INT;
	cnpj_card VARCHAR(14);
begin
/*
	BEGIN;

	DELETE FROM nfe.raiz_nfe WHERE xml_id IN (15808283, 16324644, 16324643) 
	SELECT * FROM xml.desestruturar_xml_nfe_nfce(15808283, FALSE);

	COMMIT;
	
	SELECT * FROM xml.nfe_nfce AS a WHERE ch_nf = '51250303662768000119651030001175011912040881'
	
	SELECT * FROM nfe.raiz_nfe WHERE inf_nfe = '51250309494971000290550010000020711086141751'
*/

/* REMOÇÃO DE VERSÃO ANTERIOR C/ BASE NA CHAVE */
SELECT ch_nf INTO _ch_nf FROM xml.nfe_nfce WHERE xml_id = _xml_id;
SELECT id_nfe INTO _id_nfe FROM nfe.raiz_nfe WHERE inf_nfe = _ch_nf LIMIT 1;
IF _id_nfe IS NOT NULL THEN
	IF substituir IS TRUE THEN
		--DELETE FROM nfe.raiz_nfe WHERE id_nfe = _id_nfe;
		RAISE NOTICE 'DELEÇÃO DESATIVADA, FAZER 1 POR 1 - 2MIN APRÓX.';
		RETURN;
	ELSE
		UPDATE
			nfe.raiz_nfe
		SET
			xml_id = _xml_id
		WHERE
			id_nfe = _id_nfe;
		RETURN;
	END IF;
END IF;

/* INSERT TABLE nfe.raiz_nfe */
INSERT INTO
	nfe.raiz_nfe(
		inf_nfe,
		n_nf,
		serie,
		cpf_cnpj,
		mod,
		ser,
		dest_cpf_cnpj,
		cnpj_chave,
		d_emi,
		ch_nfe,
		xml_id
	)
	(
		SELECT
			distinct on(a.inf_nfe)
			a.inf_nfe,
			a.n_nf,
			a.serie,
			a.cpf_cnpj,
			a.mod,
			a.ser,
			a.dest_cpf_cnpj,
			a.cnpj_chave,
			a.d_emi,
			a.ch_nfe,
			a.xml_id
		FROM
		(
			SELECT
				a.ch_nf AS inf_nfe,
				a.n_nf::INT,
				a.serie::INT,
				COALESCE(a.cnpj_emit, a.cpf_emit, '') AS cpf_cnpj,
				a.mod,
				a.serie AS ser,
				COALESCE(a.cnpj_dest, a.cpf_dest, '') AS dest_cpf_cnpj,
				SUBSTRING(a.ch_nf, 7, 14) AS cnpj_chave,
				a.dh_emi::DATE AS d_emi,
				a.ch_nf AS ch_nfe,
				a.xml_id AS xml_id
			FROM
			(
				SELECT
					a.xml_id,
					regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS n_nf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS serie,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj_dest,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf_dest,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj_emit,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf_emit,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS mod,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dh_emi
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
				-- select * from xml.nfe_nfce where ch_nf = '51250308822539000138550010001955081140116513'
				-- select * from nfe.raiz_nfe where inf_nfe = '51250308822539000138550010001955081140116513' 
			) a
		)as a
		--left join nfe.raiz_nfe as b using(cpf_cnpj, n_nf, serie, mod)
   		---where b.id_nfe is null
	)on conflict do nothing RETURNING id_nfe INTO _id_nfe;
/* FIM INSERT nfe.raiz_nfe */

/* INSERT TABLE nfe.b01_ide */
INSERT INTO 
	nfe.b01_ide(
		id_nfe, 
		c_uf, 
		nat_op, 
		ind_pag, 
		mod, 
		serie, 
		n_nf, 
		d_emi, 
		d_sai_ent, 
		h_sai_ent, 
		tp_nf, 
		c_mun_fg, 
		tp_imp, 
		tp_emis, 
		c_dv, 
		tp_amb, 
		fin_nfe, 
		proc_emi, 
		ver_proc, 
		dh_cont, 
		x_just, 
		c_nf, 
		dh_emi, 
		dh_sai_ent, 
		id_dest, 
		ind_final, 
		ind_pres
	)
	(
		SELECT
			a.id_nfe,
			a.c_uf,
			a.nat_op,
			a.ind_pag,
			a.mod,
			a.serie,
			a.n_nf,
			a.dh_emi::DATE AS d_emi,
			COALESCE(a.dh_sai_ent, a.dh_emi)::DATE AS d_sai_ent,
			(COALESCE(a.dh_sai_ent, a.dh_emi)::TIMESTAMP)::TIME AS h_sai_ent,
			a.tp_nf,
			a.c_mun_fg,
			a.tp_imp,
			a.tp_emis,
			a.c_dv,
			a.tp_amb,
			a.fin_nfe,
			a.proc_emi,
			a.ver_proc,
			a.dh_cont::TIMESTAMP AS dh_cont,
			a.x_just,
			a.c_nf,
			a.dh_emi::TIMESTAMP AS dh_emi,
			COALESCE(a.dh_sai_ent, a.dh_emi)::TIMESTAMP AS dh_sai_ent,
			a.id_dest,
			a.ind_final,
			a.ind_pres
		FROM
		(
			SELECT
				coalesce(b.id_nfe,_id_nfe) AS id_nfe,
				--b.id_nfe,
				a.c_uf,
				a.nat_op,
				a.ind_pag,
				a.mod,
				a.serie,
				a.n_nf,
				a.dh_emi::DATE AS d_emi,
				COALESCE(a.dh_sai_ent, a.dh_emi)::DATE AS d_sai_ent,
				(COALESCE(a.dh_sai_ent, a.dh_emi)::TIMESTAMP)::TIME AS h_sai_ent,
				a.tp_nf,
				a.c_mun_fg,
				a.tp_imp,
				a.tp_emis,
				a.c_dv,
				a.tp_amb,
				a.fin_nfe,
				a.proc_emi,
				a.ver_proc,
				a.dh_cont::TIMESTAMP AS dh_cont,
				a.x_just,
				a.c_nf,
				a.dh_emi::TIMESTAMP AS dh_emi,
				COALESCE(a.dh_sai_ent, a.dh_emi)::TIMESTAMP AS dh_sai_ent,
				a.id_dest,
				a.ind_final,
				a.ind_pres
			FROM
			(
				SELECT
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cUF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_uf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:natOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nat_op,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag//new:detPag/new:indPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pag,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS mod,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS serie,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::BIGINT AS n_nf,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_nf,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cMunFG/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun_fg,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpImp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_imp,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpEmis/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_emis,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cDV/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_dv,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpAmb/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_amb,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:finNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS fin_nfe,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:procEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS proc_emi,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:verProc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(20) AS ver_proc,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(9) AS c_nf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhCont/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dh_cont,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dh_emi,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:xJust/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_just,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dh_sai_ent,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:idDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS id_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indFinal/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_final,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indPres/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pres,
					a.ch_nf
				FROM
					xml.nfe_nfce a				
				WHERE
					a.xml_id = _xml_id
			)AS a
			LEFT JOIN
				nfe.raiz_nfe b on a.ch_nf = b.inf_nfe
		)AS a
		LEFT JOIN nfe.b01_ide AS b USING(id_nfe)
		WHERE b.id_nfe IS NULL
	);
/* FIM INSERT nfe.b01_ide */

/* VERIFICAR SE POSSUÍ NF REFERÊNCIADA */
SELECT
	COALESCE(array_length((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])), 1), 0)
INTO
	has_nf_ref
FROM
	xml.nfe_nfce a
WHERE
	a.xml_id = _xml_id;

IF has_nf_ref > 0 THEN
	/* INSERT TABLE nfe.b12a_nf_ref */
	INSERT INTO
	nfe.b12a_nf_ref(
		id_nfe,
		ref_nfe,
		ref_cte
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(44) AS ref_nfe,
			unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refCTe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(44) AS ref_cte
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	);
END IF;

/* INSERT TABLE nfe.c01_emit */
INSERT INTO 
	nfe.c01_emit(
		id_nfe, 
		cnpj, 
		cpf, 
		x_nome, 
		x_fant, 
		ie, 
		iest, 
		im, 
		cnae, 
		crt, 
		cpf_cnpj
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.cnpj, '')::VARCHAR(14) AS cnpj,
			COALESCE(a.cpf, '')::VARCHAR(11) AS cpf,
			a.x_nome,
			COALESCE(a.x_fant, '')::VARCHAR(60) AS x_fant,
			a.ie,
			COALESCE(a.iest, '')::VARCHAR(14) AS iest,
			COALESCE(a.im, '')::VARCHAR(15) AS im,
			COALESCE(a.cnae, '')::VARCHAR(7) AS cnae,
			a.crt,
			COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_nome,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xFant/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_fant,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS ie,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IEST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS iest,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IM/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS im,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNAE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnae,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CRT/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS crt
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
	) RETURNING id INTO _id_emit;
/* FIM INSERT nfe.c01_emit */

/* INSERT TABLE nfe.c05_ender_emit */	
INSERT INTO 
	nfe.c05_ender_emit(
		id_nfe, 
		id_emit, 
		x_lgr, 
		nro, 
		x_cpl, 
		x_bairro, 
		c_mun, 
		x_mun, 
		uf, 
		cep, 
		c_pais, 
		x_pais, 
		fone
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_emit AS id_emit,
			a.x_lgr, 
			COALESCE(a.nro, '')::VARCHAR(60) AS nro, 
			COALESCE(a.x_cpl, '')::VARCHAR(60) AS x_cpl, 
			COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro, 
			a.c_mun, 
			COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun, 
			COALESCE(a.uf, '')::VARCHAR(2) AS uf, 
			COALESCE(a.cep, '')::VARCHAR(8) AS cep, 
			CASE WHEN a.c_pais = 'Brasil' THEN 1058::INTEGER 
				ELSE COALESCE(a.c_pais, '1058')::INT END AS c_pais, 
			COALESCE(a.x_pais, '')::VARCHAR(60) AS x_pais, 
			COALESCE(a.fone, '')::VARCHAR(14) AS fone
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_cpl,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS c_pais,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_pais,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS fone
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
	
	);
/* FIM INSERT nfe.c05_ender_emit */

/* VERIFICAR SE POSSUÍ DESTINATÁRIO */
SELECT
	(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1] IS NOT NULL
INTO
	has_dest
FROM
	xml.nfe_nfce a
WHERE
	a.xml_id = _xml_id;

IF has_dest IS TRUE THEN
	/* INSERT TABLE nfe.e01_dest */	
	INSERT INTO 
		nfe.e01_dest(
			id_nfe, 
			cnpj, 
			cpf, 
			ie, 
			isuf, 
			email, 
			cpf_cnpj, 
			id_estrangeiro, 
			ind_ie_dest, 
			im, 
			x_nome
		)
		(
			SELECT
				_id_nfe AS id_nfe,
				COALESCE(a.cnpj, '')::VARCHAR(14) AS cnpj,
				COALESCE(a.cpf, '')::VARCHAR(11) AS cpf,
				a.ie,
				a.isuf,
				COALESCE(a.email,'')::VARCHAR(60) AS email,
				COALESCE(a.cnpj,a.cpf)::VARCHAR(14) AS cpf_cnpj,
				COALESCE(a.id_estrangeiro, '')::VARCHAR(20) AS id_estrangeiro,
				a.ind_ie_dest,
				COALESCE(a.im, '')::VARCHAR(15) AS im,
				a.x_nome		
			FROM
			(
				SELECT
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS ie,			
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_nome,				
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:indIEDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_ie_dest,			
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IM/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS im,			
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:email/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS email,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:idEstrangeiro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS id_estrangeiro,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:isuf/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(9) AS isuf
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			)AS a		
		) RETURNING id INTO _id_dest;
	/* FIM INSERT nfe.e01_dest */

	/* INSERT TABLE nfe.e05_ender_dest */	
	INSERT INTO 
		nfe.e05_ender_dest(
			id_nfe, 
			id_dest, 
			x_lgr, 
			nro, 
			x_cpl, 
			x_bairro, 
			c_mun, 
			x_mun, 
			uf, 
			cep, 
			c_pais, 
			x_pais, 
			fone
		)
		(
			SELECT
				_id_nfe AS id_nfe,
				_id_dest AS id_dest,
				a.x_lgr, 
				COALESCE(a.nro, '')::VARCHAR(60) AS nro, 
				COALESCE(a.x_cpl, '')::VARCHAR(60) AS x_cpl, 
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro, 
				a.c_mun, 
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun, 
				COALESCE(a.uf, '')::VARCHAR(2) AS uf, 
				COALESCE(a.cep, '')::VARCHAR(8) AS cep, 
				CASE WHEN a.c_pais = 'Brasil' THEN 1058::INTEGER 
					ELSE COALESCE(a.c_pais, '1058')::INT END AS c_pais, 
				COALESCE(a.x_pais, '')::VARCHAR(60) AS x_pais, 
				COALESCE(a.fone, '')::VARCHAR(14) AS fone
			FROM
			(
				SELECT
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_cpl,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS c_pais,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_pais,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS fone
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			) AS a
		);
	/* FIM INSERT nfe.e05_ender_dest */
END IF;

/* INSERT TABLE public.participante */
INSERT INTO
	public.participante(
		cpf_cnpj,
		nome,
		suframa,
		telefone,
		email,
		cod_pais,
		cidade,
		uf,
		cep,
		logradouro,
		bairro,
		numero,
		cod_mun,
		fantasia
	)
	(
		SELECT
			a.cpf_cnpj,
			a.x_nome,
			a.isuf,
			a.fone,
			a.email,
			a.c_pais,
			a.x_mun,
			a.uf,
			a.cep,
			a.x_lgr,
			a.x_bairro,
			a.nro,
			a.c_mun,
			a.x_fant
		FROM
		(	
			SELECT
				COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
				a.x_nome,
				a.isuf,
				COALESCE(a.fone, '')::VARCHAR(14) AS fone,
				a.email,
				CASE WHEN a.c_pais = 'Brasil' THEN 1058::INTEGER 
					ELSE COALESCE(a.c_pais, '1058')::INT END AS c_pais, 
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
				COALESCE(a.uf, '')::VARCHAR(2) AS uf,
				COALESCE(a.cep, '')::VARCHAR(8) AS cep,
				a.x_lgr,
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
				COALESCE(a.nro, '')::VARCHAR(60) AS nro,
				a.c_mun,
				COALESCE(a.x_fant, '')::VARCHAR(60) AS x_fant
			FROM
			(
				SELECT
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_nome,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:isuf/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(9) AS isuf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS fone,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:email/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS email,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS c_pais,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xFant/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_fant
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id

				UNION

				SELECT
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_nome,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:isuf/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(9) AS isuf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS fone,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:email/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS email,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS c_pais,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
					(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xFant/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_fant
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			)AS a
		 	WHERE COALESCE(a.cnpj, a.cpf) IS NOT NULL
		) a
		LEFT JOIN
			public.participante b ON a.cpf_cnpj = b.cpf_cnpj
		WHERE
			b.cpf_cnpj IS NULL AND a.x_nome IS NOT NULL
	);
/* FIM INSERT public.participante */

/* INSERT TABLE public.participante_ie */
WITH encontrados AS
(
	SELECT
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS ie,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IEST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS iest
	FROM
		xml.nfe_nfce a
	WHERE
		a.xml_id = _xml_id AND substring(a.ch_nf,21,2)::varchar(2) <> '65'
	
	UNION

	SELECT
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS uf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cep,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_lgr,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_bairro,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS nro,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS ie,
		null AS iest
	FROM
		xml.nfe_nfce a
	WHERE
		a.xml_id = _xml_id AND substring(a.ch_nf,21,2)::varchar(2) <> '65'
)
INSERT INTO
	public.participante_ie(
		cpf_cnpj,
		ie,
		logradouro,
		numero,
		bairro,
		cidade,
		cep,
		uf,
		ie_substituicao,
		cod_mun
	)
	(
		SELECT
			a.cpf_cnpj,
			a.ie,
			a.x_lgr,
			a.nro,
			a.x_bairro,
			a.x_mun,
			a.cep,
			a.uf,
			a.ie_substituicao,
			a.c_mun
		FROM
		(
			SELECT
				COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
				case when a.ie <> '' then a.ie else ''::text end as ie,
				a.x_lgr,
				COALESCE(a.nro, '')::VARCHAR(60) AS nro,
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
				COALESCE(a.cep, '')::VARCHAR(8) AS cep,
				COALESCE(a.uf, '')::VARCHAR(2) AS uf,
				FALSE AS ie_substituicao,
				a.c_mun
			FROM
				encontrados a
			WHERE
				COALESCE(a.cnpj, a.cpf) IS NOT NULL AND a.iest IS NULL
			
			UNION
			
			SELECT
				COALESCE(a.cnpj, a.cpf)::VARCHAR(14) AS cpf_cnpj,
				--a.iest AS ie,
				case when a.iest <> '' then a.iest else ''::text end as ie,
				a.x_lgr,
				COALESCE(a.nro, '')::VARCHAR(60) AS nro,
				COALESCE(a.x_bairro, '')::VARCHAR(60) AS x_bairro,
				COALESCE(a.x_mun, '')::VARCHAR(60) AS x_mun,
				COALESCE(a.cep, '')::VARCHAR(8) AS cep,
				COALESCE(a.uf, '')::VARCHAR(2) AS uf,
				TRUE AS ie_substituicao,
				a.c_mun
			FROM
				encontrados a
			WHERE
				COALESCE(a.cnpj, a.cpf) IS NOT NULL AND a.iest IS NOT NULL
		) a
		LEFT JOIN
			public.participante_ie b ON (a.cpf_cnpj, a.ie) = (b.cpf_cnpj, b.ie)
		WHERE
			b.cpf_cnpj IS NULL
	);
/* FIM INSERT public.participante_ie */

/* INSERT TABLE nfe.d01_avulsa */
INSERT INTO
	nfe.d01_avulsa(
		id_nfe,
		cnpj,
		x_orgao,
		matr,
		x_agente,
		fone,
		uf,
		n_dar,
		d_emi,
		v_dar,
		rep_emi,
		d_pag
	)
	(
		SELECT
			a.id_nfe,
			a.cnpj,
			a.x_orgao,
			a.matr,
			a.x_agente,
			a.fone,
			a.uf,
			a.n_dar,
			a.d_emi::DATE,
			a.v_dar,
			a.rep_emi,
			a.d_pag::DATE
		FROM
		(
			SELECT
				_id_nfe AS id_nfe,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xOrgao/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_orgao,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:matr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS matr,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xAgente/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_agente,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS fone,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:nDAR/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS n_dar,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS d_emi,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:vDAR/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15, 2) AS v_dar,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:repEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS rep_emi,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS d_pag
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		WHERE
			a.x_orgao IS NOT NULL
	);
/* FIM INSERT nfe.d01_avulsa */

/* INÍCIO LOOP nfe.i01_prod */
FOR r_i01_prod IN
(
	-- Optimized query for large datasets
	WITH RECURSIVE xml_extract AS (
	    SELECT 
			ch_nf,
	        xml_id,
	        xpath('/new:nfeProc/new:NFe/new:infNFe/new:det', xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]) AS dets
	    FROM xml.nfe_nfce
		WHERE
			xml_id = _xml_id
	),
	det_positions AS (
	    SELECT 
			ch_nf,
	        xml_id,
	        generate_subscripts(dets, 1) AS position,
	        dets[generate_subscripts(dets, 1)] AS det_node
	    FROM xml_extract
	)
	SELECT
		a.c_prod,
		a.x_prod,
		a.ncm,
		a.ex_tipi,
		a.cfop,
		a.u_com,
		a.v_prod,
		a.u_trib,
		a.v_frete,
		a.v_seg,
		a.v_desc,
		a.v_outro,
		a.ind_tot,
		a.x_ped,
		a.n_item_ped,
		a.v_un_com,
		a.v_un_trib,
		a.q_com,
		a.q_trib,
		a.n_fci,
		a.nve,
		a.cest,
		a.c_ean,
		a.c_ean_trib,
		a.n_item,
		a.inf_ad_prod,
		a.ind_escala,
		/*a.cnpj_emit,
		a.cpf_emit,
		a.n_nf,
		a.mod,
		a.serie,
		a.d_emi,*/
		case when (a.cnpj_emit = '' or  a.cnpj_emit is null) and length(b.cpf_cnpj) = '14'
			then b.cpf_cnpj
		else a.cnpj_emit
		end as cnpj_emit,
		case when (a.cpf_emit = '' or  a.cpf_emit is null) and length(b.cpf_cnpj) = '11'
			then b.cpf_cnpj
		else a.cpf_emit
		end as cpf_emit,
		coalesce(a.n_nf,b.n_nf) as n_nf,
		coalesce(a.mod,b.mod) as mod,
		coalesce(a.serie,b.serie) as serie,
		case when (a.d_emi = '' or  a.d_emi is null)
			then b.d_emi 
		else a.d_emi::date end as d_emi,
		a.vl_st_apurado, 
		a.vl_pobreza_apurado, 
		a.vl_difal, 
		a.vl_bc_difal,
		a.aliq_difal
	FROM
	(
		SELECT
			ch_nf,
		    xml_id,
		    position,
		    (xpath('/new:det/new:prod/new:cProd/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::TEXT[])[1] AS c_prod,
		    (xpath('/new:det/new:prod/new:xProd/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::TEXT[])[1] AS x_prod,
			(xpath('/new:det/new:prod/new:NCM/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::VARCHAR(10)[])[1] AS ncm,
			(xpath('/new:det/new:prod/new:EXTIPI/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::VARCHAR(3)[])[1] AS ex_tipi,
			((xpath('/new:det/new:prod/new:CFOP/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INTEGER AS cfop,
			(xpath('/new:det/new:prod/new:uCom/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(10) AS u_com,
			((xpath('/new:det/new:prod/new:vProd/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_prod,
			(xpath('/new:det/new:prod/new:uTrib/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(10) AS u_trib,
			((xpath('/new:det/new:prod/new:vFrete/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_frete,
			((xpath('/new:det/new:prod/new:vSeg/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_seg,
			((xpath('/new:det/new:prod/new:vDesc/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_desc,
			((xpath('/new:det/new:prod/new:vOutro/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_outro,
			((xpath('/new:det/new:prod/new:indTot/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INTEGER AS ind_tot,
			(xpath('/new:det/new:prod/new:xPed/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(15) AS x_ped,
			(xpath('/new:det/new:prod/new:nItemPed/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(15) AS n_item_ped,
			(xpath('/new:det/new:prod/new:vUnCom/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS v_un_com,
			(xpath('/new:det/new:prod/new:vUnTrib/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS v_un_trib,
			((xpath('/new:det/new:prod/new:qCom/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS q_com,
			((xpath('/new:det/new:prod/new:qTrib/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS q_trib,
			(xpath('/new:det/new:prod/new:nFCI/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS n_fci,
			(xpath('/new:det/new:prod/new:NVE/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(10) AS nve,
			((xpath('/new:det/new:prod/new:CEST/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::BIGINT AS cest,
			(xpath('/new:det/new:prod/new:cEAN/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS c_ean,
			(xpath('/new:det/new:prod/new:cEANTrib/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS c_ean_trib,
			((xpath('/new:det/@nItem', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::TEXT[])[1])::INTEGER AS n_item,
			(xpath('/new:det/new:infAdProd/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(500) AS inf_ad_prod,
			(xpath('/new:det/new:prod/new:indEscala/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(1) AS ind_escala,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj_emit,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf_emit,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INTEGER AS n_nf,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS mod,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INTEGER AS serie,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS d_emi,
			0.00::NUMERIC(18,2) as vl_st_apurado, 
			0.00::NUMERIC(18,2) as vl_pobreza_apurado, 
			0.00::NUMERIC(18,2) as vl_difal, 
			0.00::NUMERIC(18,2) as vl_bc_difal,
			0.00::NUMERIC(18,2) AS aliq_difal
		FROM det_positions
		ORDER BY xml_id, position
	) a
	join nfe.raiz_nfe as b on a.ch_nf = b.inf_nfe
	WHERE
		c_prod IS NOT NULL
) LOOP
	/* INSERT TABLE nfe.i01_prod */
	INSERT INTO
	nfe.i01_prod(
		id_nfe,
		c_prod,
		x_prod,
		ncm,
		ex_tipi,
		cfop,
		u_com,
		v_prod,
		u_trib,
		v_frete,
		v_seg,
		v_desc,
		v_outro,
		ind_tot,
		x_ped,
		n_item_ped,
		v_un_com,
		v_un_trib,
		q_com,
		q_trib,
		n_fci,
		nve,
		cest,
		c_ean,
		c_ean_trib,
		n_item,
		inf_ad_prod,
		ind_escala,
		cpf_cnpj,
		n_nf,
		mod,
		serie,
		d_emi,
		vl_st_apurado,
		vl_pobreza_apurado,
		vl_difal,
		vl_bc_difal,
		aliq_difal
	)
	(
		SELECT
			_id_nfe,
			r_i01_prod.c_prod,
			r_i01_prod.x_prod,
			COALESCE(r_i01_prod.ncm, '')::VARCHAR(8) AS ncm,
			COALESCE(r_i01_prod.ex_tipi, '') AS ex_tipi,
			r_i01_prod.cfop,
			r_i01_prod.u_com,
			r_i01_prod.v_prod,
			r_i01_prod.u_trib,
			COALESCE(r_i01_prod.v_frete::NUMERIC, 0.00)::NUMERIC(18,2) AS v_frete,
			COALESCE(r_i01_prod.v_seg::NUMERIC, 0.00)::NUMERIC(18,2) AS v_seg,
			COALESCE(r_i01_prod.v_desc::NUMERIC(18,2), 0.00)::NUMERIC(18,2) AS v_desc,
			COALESCE(r_i01_prod.v_outro::NUMERIC, 0.00)::NUMERIC(18,2) AS v_outro,
			r_i01_prod.ind_tot,
			r_i01_prod.x_ped,
			r_i01_prod.n_item_ped,
			r_i01_prod.v_un_com,
			COALESCE(r_i01_prod.v_un_trib::NUMERIC, 0.00)::NUMERIC(18,2) AS v_un_trib,
			r_i01_prod.q_com,
			COALESCE(r_i01_prod.q_trib::NUMERIC, 0.00)::numeric(18,3) AS q_trib,
			COALESCE(r_i01_prod.n_fci, '') AS n_fci,
			COALESCE(r_i01_prod.nve, '') AS nve,
			r_i01_prod.cest,
			CASE WHEN r_i01_prod.c_ean = 'SEM GTIN' OR r_i01_prod.c_ean IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean
			END AS c_ean,
			CASE WHEN r_i01_prod.c_ean_trib = 'SEM GTIN' OR r_i01_prod.c_ean_trib IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean_trib
			END AS c_ean_trib,
			r_i01_prod.n_item,
			r_i01_prod.inf_ad_prod,
			r_i01_prod.ind_escala,
			COALESCE(r_i01_prod.cnpj_emit, r_i01_prod.cpf_emit, '') AS cpf_cnpj,
			r_i01_prod.n_nf,
			r_i01_prod.mod,
			r_i01_prod.serie,
			r_i01_prod.d_emi::DATE,
			r_i01_prod.vl_st_apurado,
			r_i01_prod.vl_pobreza_apurado,
			r_i01_prod.vl_difal,
			r_i01_prod.vl_bc_difal,
			r_i01_prod.aliq_difal
	) RETURNING id INTO _id_prod;
	/* FIM INSERT nfe.i01_prod */

	/* INSERT TABLE nfe.m01_imposto */
	INSERT INTO 
	nfe.m01_imposto(
		id_nfe,
		id_prod,
		v_tot_trib
	)
	(                                                                          
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			COALESCE(v_tot_trib, 0.00) AS v_tot_trib
		FROM
		(
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:imposto/new:vTotTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_trib
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
	);
	/* FIM INSERT nfe.m01_imposto */

	/* IMPOSTO ICMS em icms_filhos */
	WITH todos_icms AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:orig/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS orig,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cst,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:modBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mod_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:modBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mod_bc_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pMVAST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_mva_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pICMSST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSDeson/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_deson,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:motDesICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mot_des_icms,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_op,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pDif/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSDif/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_dif,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_ret,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_ret,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pBCOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_bc_op,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:UFST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCSTDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_dest,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSTDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_dest,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:CSOSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS cso_sn,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pCredSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_cred_sn,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vCredICMSSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_icms_sn,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st_ret,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st_ret,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st_ret,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSubstituto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_substituto,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBCEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_efet,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vBCEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_efet,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:pICMSEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms_efet,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_efet
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
	INSERT INTO
	nfe.icms_filhos(
		id_nfe,
		id_prod,
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
		p_st, uf_st,
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
	(
		SELECT
			id_nfe,
			id_prod,
			orig,
			LPAD(cst, '3', '0') AS cst,
			COALESCE(LPAD(cso_sn, '3', '0'),'') AS cso_sn,
			COALESCE(p_cred_sn, 0.0000) AS p_cred_sn,
			COALESCE(v_cred_icms_sn, 0.00) AS v_cred_icms_sn,
			mod_bc,
			mod_bc_st,
			COALESCE(p_red_bc, 0.0000) AS p_red_bc,
			COALESCE(p_red_bc_st, 0.0000) AS p_red_bc_st,
			COALESCE(p_mva_st, 0.0000) AS p_mva_st,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(v_bc_st, 0.00) AS v_bc_st,
			COALESCE(v_bc_st_ret, 0.00) AS v_bc_st_ret,
			COALESCE(p_icms, 0.0000) AS p_icms,
			COALESCE(v_icms, 0.00) AS v_icms,
			COALESCE(p_icms_st, 0.0000) AS p_icms_st,
			COALESCE(v_icms_st, 0.00) AS v_icms_st,
			COALESCE(v_icms_st_ret, 0.00) AS v_icms_st_ret,
			mot_des_icms,
			COALESCE(p_bc_op, 0.0000) AS p_bc_op,
			COALESCE(v_icms_deson, 0.00) AS v_icms_deson,
			COALESCE(v_icms_op, 0.00) AS v_icms_op,
			COALESCE(p_dif, 0.0000) AS p_dif,
			COALESCE(v_icms_dif, 0.00) AS v_icms_dif,
			COALESCE(p_st, 0.0000) AS p_st,
			uf_st,
			COALESCE(v_bc_st_dest, 0.00) AS v_bc_st_dest,
			COALESCE(v_icms_st_dest, 0.00) AS v_icms_st_dest,
			COALESCE(v_bc_fcp, 0.00) AS v_bc_fcp,
			COALESCE(p_fcp, 0.0000) AS p_fcp,
			COALESCE(v_bc_fcp_st, 0.00) AS v_bc_fcp_st,
			COALESCE(p_fcp_st, 0.0000) AS p_fcp_st,
			COALESCE(v_fcp_st, 0.00) AS v_fcp_st,
			COALESCE(v_bc_fcp_st_ret, 0.00) AS v_bc_fcp_st_ret,
			COALESCE(p_fcp_st_ret, 0.0000) AS p_fcp_st_ret,
			COALESCE(v_fcp_st_ret, 0.00) AS v_fcp_st_ret,
			COALESCE(v_fcp, 0.00) AS v_fcp,
			COALESCE(v_icms_substituto, 0.00) AS v_icms_substituto,
			COALESCE(p_red_bc_efet, 0.0000) AS p_red_bc_efet,
			COALESCE(v_bc_efet, 0.00) AS v_bc_efet,
			COALESCE(p_icms_efet, 0.0000) AS p_icms_efet,
			COALESCE(v_icms_efet, 0.00) AS v_icms_efet
		FROM
			todos_icms
		WHERE
			orig IS NOT NULL
	);
	/* FIM IMPOSTO ICMS */

	/* IMPOSTO IPI em ipi_filhos */
	WITH todos_ipi AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:clEnq/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(5) AS cl_enq,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:CNPJProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj_prod,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:cSelo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS c_selo,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:qSelo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(12) AS q_selo,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:cEnq/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS c_enq,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cst,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:pIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_ipi,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:vIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:qUnid/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS q_unid,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IPI/new:*/new:vUnid/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS v_unid
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
	INSERT INTO 
	nfe.ipi_filhos(
		id_nfe,
		id_prod,
		cst,
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
	(
		SELECT
			id_nfe,
			id_prod, 
			cst, 
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(p_ipi, 0.00) AS p_ipi, 
			COALESCE(q_unid, 0.0000) AS q_unid, 
			COALESCE(v_unid, 0.0000) AS v_unid, 
			COALESCE(v_ipi, 0.00) AS v_ipi,
			cl_enq, 
			cnpj_prod, 
			c_selo, 
			q_selo, 
			c_enq
		FROM
			todos_ipi
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO IPI */

	/* INSERT TABLE nfe.p01_ii */
	INSERT INTO 
	nfe.p01_ii(
		id_nfe,
		id_prod, 
		v_bc, 
		v_desp_adu, 
		v_ii, 
		v_iof
	)
	(
		SELECT
			id_nfe,
			id_prod,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(v_desp_adu, 0.00) AS v_desp_adu, 
			COALESCE(v_ii, 0.00) AS v_ii, 
			COALESCE(v_iof, 0.00) AS v_iof
		FROM
		(
			SELECT
				_id_nfe AS id_nfe,
				_id_prod AS id_prod,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:II/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:II/new:vDespAdu/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_desp_adu,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:II/new:vII/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ii,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:II/new:vIOF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_iof
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
		WHERE
			a.v_bc IS NOT NULL
	);
	/* FIM INSERT nfe.p01_ii */

	/* IMPOSTO PIS em pis_filhos */
	WITH todos_pis AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cst,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:pPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_pis,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:vPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:qBCProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS q_bc_prod,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:PIS/new:*/new:vAliqProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS v_aliq_prod
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
	INSERT INTO
	nfe.pis_filhos(
		id_nfe, 
		id_prod, 
		cst, 
		q_bc_prod, 
		v_aliq_prod, 
		v_bc,
		p_pis, 
		v_pis
	)
	(		
		SELECT
			id_nfe,
			id_prod, 
			cst, 
			COALESCE(q_bc_prod, 0.0000) AS q_bc_prod,
			COALESCE(v_aliq_prod, 0.0000) AS v_aliq_prod, 
			COALESCE(v_bc, 0.00) AS v_bc, 
			COALESCE(p_pis, 0.00) AS p_pis, 
			COALESCE(v_pis, 0.00) AS v_pis
		FROM
			todos_pis
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO PIS */

	/* IMPOSTO PIS em cofins_filhos */
	WITH todos_cofins AS
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cst,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:pCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_cofins,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:vCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:qBCProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS q_bc_prod,
			((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:COFINS/new:*/new:vAliqProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS v_aliq_prod
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
	INSERT INTO
	nfe.cofins_filhos(
		id_nfe, 
		id_prod, 
		cst, 
		q_bc_prod,
		v_aliq_prod, 
		v_bc,
		p_cofins, 		
		v_cofins
	)
	(		
		SELECT
			id_nfe,
			id_prod, 
			cst,
			COALESCE(q_bc_prod, 0.0000) AS q_bc_prod,
			COALESCE(v_aliq_prod, 0.0000) AS v_aliq_prod,
			COALESCE(v_bc, 0.00) AS v_bc,
			COALESCE(p_cofins, 0.00) AS p_cofins,
			COALESCE(v_cofins, 0.00) AS v_cofins
		FROM
			todos_cofins
		WHERE
			cst IS NOT NULL
	);
	/* FIM IMPOSTO COFINS */

	/* INSERT TABLE nfe.ua01_imposto_devol */	
	INSERT INTO 
	nfe.ua01_imposto_devol(
		id_nfe,
		id_prod,
		p_devol
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod, 
			COALESCE(a.p_devol, 0.00) AS p_devol
		FROM
		(
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:impostoDevol/new:pDevol/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_devol
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		)AS a
		WHERE
			a.p_devol IS NOT NULL
	) RETURNING id INTO _id_imposto_devol;

	/* INSERT TABLE nfe.ua04_ipi */
	IF _id_imposto_devol IS NOT NULL THEN	
		INSERT INTO
		nfe.ua04_ipi(
			id_nfe,
			id_imposto_devol,
			v_ipi_devol
		)
		(
			SELECT
				_id_nfe AS id_nfe,
				_id_imposto_devol AS id_imposto_devol, 
				COALESCE(v_ipi_devol, 0.00) AS v_ipi_devol
			FROM
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_imposto_devol AS id_imposto_devol,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:impostoDevol/new:IPI/new:vIPIDevol/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi_devol
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			) AS a
		);
	END IF;
	/* FIM INSERT nfe.ua04_ipi */

	/* VERIFICAR SE POSSUÍ ICMS NO DESTINATÁRIO */
	SELECT
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1] IS NOT NULL
	INTO
		has_icms_uf_dest
	FROM
		xml.nfe_nfce a
	WHERE
		a.xml_id = _xml_id;

	/* INSERT TABLE nfe.na01_icms_uf_dest */
	IF has_icms_uf_dest IS TRUE THEN
		INSERT INTO 
		nfe.na01_icms_uf_dest(
			id_nfe, 
			id_prod, 
			v_bc_uf_dest, 
			p_fcp_uf_dest, 
			p_icms_uf_dest, 
			p_icms_inter, 
			p_icms_inter_part, 
			v_fcp_uf_dest, 
			v_icms_uf_dest, 
			v_icms_uf_remet
		)
		(
			SELECT
				_id_nfe AS id_nfe, 
				_id_prod AS id_prod, 
				COALESCE(a.v_bc_uf_dest, 0.00) AS v_bc_uf_dest, 
				COALESCE(a.p_fcp_uf_dest, 0.00) AS p_fcp_uf_dest,  
				COALESCE(a.p_icms_uf_dest, 0.00) AS p_icms_uf_dest,  
				COALESCE(a.p_icms_inter, 0.00) AS p_icms_inter, 
				COALESCE(a.p_icms_inter_part, 0.00) AS p_icms_inter_part, 
				COALESCE(a.v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest, 
				COALESCE(a.v_icms_uf_dest, 0.00) AS v_icms_uf_dest, 
				COALESCE(a.v_icms_uf_remet, 0.00) AS v_icms_uf_remet
			FROM
			(
				SELECT
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:vBCUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:vBCFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:pFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_fcp_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSInter/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSInterPart/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter_part,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:vFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:vICMSUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_dest,
					((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:ICMSUFDest/new:vICMSUFRemet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_remet
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			) AS a
		);
	END IF;
	/* FIM INSERT nfe.na01_icms_uf_dest */

	/* INSERT TABLE nfe.ub12_ibs_cbs */
	INSERT INTO nfe.ub12_ibs_cbs (
		id_nfe,
		id_i01_prod,
		cst,
		c_class_trib,
		ind_doacao,
		v_bc,
		p_ibs_uf,
		p_dif_ibs,
		v_dif_ibs,
		v_dev_trib_ibs,
		p_red_aliq_ibs,
		p_aliq_efet_ibs,
		v_ibs_uf,
		p_ibs_mun,
		p_dif_ibs_mun,
		v_dif_ibs_mun,
		v_dev_trib_ibs_mun,
		p_red_aliq_ibs_mun,
		p_aliq_efet_ibs_mun,
		v_ibs_mun,
		v_ibs,
		p_cbs,
		p_dif_cbs,
		v_dif_cbs,
		v_dev_trib_cbs,
		p_red_aliq_cbs,
		p_aliq_efet_cbs,
		v_cbs,
		cst_reg,
		c_class_trib_reg,
		p_aliq_efet_reg_ibs_uf,
		v_trib_reg_ibs_uf,
		p_aliq_efet_reg_ibs_mun,
		v_trib_reg_ibs_mun,
		p_aliq_efet_reg_cbs,
		v_trib_reg_cbs,
		p_aliq_ibs_uf,
		v_trib_ibs_uf,
		p_aliq_ibs_mun,
		v_trib_ibs_mun,
		p_aliq_cbs,
		v_trib_cbs,
		q_bc_mono,
		ad_rem_ibs,
		ad_rem_cbs,
		v_ibs_mono,
		v_cbs_mono,
		q_bc_mono_reten,
		ad_rem_ibs_reten,
		v_ibs_mono_reten,
		ad_rem_cbs_reten,
		v_cbs_mono_reten,
		q_bc_mono_ret,
		ad_rem_ibs_ret,
		v_ibs_mono_ret,
		ad_rem_cbs_ret,
		v_cbs_mono_ret,
		p_dif_ibs_mono,
		v_ibs_mono_dif,
		p_dif_cbs_mono,
		v_cbs_mono_dif,
		v_tot_ibs_mono_item,
		v_tot_cbs_mono_item,
		v_ibs_trans_cred,
		v_cbs_trans_cred,
		compet_apur_ajuste_compet,
		v_ibs_ajuste_compet,
		v_cbs_ajuste_compet,
		v_ibs_est_cred,
		v_cbs_est_cred,
		v_bc_cred_pres,
		c_cred_pres,
		p_cred_pres_ibs,
		v_cred_pres_ibs,
		v_cred_pres_cond_sus_ibs,
		p_cred_pres_cbs,
		v_cred_pres_cbs,
		v_cred_pres_cond_sus_cbs,
		compet_apur_ibs_zfm,
		tp_cred_pres_ibs_zfm,
		v_cred_pres_ibs_zfm
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_prod AS id_prod,
			a.cst,
			a.c_class_trib,
			a.ind_doacao,
			COALESCE(a.v_bc, 0.00) AS v_bc,
			COALESCE(a.p_ibs_uf, 0.0000) AS p_ibs_uf,
			COALESCE(a.p_dif_ibs, 0.0000) AS p_dif_ibs,
			COALESCE(a.v_dif_ibs, 0.00) AS v_dif_ibs,
			COALESCE(a.v_dev_trib_ibs, 0.00) AS v_dev_trib_ibs,
			COALESCE(a.p_red_aliq_ibs, 0.0000) AS p_red_aliq_ibs,
			COALESCE(a.p_aliq_efet_ibs, 0.0000) AS p_aliq_efet_ibs,
			COALESCE(a.v_ibs_uf, 0.00) AS v_ibs_uf,
			COALESCE(a.p_ibs_mun, 0.0000) AS p_ibs_mun,
			COALESCE(a.p_dif_ibs_mun, 0.0000) AS p_dif_ibs_mun,
			COALESCE(a.v_dif_ibs_mun, 0.00) AS v_dif_ibs_mun,
			COALESCE(a.v_dev_trib_ibs_mun, 0.00) AS v_dev_trib_ibs_mun,
			COALESCE(a.p_red_aliq_ibs_mun, 0.0000) AS p_red_aliq_ibs_mun,
			COALESCE(a.p_aliq_efet_ibs_mun, 0.0000) AS p_aliq_efet_ibs_mun,
			COALESCE(a.v_ibs_mun, 0.00) AS v_ibs_mun,
			COALESCE(a.v_ibs, 0.00) AS v_ibs,
			COALESCE(a.p_cbs, 0.0000) AS p_cbs,
			COALESCE(a.p_dif_cbs, 0.0000) AS p_dif_cbs,
			COALESCE(a.v_dif_cbs, 0.00) AS v_dif_cbs,
			COALESCE(a.v_dev_trib_cbs, 0.00) AS v_dev_trib_cbs,
			COALESCE(a.p_red_aliq_cbs, 0.00) AS p_red_aliq_cbs,
			COALESCE(a.p_aliq_efet_cbs, 0.0000) AS p_aliq_efet_cbs,
			COALESCE(a.v_cbs, 0.00) AS v_cbs,
			a.cst_reg,
			a.c_class_trib_reg,
			COALESCE(a.p_aliq_efet_reg_ibs_uf, 0.0000) AS p_aliq_efet_reg_ibs_uf,
			COALESCE(a.v_trib_reg_ibs_uf, 0.00) AS v_trib_reg_ibs_uf,
			COALESCE(a.p_aliq_efet_reg_ibs_mun, 0.0000) AS p_aliq_efet_reg_ibs_mun,
			COALESCE(a.v_trib_reg_ibs_mun, 0.00) AS v_trib_reg_ibs_mun,
			COALESCE(a.p_aliq_efet_reg_cbs, 0.0000) AS p_aliq_efet_reg_cbs,
			COALESCE(a.v_trib_reg_cbs, 0.00) AS v_trib_reg_cbs,
			COALESCE(a.p_aliq_ibs_uf, 0.0000) AS p_aliq_ibs_uf,
			COALESCE(a.v_trib_ibs_uf, 0.00) AS v_trib_ibs_uf,
			COALESCE(a.p_aliq_ibs_mun, 0.0000) AS p_aliq_ibs_mun,
			COALESCE(a.v_trib_ibs_mun, 0.00) AS v_trib_ibs_mun,
			COALESCE(a.p_aliq_cbs, 0.0000) AS p_aliq_cbs,
			COALESCE(a.v_trib_cbs, 0.00) AS v_trib_cbs,
			COALESCE(a.q_bc_mono, 0.0000) AS q_bc_mono,
			COALESCE(a.ad_rem_ibs, 0.0000) AS ad_rem_ibs,
			COALESCE(a.ad_rem_cbs, 0.0000) AS ad_rem_cbs,
			COALESCE(a.v_ibs_mono, 0.00) AS v_ibs_mono,
			COALESCE(a.v_cbs_mono, 0.00) AS v_cbs_mono,
			COALESCE(a.q_bc_mono_reten, 0.0000) AS q_bc_mono_reten,
			COALESCE(a.ad_rem_ibs_reten, 0.0000) AS ad_rem_ibs_reten,
			COALESCE(a.v_ibs_mono_reten, 0.00) AS v_ibs_mono_reten,
			COALESCE(a.ad_rem_cbs_reten, 0.0000) AS ad_rem_cbs_reten,
			COALESCE(a.v_cbs_mono_reten, 0.00) AS v_cbs_mono_reten,
			COALESCE(a.q_bc_mono_ret, 0.0000) AS q_bc_mono_ret,
			COALESCE(a.ad_rem_ibs_ret, 0.0000) AS ad_rem_ibs_ret,
			COALESCE(a.v_ibs_mono_ret, 0.00) AS v_ibs_mono_ret,
			COALESCE(a.ad_rem_cbs_ret, 0.0000) AS ad_rem_cbs_ret,
			COALESCE(a.v_cbs_mono_ret, 0.00) AS v_cbs_mono_ret,
			COALESCE(a.p_dif_ibs_mono, 0.0000) AS p_dif_ibs_mono,
			COALESCE(a.v_ibs_mono_dif, 0.00) AS v_ibs_mono_dif,
			COALESCE(a.p_dif_cbs_mono, 0.0000) AS p_dif_cbs_mono,
			COALESCE(a.v_cbs_mono_dif, 0.00) AS v_cbs_mono_dif,
			COALESCE(a.v_tot_ibs_mono_item, 0.00) AS v_tot_ibs_mono_item,
			COALESCE(a.v_tot_cbs_mono_item, 0.00) AS v_tot_cbs_mono_item,
			COALESCE(a.v_ibs_trans_cred, 0.00) AS v_ibs_trans_cred,
			COALESCE(a.v_cbs_trans_cred, 0.00) AS v_cbs_trans_cred,
			a.compet_apur_ajuste_compet,
			COALESCE(a.v_ibs_ajuste_compet, 0.00) AS v_ibs_ajuste_compet,
			COALESCE(a.v_cbs_ajuste_compet, 0.00) AS v_cbs_ajuste_compet,
			COALESCE(a.v_ibs_est_cred, 0.00) AS v_ibs_est_cred,
			COALESCE(a.v_cbs_est_cred, 0.00) AS v_cbs_est_cred,
			COALESCE(a.v_bc_cred_pres, 0.00) AS v_bc_cred_pres,
			a.c_cred_pres,
			COALESCE(a.p_cred_pres_ibs, 0.0000) AS p_cred_pres_ibs,
			COALESCE(a.v_cred_pres_ibs, 0.00) AS v_cred_pres_ibs,
			COALESCE(a.v_cred_pres_cond_sus_ibs, 0.00) AS v_cred_pres_cond_sus_ibs,
			COALESCE(a.p_cred_pres_cbs, 0.0000) AS p_cred_pres_cbs,
			COALESCE(a.v_cred_pres_cbs, 0.00) AS v_cred_pres_cbs,
			COALESCE(a.v_cred_pres_cond_sus_cbs, 0.00) AS v_cred_pres_cond_sus_cbs,
			a.compet_apur_ibs_zfm,
			a.tp_cred_pres_ibs_zfm,
			COALESCE(a.v_cred_pres_ibs_zfm, 0.00) AS v_cred_pres_ibs_zfm
		FROM
		(
			SELECT
			    -- UB13 - CST (Código de Situação Tributária do IBS e CBS)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:CST/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS cst,
			    -- UB14 - cClassTrib (Código de Classificação Tributária do IBS e CBS)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:cClassTrib/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(6) AS c_class_trib,
			    -- UB14a - indDoacao (Indica natureza da operação de doação)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:indDoacao/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(1) AS ind_doacao,
			    -- UB16 - vBC (Base de cálculo do IBS e CBS)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:vBC/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			    -- UB18 - pIBSUF (Alíquota do IBS de competência das UF)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:pIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_uf,
			    -- UB22/UB23 - Grupo Diferimento IBS UF (gDif)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:pDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:vDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs,
			    -- UB25 - vDevTrib (Valor do tributo devolvido - IBS UF)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDevTrib/new:vDevTrib/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs,
			    -- UB27/UB28 - Grupo Redução de Alíquota IBS UF (gRed)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pRedAliq/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pAliqEfet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs,
			    -- UB35 - vIBSUF (Valor do IBS de competência da UF)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:vIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_uf,
			    -- UB37 - pIBSMun (Alíquota do IBS de competência do Município)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:pIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_mun,
			    -- UB41/UB42 - Grupo Diferimento IBS Município (gDif)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:pDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mun,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:vDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs_mun,
			    -- UB44 - vDevTrib (Valor do tributo devolvido - IBS Município)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDevTrib/new:vDevTrib/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs_mun,
			    -- UB46/UB47 - Grupo Redução de Alíquota IBS Município (gRed)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pRedAliq/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs_mun,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pAliqEfet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs_mun,
			    -- UB54 - vIBSMun (Valor do IBS de competência do Município)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:vIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mun,
			    -- UB54a - vIBS (Valor total do IBS - soma de vIBSUF e vIBSMun)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:vIBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs,
			    -- UB56 - pCBS (Alíquota da CBS)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:pCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_cbs,
			    -- UB60/UB61 - Grupo Diferimento CBS (gDif)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:pDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:vDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dif_cbs,
			    -- UB63 - vDevTrib (Valor do tributo devolvido - CBS)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDevTrib/new:vDevTrib/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_cbs,
			    -- UB65/UB66 - Grupo Redução de Alíquota CBS (gRed)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pRedAliq/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS p_red_aliq_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pAliqEfet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_cbs,
			    -- UB67 - vCBS (Valor da CBS)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:vCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs,
			    -- UB69/UB70 - Grupo Tributação Regular (gTribRegular)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:CSTReg/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS cst_reg,
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:cClassTribReg/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(6) AS c_class_trib_reg,
			    -- UB71/UB72 - Tributação Regular IBS UF
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_uf,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_uf,
			    -- UB72a/UB72b - Tributação Regular IBS Município
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_mun,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_mun,
			    -- UB72c/UB72d - Tributação Regular CBS
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_cbs,
			    -- UB82b/UB82c - Grupo Tributação Compra Governamental IBS UF (gTribCompraGov)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_uf,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSUF/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_uf,
			    -- UB82d/UB82e - Grupo Tributação Compra Governamental IBS Município
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_mun,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSMun/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_mun,
			    -- UB82f/UB82g - Grupo Tributação Compra Governamental CBS
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_trib_cbs,
			    -- UB85/UB86/UB87 - Grupo Monofásica Padrão (gMonoPadrao)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:qBCMono/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemIBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs,
			    -- UB88/UB89 - Valores Monofásica Padrão
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vIBSMono/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vCBSMono/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono,
			    -- UB91/UB92/UB93/UB93a/UB93b - Grupo Monofásica Retenção (gMonoReten)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:qBCMonoReten/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_reten,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemIBSReten/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_reten,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vIBSMonoReten/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_reten,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemCBSReten/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_reten,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vCBSMonoReten/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_reten,
			    -- UB95/UB96/UB97/UB98/UB98a - Grupo Monofásica Retida Anteriormente (gMonoRet)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:qBCMonoRet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_ret,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemIBSRet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_ret,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vIBSMonoRet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_ret,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemCBSRet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_ret,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vCBSMonoRet/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_ret,
			    -- UB100/UB101/UB102/UB103 - Grupo Diferimento Monofásica (gMonoDif)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifIBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mono,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vIBSMonoDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_dif,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs_mono,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vCBSMonoDif/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_dif,
			    -- UB104/UB105 - Totais Monofásica
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotIBSMonoItem/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_ibs_mono_item,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotCBSMonoItem/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_cbs_mono_item,
			    -- UB107/UB108 - Grupo Transferências de Crédito (gTransfCred)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gTransfCred/new:vIBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_trans_cred,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gTransfCred/new:vCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_trans_cred,
			    -- UB113/UB114/UB115 - Grupo Ajuste de Competência (gAjusteCompet)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gAjusteCompet/new:competApur/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(7) AS compet_apur_ajuste_compet,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vIBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_ajuste_compet,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vCBS/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_ajuste_compet,
			    -- UB117/UB118 - Grupo Estorno de Crédito (gEstornoCred)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gEstornoCred/new:vIBSEstCred/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_est_cred,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gEstornoCred/new:vCBSEstCred/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_est_cred,
			    -- UB121/UB122 - Grupo Crédito Presumido da Operação (gCredPresOper)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:vBCCredPres/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_cred_pres,
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:cCredPres/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS c_cred_pres,
			    -- UB124/UB125/UB126 - Grupo Crédito Presumido IBS (gIBSCredPres)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:pCredPres/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_ibs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPres/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPresCondSus/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_ibs,
			    -- UB128/UB129/UB130 - Grupo Crédito Presumido CBS (gCBSCredPres)
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:pCredPres/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPres/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cbs,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPresCondSus/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_cbs,
			    -- UB132/UB133/UB134 - Grupo Crédito Presumido IBS ZFM (gCredPresIBSZFM)
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:competApur/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(7) AS compet_apur_ibs_zfm,
			    (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:tpCredPresIBSZFM/text()',
			           a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(1) AS tp_cred_pres_ibs_zfm,
			    ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||r_i01_prod.n_item||'"]/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:vCredPresIBSZFM/text()',
			            a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs_zfm
			FROM
			    xml.nfe_nfce a
			WHERE
			    a.xml_id = _xml_id
		) AS a
		WHERE
			a.cst IS NOT NULL
	);
	/* FIM INSERT nfe.ub12_ibs_cbs */

	/* INSERT TABLE ncm_helper.cad_produtos */
	INSERT INTO
	ncm_helper.cad_produtos(
		id_empresa,
		codg_produto,
		codg_barra,
		descricao,
		ncm,
		cest
	)
	(
		SELECT
			b.id_empresa,
			r_i01_prod.c_prod,
			CASE WHEN r_i01_prod.c_ean = 'SEM GTIN' OR r_i01_prod.c_ean IS NULL THEN
				''::TEXT
			ELSE
				r_i01_prod.c_ean
			END AS c_ean,
			r_i01_prod.x_prod,
			COALESCE(r_i01_prod.ncm, '')::VARCHAR(8) AS ncm,
			r_i01_prod.cest
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnpj_emit,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cpf_emit
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		JOIN
			ncm_helper.cad_empresas b ON COALESCE(a.cnpj_emit, a.cpf_emit, '') = b.cpf_cnpj
	) ON CONFLICT DO NOTHING;
	/* FIM INSERT ncm_helper.cad_produtos */
END LOOP;
/* FIM LOOP TABLE i01_prod */

/* INSERT TABLE nfe.w02_icms_tot */	
INSERT INTO 
	nfe.w02_icms_tot(
		id_nfe, 
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
	(		
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_bc, 0.00) AS v_bc, 
			COALESCE(a.v_icms, 0.00) AS v_icms,  
			COALESCE(a.v_bc_st, 0.00) AS v_bc_st,
			COALESCE(a.v_st, 0.00) AS v_st,
			COALESCE(a.v_prod, 0.00) AS v_prod,
			COALESCE(a.v_frete, 0.00) AS v_frete,
			COALESCE(a.v_seg, 0.00) AS v_seg,
			COALESCE(a.v_desc, 0.00) AS v_desc,
			COALESCE(a.v_ii, 0.00) AS v_ii,
			COALESCE(a.v_ipi, 0.00) AS v_ipi,
			COALESCE(a.v_pis, 0.00) AS v_pis,
			COALESCE(a.v_cofins, 0.00) AS v_cofins,
			COALESCE(a.v_outro, 0.00) AS v_outro,
			COALESCE(a.v_nf, 0.00) AS v_nf,
			COALESCE(a.v_tot_trib, 0.00) AS v_tot_trib,
			COALESCE(a.v_icms_deson, 0.00) AS v_icms_deson,
			COALESCE(a.v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest,
			COALESCE(a.v_icms_uf_dest, 0.00) AS v_icms_uf_dest,
			COALESCE(a.v_icms_uf_remet, 0.00) AS v_icms_uf_remet,
			COALESCE(a.v_fcp, 0.00) AS v_fcp,
			COALESCE(a.v_fcp_st, 0.00) AS v_fcp_st,
			COALESCE(a.v_fcp_st_ret, 0.00) AS v_fcp_st_ret,
			COALESCE(a.v_ipi_devol, 0.00) AS v_ipi_devol
		FROM
		(			
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSDeson/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(18,2) AS v_icms_deson,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st_ret,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_prod,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFrete/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_frete,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vSeg/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_seg,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vDesc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_desc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vII/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ii,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vIPIDevol/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi_devol, 
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vOutro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_outro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_nf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_uf_dest,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_dest,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vICMSUFRemet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_remet,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vTotTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_trib
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		)AS a
	);
	/* FIM INSERT nfe.w02_icms_tot */

/* INSERT TABLE nfe.w17_issqn_tot */
INSERT INTO
	nfe.w17_issqn_tot(
		id_nfe,
		v_serv,
		v_bc,
		v_iss,
		v_pis,
		v_cofins,
		d_compet,
		v_deducao,
		v_outro,
		v_desc_incond,
		v_desc_cond,
		v_iss_ret,
		c_reg_trib
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_serv, 0.00) AS v_serv, 
			COALESCE(a.v_bc, 0.00) AS v_bc,  
			COALESCE(a.v_iss, 0.00) AS v_iss,
			COALESCE(a.v_pis, 0.00) AS v_pis,
			COALESCE(a.v_cofins, 0.00) AS v_cofins,
			a.d_compet::DATE,
			COALESCE(a.v_deducao, 0.00) AS v_deducao,
			COALESCE(a.v_outro, 0.00) AS v_outro,
			COALESCE(a.v_desc_incond, 0.00) AS v_desc_incond,
			COALESCE(a.v_desc_cond, 0.00) AS v_desc_cond,
			COALESCE(a.v_iss_ret, 0.00) AS v_iss_ret,
			a.c_reg_trib
		FROM
		(			
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vServ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_serv,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vISS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_iss,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:dCompet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS d_compet,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDeducao/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_deducao,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vOutro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_outro,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDescIncond/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_desc_incond,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vDescCond/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_desc_cond,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vISSRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_iss_ret,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:cRegTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_reg_trib
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
		WHERE
			a.d_compet IS NOT NULL
	);
	/* FIM INSERT nfe.w17_issqn_tot */

/* INSERT TABLE nfe.w23_ret_trib */
INSERT INTO
	nfe.w23_ret_trib(
		id_nfe,
		v_ret_pis,
		v_ret_cofins,
		v_ret_csll,
		v_bc_irrf,
		v_irrf,
		v_bc_ret_prev,
		v_ret_prev
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			COALESCE(a.v_ret_pis, 0.00) AS v_ret_pis, 
			COALESCE(a.v_ret_cofins, 0.00) AS v_ret_cofins,  
			COALESCE(a.v_ret_csll, 0.00) AS v_ret_csll,
			COALESCE(a.v_bc_irrf, 0.00) AS v_bc_irrf,
			COALESCE(a.v_irrf, 0.00) AS v_irrf,
			COALESCE(a.v_bc_ret_prev, 0.00) AS v_bc_ret_prev,
			COALESCE(a.v_ret_prev, 0.00) AS v_ret_prev
		FROM
		(
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ret_pis,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ret_cofins,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetCSLL/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ret_csll,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vBCIRRF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_irrf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vIRRF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_irrf,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vBCRetPrev/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_ret_prev,
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:retTrib/new:vRetPrev/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ret_prev
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		WHERE
			a.v_ret_pis IS NOT NULL OR a.v_ret_cofins IS NOT NULL OR a.v_ret_csll IS NOT NULL OR a.v_irrf IS NOT NULL
	);
	/* FIM INSERT nfe.w23_ret_trib */

/* INSERT TABLE nfe.z01_inf_adic */	
INSERT INTO
	nfe.z01_inf_adic(
		id_nfe,
		inf_ad_fisco,
		inf_cpl
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.inf_ad_fisco,
			a.inf_cpl
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infAdFisco/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2000) AS inf_ad_fisco,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2000) AS inf_cpl
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		WHERE
			a.inf_ad_fisco IS NOT NULL OR a.inf_cpl IS NOT NULL
	) RETURNING id INTO _id_inf_adic;
	/* FIM INSERT nfe.z01_inf_adic */

	IF _id_inf_adic IS NOT NULL THEN
		/* INSERT TABLE nfe.z04_obs_cont */
		INSERT INTO
			nfe.z04_obs_cont(
				id_nfe,
				id_inf_adic,
				x_campo,
				x_texto
			)
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_inf_adic AS id_inf_adic,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/new:xCampo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(20) AS x_campo,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/new:xTexto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS x_texto
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			);
		/* FIM INSERT nfe.z04_obs_cont */

		/* INSERT TABLE nfe.z07_obs_fisco */
		INSERT INTO
			nfe.z07_obs_fisco(
				id_nfe,
				id_inf_adic,
				x_campo,
				x_texto
			)
			(
				SELECT
					_id_nfe AS id_nfe,
					_id_inf_adic AS id_inf_adic,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/new:xCampo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(20) AS x_campo,
					unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/new:xTexto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS x_texto
				FROM
					xml.nfe_nfce a
				WHERE
					a.xml_id = _xml_id
			);
		/* FIM INSERT nfe.z07_obs_fisco */
	END IF;

/* INSERT TABLE nfe.pr03_inf_prot */
INSERT INTO
	nfe.pr03_inf_prot(
		id_nfe,
		ch_nfe,
		dh_recbto,
		n_prot,
		dig_val,
		c_stat,
		x_motivo
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.ch_nfe,
			a.dh_recbto::TIMESTAMP,
			a.n_prot,
			a.dig_val,
			a.c_stat,
			a.x_motivo
		FROM
		(
			SELECT
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:chNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(44) AS ch_nfe,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:dhRecbto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dh_recbto,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:nProt/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS n_prot,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:digVal/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dig_val,
				((xpath('/new:nfeProc/new:protNFe/new:infProt/new:cStat/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_stat,
				(xpath('/new:nfeProc/new:protNFe/new:infProt/new:xMotivo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_motivo
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		WHERE 
			a.c_stat IS NOT NULL
	);
/* FIM INSERT nfe.pr03_inf_prot */

/* INSERT TABLE nfe.y07_dup */
INSERT INTO
	nfe.y07_dup(
		id_nfe,
		n_dup,
		d_venc,
		v_dup
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			a.n_dup,
			a.d_venc::DATE,
			a.v_dup
		FROM
		(
			SELECT
				UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:nDup/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS n_dup,
				UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:dVenc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT AS d_venc,
				(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:vDup/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC(15, 2) AS v_dup
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) a
		WHERE
			a.v_dup IS NOT NULL
	);
/* FIM INSERT nfe.y07_dup */

/*
FOR xml_det_pag IN
(
	SELECT
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])) AS xml_det_pag
	FROM
		xml.nfe_nfce a
	WHERE
		a.xml_id = _xml_id
) LOOP
	RAISE NOTICE 'PASSOU';
	SELECT
		((xpath('/new:detPag/new:indPag/text()', xml_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pag,
		(xpath('/new:detPag/new:card/new:CNPJ/text()', xml_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj
	INTO
		ind_pag,
		cnpj_card;
	RAISE NOTICE 'BORA VER % | %', ind_pag, cnpj;
END LOOP;
*/
/* INÍCIO LOOP nfe.ya01_pag */
/*FOR r_ya01_pag IN
(
	SELECT
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:tPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(2) AS t_pag,
		(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:vPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC(15, 2) AS v_pag,
		(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:vTroco/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC(15, 2) AS v_troco,
		(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:indPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::INT AS ind_pag,
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:xPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS x_pag,
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:dPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT AS d_pag,
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:CNPJPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cnpj_pag,
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:UFPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(2) AS uf_pag,
		ROW_NUMBER() OVER () AS idx_pag
	FROM
		xml.nfe_nfce a
	WHERE
		a.xml_id = _xml_id
) LOOP
	/* INSERT TABLE nfe.ya01_pag */
	INSERT INTO
	nfe.ya01_pag(
		id_nfe,
		t_pag,
		v_pag,
		v_troco,
		ind_pag,
		x_pag,
		d_pag,
		cnpj_pag,
		uf_pag
	)
	(
		SELECT
			_id_nfe,
			r_ya01_pag.t_pag,
			r_ya01_pag.v_pag,
			r_ya01_pag.v_troco,
			r_ya01_pag.ind_pag,
			r_ya01_pag.x_pag,
			r_ya01_pag.d_pag::DATE,
			r_ya01_pag.cnpj_pag,
			r_ya01_pag.uf_pag
	) RETURNING id INTO _id_pag;

	/* INSERT TABLE nfe.ya04_card */
	INSERT INTO
	nfe.ya04_card(
		id_nfe,
		id_pag,
		cnpj,
		t_band,
		c_aut,
		tp_integra,
		cnpj_receb,
		id_term_pag
	)
	(
		SELECT
			_id_nfe AS id_nfe,
			_id_pag AS id_pag,
			a.cnpj,
			a.t_band,
			a.c_aut,
			a.tp_integra,
			a.cnpj_receb,
			a.id_term_pag
		FROM
		(
			SELECT
				((xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:tpIntegra/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::TEXT)::INT AS tp_integra,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(14) AS cnpj,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:tBand/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(2) AS t_band,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:cAut/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(128) AS c_aut,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:CNPJReceb/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(14) AS cnpj_receb,
				(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:card/new:idTermPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(40) AS id_term_pag
			FROM
				xml.nfe_nfce a
			WHERE
				a.xml_id = _xml_id
		) AS a
	);
	/* FIM INSERT nfe.ya04_card */
END LOOP;*/
/* FIM LOOP TABLE ya01_pag */

/* INSERT TABLE ncm_helper.cad_produtos */
insert into ncm_helper.cad_produtos (id_empresa, codg_produto, codg_barra,  ncm,  cest, descricao)
(
	select
		a.id_empresa,
		a.c_prod,
		a.c_ean,
		a.ncm,
		a.cest,
		a.descricao
	from
	(
		select
			a.id_empresa,
			c.c_prod,
			case when c.c_ean = 'SEM GTIN' then ''::text 
			when (c.c_ean is null or c.c_ean = '') then ''::text 
			when c.c_ean = c.c_ean_trib then c.c_ean
			when c.c_ean <> c.c_ean_trib then c.c_ean_trib
			else c.c_ean end as c_ean,
			case when length(c.ncm) = '8' then
			trim(c.ncm) else ''::text end as ncm,
			case when c.cest = 0 then ''::varchar(7)
			when c.cest is null then ''::varchar(7)
			else lpad(c.cest::text, 7,'0')::varchar(7) end as cest,
			to_char(b.d_emi,'yyyy-mm-01')::date as dt_ocorrencia,
			upper(trim(c.x_prod))::varchar(255) as descricao,
			upper(trim(c.u_com)) as unid
		from ncm_helper.cad_empresas as a
		join nfe.raiz_nfe as b using(cpf_cnpj)
		join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
		where b.inf_nfe = _ch_nf 
	)as a
	left join ncm_helper.cad_produtos as b on (a.id_empresa, a.c_prod) = (b.id_empresa, b.codg_produto)
	where b.id_empresa is null	
)on conflict do nothing;
/* FIM TABLE ncm_helper.cad_produtos */	

/* INSERT TABLE ncm_helper.cad_produtos_ocorrencia */
	INSERT INTO ncm_helper.cad_produtos_ocorrencia (id_empresa, codg_produto, dt_ocorrencia, cst_icms, descricao, ncm, unid, codg_barra, cest) 
	(
		SELECT
			DISTINCT ON(a.id_empresa, a.dt_ocorrencia, a.c_prod)
			a.id_empresa,
			a.c_prod,
			a.dt_ocorrencia,
			'060'::VARCHAR(3) AS cst_icms,
			a.descricao,		
			a.ncm,
			a.unid,
			a.c_ean,
			a.cest
		FROM
		(
			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = '8' THEN
				TRIM(c.ncm) ELSE ''::text END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.i01_prod AS c USING(cpf_cnpj, n_nf, serie, mod)
			WHERE b.inf_nfe = _ch_nf and c.c_ean = c.c_ean_trib

			UNION

			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = '8' THEN
				c.ncm ELSE ''::text	END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.i01_prod AS c USING(cpf_cnpj, n_nf, serie, mod)
			WHERE b.inf_nfe = _ch_nf and c.c_ean <> c.c_ean_trib

			UNION

			SELECT
				a.id_empresa,
				a.tipo,
				c.c_prod,
				CASE WHEN c.c_ean = 'SEM GTIN' THEN ''::text 
				WHEN (c.c_ean IS null OR c.c_ean = '') THEN ''::text 
				ELSE c.c_ean END AS c_ean,
				CASE WHEN length(c.ncm) = '8' THEN
				c.ncm ELSE ''::text	END AS ncm,
				CASE WHEN c.cest = 0 THEN ''::varchar(7)
				WHEN c.cest IS null THEN ''::varchar(7)
				ELSE lpad(c.cest::text, 7,'0')::varchar(7) END AS cest,
				to_char(b.d_emi,'yyyy-mm-01')::date AS dt_ocorrencia,
				UPPER(TRIM(c.x_prod))::varchar(255) AS descricao,
				UPPER(TRIM(c.u_com)) AS unid
			FROM ncm_helper.cad_empresas AS a
			JOIN nfe.raiz_nfe AS b USING(cpf_cnpj)
			JOIN nfe.c01_emit AS d USING(id_nfe, ie)
			JOIN nfe.i01_prod AS c ON(a.cpf_cnpj, b.n_nf, b.serie, b.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			WHERE b.inf_nfe = _ch_nf
		)AS a
		LEFT JOIN ncm_helper.cad_produtos_ocorrencia AS b ON (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		WHERE b.id_empresa IS NULL
	)ON  CONFLICT DO NOTHING;
/* FIM TABLE ncm_helper.cad_produtos_ocorrencia */	

/* INSERT TABLE sf.resumo_nota_propria */
	insert into sf.resumo_nota_propria(cpf_cnpj, num_doc, ser, cod_mod, chv_nfe, cfop, cst_icms, aliquota, vl_opr, vl_bc_icms, vl_icms, vl_bc_icms_st, vl_icms_st, vl_frt, vl_seg, vl_desc, vl_out_da, vl_doc, vl_ipi, vl_merc, operacao, dt_doc2, aliq_icms, dt_ini2, cod_sit, vl_red_bc)
	(
		select
			a.cpf_cnpj, 
			a.num_doc, 
			a.ser, 
			a.cod_mod, 
			a.chv_nfe, 
			a.cfop, 
			a.cst_icms, 
			a.aliquota, 
			a.vl_opr, 
			a.vl_bc_icms,
			a.vl_icms,
			a.vl_bc_icms_st,
			a.vl_icms_st,
			a.vl_frt, 
			a.vl_seg, 
			a.vl_desc, 
			a.vl_out_da, 
			a.vl_doc, 
			a.vl_ipi, 
			a.vl_merc, 
			a.operacao, 
			a.dt_doc2, 
			a.aliq_icms, 
			a.dt_ini2, 
			a.cod_sit, 
			a.vl_red_bc
		from
		(
			select
				a.cpf_cnpj, 
				a.num_doc, 
				a.ser, 
				a.cod_mod, 
				a.chv_nfe, 
				a.cfop, 
				a.cst_icms, 
				a.aliquota::numeric(18,3) as aliquota, 
				sum(a.vl_opr)::numeric(18,2) as vl_opr, 
				sum(a.vl_bc_icms)::numeric(18,2) as vl_bc_icms,
				sum(a.vl_icms)::numeric(18,2) as vl_icms,
				sum(a.vl_bc_icms_st)::numeric(18,2) as vl_bc_icms_st,
				sum(a.vl_icms_st)::numeric(18,2) as vl_icms_st,
				sum(a.vl_frt)::numeric(18,2) as vl_frt, 
				sum(a.vl_seg)::numeric(18,2) as vl_seg, 
				sum(a.vl_desc)::numeric(18,2) as vl_desc, 
				sum(a.vl_out_da)::numeric(18,2) as vl_out_da, 
				a.vl_doc, 
				sum(a.vl_ipi)::numeric(18,2) as vl_ipi, 
				a.vl_merc, 
				a.operacao, 
				a.dt_doc2, 
				a.aliq_icms::numeric(18,3) as aliq_icms, 
				a.dt_ini2, 
				a.cod_sit, 
				sum(a.vl_red_bc)::numeric(18,2) as vl_red_bc
			from
			(
				select
					a.cpf_cnpj, 
					a.num_doc, 
					a.ser, 
					a.cod_mod, 
					a.chv_nfe, 
					a.cfop, 
					a.cst_icms, 
					a.aliquota, 
					a.vl_opr, 
					a.vl_bc_icms, 
					a.vl_icms, 
					a.vl_bc_icms_st, 
					a.vl_icms_st, 
					a.vl_frt, 
					a.vl_seg, 
					a.vl_desc, 
					a.vl_out_da, 
					a.vl_doc, 
					a.vl_ipi, 
					a.vl_merc, 
					a.operacao, 
					a.dt_doc2, 
					a.aliq_icms, 
					a.dt_ini2, 
					a.cod_sit, 
					case when a.cst_icms = '020' and (a.vl_opr - a.vl_bc_icms) > 0.00 then (a.vl_opr - a.vl_bc_icms)::numeric(18,2)
					when a.cst_icms = '070' and (a.vl_opr - a.vl_bc_icms_st) > 0.00 then (a.vl_opr - a.vl_bc_icms_st)::numeric(18,2)
					when a.cst_icms = any(array['070','020']) and (a.vl_bc_icms + a.vl_bc_icms_st) = 0.00 then 0.01::numeric(18,2)
					else 0.00::numeric(18,2) end as vl_red_bc
				from
				(
					select
						a.cpf_cnpj,	a.num_doc, a.ser, a.cod_mod, a.chv_nfe, a.dt_ini2,
						a.cod_sit, a.dt_doc2,
						a.vl_merc, a.vl_doc,
						case when d.cso_sn <> '' then trim(lpad(d.cso_sn, 3, '0'))
						else trim(lpad(d.cst, 3, '0'))  end as cst_icms,
						b.cfop,
						case when d.p_icms > 0 then d.p_icms else 0.00::numeric(18,2) end aliquota,
						case when d.p_icms > 0 then d.p_icms else null::numeric(18,2) end aliq_icms,
						(b.v_prod + coalesce(b.v_frete, .0)::numeric(18, 2) + coalesce(b.v_seg, .0)::numeric(18, 2) + coalesce(e.v_ipi, .0)::numeric(18, 2) + coalesce(b.v_outro, .0)::numeric(15, 2) - coalesce(b.v_desc, .0)::numeric(18, 2))::decimal(18, 2) as vl_opr,
						coalesce(d.v_bc, 0.00) as vl_bc_icms,
						coalesce(d.v_icms, 0.00) as vl_icms,
						coalesce(d.v_bc_st, 0.00) as vl_bc_icms_st,
						coalesce(d.v_icms_st, 0.00) as vl_icms_st,	
						coalesce(b.v_frete, .0)::numeric(18, 2 ) as vl_frt,
						coalesce(b.v_seg, .0)::numeric(18, 2 ) as vl_seg,
						coalesce(e.v_ipi, .0)::numeric(18, 2) as vl_ipi,
						coalesce(b.v_outro, .0)::numeric(15, 2) as vl_out_da,
						coalesce(b.v_desc, .0)::numeric(18, 2 ) as vl_desc,
						c.operacao
					from
					(
						select
							a.cpf_cnpj,	a.n_nf, a.serie, a.mod,
							a.n_nf as num_doc,
							a.ser, 
							a.mod as cod_mod, 
							a.inf_nfe as chv_nfe,
							to_char(a.d_emi,'yyyy-mm-01')::date as dt_ini2,
							a.cod_sit,
							a.d_emi as dt_doc2,
							b.v_prod as vl_merc,
							b.v_nf as vl_doc
						from nfe.raiz_nfe as a
						join nfe.w02_icms_tot as b using(id_nfe)
						where a.id_nfe = _id_nfe
					)as a
					join nfe.i01_prod as b using(cpf_cnpj, n_nf, serie, mod)
					join ncm_helper.cad_cfop as c using(cfop)
					join nfe.icms_filhos as d on (b.id_nfe, b.id) = (d.id_nfe, d.id_prod)
					left join nfe.ipi_filhos as e on (b.id_nfe, b.id) = (e.id_nfe, e.id_prod)
				)as a
			)as a
			group by a.cpf_cnpj, a.num_doc, a.ser, a.cod_mod, a.chv_nfe, a.cfop, a.cst_icms, a.aliquota, a.vl_doc, a.vl_merc, a.operacao, a.dt_doc2, a.aliq_icms, a.dt_ini2, a.cod_sit
		)as a
		left join sf.resumo_nota_propria as b using(cpf_cnpj, num_doc, ser, cod_mod, chv_nfe, cfop, cst_icms, aliquota)
		where b.cpf_cnpj is null
	)on conflict do nothing;
/* FIM TABLE sf.resumo_nota_propria */

/* UPDATE COD_CTA nfe.i01_prod */
	update nfe.i01_prod as a
	set cod_cta = b.cod_cta
	from
	(
		select
			b.id_nfe, b.id,
			'4101010004'::varchar(60) as cod_cta
		from nfe.raiz_nfe as a
		join nfe.i01_prod as b using(cpf_cnpj, n_nf, serie, mod)
		where a.id_nfe = _id_nfe and a.mod = '65'
		and (b.cod_cta = '' or b.cod_cta is null)
	)as b
	where (a.id_nfe, a.id) = (b.id_nfe, b.id);
	
	update nfe.i01_prod as a
	set cod_cta = b.cod_cta
	from
	(
		select
			c.id_nfe, c.id, 
			d.cod_cta
		from ncm_helper.cad_empresas as a
		join nfe.raiz_nfe as b using(cpf_cnpj)
		join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
		join contabil.plano_conta_padrao_has_cfop as d on c.cfop = d.cfop
		where b.id_nfe = _id_nfe 
		and b.mod = '55' and d.cod_cta <> '4101010004'
		and (c.cod_cta = '' or c.cod_cta is null)
	)as b
	where (a.id_nfe, a.id) = (b.id_nfe, b.id);
	
/* FIM TABLE nfe.i01_prod */
END;
$$;


ALTER FUNCTION xml.desestruturar_xml_nfe_nfce_old(_xml_id bigint, substituir boolean) OWNER TO dorcilio;

--
-- TOC entry 3669 (class 1255 OID 546075257)
-- Name: desestruturar_xml_v_desc(); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.desestruturar_xml_v_desc() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	r_nfe_nfce RECORD;
begin
/*
	begin;

	SELECT * FROM xml.desestruturar_xml_v_desc();

	commit;
*/

FOR r_nfe_nfce IN
(
	WITH RECURSIVE xml_extract AS (
	    SELECT 
			ch_nf,
	        xml_id,
	        xpath('/new:nfeProc/new:NFe/new:infNFe/new:det', xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]) AS dets
	    FROM xml.nfe_nfce
		WHERE
			/* SOMENTE SE TIVER V_DESC */
			xpath_exists('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vDesc', xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])
	),
	det_positions AS (
	    SELECT 
			ch_nf,
	        xml_id,
	        generate_subscripts(dets, 1) AS position,
	        dets[generate_subscripts(dets, 1)] AS det_node
	    FROM xml_extract
	)
	SELECT
		DISTINCT id_nfe,
		xml_id
	FROM
	(
		SELECT
			b.id_nfe,
			a.xml_id,
			a.position,
			((xpath('/new:det/new:prod/new:vDesc/text()', a.det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC AS v_desc,
			((xpath('/new:det/@nItem', a.det_node, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])::TEXT[])[1])::INTEGER AS n_item
		FROM det_positions a
		JOIN nfe.raiz_nfe AS b ON a.ch_nf = b.inf_nfe
		WHERE b.d_emi between '2025-05-01' and '2025-05-31'
		ORDER BY a.xml_id, a.position
	) a
	JOIN nfe.i01_prod b USING(id_nfe, n_item)
	WHERE
		a.v_desc <> b.v_desc
) LOOP
	RAISE NOTICE 'REMOVENDO NF-E |ID_NFE|DATA| - |%|%|', r_nfe_nfce.id_nfe, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss');
	DELETE FROM nfe.raiz_nfe WHERE id_nfe = r_nfe_nfce.id_nfe;
	RAISE NOTICE 'NF-E REMOVIDA |ID_NFE|DATA| - |%|%|', r_nfe_nfce.id_nfe, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss');
	RAISE NOTICE 'DESESTRUTURANDO |XML_ID|DATA| - |%|%|', r_nfe_nfce.xml_id, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss');
	PERFORM xml.desestruturar_xml_nfe_nfce(
		r_nfe_nfce.xml_id,
		FALSE
	);
	RAISE NOTICE 'DESESTRUTURADA |XML_ID|DATA| - |%|%|', r_nfe_nfce.xml_id, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss');
END LOOP;
end;
$$;


ALTER FUNCTION xml.desestruturar_xml_v_desc() OWNER TO dorcilio;

--
-- TOC entry 3746 (class 1255 OID 606171769)
-- Name: fn_update_import_job_fts(); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.fn_update_import_job_fts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_month_name_pt TEXT;
    v_period_mm_yyyy TEXT;
    v_period_month_year TEXT;
    v_month SMALLINT;
    v_year SMALLINT;
BEGIN
    v_month := EXTRACT(MONTH FROM COALESCE(NEW.created_at, clock_timestamp()))::SMALLINT;
    v_year := EXTRACT(YEAR FROM COALESCE(NEW.created_at, clock_timestamp()))::SMALLINT;

    v_month_name_pt := CASE v_month
        WHEN 1 THEN 'janeiro'
        WHEN 2 THEN 'fevereiro'
        WHEN 3 THEN 'marco'
        WHEN 4 THEN 'abril'
        WHEN 5 THEN 'maio'
        WHEN 6 THEN 'junho'
        WHEN 7 THEN 'julho'
        WHEN 8 THEN 'agosto'
        WHEN 9 THEN 'setembro'
        WHEN 10 THEN 'outubro'
        WHEN 11 THEN 'novembro'
        WHEN 12 THEN 'dezembro'
    END;

    v_period_mm_yyyy := LPAD(v_month::TEXT, 2, '0') || '/' || v_year::TEXT;
    v_period_month_year := v_month_name_pt || ' ' || v_year::TEXT;

    NEW.job_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.file_name, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cpf_cnpj, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.dest_cpf_cnpj, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(v_period_mm_yyyy, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(v_period_month_year, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.job_type, '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.job_status, '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(v_month_name_pt, '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.notes, '')), 'C');
    RETURN NEW;
END;
$$;


ALTER FUNCTION xml.fn_update_import_job_fts() OWNER TO dorcilio;

--
-- TOC entry 12189 (class 0 OID 0)
-- Dependencies: 3746
-- Name: FUNCTION fn_update_import_job_fts(); Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON FUNCTION xml.fn_update_import_job_fts() IS 'Atualiza o vetor FTS de import_job com public.simple_portuguese (sem acentos). Pesos: file_name, cpf_cnpj, dest_cpf_cnpj, MM/YYYY e mes+ano = A; job_type, job_status e mes = B; notes = C. Permite busca por nome do mes (maio, junho, julho, etc).';


--
-- TOC entry 3715 (class 1255 OID 597869271)
-- Name: reprocessar_nfe_sem_ibs_cbs(date, date, integer, integer); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.reprocessar_nfe_sem_ibs_cbs(_dt_inicial date DEFAULT '2026-01-01'::date, _dt_final date DEFAULT NULL::date, _limite integer DEFAULT 500, _lote_delete integer DEFAULT 200) RETURNS TABLE(xml_id bigint, ch_nf character varying, id_nfe bigint, sucesso boolean, mensagem text)
    LANGUAGE plpgsql
    AS $$
/*
===================================================================================
FUNÇÃO: xml.reprocessar_nfe_sem_ibs_cbs
===================================================================================
Objetivo:
    Identifica XMLs com <IBSCBS> sem registro em nfe.ub12_ibs_cbs e os reprocessa.

Estratégia (3 fases separadas para máxima performance):

    FASE 1 — Identificar (xpath_exists roda UMA VEZ)
        Materializa os IDs pendentes em temp table. O xpath_exists (varredura pesada)
        executa uma única vez sem manter cursor aberto.

    FASE 2 — Deletar em sub-lotes (_lote_delete IDs por vez)
        Um único DELETE em lote por sub-lote é muito mais rápido do que N DELETEs
        individuais dentro do desestruturar: menos aquisições de lock, menos escritas
        no WAL, cascade processa em conjunto.
        Sub-lotes menores (200) evitam travar raiz_nfe por tempo demais.

    FASE 3 — Reprocessar com substituir=FALSE
        Como o registro já foi deletado na fase 2, a função vai direto para o INSERT
        sem entrar no bloco de delete interno — apenas INSERTs, sem overhead extra.

Parâmetros:
    _dt_inicial   DATE     criado_em >= este valor (padrão: 2026-01-01)
    _dt_final     DATE     Limite superior opcional (padrão: sem limite)
    _limite       INTEGER  Total de NFes por chamada (padrão: 500)
    _lote_delete  INTEGER  NFes por sub-lote de DELETE (padrão: 200)

Uso:
    -- Processar lote padrão (500 NFes, delete em sub-lotes de 200)
    SELECT * FROM xml.reprocessar_nfe_sem_ibs_cbs();

    -- Conexão mais lenta: lotes menores
    SELECT * FROM xml.reprocessar_nfe_sem_ibs_cbs('2026-01-01', NULL, 100, 50);

    -- Servidor robusto: lote maior
    SELECT * FROM xml.reprocessar_nfe_sem_ibs_cbs('2026-07-01', '2026-07-31', 2000, 500);

    -- Chamar repetidamente até retornar 0 linhas (processa todos os pendentes)
===================================================================================
*/
DECLARE
    r               RECORD;
    _resultado      JSONB;
    _qtd_total      INTEGER := 0;
    _qtd_sucesso    INTEGER := 0;
    _qtd_erro       INTEGER := 0;
    _qtd_pendentes   INTEGER := 0;
    _qtd_deletados   INTEGER := 0;
    _qtd_corrompidos INTEGER := 0;
    _offset          INTEGER := 0;
    _ids_lote        BIGINT[];
BEGIN

    SET LOCAL statement_timeout = 0;
    -- Suprime RAISE INFO e RAISE NOTICE de funções chamadas (desestruturar emite ~20
    -- mensagens por NFe — em batch de 500 são 10k+ mensagens que travam o pgAdmin).
    -- RAISE WARNING desta função continua aparecendo normalmente.
    SET LOCAL client_min_messages = WARNING;
    -- Desabilita parallel workers: xpath_exists acessa coluna TOAST (xml_file) e workers
    -- paralelos podem falhar com "missing chunk number N for toast value" mesmo quando
    -- os dados não estão corrompidos — bug conhecido do PostgreSQL com TOAST + paralelismo.
    SET LOCAL max_parallel_workers_per_gather = 0;

    RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] FASE 1 — Coletando IDs. Período: % a % | Limite: % | Lote delete: %',
        _dt_inicial, COALESCE(_dt_final::TEXT, 'sem limite'), _limite, _lote_delete;

    -- =========================================================================
    -- FASE 1: materializa os IDs pendentes (xpath_exists roda uma única vez)
    -- Modo batch (rápido). Se houver TOAST corrompido, fallback linha a linha
    -- com BEGIN/EXCEPTION por registro — pula corrompidos, processa os demais.
    -- =========================================================================
    DROP TABLE IF EXISTS _tmp_ibs_pendentes;
    BEGIN
        -- Caminho rápido: xpath_exists em batch (1 query, sem overhead por linha)
        CREATE TEMP TABLE _tmp_ibs_pendentes AS
        SELECT
            x.xml_id,
            x.ch_nf,
            rn.id_nfe,
            x.criado_em
        FROM xml.nfe_nfce AS x
        INNER JOIN nfe.raiz_nfe AS rn ON x.ch_nf = rn.inf_nfe
        WHERE
            x.criado_em >= _dt_inicial
            AND (_dt_final IS NULL OR x.criado_em <= (_dt_final + INTERVAL '1 day'))
            AND NOT EXISTS (
                SELECT 1 FROM nfe.ub12_ibs_cbs AS u WHERE u.id_nfe = rn.id_nfe
            )
            AND xpath_exists(
                '/new:nfeProc/new:NFe/new:infNFe/new:det/new:imposto/new:IBSCBS',
                x.xml_file,
                ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]
            )
        ORDER BY x.criado_em ASC
        LIMIT _limite;

        GET DIAGNOSTICS _qtd_pendentes = ROW_COUNT;

    EXCEPTION WHEN OTHERS THEN
        -- Caminho seguro: há pelo menos 1 entrada com TOAST corrompido no lote.
        -- Processa linha a linha: cada xml_id é lido em subtransação isolada;
        -- corrompidos disparam a exceção interna, são logados e ignorados.
        RAISE WARNING '[FASE 1] Modo batch falhou (SQLSTATE=% — %). Ativando modo seguro (linha a linha)...',
            SQLSTATE, SQLERRM;

        DROP TABLE IF EXISTS _tmp_ibs_pendentes;
        CREATE TEMP TABLE _tmp_ibs_pendentes (
            xml_id    BIGINT,
            ch_nf     VARCHAR(44),
            id_nfe    BIGINT,
            criado_em TIMESTAMP
        );

        FOR r IN
            -- Candidatos sem tocar xml_file: join + NOT EXISTS apenas
            SELECT x.xml_id, x.ch_nf, rn.id_nfe, x.criado_em
            FROM xml.nfe_nfce AS x
            INNER JOIN nfe.raiz_nfe AS rn ON x.ch_nf = rn.inf_nfe
            WHERE
                x.criado_em >= _dt_inicial
                AND (_dt_final IS NULL OR x.criado_em <= (_dt_final + INTERVAL '1 day'))
                AND NOT EXISTS (
                    SELECT 1 FROM nfe.ub12_ibs_cbs AS u WHERE u.id_nfe = rn.id_nfe
                )
            ORDER BY x.criado_em ASC
            LIMIT _limite * 5   -- margem para corrompidos sem IBSCBS
        LOOP
            BEGIN
                -- Lê xml_file de 1 linha; se TOAST corrompido, cai no EXCEPTION
                IF (
                    SELECT xpath_exists(
                        '/new:nfeProc/new:NFe/new:infNFe/new:det/new:imposto/new:IBSCBS',
                        nx.xml_file,
                        ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]
                    )
                    FROM xml.nfe_nfce nx
                    WHERE nx.xml_id = r.xml_id
                ) THEN
                    INSERT INTO _tmp_ibs_pendentes
                        VALUES (r.xml_id, r.ch_nf, r.id_nfe, r.criado_em);
                    _qtd_pendentes := _qtd_pendentes + 1;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                _qtd_corrompidos := _qtd_corrompidos + 1;
                RAISE WARNING '[FASE 1] xml_id=% TOAST corrompido, ignorado (SQLSTATE=% — %)',
                    r.xml_id, SQLSTATE, SQLERRM;
            END;
            EXIT WHEN _qtd_pendentes >= _limite;
        END LOOP;

        IF _qtd_corrompidos > 0 THEN
            RAISE WARNING '[FASE 1] % registro(s) com TOAST corrompido ignorado(s) no total.', _qtd_corrompidos;
        END IF;
    END;

    RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] % NFe(s) identificadas.', _qtd_pendentes;

    IF _qtd_pendentes = 0 THEN
        DROP TABLE IF EXISTS _tmp_ibs_pendentes;
        RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] Nenhuma NFe pendente. Nada a fazer.';
        RETURN;
    END IF;

    -- =========================================================================
    -- FASE 2: DELETE em sub-lotes — evita travar raiz_nfe por tempo demais
    -- Um DELETE de N IDs é muito mais rápido que N DELETEs individuais:
    -- menos locks, menos WAL, cascade processa em conjunto por lote.
    -- =========================================================================
    RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] FASE 2 — Deletando em sub-lotes de % IDs...', _lote_delete;

    _offset := 0;
    LOOP
        SELECT array_agg(t.id_nfe)
        INTO _ids_lote
        FROM (
            SELECT t2.id_nfe
            FROM _tmp_ibs_pendentes AS t2
            ORDER BY t2.criado_em ASC
            LIMIT _lote_delete OFFSET _offset
        ) t;

        EXIT WHEN _ids_lote IS NULL;

        DELETE FROM nfe.raiz_nfe AS rn WHERE rn.id_nfe = ANY(_ids_lote);
        GET DIAGNOSTICS _qtd_deletados = ROW_COUNT;

        RAISE WARNING '[FASE 2] Lote offset=%: % NFe(s) deletadas (cascade).', _offset, _qtd_deletados;

        _offset := _offset + _lote_delete;
    END LOOP;

    RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] FASE 3 — Reprocessando % NFe(s) com substituir=FALSE...', _qtd_pendentes;

    -- =========================================================================
    -- FASE 3: reprocessa com substituir=FALSE
    -- O registro foi deletado na fase 2, então a função vai direto para INSERT
    -- sem passar pelo bloco de delete interno — apenas INSERTs, zero overhead extra.
    -- =========================================================================
    FOR r IN SELECT * FROM _tmp_ibs_pendentes ORDER BY criado_em ASC LOOP

        _qtd_total := _qtd_total + 1;

        -- Progresso a cada 10 NFes para não poluir o log
        IF _qtd_total % 10 = 0 OR _qtd_total = 1 THEN
            RAISE WARNING '[%/%] XML_ID=% | CHAVE=%',
                _qtd_total, _qtd_pendentes, r.xml_id, r.ch_nf;
        END IF;

        _resultado := xml.desestruturar_xml_nfe_nfce(r.xml_id, FALSE);

        IF (_resultado->>'success')::BOOLEAN THEN
            _qtd_sucesso := _qtd_sucesso + 1;
        ELSE
            _qtd_erro := _qtd_erro + 1;
            -- Erros sempre aparecem independente do intervalo
            RAISE WARNING '[ERRO %/%] XML_ID=% | %',
                _qtd_total, _qtd_pendentes, r.xml_id,
                COALESCE(_resultado->'error'->>'message', _resultado->>'message');
        END IF;

        xml_id   := r.xml_id;
        ch_nf    := r.ch_nf;
        id_nfe   := (_resultado->'data'->>'nfe_id')::BIGINT;
        sucesso  := (_resultado->>'success')::BOOLEAN;
        mensagem := COALESCE(
                        _resultado->'error'->>'message',
                        _resultado->>'message'
                    );
        RETURN NEXT;

    END LOOP;

    DROP TABLE IF EXISTS _tmp_ibs_pendentes;

    RAISE WARNING '[reprocessar_nfe_sem_ibs_cbs] Concluído: % processadas | % sucesso | % erro',
        _qtd_total, _qtd_sucesso, _qtd_erro;

END;
$$;


ALTER FUNCTION xml.reprocessar_nfe_sem_ibs_cbs(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer) OWNER TO dorcilio;

--
-- TOC entry 12190 (class 0 OID 0)
-- Dependencies: 3715
-- Name: FUNCTION reprocessar_nfe_sem_ibs_cbs(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer); Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON FUNCTION xml.reprocessar_nfe_sem_ibs_cbs(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer) IS 'Reprocessa em lote NFes com <IBSCBS> no XML sem registro em nfe.ub12_ibs_cbs.
3 fases: (1) coleta IDs via xpath_exists — modo batch (rápido), com fallback linha
a linha (BEGIN/EXCEPTION por registro) se houver TOAST corrompido: corrompidos são
logados e ignorados, demais são processados normalmente;
(2) DELETE em sub-lotes (_lote_delete) — bulk delete + cascade por lote, menos locks;
(3) reprocessa com substituir=FALSE — registro já deletado, vai direto para INSERT.
Parâmetros: _dt_inicial, _dt_final, _limite (padrão 500), _lote_delete (padrão 200).
Chame repetidamente até retornar 0 linhas.';


--
-- TOC entry 3744 (class 1255 OID 601447045)
-- Name: reprocessar_nfe_sem_itens(date, date, integer, integer); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.reprocessar_nfe_sem_itens(_dt_inicial date DEFAULT '2026-07-01'::date, _dt_final date DEFAULT NULL::date, _limite integer DEFAULT 500, _lote_delete integer DEFAULT 200) RETURNS TABLE(xml_id bigint, ch_nf character varying, id_nfe bigint, sucesso boolean, mensagem text)
    LANGUAGE plpgsql
    AS $$
/*
===================================================================================
FUNÇÃO: xml.reprocessar_nfe_sem_itens
===================================================================================
Objetivo:
    Identifica NFes que existem em nfe.raiz_nfe mas sem nenhum registro em
    nfe.i01_prod (itens da nota), e as reprocessa a partir do XML original.
    O diagnóstico é feito cruzando livros.consulta_nfe_sefaz e
    livros.consulta_nfe_sefaz_saida para restringir ao período de interesse.

Estratégia (3 fases — mesmo padrão de xml.reprocessar_nfe_sem_ibs_cbs):

    FASE 1 — Identificar (sem acesso a xml_file — muito mais rápido que ibs_cbs)
        Join entre xml.nfe_nfce, livros.consulta_nfe_sefaz(_saida), nfe.raiz_nfe
        e NOT EXISTS em nfe.i01_prod. Materializa em temp table antes de deletar.

    FASE 2 — Deletar em sub-lotes (_lote_delete IDs por vez)
        DELETE manual em nfe.raiz_nfe (cascade limpa todas as tabelas filhas).
        Bulk delete por lote >> N deletes individuais dentro do desestruturar:
        menos locks, menos WAL, cascade em conjunto por lote.

    FASE 3 — Reprocessar com substituir=FALSE
        Registro já deletado na fase 2 → desestruturar vai direto para INSERT,
        zero overhead do bloco de verificação de duplicata interno.

Parâmetros:
    _dt_inicial   DATE     d_emi >= este valor nas tabelas sefaz (padrão: 2026-07-01)
    _dt_final     DATE     Limite superior opcional de d_emi (padrão: sem limite)
    _limite       INTEGER  Total de NFes por chamada (padrão: 500)
    _lote_delete  INTEGER  NFes por sub-lote de DELETE (padrão: 200)

Uso:
    -- Diagnóstico rápido (sem executar): use o SELECT do script patch-resync-...

    -- Processar julho/2026 em lote padrão
    SELECT * FROM xml.reprocessar_nfe_sem_itens('2026-07-01', '2026-07-31');

    -- Lotes menores para conexão mais lenta
    SELECT * FROM xml.reprocessar_nfe_sem_itens('2026-07-01', '2026-07-31', 100, 50);

    -- Servidor robusto: lote maior
    SELECT * FROM xml.reprocessar_nfe_sem_itens('2026-07-01', NULL, 2000, 500);

    -- Chamar repetidamente até retornar 0 linhas (processa todos os pendentes)
===================================================================================
*/
DECLARE
    r              RECORD;
    _resultado     JSONB;
    _qtd_total     INTEGER := 0;
    _qtd_sucesso   INTEGER := 0;
    _qtd_erro      INTEGER := 0;
    _qtd_pendentes INTEGER := 0;
    _qtd_deletados INTEGER := 0;
    _offset        INTEGER := 0;
    _ids_lote      BIGINT[];
BEGIN

    SET LOCAL statement_timeout = 0;
    -- Suprime RAISE INFO/NOTICE da função desestruturar (~20 msgs por NFe).
    -- RAISE WARNING desta função continua aparecendo normalmente.
    SET LOCAL client_min_messages = WARNING;

    RAISE WARNING '[reprocessar_nfe_sem_itens] FASE 1 — Coletando IDs. Período: % a % | Limite: % | Lote delete: %',
        _dt_inicial, COALESCE(_dt_final::TEXT, 'sem limite'), _limite, _lote_delete;

    -- =========================================================================
    -- FASE 1: materializa os IDs pendentes
    -- Sem leitura de xml_file (sem TOAST) — join simples entre metadados.
    -- DISTINCT ON (id_nfe) evita duplicatas quando a mesma NFe aparece em
    -- ambas as tabelas sefaz (entrada e saída).
    -- =========================================================================
    DROP TABLE IF EXISTS _tmp_nfe_sem_itens;
    CREATE TEMP TABLE _tmp_nfe_sem_itens AS
    SELECT DISTINCT ON (u.id_nfe)
        u.xml_id,
        u.ch_nf,
        u.id_nfe,
        u.d_emi
    FROM (
        -- NFes de entrada (livros.consulta_nfe_sefaz)
        SELECT
            x2.xml_id,
            x2.ch_nf,
            rn2.id_nfe,
            b.d_emi
        FROM xml.nfe_nfce                   AS x2
        JOIN livros.consulta_nfe_sefaz      AS b   ON x2.ch_nf = b.inf_nfe
        JOIN nfe.raiz_nfe                   AS rn2 ON x2.ch_nf = rn2.inf_nfe
        WHERE b.d_emi >= _dt_inicial
          AND (_dt_final IS NULL OR b.d_emi <= _dt_final)
          AND NOT EXISTS (
              SELECT 1 FROM nfe.i01_prod AS p WHERE p.id_nfe = rn2.id_nfe
          )

        UNION ALL

        -- NFes de saída (livros.consulta_nfe_sefaz_saida)
        SELECT
            x2.xml_id,
            x2.ch_nf,
            rn2.id_nfe,
            b.d_emi
        FROM xml.nfe_nfce                        AS x2
        JOIN livros.consulta_nfe_sefaz_saida     AS b   ON x2.ch_nf = b.inf_nfe
        JOIN nfe.raiz_nfe                        AS rn2 ON x2.ch_nf = rn2.inf_nfe
        WHERE b.d_emi >= _dt_inicial
          AND (_dt_final IS NULL OR b.d_emi <= _dt_final)
          AND NOT EXISTS (
              SELECT 1 FROM nfe.i01_prod AS p WHERE p.id_nfe = rn2.id_nfe
          )
    ) AS u
    ORDER BY u.id_nfe, u.d_emi ASC
    LIMIT _limite;

    GET DIAGNOSTICS _qtd_pendentes = ROW_COUNT;

    RAISE WARNING '[reprocessar_nfe_sem_itens] % NFe(s) identificadas.', _qtd_pendentes;

    IF _qtd_pendentes = 0 THEN
        DROP TABLE IF EXISTS _tmp_nfe_sem_itens;
        RAISE WARNING '[reprocessar_nfe_sem_itens] Nenhuma NFe pendente. Nada a fazer.';
        RETURN;
    END IF;

    -- =========================================================================
    -- FASE 2: DELETE em sub-lotes
    -- Um DELETE de N IDs >> N DELETEs individuais: menos locks, menos WAL,
    -- cascade processa em conjunto. Sub-lotes menores evitam travar raiz_nfe.
    -- =========================================================================
    RAISE WARNING '[reprocessar_nfe_sem_itens] FASE 2 — Deletando em sub-lotes de % IDs...', _lote_delete;

    _offset := 0;
    LOOP
        SELECT array_agg(t.id_nfe)
        INTO _ids_lote
        FROM (
            SELECT t2.id_nfe
            FROM _tmp_nfe_sem_itens AS t2
            ORDER BY t2.d_emi ASC
            LIMIT _lote_delete OFFSET _offset
        ) t;

        EXIT WHEN _ids_lote IS NULL;

        DELETE FROM nfe.raiz_nfe AS rn WHERE rn.id_nfe = ANY(_ids_lote);
        GET DIAGNOSTICS _qtd_deletados = ROW_COUNT;

        RAISE WARNING '[FASE 2] Lote offset=%: % NFe(s) deletadas (cascade).', _offset, _qtd_deletados;

        _offset := _offset + _lote_delete;
    END LOOP;

    -- =========================================================================
    -- FASE 3: reprocessa com substituir=FALSE
    -- Registro deletado na fase 2 → desestruturar vai direto para INSERT.
    -- =========================================================================
    RAISE WARNING '[reprocessar_nfe_sem_itens] FASE 3 — Reprocessando % NFe(s) com substituir=FALSE...', _qtd_pendentes;

    FOR r IN SELECT * FROM _tmp_nfe_sem_itens ORDER BY d_emi ASC LOOP

        _qtd_total := _qtd_total + 1;

        IF _qtd_total % 10 = 0 OR _qtd_total = 1 THEN
            RAISE WARNING '[%/%] XML_ID=% | CHAVE=%',
                _qtd_total, _qtd_pendentes, r.xml_id, r.ch_nf;
        END IF;

        _resultado := xml.desestruturar_xml_nfe_nfce(r.xml_id, FALSE);

        IF (_resultado->>'success')::BOOLEAN THEN
            _qtd_sucesso := _qtd_sucesso + 1;
        ELSE
            _qtd_erro := _qtd_erro + 1;
            RAISE WARNING '[ERRO %/%] XML_ID=% | %',
                _qtd_total, _qtd_pendentes, r.xml_id,
                COALESCE(_resultado->'error'->>'message', _resultado->>'message');
        END IF;

        xml_id   := r.xml_id;
        ch_nf    := r.ch_nf;
        id_nfe   := (_resultado->'data'->>'nfe_id')::BIGINT;
        sucesso  := (_resultado->>'success')::BOOLEAN;
        mensagem := COALESCE(
                        _resultado->'error'->>'message',
                        _resultado->>'message'
                    );
        RETURN NEXT;

    END LOOP;

    DROP TABLE IF EXISTS _tmp_nfe_sem_itens;

    RAISE WARNING '[reprocessar_nfe_sem_itens] Concluído: % processadas | % sucesso | % erro',
        _qtd_total, _qtd_sucesso, _qtd_erro;

END;
$$;


ALTER FUNCTION xml.reprocessar_nfe_sem_itens(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer) OWNER TO dorcilio;

--
-- TOC entry 12191 (class 0 OID 0)
-- Dependencies: 3744
-- Name: FUNCTION reprocessar_nfe_sem_itens(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer); Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON FUNCTION xml.reprocessar_nfe_sem_itens(_dt_inicial date, _dt_final date, _limite integer, _lote_delete integer) IS 'Reprocessa em lote NFes que existem em nfe.raiz_nfe mas sem itens em nfe.i01_prod.
Identifica cruzando livros.consulta_nfe_sefaz e consulta_nfe_sefaz_saida por d_emi.
3 fases: (1) coleta IDs sem acesso a xml_file — rápido, sem problema de TOAST;
(2) DELETE manual em sub-lotes (_lote_delete) + cascade por lote;
(3) reprocessa com substituir=FALSE — vai direto para INSERT.
Parâmetros: _dt_inicial, _dt_final, _limite (padrão 500), _lote_delete (padrão 200).
Chame repetidamente até retornar 0 linhas.';


--
-- TOC entry 3696 (class 1255 OID 570086692)
-- Name: save_all_xmls_to_folder(character varying); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.save_all_xmls_to_folder(_cpf_cnpj character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	r_nfe_nfce RECORD;
	rows_exported INT := 0;
	formatted_query TEXT;
begin
/*
	begin;

	SELECT * FROM xml.save_all_xmls_to_folder('35910448000127');

	commit;
*/

FOR r_nfe_nfce IN
(
	SELECT
		xml_id,
		ch_nf,
		--xml_file,
		criado_em,
		COUNT(xml_id) OVER() AS rows_number
	FROM
		xml.nfe_nfce
	WHERE
		cpf_cnpj = _cpf_cnpj OR dest_cpf_cnpj = _cpf_cnpj
) LOOP
	RAISE NOTICE 'SALVANDO |ID|CHAVE|DATA|QTD_PROCESSADA|QTD_PROCESSAR| - |%|%|%|%|%|', r_nfe_nfce.xml_id, r_nfe_nfce.ch_nf, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss'), rows_exported, r_nfe_nfce.rows_number;
	formatted_query := format('COPY (SELECT xml_file FROM xml.nfe_nfce WHERE xml_id = %s) TO ''/tmp/%s/%s.xml'';', r_nfe_nfce.xml_id, _cpf_cnpj, r_nfe_nfce.ch_nf);
	EXECUTE formatted_query;
	rows_exported := rows_exported + 1;
	RAISE NOTICE 'XML SALVA |ID|CHAVE|DATA|QTD_PROCESSADA|QTD_PROCESSAR| - |%|%|%|%|%|', r_nfe_nfce.xml_id, r_nfe_nfce.ch_nf, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss'), rows_exported, r_nfe_nfce.rows_number;
END LOOP;
end;
$$;


ALTER FUNCTION xml.save_all_xmls_to_folder(_cpf_cnpj character varying) OWNER TO dorcilio;

--
-- TOC entry 3670 (class 1255 OID 547395776)
-- Name: save_xmls_to_folder(character varying, date, date); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.save_xmls_to_folder(_cpf_cnpj character varying, dt_ini date, dt_fim date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	r_nfe_nfce RECORD;
	rows_exported INT := 0;
	formatted_query TEXT;
begin
/*
	begin;

	SELECT * FROM xml.desestruturar_all_xml();

	commit;
*/

FOR r_nfe_nfce IN
(
	SELECT
		xml_id,
		ch_nf,
		--xml_file,
		criado_em,
		COUNT(xml_id) OVER() AS rows_number
	FROM
		xml.nfe_nfce
	WHERE
		cpf_cnpj = _cpf_cnpj AND criado_em BETWEEN dt_ini AND dt_fim
) LOOP
	RAISE NOTICE 'SALVANDO |ID|CHAVE|DATA|QTD_PROCESSADA|QTD_PROCESSAR| - |%|%|%|%|%|', r_nfe_nfce.xml_id, r_nfe_nfce.ch_nf, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss'), rows_exported, r_nfe_nfce.rows_number;
	formatted_query := format('COPY (SELECT xml_file FROM xml.nfe_nfce WHERE xml_id = %s) TO ''/tmp/%s/%s.xml'';', r_nfe_nfce.xml_id, _cpf_cnpj, r_nfe_nfce.ch_nf);
	EXECUTE formatted_query;
	rows_exported := rows_exported + 1;
	RAISE NOTICE 'XML SALVA |ID|CHAVE|DATA|QTD_PROCESSADA|QTD_PROCESSAR| - |%|%|%|%|%|', r_nfe_nfce.xml_id, r_nfe_nfce.ch_nf, to_char(NOW(), 'dd/mm/yyyy HH:MM:ss'), rows_exported, r_nfe_nfce.rows_number;
END LOOP;
end;
$$;


ALTER FUNCTION xml.save_xmls_to_folder(_cpf_cnpj character varying, dt_ini date, dt_fim date) OWNER TO dorcilio;

--
-- TOC entry 3660 (class 1255 OID 538315423)
-- Name: teste_xml(bigint); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.teste_xml(_xml_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	xml_det_pag XML;
	ind_pag INT;
	cnpj_card VARCHAR(14);
begin
/*
	BEGIN;

	SELECT * FROM xml.teste_xml(179286);

	COMMIT;
*/
FOR xml_det_pag IN
(
	SELECT
		node_in_ya01_pag
	FROM
	(
		SELECT
			UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::XML AS node_in_ya01_pag
		FROM
	        xml.nfe_nfce a
	    WHERE
	        a.xml_id = _xml_id
	) a
	WHERE
		node_in_ya01_pag::TEXT LIKE '%detPag%'
) LOOP
	RAISE NOTICE 'PASSOU %', xml_det_pag;
	SELECT
		((xpath('/new:detPag/new:indPag/text()', xml_det_pag::XML, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pag,
		(xpath('/new:detPag/new:card/new:CNPJ/text()', xml_det_pag::XML, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj
	INTO
		ind_pag,
		cnpj_card;
	RAISE NOTICE 'BORA VER % | %', ind_pag, cnpj_card;
END LOOP;
END;
$$;


ALTER FUNCTION xml.teste_xml(_xml_id bigint) OWNER TO dorcilio;

--
-- TOC entry 3747 (class 1255 OID 607108386)
-- Name: verificar_importar_nfe_nfce(uuid, xml); Type: FUNCTION; Schema: xml; Owner: dorcilio
--

CREATE FUNCTION xml.verificar_importar_nfe_nfce(_import_job_id uuid, _xml_file xml) RETURNS TABLE(inserida boolean, erro_importada boolean, erro_ch_nf boolean, erro_mod boolean, erro_participante boolean, xml_id bigint, ch_nf character varying, cpf_cnpj character varying, dest_cpf_cnpj character varying)
    LANGUAGE plpgsql ROWS 1
    AS $$
DECLARE
    _ch_nf              VARCHAR(44);
    _emit_cnpj_cpf      VARCHAR(14);
    _emit_ie            VARCHAR(15);
    _dest_cnpj_cpf      VARCHAR(14);
    _dest_ie            VARCHAR(15);
    _mod_nf             TEXT;
    _xml_id_existente   BIGINT;
    _xml_id_inserido    BIGINT;

    _e_importada    BOOLEAN := FALSE;
    _e_ch_nf        BOOLEAN := FALSE;
    _e_mod          BOOLEAN := FALSE;
    _e_participante BOOLEAN := FALSE;

    _ns TEXT[][] := ARRAY[ARRAY['x', 'http://www.portalfiscal.inf.br/nfe']];
BEGIN
    -- Extração via XPath
    _ch_nf := regexp_replace(
        (xpath('//x:infNFe/@Id', _xml_file, _ns))[1]::TEXT,
        '[^0-9]', '', 'g'
    );

    _emit_cnpj_cpf := COALESCE(
        (xpath('//x:emit/x:CNPJ/text()', _xml_file, _ns))[1]::TEXT,
        (xpath('//x:emit/x:CPF/text()', _xml_file, _ns))[1]::TEXT
    );
    _emit_ie       := (xpath('//x:emit/x:IE/text()', _xml_file, _ns))[1]::TEXT;

    _dest_cnpj_cpf := COALESCE(
        (xpath('//x:dest/x:CNPJ/text()', _xml_file, _ns))[1]::TEXT,
        (xpath('//x:dest/x:CPF/text()', _xml_file, _ns))[1]::TEXT
    );
    _dest_ie       := (xpath('//x:dest/x:IE/text()', _xml_file, _ns))[1]::TEXT;

    _mod_nf        := (xpath('//x:ide/x:mod/text()', _xml_file, _ns))[1]::TEXT;

    -- Validações
    IF _ch_nf IS NULL OR length(_ch_nf) <> 44 THEN
        _e_ch_nf := TRUE;
    END IF;

    IF _mod_nf NOT IN ('55', '65') THEN
        _e_mod := TRUE;
    END IF;

    SELECT n.xml_id INTO _xml_id_existente
    FROM xml.nfe_nfce n
    WHERE n.ch_nf = _ch_nf
    LIMIT 1;

    IF _xml_id_existente IS NOT NULL THEN
        _e_importada := TRUE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ncm_helper.cad_empresas AS ce
        WHERE ce.cpf_cnpj IN (_emit_cnpj_cpf, _dest_cnpj_cpf)
    ) THEN
        _e_participante := TRUE;
    END IF;

    -- Execução
    IF (_e_ch_nf OR _e_mod OR _e_participante OR _e_importada) THEN
        IF _e_importada AND NOT (_e_ch_nf OR _e_mod OR _e_participante) THEN
            UPDATE xml.nfe_nfce AS n
            SET import_job_id = _import_job_id,
                xml_file      = _xml_file
            WHERE n.xml_id = _xml_id_existente;
        END IF;
        RETURN QUERY
            SELECT FALSE, _e_importada, _e_ch_nf, _e_mod, _e_participante,
                   _xml_id_existente, _ch_nf,
                   _emit_cnpj_cpf, _dest_cnpj_cpf;
    ELSE
        INSERT INTO xml.nfe_nfce AS t (
            ch_nf, cpf_cnpj, ie, dest_cpf_cnpj, dest_ie, import_job_id, xml_file
        ) VALUES (
            _ch_nf, _emit_cnpj_cpf, _emit_ie,
            _dest_cnpj_cpf, _dest_ie, _import_job_id, _xml_file
        )
        RETURNING t.xml_id INTO _xml_id_inserido;

        RETURN QUERY
            SELECT TRUE, FALSE, FALSE, FALSE, FALSE,
                   _xml_id_inserido, _ch_nf,
                   _emit_cnpj_cpf, _dest_cnpj_cpf;
    END IF;
END;
$$;


ALTER FUNCTION xml.verificar_importar_nfe_nfce(_import_job_id uuid, _xml_file xml) OWNER TO dorcilio;

--
-- TOC entry 3743 (class 1255 OID 598167259)
-- Name: verificar_toast_xml(integer, integer); Type: FUNCTION; Schema: xml; Owner: postgres
--

CREATE FUNCTION xml.verificar_toast_xml(p_inicio integer DEFAULT 1, p_fim integer DEFAULT NULL::integer) RETURNS TABLE(xml_id integer, ch_nf character varying, criado_em timestamp with time zone, status text, erro text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT
            x.xml_id,
            x.ch_nf,
            x.criado_em,
            x.xml_file
        FROM xml.nfe_nfce x
        WHERE x.xml_id >= p_inicio
          AND (p_fim IS NULL OR x.xml_id <= p_fim)
        ORDER BY x.xml_id
    LOOP
        BEGIN
            PERFORM xpath_exists(
                '/new:nfeProc/new:NFe/new:infNFe/new:det/new:imposto/new:IBSCBS',
                r.xml_file,
                ARRAY[
                    ARRAY[
                        'new',
                        'http://www.portalfiscal.inf.br/nfe'
                    ]
                ]
            );

        EXCEPTION
            WHEN OTHERS THEN

                xml_id := r.xml_id;
                ch_nf := r.ch_nf;
                criado_em := r.criado_em;
                status := 'ERRO';
                erro := SQLERRM;

                RETURN NEXT;
                RETURN;
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION xml.verificar_toast_xml(p_inicio integer, p_fim integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 2760 (class 1259 OID 606170580)
-- Name: import_job; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.import_job (
    job_id uuid DEFAULT gen_random_uuid() NOT NULL,
    id_usuario bigint NOT NULL,
    cpf_cnpj character varying(14),
    dest_cpf_cnpj character varying(14),
    job_type character varying(20) NOT NULL,
    job_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    file_name character varying(256) NOT NULL,
    bucket_path text,
    total_count bigint DEFAULT 0 NOT NULL,
    notes text,
    job_fts tsvector,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    expires_at timestamp with time zone DEFAULT (clock_timestamp() + '90 days'::interval) NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    reimport boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_import_job_status CHECK (((job_status)::text = ANY ((ARRAY['PENDING'::character varying, 'RUNNING'::character varying, 'COMPLETED'::character varying, 'PARTIAL'::character varying, 'FAILED'::character varying, 'CANCELLED'::character varying])::text[]))),
    CONSTRAINT ck_import_job_total CHECK ((total_count >= 0)),
    CONSTRAINT ck_import_job_type CHECK (((job_type)::text = ANY ((ARRAY['SINGLE_XML'::character varying, 'BATCH_PACKAGE'::character varying, 'SIEG_BATCH'::character varying])::text[])))
);


ALTER TABLE xml.import_job OWNER TO dorcilio;

--
-- TOC entry 12192 (class 0 OID 0)
-- Dependencies: 2760
-- Name: TABLE import_job; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON TABLE xml.import_job IS 'Log de controle de importação de XMLs. TTL gerenciado via expires_at. Tipos: SINGLE_XML (upload API), BATCH_PACKAGE (ZIP/RAR GCS), SIEG_BATCH (worker SIEG). Removível após 2-3 meses sem impacto nas XMLs em nfe_nfce.';


--
-- TOC entry 12193 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.cpf_cnpj; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.cpf_cnpj IS 'CNPJ/CPF do emitente principal.';


--
-- TOC entry 12194 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.dest_cpf_cnpj; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.dest_cpf_cnpj IS 'CNPJ/CPF do destinatário (quando o cliente é o dest da NF).';


--
-- TOC entry 12195 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.job_type; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.job_type IS 'SINGLE_XML=upload unitário; BATCH_PACKAGE=ZIP ou RAR via bucket; SIEG_BATCH=worker SIEG automático.';


--
-- TOC entry 12196 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.job_status; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.job_status IS 'PENDING→RUNNING→COMPLETED|PARTIAL|FAILED. PARTIAL = sucesso parcial com erros.';


--
-- TOC entry 12197 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.job_fts; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.job_fts IS 'Vetor FTS (public.simple_portuguese) para busca por nome de arquivo, CPF/CNPJ, tipo, status e periodo (MM/YYYY, mes, mes+ano).';


--
-- TOC entry 12198 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.expires_at; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.expires_at IS 'Data de expiração para limpeza via cron. Padrão: 90 dias após criação.';


--
-- TOC entry 12199 (class 0 OID 0)
-- Dependencies: 2760
-- Name: COLUMN import_job.reimport; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.import_job.reimport IS 'Quando definido como TRUE, ignora a verificação de chaves duplicadas e reprocessa todos os arquivos XML do pacote.';


--
-- TOC entry 2762 (class 1259 OID 606171793)
-- Name: import_job_error; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.import_job_error (
    error_id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    step_name character varying(20),
    file_reference character varying(256),
    ch_nf character varying(44),
    error_code character varying(60),
    error_message text,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE xml.import_job_error OWNER TO dorcilio;

--
-- TOC entry 12201 (class 0 OID 0)
-- Dependencies: 2762
-- Name: TABLE import_job_error; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON TABLE xml.import_job_error IS 'Erros individuais por job. Removidos em CASCADE ao deletar o import_job. error_code: DUPLICATE_CH_NF | INVALID_XML | INVALID_MODEL | NF_EXTRACT_FAILED | NO_PARTICIPANT | STORE_XML_FAILED | EXTRACT_FAILED | NO_XML_FOUND.';


--
-- TOC entry 2761 (class 1259 OID 606171771)
-- Name: import_job_step; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.import_job_step (
    step_id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    step_order smallint NOT NULL,
    step_name character varying(20) NOT NULL,
    step_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    total_count bigint DEFAULT 0 NOT NULL,
    success_count bigint DEFAULT 0 NOT NULL,
    error_count bigint DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT ck_import_job_step_counts CHECK (((total_count >= 0) AND (success_count >= 0) AND (error_count >= 0))),
    CONSTRAINT ck_import_job_step_name CHECK (((step_name)::text = ANY ((ARRAY['EXTRACT_ZIP'::character varying, 'STORE_XML'::character varying, 'PROCESS_NF'::character varying])::text[]))),
    CONSTRAINT ck_import_job_step_status CHECK (((step_status)::text = ANY ((ARRAY['PENDING'::character varying, 'RUNNING'::character varying, 'COMPLETED'::character varying, 'PARTIAL'::character varying, 'FAILED'::character varying, 'CANCELLED'::character varying, 'SKIPPED'::character varying])::text[])))
);


ALTER TABLE xml.import_job_step OWNER TO dorcilio;

--
-- TOC entry 12203 (class 0 OID 0)
-- Dependencies: 2761
-- Name: TABLE import_job_step; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON TABLE xml.import_job_step IS 'Etapas individuais de cada job. Removidas em CASCADE ao deletar o import_job.';


--
-- TOC entry 2608 (class 1259 OID 533932302)
-- Name: nfe_nfce; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.nfe_nfce (
    xml_id integer NOT NULL,
    ch_nf character varying(44) NOT NULL,
    xml_file xml NOT NULL,
    criado_em timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    cpf_cnpj character varying(14) NOT NULL,
    ie character varying(15),
    dest_cpf_cnpj character varying(14),
    dest_ie character varying(15),
    import_job_id uuid
);


ALTER TABLE xml.nfe_nfce OWNER TO dorcilio;

--
-- TOC entry 12205 (class 0 OID 0)
-- Dependencies: 2608
-- Name: COLUMN nfe_nfce.import_job_id; Type: COMMENT; Schema: xml; Owner: dorcilio
--

COMMENT ON COLUMN xml.nfe_nfce.import_job_id IS 'UUID do import_job que originou esta XML. Soft reference (sem FK) — import_job pode ser deletado após TTL sem impacto na XML.';


--
-- TOC entry 2607 (class 1259 OID 533932300)
-- Name: nfe_nfce_xml_id_seq; Type: SEQUENCE; Schema: xml; Owner: dorcilio
--

CREATE SEQUENCE xml.nfe_nfce_xml_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE xml.nfe_nfce_xml_id_seq OWNER TO dorcilio;

--
-- TOC entry 12207 (class 0 OID 0)
-- Dependencies: 2607
-- Name: nfe_nfce_xml_id_seq; Type: SEQUENCE OWNED BY; Schema: xml; Owner: dorcilio
--

ALTER SEQUENCE xml.nfe_nfce_xml_id_seq OWNED BY xml.nfe_nfce.xml_id;


--
-- TOC entry 2763 (class 1259 OID 606292460)
-- Name: sieg_checkpoint; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.sieg_checkpoint (
    id integer DEFAULT 1 NOT NULL,
    ultima_execucao timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT ck_sieg_checkpoint_single_row CHECK ((id = 1))
);


ALTER TABLE xml.sieg_checkpoint OWNER TO dorcilio;

--
-- TOC entry 2769 (class 1259 OID 608909268)
-- Name: sieg_empresa_checkpoint; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.sieg_empresa_checkpoint (
    cpf_cnpj character varying(14) NOT NULL,
    contagem_em timestamp with time zone,
    ultima_consulta_em timestamp with time zone,
    ultima_download_em timestamp with time zone,
    ultimo_total_xmls integer DEFAULT 0 NOT NULL,
    ultimo_total_baixado integer DEFAULT 0 NOT NULL,
    ultima_janela_inicio timestamp with time zone,
    ultima_janela_fim timestamp with time zone,
    ultima_consulta_status smallint,
    download_status smallint,
    ultima_download_status smallint,
    download_pendente boolean DEFAULT false NOT NULL,
    falhas_consecutivas integer DEFAULT 0 NOT NULL,
    proxima_tentativa_em timestamp with time zone,
    ultimo_erro text,
    atualizado_em timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE xml.sieg_empresa_checkpoint OWNER TO dorcilio;

--
-- TOC entry 2771 (class 1259 OID 608909422)
-- Name: sieg_requisicao_log; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.sieg_requisicao_log (
    id bigint NOT NULL,
    cpf_cnpj character varying(14),
    endpoint character varying(40) NOT NULL,
    metodo character varying(8) DEFAULT 'POST'::character varying NOT NULL,
    status_http smallint,
    tentativas integer DEFAULT 1 NOT NULL,
    duracao_ms integer,
    janela_inicio timestamp with time zone,
    janela_fim timestamp with time zone,
    total_encontrado integer,
    total_baixado integer,
    erro text,
    criado_em timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE xml.sieg_requisicao_log OWNER TO dorcilio;

--
-- TOC entry 2770 (class 1259 OID 608909420)
-- Name: sieg_requisicao_log_id_seq; Type: SEQUENCE; Schema: xml; Owner: dorcilio
--

CREATE SEQUENCE xml.sieg_requisicao_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE xml.sieg_requisicao_log_id_seq OWNER TO dorcilio;

--
-- TOC entry 12210 (class 0 OID 0)
-- Dependencies: 2770
-- Name: sieg_requisicao_log_id_seq; Type: SEQUENCE OWNED BY; Schema: xml; Owner: dorcilio
--

ALTER SEQUENCE xml.sieg_requisicao_log_id_seq OWNED BY xml.sieg_requisicao_log.id;


--
-- TOC entry 2768 (class 1259 OID 608909224)
-- Name: sieg_token; Type: TABLE; Schema: xml; Owner: dorcilio
--

CREATE TABLE xml.sieg_token (
    id integer DEFAULT 1 NOT NULL,
    token text DEFAULT ''::text NOT NULL,
    expires_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT ck_sieg_token_single_row CHECK ((id = 1))
);


ALTER TABLE xml.sieg_token OWNER TO dorcilio;

--
-- TOC entry 11831 (class 2604 OID 533932305)
-- Name: nfe_nfce xml_id; Type: DEFAULT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.nfe_nfce ALTER COLUMN xml_id SET DEFAULT nextval('xml.nfe_nfce_xml_id_seq'::regclass);


--
-- TOC entry 11861 (class 2604 OID 608909425)
-- Name: sieg_requisicao_log id; Type: DEFAULT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.sieg_requisicao_log ALTER COLUMN id SET DEFAULT nextval('xml.sieg_requisicao_log_id_seq'::regclass);


--
-- TOC entry 11901 (class 2606 OID 606171802)
-- Name: import_job_error import_job_error_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job_error
    ADD CONSTRAINT import_job_error_pkey PRIMARY KEY (error_id);


--
-- TOC entry 11892 (class 2606 OID 606170596)
-- Name: import_job import_job_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job
    ADD CONSTRAINT import_job_pkey PRIMARY KEY (job_id);


--
-- TOC entry 11895 (class 2606 OID 606171785)
-- Name: import_job_step import_job_step_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job_step
    ADD CONSTRAINT import_job_step_pkey PRIMARY KEY (step_id);


--
-- TOC entry 11882 (class 2606 OID 534944591)
-- Name: nfe_nfce nfe_nfce_ch_nf_ukey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.nfe_nfce
    ADD CONSTRAINT nfe_nfce_ch_nf_ukey UNIQUE (ch_nf);


--
-- TOC entry 11884 (class 2606 OID 533932311)
-- Name: nfe_nfce nfe_nfce_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.nfe_nfce
    ADD CONSTRAINT nfe_nfce_pkey PRIMARY KEY (xml_id);


--
-- TOC entry 11903 (class 2606 OID 606292468)
-- Name: sieg_checkpoint sieg_checkpoint_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.sieg_checkpoint
    ADD CONSTRAINT sieg_checkpoint_pkey PRIMARY KEY (id);


--
-- TOC entry 11909 (class 2606 OID 608909290)
-- Name: sieg_empresa_checkpoint sieg_empresa_checkpoint_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.sieg_empresa_checkpoint
    ADD CONSTRAINT sieg_empresa_checkpoint_pkey PRIMARY KEY (cpf_cnpj);


--
-- TOC entry 11913 (class 2606 OID 608909433)
-- Name: sieg_requisicao_log sieg_requisicao_log_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.sieg_requisicao_log
    ADD CONSTRAINT sieg_requisicao_log_pkey PRIMARY KEY (id);


--
-- TOC entry 11905 (class 2606 OID 608909249)
-- Name: sieg_token sieg_token_pkey; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.sieg_token
    ADD CONSTRAINT sieg_token_pkey PRIMARY KEY (id);


--
-- TOC entry 11897 (class 2606 OID 606171787)
-- Name: import_job_step uk_import_job_step_order; Type: CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job_step
    ADD CONSTRAINT uk_import_job_step_order UNIQUE (job_id, step_order);


--
-- TOC entry 11873 (class 1259 OID 534610315)
-- Name: idx_ch_nf_on_nfe_nfce; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_ch_nf_on_nfe_nfce ON xml.nfe_nfce USING btree (ch_nf);


--
-- TOC entry 11874 (class 1259 OID 606049465)
-- Name: idx_cpf_cnpj_ch_nf_on_nfe_nfce; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_cpf_cnpj_ch_nf_on_nfe_nfce ON xml.nfe_nfce USING btree (cpf_cnpj, ch_nf);


--
-- TOC entry 11875 (class 1259 OID 534610316)
-- Name: idx_cpf_cnpj_on_nfe_nfce; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_cpf_cnpj_on_nfe_nfce ON xml.nfe_nfce USING btree (cpf_cnpj);


--
-- TOC entry 11876 (class 1259 OID 547377385)
-- Name: idx_criado_em_on_nfe_nfce; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_criado_em_on_nfe_nfce ON xml.nfe_nfce USING btree (criado_em);


--
-- TOC entry 11877 (class 1259 OID 534610317)
-- Name: idx_dest_cpf_cnpj_on_nfe_nfce; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_dest_cpf_cnpj_on_nfe_nfce ON xml.nfe_nfce USING btree (dest_cpf_cnpj);


--
-- TOC entry 11885 (class 1259 OID 606908817)
-- Name: idx_import_job_cpf_cnpj; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_cpf_cnpj ON xml.import_job USING btree (cpf_cnpj) WHERE (cpf_cnpj IS NOT NULL);


--
-- TOC entry 11886 (class 1259 OID 606908818)
-- Name: idx_import_job_dest_cpf_cnpj; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_dest_cpf_cnpj ON xml.import_job USING btree (dest_cpf_cnpj) WHERE (dest_cpf_cnpj IS NOT NULL);


--
-- TOC entry 11898 (class 1259 OID 606172823)
-- Name: idx_import_job_error_ch_nf; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_error_ch_nf ON xml.import_job_error USING btree (ch_nf) WHERE (ch_nf IS NOT NULL);


--
-- TOC entry 11899 (class 1259 OID 606172804)
-- Name: idx_import_job_error_job; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_error_job ON xml.import_job_error USING btree (job_id);


--
-- TOC entry 11887 (class 1259 OID 606172462)
-- Name: idx_import_job_expires; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_expires ON xml.import_job USING btree (expires_at) WHERE ((job_status)::text = ANY ((ARRAY['COMPLETED'::character varying, 'PARTIAL'::character varying, 'FAILED'::character varying, 'CANCELLED'::character varying])::text[]));


--
-- TOC entry 11888 (class 1259 OID 606908819)
-- Name: idx_import_job_fts; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_fts ON xml.import_job USING gin (job_fts);


--
-- TOC entry 11889 (class 1259 OID 606172460)
-- Name: idx_import_job_id_usuario; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_id_usuario ON xml.import_job USING btree (id_usuario, created_at DESC);


--
-- TOC entry 11890 (class 1259 OID 606172461)
-- Name: idx_import_job_status; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_status ON xml.import_job USING btree (job_status, created_at DESC);


--
-- TOC entry 11893 (class 1259 OID 606172553)
-- Name: idx_import_job_step_job; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_import_job_step_job ON xml.import_job_step USING btree (job_id, step_order);


--
-- TOC entry 11878 (class 1259 OID 606173123)
-- Name: idx_nfe_nfce_import_job_id; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_nfe_nfce_import_job_id ON xml.nfe_nfce USING btree (import_job_id) WHERE (import_job_id IS NOT NULL);


--
-- TOC entry 11879 (class 1259 OID 585710350)
-- Name: idx_nfe_nfce_xml_id_ch_nf; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_nfe_nfce_xml_id_ch_nf ON xml.nfe_nfce USING btree (xml_id, ch_nf) INCLUDE (cpf_cnpj, dest_cpf_cnpj);


--
-- TOC entry 11880 (class 1259 OID 585692124)
-- Name: idx_nfe_nfce_xml_id_hash; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_nfe_nfce_xml_id_hash ON xml.nfe_nfce USING hash (xml_id);


--
-- TOC entry 11906 (class 1259 OID 608909403)
-- Name: idx_sieg_empresa_checkpoint_proxima; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_sieg_empresa_checkpoint_proxima ON xml.sieg_empresa_checkpoint USING btree (proxima_tentativa_em);


--
-- TOC entry 11907 (class 1259 OID 608909409)
-- Name: idx_sieg_empresa_checkpoint_ultima_consulta; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_sieg_empresa_checkpoint_ultima_consulta ON xml.sieg_empresa_checkpoint USING btree (ultima_consulta_em DESC);


--
-- TOC entry 11910 (class 1259 OID 608909442)
-- Name: idx_sieg_requisicao_log_cnpj; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_sieg_requisicao_log_cnpj ON xml.sieg_requisicao_log USING btree (cpf_cnpj, criado_em DESC);


--
-- TOC entry 11911 (class 1259 OID 608909438)
-- Name: idx_sieg_requisicao_log_data; Type: INDEX; Schema: xml; Owner: dorcilio
--

CREATE INDEX idx_sieg_requisicao_log_data ON xml.sieg_requisicao_log USING btree (criado_em DESC);


--
-- TOC entry 11916 (class 2620 OID 606171770)
-- Name: import_job tr_fts_import_job; Type: TRIGGER; Schema: xml; Owner: dorcilio
--

CREATE TRIGGER tr_fts_import_job BEFORE INSERT OR UPDATE OF file_name, cpf_cnpj, dest_cpf_cnpj, job_type, job_status, notes, created_at ON xml.import_job FOR EACH ROW EXECUTE FUNCTION xml.fn_update_import_job_fts();


--
-- TOC entry 11915 (class 2606 OID 606171803)
-- Name: import_job_error fk_import_job_error_job; Type: FK CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job_error
    ADD CONSTRAINT fk_import_job_error_job FOREIGN KEY (job_id) REFERENCES xml.import_job(job_id) ON DELETE CASCADE;


--
-- TOC entry 11914 (class 2606 OID 606171788)
-- Name: import_job_step fk_import_job_step_job; Type: FK CONSTRAINT; Schema: xml; Owner: dorcilio
--

ALTER TABLE ONLY xml.import_job_step
    ADD CONSTRAINT fk_import_job_step_job FOREIGN KEY (job_id) REFERENCES xml.import_job(job_id) ON DELETE CASCADE;


--
-- TOC entry 12185 (class 0 OID 0)
-- Dependencies: 290
-- Name: SCHEMA xml; Type: ACL; Schema: -; Owner: dorcilio
--

GRANT USAGE ON SCHEMA xml TO cassio;


--
-- TOC entry 12200 (class 0 OID 0)
-- Dependencies: 2760
-- Name: TABLE import_job; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xml.import_job TO cassio;


--
-- TOC entry 12202 (class 0 OID 0)
-- Dependencies: 2762
-- Name: TABLE import_job_error; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xml.import_job_error TO cassio;


--
-- TOC entry 12204 (class 0 OID 0)
-- Dependencies: 2761
-- Name: TABLE import_job_step; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xml.import_job_step TO cassio;


--
-- TOC entry 12206 (class 0 OID 0)
-- Dependencies: 2608
-- Name: TABLE nfe_nfce; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xml.nfe_nfce TO cassio;


--
-- TOC entry 12208 (class 0 OID 0)
-- Dependencies: 2607
-- Name: SEQUENCE nfe_nfce_xml_id_seq; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,USAGE ON SEQUENCE xml.nfe_nfce_xml_id_seq TO cassio;


--
-- TOC entry 12209 (class 0 OID 0)
-- Dependencies: 2763
-- Name: TABLE sieg_checkpoint; Type: ACL; Schema: xml; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xml.sieg_checkpoint TO cassio;


-- Completed on 2026-09-09 18:14:18

--
-- PostgreSQL database dump complete
--

