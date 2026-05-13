-- =============================================================================
-- FUNCTION: xml.fn_validate_and_store_xml
-- SCHEMA:   xml
-- DESCRIPTION:
--   Validates a NF-e / NFC-e XML document and stores it in xml.xml_storage
--   when all checks pass. emission_year and emission_month are filled
--   automatically by the trigger tr_set_xml_storage_emission_year.
--
-- Parameters:
--   _est_id        — UUID of the establishment (used for participant validation).
--   _import_job_id — UUID of the import job for traceability. NULL is allowed
--                    (single-file imports may not belong to a batch job).
--   _xml_content   — Full XML document of the NF-e or NFC-e.
--
-- Validations (all evaluated independently before insert):
--   1. invalid_ch_nf       — ch_nf is NULL or does not have exactly 44 digits.
--   2. invalid_model       — NF model (//ide/mod) is not "55" (NF-e) or "65" (NFC-e).
--   3. duplicate_import    — ch_nf already exists in xml.xml_storage.
--                            Returns existing xml_id and ch_nf so the client can
--                            reference the stored record if needed.
--   4. invalid_participant — neither the emitente nor the destinatário document
--                            matches the document of the establishment (_est_id).
--
-- Returns JSONB:
--   Success → { "inserted": true,  "xml_id": 123, "ch_nf": "35240712345..." }
--   Failure → { "inserted": false, "errors": { ... } }
--
-- Error object fields:
--   duplicate_import    BOOLEAN  — XML already stored.
--   xml_id              BIGINT?  — Existing xml_id (populated only when duplicate_import = true).
--   ch_nf               TEXT?    — Existing ch_nf  (populated only when duplicate_import = true).
--   invalid_participant BOOLEAN  — Establishment is not emitente nor destinatário of the XML.
--   invalid_model       BOOLEAN  — Model is not 55 or 65.
--   invalid_ch_nf       BOOLEAN  — ch_nf is NULL or not 44 digits.
-- =============================================================================

-- DROP FUNCTION IF EXISTS xml.fn_validate_and_store_xml(UUID, UUID, XML);

CREATE OR REPLACE FUNCTION xml.fn_validate_and_store_xml(
    _est_id        UUID,
    _import_job_id UUID DEFAULT NULL,
    _xml_content   XML  DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
    _ns TEXT[][] := ARRAY[ARRAY['x', 'http://www.portalfiscal.inf.br/nfe']];

    _ch_nf         VARCHAR(44);
    _emit_cpf_cnpj VARCHAR(14);
    _emit_ie       VARCHAR(15);
    _dest_cpf_cnpj VARCHAR(14);
    _dest_ie       VARCHAR(15);
    _nf_model      TEXT;

    _est_document    VARCHAR(14);
    _existing_xml_id BIGINT;
    _new_xml_id      BIGINT;

    _err_duplicate_import    BOOLEAN := FALSE;
    _err_invalid_participant BOOLEAN := FALSE;
    _err_invalid_model       BOOLEAN := FALSE;
    _err_invalid_ch_nf       BOOLEAN := FALSE;
BEGIN

    -- ------------------------------------------------------------------
    -- 1. Resolve establishment document for participant validation
    -- ------------------------------------------------------------------
    SELECT document INTO _est_document
    FROM partner.establishments
    WHERE est_id = _est_id;

    -- Establishment not found → treat as invalid participant right away
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'inserted', FALSE,
            'errors', jsonb_build_object(
                'duplicate_import',    FALSE,
                'xml_id',              NULL,
                'ch_nf',               NULL,
                'invalid_participant', TRUE,
                'invalid_model',       FALSE,
                'invalid_ch_nf',       FALSE
            )
        );
    END IF;

    -- ------------------------------------------------------------------
    -- 2. Extract key fields from XML via XPath
    -- ------------------------------------------------------------------
    _ch_nf := NULLIF(
        regexp_replace(
            COALESCE((xpath('//x:infNFe/@Id', _xml_content, _ns))[1]::TEXT, ''),
            '[^0-9]', '', 'g'
        ),
        ''
    );

    _emit_cpf_cnpj := COALESCE(
        NULLIF((xpath('//x:emit/x:CNPJ/text()', _xml_content, _ns))[1]::TEXT, ''),
        NULLIF((xpath('//x:emit/x:CPF/text()',  _xml_content, _ns))[1]::TEXT, '')
    );
    _emit_ie := NULLIF((xpath('//x:emit/x:IE/text()', _xml_content, _ns))[1]::TEXT, '');

    _dest_cpf_cnpj := COALESCE(
        NULLIF((xpath('//x:dest/x:CNPJ/text()', _xml_content, _ns))[1]::TEXT, ''),
        NULLIF((xpath('//x:dest/x:CPF/text()',  _xml_content, _ns))[1]::TEXT, '')
    );
    _dest_ie := NULLIF((xpath('//x:dest/x:IE/text()', _xml_content, _ns))[1]::TEXT, '');

    _nf_model := NULLIF((xpath('//x:ide/x:mod/text()', _xml_content, _ns))[1]::TEXT, '');

    -- ------------------------------------------------------------------
    -- 3. Validate ch_nf (must be exactly 44 numeric digits)
    -- ------------------------------------------------------------------
    IF _ch_nf IS NULL OR length(_ch_nf) <> 44 THEN
        _err_invalid_ch_nf := TRUE;
    END IF;

    -- ------------------------------------------------------------------
    -- 4. Validate NF model (55 = NF-e, 65 = NFC-e)
    -- ------------------------------------------------------------------
    IF _nf_model IS NULL OR _nf_model NOT IN ('55', '65') THEN
        _err_invalid_model := TRUE;
    END IF;

    -- ------------------------------------------------------------------
    -- 5. Check for duplicate import (only when ch_nf is valid)
    -- ------------------------------------------------------------------
    IF NOT _err_invalid_ch_nf THEN
        SELECT xml_id INTO _existing_xml_id
        FROM xml.xml_storage
        WHERE ch_nf = _ch_nf
        LIMIT 1;

        IF FOUND THEN
            _err_duplicate_import := TRUE;
        END IF;
    END IF;

    -- ------------------------------------------------------------------
    -- 6. Validate participant
    --    The establishment document must match either emitente or destinatário.
    -- ------------------------------------------------------------------
    IF _est_document IS DISTINCT FROM _emit_cpf_cnpj
       AND _est_document IS DISTINCT FROM _dest_cpf_cnpj
    THEN
        _err_invalid_participant := TRUE;
    END IF;

    -- ------------------------------------------------------------------
    -- 7. Return detailed error if any validation failed
    -- ------------------------------------------------------------------
    IF _err_duplicate_import OR _err_invalid_participant
       OR _err_invalid_model OR _err_invalid_ch_nf
    THEN
        RETURN jsonb_build_object(
            'inserted', FALSE,
            'errors', jsonb_build_object(
                'duplicate_import',    _err_duplicate_import,
                'xml_id',              CASE WHEN _err_duplicate_import THEN _existing_xml_id ELSE NULL END,
                'ch_nf',               CASE WHEN _err_duplicate_import THEN _ch_nf           ELSE NULL END,
                'invalid_participant', _err_invalid_participant,
                'invalid_model',       _err_invalid_model,
                'invalid_ch_nf',       _err_invalid_ch_nf
            )
        );
    END IF;

    -- ------------------------------------------------------------------
    -- 8. Insert the XML
    --    emission_year and emission_month are computed by
    --    trigger tr_set_xml_storage_emission_year (BEFORE INSERT).
    -- ------------------------------------------------------------------
    INSERT INTO xml.xml_storage (
        ch_nf,
        cpf_cnpj,
        ie,
        dest_cpf_cnpj,
        dest_ie,
        xml_content,
        import_job_id
    ) VALUES (
        _ch_nf,
        _emit_cpf_cnpj,
        _emit_ie,
        _dest_cpf_cnpj,
        _dest_ie,
        _xml_content,
        _import_job_id
    )
    RETURNING xml_id INTO _new_xml_id;

    -- ------------------------------------------------------------------
    -- 9. Return success
    -- ------------------------------------------------------------------
    RETURN jsonb_build_object(
        'inserted', TRUE,
        'xml_id',   _new_xml_id,
        'ch_nf',    _ch_nf
    );

END;
$$;

ALTER FUNCTION xml.fn_validate_and_store_xml(UUID, UUID, XML) OWNER TO dorcilio;

COMMENT ON FUNCTION xml.fn_validate_and_store_xml(UUID, UUID, XML) IS
    'Validates and stores a NF-e/NFC-e XML document in xml.xml_storage. '
    'Validations: ch_nf integrity (44 digits), NF model (55/65), duplicate import '
    '(returns existing xml_id and ch_nf), and participant match via est_id against '
    'partner.establishments. Returns JSONB: inserted=true with xml_id on success, '
    'or inserted=false with a detailed error flags object on failure.';


SELECT xml.fn_validate_and_store_xml(
	<_est_id uuid>,
	<_import_job_id uuid>,
	<_xml_content xml>
)