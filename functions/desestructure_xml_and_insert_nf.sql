CREATE FUNCTION xml.desestructure_xml_and_insert_nf(_xml_id bigint, substituir boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	_ch_nf VARCHAR(44);
	has_nf_ref INTEGER := 0;
	row_i01_prod RECORD;
	_id_inf_adic INTEGER;
	xml_ya01_det_pag XML;
	_id_det_pag INTEGER;
begin
/*
	BEGIN;

	SELECT * FROM xml.desestruturar_xml_nfe_nfce(553, true);

	COMMIT;
	
	SELECT * FROM xml.nfe_nfce AS a WHERE ch_nf = '51250202003402002461550120004637671004760987'
*/

/* REMOVER ANTERIOR SE EXISTIR */
SELECT ch_nf INTO _ch_nf FROM nota_fiscal.b01_ide WHERE xml_id = _xml_id;
IF _ch_nf IS NOT NULL THEN
	IF substituir IS TRUE THEN
		DELETE FROM nota_fiscal.b01_ide WHERE ch_nf = _ch_nf;
	ELSE
		RETURN;
	END IF;
END IF;

/* INICIO nota_fiscal.b01_ide | NV0 | PAI: */
WITH b01_ide AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS emit_cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS emit_cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS emit_ie,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS num_doc,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS ser,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dest_cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dest_cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS dest_ie,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cod_mod,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cUF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS cod_uf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:natOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS nat_oper,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:detPag/new:indPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pag,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_doc,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_e_s,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_nf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cMunFG/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(7) AS cod_mun,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpImp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_imp,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpEmis/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_emis,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:cDV/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_dv,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:tpAmb/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_amb,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:finNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS fin_nfe,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:procEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS proc_emi,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:verProc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(20) AS ver_proc,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhCont/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::TIMESTAMP WITH TIME ZONE AS dh_cont,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:xJust/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_just,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::TIMESTAMP WITH TIME ZONE AS dh_emi,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:dhSaiEnt/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::TIMESTAMP WITH TIME ZONE AS dh_sai_ent,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:idDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS id_dest,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indFinal/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_final,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:indPres/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pres
    FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
INSERT INTO nota_fiscal.b01_ide (
		xml_id,
		ch_nf,
		cpf_cnpj,
		ie,
		num_doc,
		ser,
		cod_mod,
		dest_cpf_cnpj,
		dest_ie,
		cod_uf,
		nat_oper,
		ind_pag,
		dt_doc,
		dt_e_s,
		tp_nf,
		cod_mun,
		tp_imp,
		tp_emis,
		c_dv,
		tp_amb,
		fin_nfe,
		proc_emi,
		ver_proc,
		dh_cont,
		x_just,
		dh_emi,
		dh_sai_ent,
		id_dest,
		ind_final,
		ind_pres
	)
	(
		SELECT
			_xml_id AS xml_id,
			ch_nf,
			COALESCE(emit_cnpj, emit_cpf) AS cpf_cnpj,
			emit_ie AS ie,
			num_doc,
			ser,
			cod_mod,
			COALESCE(dest_cnpj, dest_cpf) AS dest_cpf_cnpj,
			dest_ie,
			cod_uf,
			nat_oper,
			ind_pag,
			dt_doc,
			dt_e_s,
			tp_nf,
			cod_mun,
			tp_imp,
			tp_emis,
			c_dv,
			tp_amb,
			fin_nfe,
			proc_emi,
			ver_proc,
			dh_cont,
			x_just,
			dh_emi,
			dh_sai_ent,
			id_dest,
			ind_final,
			ind_pres
		FROM
			b01_ide
	);
/* FIM nota_fiscal.b01_ide | NV0 | PAI: */

/* BUSCAR QUANTIDADE NF REF */
SELECT
	COALESCE(array_length((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']])), 1), 0)
INTO
	has_nf_ref
FROM
	xml.nfe_nfce a
WHERE
	a.xml_id = _xml_id;

IF has_nf_ref > 0 THEN
	/* INICIO nota_fiscal.b12a_nf_ref | NV1 | PAI: nota_fiscal.b01_ide */
    WITH b12a_nf_ref AS
    (
        SELECT
			regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
			UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(44) AS ref_nfe,
			UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:NFref/new:refCTe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(44) AS ref_cte
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
    )
    INSERT INTO nota_fiscal.b12a_nf_ref (
		ch_nf,
		ref_nfe,
		ref_cte
	)
	(
		SELECT
            ch_nf,
            ref_nfe,
            ref_cte
        FROM
            b12a_nf_ref
	);
	/* FIM nota_fiscal.b12a_nf_ref | NV1 | PAI: nota_fiscal.b01_ide */
END IF;

/* INICIO nota_fiscal.c01_emit_c05_ender | NV1 | PAI: nota_fiscal.b01_ide */
WITH c01_emit_c05_ender AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS emit_cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS emit_cpf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS ie,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS nome,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:xFant/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS fantasia,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IEST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS iest,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:IM/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS im,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CNAE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cnae,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:CRT/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS crt,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS "end",
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS num,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS compl,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS bairro,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS cod_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_mun,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(8) AS cep,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS cod_pais,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:xPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_pais,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:emit/new:enderEmit/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS fone
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
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
	(
        SELECT
            ch_nf,
            COALESCE(emit_cnpj, emit_cpf) AS cpf_cnpj,
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
        FROM
            c01_emit_c05_ender
	);
/* FIM nota_fiscal.c01_emit_c05_ender | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.e01_dest_e05_ender | NV1 | PAI: nota_fiscal.b01_ide */
WITH e01_dest_e05_ender AS
(
    SELECT
        regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dest_cnpj,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:CPF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dest_cpf,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS ie,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xNome/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS nome,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:xFant/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS fantasia,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:idEstrangeiro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS id_estrangeiro,
        ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:indIEDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_ie_dest,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:isuf/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(9) AS isuf,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:IM/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS im,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:email/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS email,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xLgr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS "end",
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:nro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS num,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS compl,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xBairro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS bairro,
        ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS cod_mun,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xMun/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_mun,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:CEP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(8) AS cep,
        ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:cPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS cod_pais,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:xPais/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_pais,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:dest/new:enderDest/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS fone
    FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
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
(
    SELECT
        ch_nf,
        COALESCE(dest_cnpj, dest_cpf) AS cpf_cnpj,
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
    FROM
        e01_dest_e05_ender
    WHERE
        dest_cnpj IS NOT NULL OR dest_cpf IS NOT NULL
);
/* FIM nota_fiscal.e01_dest_e05_ender | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.d01_avulsa | NV1 | PAI: nota_fiscal.b01_ide */
WITH d01_avulsa AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xOrgao/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_orgao,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:matr/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS matr,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:xAgente/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS descr_agente,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:fone/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS fone,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:UF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:nDAR/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS n_dar,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_doc,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:vDAR/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15, 2) AS v_dar,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:repEmi/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS rep_emi,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:avulsa/new:dPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_pag
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
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
	(
		SELECT
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
        FROM
            d01_avulsa
        WHERE
            cnpj IS NOT NULL
	);
/* INICIO nota_fiscal.d01_avulsa | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO LOOP nota_fiscal.i01_prod | NV1 | PAI: nota_fiscal.b01_ide */
FOR row_i01_prod IN
(
	SELECT
		a.ch_nf,
        a.num_item,
        a.cod_item,
        a.num_doc,
        a.ser,
        a.cod_mod,
        a.descr_item,
        a.cod_ncm,
        a.ex_tipi,
        a.cfop,
        a.unid,
        a.v_item,
        a.unid_trib,
        a.v_frt,
        a.v_seg,
        a.v_desc,
        a.v_outro,
        a.ind_tot,
        a.x_ped,
        a.num_item_ped,
        a.v_unit,
        a.v_unit_trib,
        a.qtd,
        a.qtd_trib,
        a.n_fci,
        a.nve,
        a.cest,
        a.cod_barra,
        a.cod_barra_not_gtin,
        a.cod_barra_trib,
        a.cod_barra_trib_not_gtin,
        a.inf_ad_prod,
        a.ind_escala,
        a.cnpj_fab,
        a.c_benef,
		a.v_tot_trib
	FROM 
	(
		SELECT
            regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/@nItem', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(3) AS num_item,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS cod_item,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:nNF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INTEGER AS num_doc,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:serie/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS ser,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:ide/new:mod/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cod_mod,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:xProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT AS descr_item,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:NCM/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(10) AS cod_ncm,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:EXTIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(3) AS ex_tipi,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:CFOP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::INTEGER AS cfop,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:uCom/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(10) AS unid,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS v_item,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:uTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(10) AS unid_trib,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vFrete/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS v_frt,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vSeg/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS v_seg,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vDesc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS v_desc,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vOutro/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS v_outro,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:indTot/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::INTEGER AS ind_tot,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:xPed/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(15) AS x_ped,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:nItemPed/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(15) AS num_item_ped,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vUnCom/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(32) AS v_unit,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:vUnTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(32) AS v_unit_trib,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:qCom/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS qtd,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:qTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC AS qtd_trib,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:nFCI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT AS n_fci,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:NVE/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(10) AS nve,
            (UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:CEST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::BIGINT AS cest,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cEAN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cod_barra,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cBarra/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cod_barra_not_gtin,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cEANTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cod_barra_trib,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cBarraTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cod_barra_trib_not_gtin,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:infAdProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(500) AS inf_ad_prod,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:indEscala/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(1) AS ind_escala,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:CNPJFab/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(14) AS cnpj_fab,
            UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:det/new:prod/new:cBenef/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(10) AS c_benef,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:imposto/new:vTotTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_trib
        	--((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ICMSTot/new:vTotTrib/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_tot_trib
		FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	) AS a
	WHERE 
		a.cod_item IS NOT NULL
) LOOP
	/* INICIO nota_fiscal.i01_prod | NV1 | PAI: nota_fiscal.b01_ide */
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
	)
	(
		SELECT
			row_i01_prod.ch_nf,
			row_i01_prod.num_item,
			row_i01_prod.cod_item,
			row_i01_prod.num_doc,
			row_i01_prod.ser,
			row_i01_prod.cod_mod,
			row_i01_prod.descr_item,
			COALESCE(row_i01_prod.cod_ncm, '') AS cod_ncm,
			COALESCE(row_i01_prod.ex_tipi, '') AS ex_tipi,
			row_i01_prod.cfop,
			row_i01_prod.unid,
			row_i01_prod.v_item,
			row_i01_prod.unid_trib,
			COALESCE(row_i01_prod.v_frt::NUMERIC, 0.00)::NUMERIC(18,2) AS v_frt,
			COALESCE(row_i01_prod.v_seg::NUMERIC, 0.00)::NUMERIC(18,2) AS v_seg,
			COALESCE(row_i01_prod.v_desc::NUMERIC(18,2), 0.00)::NUMERIC(18,2) AS v_desc,
			COALESCE(row_i01_prod.v_outro::NUMERIC, 0.00)::NUMERIC(18,2) AS v_outro,
			row_i01_prod.ind_tot,
			row_i01_prod.x_ped,
			row_i01_prod.num_item_ped,
			row_i01_prod.v_unit,
			COALESCE(row_i01_prod.v_unit_trib::NUMERIC, 0.00)::NUMERIC(18,2) AS v_unit_trib,
			row_i01_prod.qtd,
			COALESCE(row_i01_prod.qtd_trib::NUMERIC, 0.00)::numeric(18,3) AS qtd_trib,
			COALESCE(row_i01_prod.n_fci, '') AS n_fci,
			COALESCE(row_i01_prod.nve, '') AS nve,
			row_i01_prod.cest,
			CASE WHEN row_i01_prod.cod_barra = 'SEM GTIN' OR row_i01_prod.cod_barra IS NULL THEN
				''::TEXT
			ELSE
				row_i01_prod.cod_barra
			END AS cod_barra,
			row_i01_prod.cod_barra_not_gtin,
			CASE WHEN row_i01_prod.cod_barra_trib = 'SEM GTIN' OR row_i01_prod.cod_barra_trib IS NULL THEN
				''::TEXT
			ELSE
				row_i01_prod.cod_barra_trib
			END AS cod_barra_trib,
			row_i01_prod.cod_barra_trib_not_gtin,
			row_i01_prod.inf_ad_prod,
			row_i01_prod.ind_escala,
			row_i01_prod.cnpj_fab,
			row_i01_prod.c_benef,
            row_i01_prod.v_tot_trib
	);
	/* FIM nota_fiscal.i01_prod | NV1 | PAI: nota_fiscal.b01_ide */

	/* INICIO nota_fiscal.n01_icms | NV2 | PAI: nota_fiscal.i01_prod */
	WITH n01_icms AS
	(
		SELECT
            regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:orig/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS orig,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS cst,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:CSOSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS cso_sn,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pCredSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_cred_sn,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:modBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mod_bc,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:modBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mod_bc_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pMVAST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_mva_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pICMSST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSDeson/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_deson,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:motDesICMS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS mot_des_icms,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_op,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pDif/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_dif,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSDif/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_dif,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_ret,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_ret,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pBCOp/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_bc_op,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:UFST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCSTDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_st_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSTDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_st_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vCredICMSSN/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cred_icms_sn,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vFCP/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vFCPST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_st_ret,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_fcp_st_ret,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vFCPSTRet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_st_ret,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSSubstituto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_substituto,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pRedBCEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_red_bc_efet,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vBCEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_efet,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:pICMSEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS p_icms_efet,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMS/new:*/new:vICMSEfet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_efet
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
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
	(
		SELECT
            ch_nf,
            num_item,
            orig,
            LPAD(cst, '3', '0') AS cst,
            LPAD(cso_sn, '3', '0') AS cso_sn,
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
            n01_icms
        WHERE
            orig IS NOT NULL
	);
	/* FIM nota_fiscal.n01_icms | NV2 | PAI: nota_fiscal.i01_prod */

	/* INICIO nota_fiscal.o01_ipi | NV2 | PAI: nota_fiscal.i01_prod */
	WITH o01_ipi AS
	(
		SELECT
			regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:clEnq/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(5) AS cl_enq,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:CNPJProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj_prod,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:cSelo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS c_selo,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:qSelo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(12) AS q_selo,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:cEnq/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(3) AS c_enq,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cst,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:pIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_ipi,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:vIPI/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:qUnid/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS q_unid,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:IPI/new:*/new:vUnid/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS v_unid
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
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
	(
		SELECT
            ch_nf,
            num_item,
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
            o01_ipi
        WHERE
            cst IS NOT NULL
	);
	/* FIM nota_fiscal.o01_ipi | NV2 | PAI: nota_fiscal.i01_prod */

	/* INICIO nota_fiscal.p01_ii | NV2 | PAI: nota_fiscal.i01_prod */
    WITH p01_ii AS
    (
        SELECT
            regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:II/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:II/new:vDespAdu/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_desp_adu,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:II/new:vII/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ii,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:II/new:vIOF/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_iof
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
    )
    INSERT INTO nota_fiscal.p01_ii (
		ch_nf,
		num_item,
		v_bc,
		v_desp_adu,
		v_ii,
		v_iof
	)
	(
		SELECT
            ch_nf,
            num_item,
            COALESCE(v_bc, 0.00) AS v_bc,
            COALESCE(v_desp_adu, 0.00) AS v_desp_adu, 
            COALESCE(v_ii, 0.00) AS v_ii, 
            COALESCE(v_iof, 0.00) AS v_iof
        FROM
            p01_ii
        WHERE
            v_bc IS NOT NULL
	);
	/* FIM nota_fiscal.p01_ii | NV2 | PAI: nota_fiscal.i01_prod */

	/* INICIO nota_fiscal.q01_pis_s01_cofins | NV2 | PAI: nota_fiscal.i01_prod */
	WITH q01_pis_s01_cofins AS
	(
		SELECT
			regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS cst_pis,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_pis,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:pPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS aliq_pis,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:vPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:qBCProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS quant_bc_pis,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:PIS/new:*/new:vAliqProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS aliq_pis_quant,
            (xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:CST/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS cst_cofins,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_cofins,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:pCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS aliq_cofins,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:vCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:qBCProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(16,4) AS quant_bc_cofins,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:COFINS/new:*/new:vAliqProd/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,4) AS aliq_cofins_quant
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
	)
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
	(
		SELECT
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
        FROM
            q01_pis_s01_cofins
        WHERE
            cst_pis IS NOT NULL OR cst_cofins IS NOT NULL
	);
	/* FIM nota_fiscal.q01_pis_s01_cofins | NV2 | PAI: nota_fiscal.i01_prod */

	/* INICIO nota_fiscal.ua01_imposto_devol_ua03_ipi | NV2 / NV3 | PAI: nota_fiscal.i01_prod */
    WITH ua01_imposto_devol_ua03_ipi AS
    (
        SELECT
            regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:impostoDevol/new:pDevol/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_devol,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:impostoDevol/new:IPI/new:vIPIDevol/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_ipi_devol
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
    )
    INSERT INTO nota_fiscal.ua01_imposto_devol_ua03_ipi (
		ch_nf,
		num_item,
		p_devol,
		v_ipi_devol
	)
	(
		SELECT
            ch_nf,
            num_item,
            COALESCE(p_devol, 0.00) AS p_devol,
            COALESCE(v_ipi_devol, 0.00) AS v_ipi_devol
        FROM
            ua01_imposto_devol_ua03_ipi
        WHERE
            p_devol IS NOT NULL
	);
	/* FIM nota_fiscal.ua01_imposto_devol_ua03_ipi | NV2 / NV3 | PAI: nota_fiscal.i01_prod */

    /* INICIO nota_fiscal.na01_icms_uf_dest | NV2 | PAI: nota_fiscal.i01_prod */
    WITH na01_icms_uf_dest AS
    (
        SELECT
            regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
            row_i01_prod.num_item AS num_item,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:vBCUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:vBCFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc_fcp_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:pFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_fcp_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSInter/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:pICMSInterPart/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(5,2) AS p_icms_inter_part,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:vFCPUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_fcp_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:vICMSUFDest/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_dest,
            ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:det[@nItem="'||row_i01_prod.num_item||'"]/new:imposto/new:ICMSUFDest/new:vICMSUFRemet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_icms_uf_remet 
        FROM
			xml.nfe_nfce a
		WHERE
			a.xml_id = _xml_id
    )
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
	(
		SELECT
            ch_nf,
            num_item,
            COALESCE(v_bc_uf_dest, 0.00) AS v_bc_uf_dest, 
            COALESCE(p_fcp_uf_dest, 0.00) AS p_fcp_uf_dest,  
            COALESCE(p_icms_uf_dest, 0.00) AS p_icms_uf_dest,  
            COALESCE(p_icms_inter, 0.00) AS p_icms_inter, 
            COALESCE(p_icms_inter_part, 0.00) AS p_icms_inter_part, 
            COALESCE(v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest, 
            COALESCE(v_icms_uf_dest, 0.00) AS v_icms_uf_dest, 
            COALESCE(v_icms_uf_remet, 0.00) AS v_icms_uf_remet
        FROM
            na01_icms_uf_dest
        WHERE
            v_bc_uf_dest IS NOT NULL
	);
	/* FIM nota_fiscal.na01_icms_uf_dest | NV2 | PAI: nota_fiscal.i01_prod */
END LOOP;
/* FIM LOOP nota_fiscal.i01_prod | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.w02_icms_tot | NV1 | PAI: nota_fiscal.b01_ide */
WITH w02_icms_tot AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
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
)
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
	(
		SELECT
            ch_nf,
            COALESCE(v_bc, 0.00) AS v_bc, 
            COALESCE(v_icms, 0.00) AS v_icms,  
            COALESCE(v_bc_st, 0.00) AS v_bc_st,
            COALESCE(v_st, 0.00) AS v_st,
            COALESCE(v_prod, 0.00) AS v_prod,
            COALESCE(v_frete, 0.00) AS v_frete,
            COALESCE(v_seg, 0.00) AS v_seg,
            COALESCE(v_desc, 0.00) AS v_desc,
            COALESCE(v_ii, 0.00) AS v_ii,
            COALESCE(v_ipi, 0.00) AS v_ipi,
            COALESCE(v_pis, 0.00) AS v_pis,
            COALESCE(v_cofins, 0.00) AS v_cofins,
            COALESCE(v_outro, 0.00) AS v_outro,
            COALESCE(v_nf, 0.00) AS v_nf,
            COALESCE(v_tot_trib, 0.00) AS v_tot_trib,
            COALESCE(v_icms_deson, 0.00) AS v_icms_deson,
            COALESCE(v_fcp_uf_dest, 0.00) AS v_fcp_uf_dest,
            COALESCE(v_icms_uf_dest, 0.00) AS v_icms_uf_dest,
            COALESCE(v_icms_uf_remet, 0.00) AS v_icms_uf_remet,
            COALESCE(v_fcp, 0.00) AS v_fcp,
            COALESCE(v_fcp_st, 0.00) AS v_fcp_st,
            COALESCE(v_fcp_st_ret, 0.00) AS v_fcp_st_ret,
            COALESCE(v_ipi_devol, 0.00) AS v_ipi_devol
        FROM
            w02_icms_tot
	);
/* FIM nota_fiscal.w02_icms_tot | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.w17_issqn_tot | NV1 | PAI: nota_fiscal.b01_ide */
WITH w17_issqn_tot AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
        ((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vServ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_serv,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vBC/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_bc,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vISS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_iss,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vPIS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pis,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:vCOFINS/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_cofins,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:total/new:ISSQNtot/new:dCompet/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_compet,
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
)
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
	(
		SELECT
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
        FROM
            w17_issqn_tot
        WHERE
            dt_compet IS NOT NULL
	);
/* FIM nota_fiscal.w17_issqn_tot | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.w23_ret_trib | NV1 | PAI: nota_fiscal.b01_ide */
WITH w23_ret_trib AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
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
)
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
	(
		SELECT
            ch_nf,
            COALESCE(v_ret_pis, 0.00) AS v_ret_pis, 
            COALESCE(v_ret_cofins, 0.00) AS v_ret_cofins,  
            COALESCE(v_ret_csll, 0.00) AS v_ret_csll,
            COALESCE(v_bc_irrf, 0.00) AS v_bc_irrf,
            COALESCE(v_irrf, 0.00) AS v_irrf,
            COALESCE(v_bc_ret_prev, 0.00) AS v_bc_ret_prev,
            COALESCE(v_ret_prev, 0.00) AS v_ret_prev
        FROM
            w23_ret_trib
        WHERE
            v_ret_pis IS NOT NULL OR v_ret_cofins IS NOT NULL OR v_ret_csll IS NOT NULL OR v_irrf IS NOT NULL
	);
/* FIM nota_fiscal.w23_ret_trib | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.z01_inf_adic | NV1 | PAI: nota_fiscal.b01_ide */
WITH z01_inf_adic AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
        (xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infAdFisco/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2000) AS inf_ad_fisco,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:infCpl/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2000) AS inf_cpl
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
INSERT INTO nota_fiscal.z01_inf_adic (
		ch_nf,
		inf_ad_fisco,
		inf_cpl
	)
	(
		SELECT
            ch_nf,
            inf_ad_fisco,
            inf_cpl
        FROM
            z01_inf_adic
        WHERE
            inf_ad_fisco IS NOT NULL OR inf_cpl IS NOT NULL
	) RETURNING id_inf_adic INTO _id_inf_adic;
	/* TRANSACAO nota_fiscal.z01_inf_adic | NV1 | PAI: nota_fiscal.b01_ide */

	IF _id_inf_adic IS NOT NULL THEN
		/* INICIO nota_fiscal.z04_obs_cont | NV2 | PAI: nota_fiscal.z01_inf_adic */
        WITH z04_obs_cont AS
        (
            SELECT
                regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
                _id_inf_adic AS id_inf_adic,
                UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/@xCampo', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(20) AS x_campo,
                UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsCont/new:xTexto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS x_texto
            FROM
                xml.nfe_nfce a
            WHERE
                a.xml_id = _xml_id
        )
        INSERT INTO nota_fiscal.z04_obs_cont (
            ch_nf,
            id_inf_adic,
            x_campo,
            x_texto
        )
        (
            SELECT
                ch_nf,
                id_inf_adic,
                x_campo,
                x_texto
            FROM
                z04_obs_cont
            WHERE
                x_texto IS NOT NULL
        );
		/* FIM nota_fiscal.z04_obs_cont | NV2 | PAI: nota_fiscal.z01_inf_adic */

		/* INICIO nota_fiscal.z07_obs_fisco | NV2 | PAI: nota_fiscal.z01_inf_adic */
        WITH z07_obs_fisco AS
        (
            SELECT
                regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
                _id_inf_adic AS id_inf_adic,
                UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/@xCampo', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(20) AS x_campo,
                UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:infAdic/new:obsFisco/new:xTexto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS x_texto
            FROM
                xml.nfe_nfce a
            WHERE
                a.xml_id = _xml_id
        )
        INSERT INTO nota_fiscal.z07_obs_fisco (
            ch_nf,
            id_inf_adic,
            x_campo,
            x_texto
        )
        (
            SELECT
                ch_nf,
                id_inf_adic,
                x_campo,
                x_texto
            FROM
                z07_obs_fisco
            WHERE
                x_texto IS NOT NULL
        );
		/* FIM nota_fiscal.z07_obs_fisco | NV2 | PAI: nota_fiscal.z01_inf_adic */
	END IF;
/* FIM nota_fiscal.z01_inf_adic | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.pr03_inf_prot | NV1 | PAI: nota_fiscal.b01_ide */
WITH pr03_inf_prot AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		((xpath('/new:nfeProc/new:protNFe/new:infProt/new:tpAmb/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS tp_amb,
		(xpath('/new:nfeProc/new:protNFe/new:infProt/new:chNFe/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(44) AS ch_nfe,
		((xpath('/new:nfeProc/new:protNFe/new:infProt/new:dhRecbto/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::TIMESTAMP WITH TIME ZONE AS dh_recbto,
		(xpath('/new:nfeProc/new:protNFe/new:infProt/new:nProt/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS n_prot,
		(xpath('/new:nfeProc/new:protNFe/new:infProt/new:digVal/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS dig_val,
		((xpath('/new:nfeProc/new:protNFe/new:infProt/new:cStat/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS c_stat,
		(xpath('/new:nfeProc/new:protNFe/new:infProt/new:xMotivo/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT AS x_motivo
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
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
	(
		SELECT
            ch_nf,
            tp_amb,
            ch_nfe,
            dh_recbto,
            n_prot,
            dig_val,
            c_stat,
            x_motivo
        FROM
            pr03_inf_prot
        WHERE
            c_stat IS NOT NULL
	);
/* FIM nota_fiscal.pr03_inf_prot | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.y07_dup | NV1 | PAI: nota_fiscal.b01_ide */
WITH y07_dup AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:nDup/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::VARCHAR(60) AS n_dup,
		(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:dVenc/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::DATE AS dt_venc,
		(UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:cobr/new:dup/new:vDup/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::TEXT)::NUMERIC(15, 2) AS v_dup
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
INSERT INTO nota_fiscal.y07_dup (
		ch_nf,
		n_dup,
		dt_venc,
		v_dup
	)
	(
		SELECT
            ch_nf,
            n_dup,
            dt_venc,
            v_dup
        FROM
            y07_dup
        WHERE
            v_dup IS NOT NULL
	);
/* FIM nota_fiscal.y07_dup | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO nota_fiscal.ya01_pag | NV1 | PAI: nota_fiscal.b01_ide */
WITH ya01_pag AS
(
	SELECT
		regexp_replace((xpath('/new:nfeProc/new:NFe/new:infNFe/@Id', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT, '[^0-9]+', '', 'g') AS ch_nf,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:CNPJPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(14) AS cnpj_pag,
		(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:UFPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS uf_pag,
		((xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/new:vTroco/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_troco
	FROM
        xml.nfe_nfce a
    WHERE
        a.xml_id = _xml_id
)
INSERT INTO nota_fiscal.ya01_pag (
		ch_nf,
		cnpj_pag,
		uf_pag,
		v_troco
	)
	(
		SELECT
            ch_nf,
            cnpj_pag,
            uf_pag,
            v_troco
        FROM
            ya01_pag
        WHERE
            cnpj_pag IS NOT NULL OR uf_pag IS NOT NULL OR v_troco IS NOT NULL
	);
/* FIM nota_fiscal.ya01_pag | NV1 | PAI: nota_fiscal.b01_ide */

/* INICIO LOOP nota_fiscal.ya01a_det_pag | NV2 / NV3 | PAI: nota_fiscal.b01_ide */
FOR _ch_nf, xml_ya01_det_pag IN
(
	SELECT
        ch_nf,
		node_in_ya01_pag
	FROM
	(
		SELECT
            a.ch_nf,
			UNNEST(xpath('/new:nfeProc/new:NFe/new:infNFe/new:pag/node()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))::XML AS node_in_ya01_pag
		FROM
	        xml.nfe_nfce a
	    WHERE
	        a.xml_id = _xml_id
	) a
	WHERE
		node_in_ya01_pag::TEXT LIKE '%detPag%'
) LOOP
	/* INICIO nota_fiscal.ya01a_det_pag | NV2 | PAI: nota_fiscal.b01_ide */
    WITH ya01a_det_pag AS
    (
        SELECT
            _ch_nf AS ch_nf,
            ((xpath('/new:detPag/new:card/new:indPag/text()', xml_ya01_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::INT AS ind_pag,
            (xpath('/new:detPag/new:card/new:tPag/text()', xml_ya01_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(2) AS t_pag,
            (xpath('/new:detPag/new:card/new:xPag/text()', xml_ya01_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::VARCHAR(60) AS x_pag,
            ((xpath('/new:detPag/new:card/new:vPag/text()', xml_ya01_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::NUMERIC(15,2) AS v_pag,
            ((xpath('/new:detPag/new:card/new:dPag/text()', xml_ya01_det_pag, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[1]::TEXT)::DATE AS dt_pag
    )
    INSERT INTO nota_fiscal.ya01a_det_pag (
		ch_nf,
		ind_pag,
		t_pag,
		x_pag,
		v_pag,
		dt_pag
	)
	(
		SELECT
			ch_nf,
            ind_pag,
            t_pag,
            x_pag,
            v_pag,
            dt_pag
        FROM
            ya01a_det_pag
        WHERE
            v_pag IS NOT NULL
	) RETURNING id_det_pag INTO _id_det_pag;
    /* FIM nota_fiscal.ya01a_det_pag | NV2 | PAI: nota_fiscal.b01_ide */

    IF _id_det_pag IS NOT NULL THEN
        /* INICIO nota_fiscal.ya04_card | NV3 | PAI: nota_fiscal.b01_ide */
        WITH ya04_card AS
        (
            SELECT
                _ch_nf AS ch_nf,
                _id_det_pag AS id_det_pag,
                ((xpath('/new:detPag/new:card/new:tpIntegra/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::TEXT)::INT AS tp_integra,
				(xpath('/new:detPag/new:card/new:CNPJ/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(14) AS cnpj,
				(xpath('/new:detPag/new:card/new:tBand/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(2) AS t_band,
				(xpath('/new:detPag/new:card/new:cAut/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(128) AS c_aut,
				(xpath('/new:detPag/new:card/new:CNPJReceb/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(14) AS cnpj_receb,
				(xpath('/new:detPag/new:card/new:idTermPag/text()', a.xml_file, ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']]))[r_ya01_pag.idx_pag]::VARCHAR(40) AS id_term_pag
        )
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
        (
            SELECT
                id_det_pag,
                ch_nf,
                tp_integra,
                cnpj,
                t_band,
                c_aut,
                cnpj_receb,
                id_term_pag
            FROM
                ya04_card
            WHERE
                tp_integra IS NOT NULL
        );
        /* FIM nota_fiscal.ya04_card | NV3 | PAI: nota_fiscal.b01_ide */
    END IF;
END LOOP;
END;
$$;