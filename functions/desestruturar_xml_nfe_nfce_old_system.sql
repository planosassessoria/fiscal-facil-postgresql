-- FUNCTION: xml.desestruturar_xml_nfe_nfce(bigint, boolean)

-- DROP FUNCTION IF EXISTS xml.desestruturar_xml_nfe_nfce(bigint, boolean);

CREATE OR REPLACE FUNCTION xml.desestruturar_xml_nfe_nfce(
	_xml_id bigint,
	substituir boolean DEFAULT false)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
	-- ✅ Variáveis principais
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
	
	-- ✅ Melhorias: Variáveis de otimização
	_xml_content XML;
	_xml_exists BOOLEAN := FALSE;
	_nfe_namespaces TEXT[][] := ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']];
	_nfe_header RECORD;
	_result JSONB;
	_step_name VARCHAR(100);
	_records_processed INTEGER;
	_start_time TIMESTAMPTZ := NOW();
	has_nf_ref INTEGER := 0;
	
	-- ✅ Estrutura para dados do cabeçalho (otimização)
	_header_data RECORD;
begin
/*
===================================================================================
🚀 FISCAL FÁCIL - DESESTRUTURAÇÃO XML NFE/NFCE OTIMIZADA
===================================================================================
Versão Otimizada com:
✅ Carregamento Único do XML
✅ Namespaces Fixos
✅ Extração Única do Cabeçalho  
✅ Controle de Erro Robusto
✅ Validações Iniciais
✅ Logging Estruturado
✅ Tratamento Melhorado de Duplicatas
*/

	-- ✅ VALIDAÇÕES INICIAIS
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
	
	-- ✅ CARREGAMENTO ÚNICO DO XML
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
	
	RAISE INFO '[%] XML carregado com sucesso. Chave NFe: %', _step_name, _ch_nf;
	
	-- ✅ EXTRAÇÃO ÚNICA DO CABEÇALHO
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
	
	RAISE INFO '[%] Cabeçalho extraído. NFe: % Serie: % Modelo: %', _step_name, _nfe_header.n_nf, _nfe_header.serie, _nfe_header.mod;

/* ✅ REMOÇÃO DE VERSÃO ANTERIOR C/ BASE NA CHAVE OTIMIZADA */
_step_name := 'check_duplicates';
SELECT id_nfe INTO _id_nfe FROM nfe.raiz_nfe WHERE inf_nfe = _ch_nf LIMIT 1;

IF _id_nfe IS NOT NULL THEN
	IF substituir IS TRUE THEN
		RAISE WARNING '[%] DELEÇÃO DESATIVADA para segurança - XML ID: % já existe como NFe ID: %', _step_name, _xml_id, _id_nfe;
		_result := jsonb_build_object(
			'success', false,
			'message', 'NFe já existe e deleção está desativada por segurança',
			'error_code', 'DELETION_DISABLED',
			'existing_nfe_id', _id_nfe,
			'xml_id', _xml_id
		);
		RETURN _result;
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
		
		RAISE INFO '[%] XML ID atualizado para NFe existente: %', _step_name, _id_nfe;
		RETURN _result;
	END IF;
END IF;

/* ✅ INSERT TABLE nfe.raiz_nfe OTIMIZADO */
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
RAISE INFO '[%] Processado raiz_nfe: % registros, NFe ID: %', _step_name, _records_processed, _id_nfe;

/* ✅ INSERT TABLE nfe.b01_ide OTIMIZADO */
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
RAISE INFO '[%] Processado IDE da NFe: % registros', _step_name, _records_processed;

/* ✅ VERIFICAR SE POSSUÍ NF REFERÊNCIADA OTIMIZADO */
_step_name := 'check_nf_ref';
SELECT COALESCE(array_length((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/node()', _xml_content, _nfe_namespaces)), 1), 0) INTO has_nf_ref;

IF has_nf_ref > 0 THEN
	INSERT INTO nfe.b12a_nf_ref(id_nfe, ref_nfe, ref_cte)
	SELECT
		_id_nfe AS id_nfe,
		unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refNFe/text()', _xml_content, _nfe_namespaces))::VARCHAR(44) AS ref_nfe,
		unnest(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refCTe/text()', _xml_content, _nfe_namespaces))::VARCHAR(44) AS ref_cte;
	
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	RAISE INFO '[%] Processado % NF referenciadas', _step_name, _records_processed;
END IF;

/* ✅ INSERT TABLE nfe.c01_emit OTIMIZADO */
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
RAISE INFO '[%] Processado emitente: % registros, ID: %', _step_name, _records_processed, _id_emit;

/* ✅ INSERT TABLE nfe.c05_ender_emit OTIMIZADO */
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
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '1058')::INT AS c_pais,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_pais,
	COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS fone;

GET DIAGNOSTICS _records_processed = ROW_COUNT;
RAISE INFO '[%] Processado endereço emitente: % registros', _step_name, _records_processed;
/* ✅ VERIFICAR SE POSSUÍ DESTINATÁRIO OTIMIZADO */
_step_name := 'check_destinatario';
SELECT (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/node()', _xml_content, _nfe_namespaces))[1] IS NOT NULL INTO has_dest;

IF has_dest IS TRUE THEN
	/* ✅ INSERT TABLE nfe.e01_dest OTIMIZADO */
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
	RAISE INFO '[%] Processado destinatário: % registros, ID: %', _step_name, _records_processed, _id_dest;
	/* FIM INSERT nfe.e01_dest */

	/* ✅ INSERT TABLE nfe.e05_ender_dest OTIMIZADO */
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
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '1058')::INT AS c_pais,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xPais/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(60) AS x_pais,
		COALESCE((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', _xml_content, _nfe_namespaces))[1]::TEXT, '')::VARCHAR(14) AS fone;

	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	RAISE INFO '[%] Processado endereço destinatário: % registros', _step_name, _records_processed;
	/* FIM INSERT nfe.e05_ender_dest */
END IF;

/* ✅ INSERT TABLE public.participante OTIMIZADO */
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
			COALESCE(a.c_pais, '1058')::INT AS c_pais,
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
RAISE INFO '[%] Processado participante: % registros', _step_name, _records_processed;
/* FIM INSERT public.participante */

/* ✅ INSERT TABLE public.participante_ie OTIMIZADO */
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
	RAISE INFO '[%] Processado participante_ie: % registros', _step_name, _records_processed;
/* FIM INSERT public.participante_ie */
END IF; -- fim mod <> '65'

/* ✅ INSERT TABLE nfe.d01_avulsa OTIMIZADO */
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
RAISE INFO '[%] Processado d01_avulsa: % registros', _step_name, _records_processed;
/* FIM INSERT nfe.d01_avulsa */

/* ✅ INÍCIO LOOP nfe.i01_prod OTIMIZADO */
_step_name := 'loop_i01_prod';
RAISE INFO '[%] Iniciando loop de produtos/impostos', _step_name;
FOR r_i01_prod IN
(
	-- ✅ Otimizado: extrai det nodes de _xml_content (memória) em vez de xml.nfe_nfce (disco)
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
			-- ✅ Cabeçalho via _nfe_header (já extraído uma vez), não xpath no det_node
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
	RAISE INFO '[loop_i01_prod] item %: i01_prod inserido, id_prod=%', r_i01_prod.n_item, _id_prod;
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
	RAISE INFO '[loop_i01_prod] item %: icms_filhos: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: ipi_filhos: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: p01_ii: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: pis_filhos: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: cofins_filhos: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: ua01_imposto_devol/ua04_ipi: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: na01_icms_uf_dest: % registros', r_i01_prod.n_item, _records_processed;

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
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:CST/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(3) AS cst,
			    -- UB14 - cClassTrib (Código de Classificação Tributária do IBS e CBS)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:cClassTrib/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(6) AS c_class_trib,
			    -- UB14a - indDoacao (Indica natureza da operação de doação)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:indDoacao/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(1) AS ind_doacao,
			    -- UB16 - vBC (Base de cálculo do IBS e CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:vBC/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
			    -- UB18 - pIBSUF (Alíquota do IBS de competência das UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:pIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_uf,
			    -- UB22/UB23 - Grupo Diferimento IBS UF (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:pDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDif/new:vDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs,
			    -- UB25 - vDevTrib (Valor do tributo devolvido - IBS UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gDevTrib/new:vDevTrib/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs,
			    -- UB27/UB28 - Grupo Redução de Alíquota IBS UF (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pRedAliq/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:gRed/new:pAliqEfet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs,
			    -- UB35 - vIBSUF (Valor do IBS de competência da UF)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSUF/new:vIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_uf,
			    -- UB37 - pIBSMun (Alíquota do IBS de competência do Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:pIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_ibs_mun,
			    -- UB41/UB42 - Grupo Diferimento IBS Município (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:pDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDif/new:vDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_ibs_mun,
			    -- UB44 - vDevTrib (Valor do tributo devolvido - IBS Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gDevTrib/new:vDevTrib/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_ibs_mun,
			    -- UB46/UB47 - Grupo Redução de Alíquota IBS Município (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pRedAliq/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_red_aliq_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:gRed/new:pAliqEfet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_ibs_mun,
			    -- UB54 - vIBSMun (Valor do IBS de competência do Município)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gIBSMun/new:vIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mun,
			    -- UB54a - vIBS (Valor total do IBS - soma de vIBSUF e vIBSMun)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:vIBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs,
			    -- UB56 - pCBS (Alíquota da CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:pCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cbs,
			    -- UB60/UB61 - Grupo Diferimento CBS (gDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:pDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDif/new:vDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dif_cbs,
			    -- UB63 - vDevTrib (Valor do tributo devolvido - CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gDevTrib/new:vDevTrib/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_dev_trib_cbs,
			    -- UB65/UB66 - Grupo Redução de Alíquota CBS (gRed)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pRedAliq/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS p_red_aliq_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:gRed/new:pAliqEfet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_cbs,
			    -- UB67 - vCBS (Valor da CBS)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gCBS/new:vCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs,
			    -- UB69/UB70 - Grupo Tributação Regular (gTribRegular)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:CSTReg/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(3) AS cst_reg,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:cClassTribReg/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(6) AS c_class_trib_reg,
			    -- UB71/UB72 - Tributação Regular IBS UF
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_uf,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_uf,
			    -- UB72a/UB72b - Tributação Regular IBS Município
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_ibs_mun,
			    -- UB72c/UB72d - Tributação Regular CBS
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:pAliqEfetRegCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_efet_reg_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribRegular/new:vTribRegCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_reg_cbs,
			    -- UB82b/UB82c - Grupo Tributação Compra Governamental IBS UF (gTribCompraGov)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_uf,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSUF/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_uf,
			    -- UB82d/UB82e - Grupo Tributação Compra Governamental IBS Município
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_ibs_mun,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribIBSMun/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_ibs_mun,
			    -- UB82f/UB82g - Grupo Tributação Compra Governamental CBS
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:pAliqCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_aliq_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBS/new:gTribCompraGov/new:vTribCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_trib_cbs,
			    -- UB85/UB86/UB87 - Grupo Monofásica Padrão (gMonoPadrao)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:qBCMono/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemIBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:adRemCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs,
			    -- UB88/UB89 - Valores Monofásica Padrão
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vIBSMono/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoPadrao/new:vCBSMono/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono,
			    -- UB91/UB92/UB93/UB93a/UB93b - Grupo Monofásica Retenção (gMonoReten)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:qBCMonoReten/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemIBSReten/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vIBSMonoReten/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:adRemCBSReten/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_reten,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoReten/new:vCBSMonoReten/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_reten,
			    -- UB95/UB96/UB97/UB98/UB98a - Grupo Monofásica Retida Anteriormente (gMonoRet)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:qBCMonoRet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS q_bc_mono_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemIBSRet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_ibs_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vIBSMonoRet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:adRemCBSRet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS ad_rem_cbs_ret,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoRet/new:vCBSMonoRet/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_ret,
			    -- UB100/UB101/UB102/UB103 - Grupo Diferimento Monofásica (gMonoDif)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifIBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_ibs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vIBSMonoDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_mono_dif,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:pDifCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_dif_cbs_mono,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:gMonoDif/new:vCBSMonoDif/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_mono_dif,
			    -- UB104/UB105 - Totais Monofásica
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotIBSMonoItem/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_tot_ibs_mono_item,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gIBSCBSMono/new:vTotCBSMonoItem/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_tot_cbs_mono_item,
			    -- UB107/UB108 - Grupo Transferências de Crédito (gTransfCred)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gTransfCred/new:vIBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_trans_cred,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gTransfCred/new:vCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_trans_cred,
			    -- UB113/UB114/UB115 - Grupo Ajuste de Competência (gAjusteCompet)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:competApur/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(7) AS compet_apur_ajuste_compet,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vIBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_ajuste_compet,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gAjusteCompet/new:vCBS/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_ajuste_compet,
			    -- UB117/UB118 - Grupo Estorno de Crédito (gEstornoCred)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gEstornoCred/new:vIBSEstCred/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_ibs_est_cred,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gEstornoCred/new:vCBSEstCred/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cbs_est_cred,
			    -- UB121/UB122 - Grupo Crédito Presumido da Operação (gCredPresOper)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:vBCCredPres/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_bc_cred_pres,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:cCredPres/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(2) AS c_cred_pres,
			    -- UB124/UB125/UB126 - Grupo Crédito Presumido IBS (gIBSCredPres)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:pCredPres/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPres/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gIBSCredPres/new:vCredPresCondSus/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_ibs,
			    -- UB128/UB129/UB130 - Grupo Crédito Presumido CBS (gCBSCredPres)
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:pCredPres/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,4) AS p_cred_pres_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPres/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cbs,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresOper/new:gCBSCredPres/new:vCredPresCondSus/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_cond_sus_cbs,
			    -- UB132/UB133/UB134 - Grupo Crédito Presumido IBS ZFM (gCredPresIBSZFM)
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:competApur/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(7) AS compet_apur_ibs_zfm,
			    (xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:tpCredPresIBSZFM/text()',
			           _xml_content, _nfe_namespaces))[1]::VARCHAR(1) AS tp_cred_pres_ibs_zfm,
			    ((xpath('/new:det/new:imposto/new:IBSCBS/new:gCredPresIBSZFM/new:vCredPresIBSZFM/text()',
			            _xml_content, _nfe_namespaces))[1]::TEXT)::NUMERIC(15,2) AS v_cred_pres_ibs_zfm
			FROM (SELECT 1) AS _dummy
		) AS a
		WHERE
			a.cst IS NOT NULL
	);
	/* FIM INSERT nfe.ub12_ibs_cbs */
	GET DIAGNOSTICS _records_processed = ROW_COUNT;
	RAISE INFO '[loop_i01_prod] item %: ub12_ibs_cbs: % registros', r_i01_prod.n_item, _records_processed;

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
	RAISE INFO '[loop_i01_prod] item %: ncm cad_produtos: % registros', r_i01_prod.n_item, _records_processed;
END LOOP;
RAISE INFO '[%] Loop i01_prod concluído', _step_name;
/* FIM LOOP TABLE i01_prod */

/* INSERT TABLE nfe.w02_icms_tot */	
_step_name := 'insert_w02_icms_tot';
RAISE INFO '[%] Iniciando totais ICMS', _step_name;
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
	RAISE INFO '[%] Processado w02_icms_tot: % registros', _step_name, _records_processed;
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
	RAISE INFO '[%] Processado w17_issqn_tot: % registros', _step_name, _records_processed;
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
	RAISE INFO '[%] Processado w23_ret_trib: % registros', _step_name, _records_processed;
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
	RAISE INFO '[%] Processado z01_inf_adic: % registros, id=%', _step_name, _records_processed, _id_inf_adic;
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
RAISE INFO '[%] Processado pr03_inf_prot: % registros', _step_name, _records_processed;
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
RAISE INFO '[%] Processado y07_dup: % registros', _step_name, _records_processed;
/* FIM INSERT nfe.y07_dup */

/* INÍCIO LOOP nfe.ya01_pag */
_step_name := 'loop_ya01_pag';
RAISE INFO '[%] Iniciando loop de pagamentos', _step_name;
IF EXISTS (SELECT 1 FROM nfe.ya01_pag WHERE id_nfe = _id_nfe) THEN
	RAISE INFO '[%] Pagamentos já existem para id_nfe %, pulando loop', _step_name, _id_nfe;
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
	RAISE INFO '[loop_ya01_pag] pos %: ya01_pag inserido, id_pag=%', r_ya01_pag.idx_pag, _id_pag;
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
	RAISE INFO '[loop_ya01_pag] pos %: ya04_card: % registros', r_ya01_pag.idx_pag, _records_processed;
	/* FIM INSERT nfe.ya04_card */
END LOOP;
END IF; -- fim guard ya01_pag
RAISE INFO '[%] Loop ya01_pag concluído', _step_name;
/* FIM LOOP TABLE ya01_pag */

/* INSERT TABLE ncm_helper.cad_produtos */
_step_name := 'insert_ncm_cad_produtos';
RAISE INFO '[%] Iniciando cad_produtos pós-loop', _step_name;
insert into ncm_helper.cad_produtos (id_empresa, codg_produto, codg_barra, ncm, cest, descricao)
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
RAISE INFO '[%] Processado ncm cad_produtos pós-loop: % registros', _step_name, _records_processed;

/* INSERT TABLE ncm_helper.cad_produtos_ocorrencia */
_step_name := 'insert_ncm_cad_produtos_ocorrencia';
RAISE INFO '[%] Iniciando cad_produtos_ocorrencia', _step_name;
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
RAISE INFO '[%] Processado sf.resumo_nota_propria: % registros', _step_name, _records_processed;

/* UPDATE COD_CTA nfe.i01_prod */
_step_name := 'update_cod_cta_mod65';
RAISE INFO '[%] Iniciando update cod_cta mod 65 (NFCe)', _step_name;
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
GET DIAGNOSTICS _records_processed = ROW_COUNT;
RAISE INFO '[%] Processado update cod_cta mod 65: % registros', _step_name, _records_processed;

_step_name := 'update_cod_cta_mod55';
RAISE INFO '[%] Iniciando update cod_cta mod 55 (NFe)', _step_name;
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
GET DIAGNOSTICS _records_processed = ROW_COUNT;
RAISE INFO '[%] Processado update cod_cta mod 55: % registros', _step_name, _records_processed;
	
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
$BODY$;

ALTER FUNCTION xml.desestruturar_xml_nfe_nfce(bigint, boolean)
    OWNER TO dorcilio;
