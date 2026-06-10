-- ============================================================================
-- Arquivo: select-imported-notas.sql
-- Operação: SELECT
-- Schema/Tabela: nota_fiscal.* + xml.xml_storage
-- Descrição: Lista notas fiscais já desestruturadas (schema nota_fiscal) e
--            XMLs armazenados que ainda não foram desestruturados.
--            Para XMLs ainda não desestruturados, campos não presentes na
--            listagem estruturada são retornados como NULL.
--
-- Regras:
--   - Filtro principal por CNPJ/CPF participante (emitente ou destinatário).
--   - Filtro opcional por intervalo de data de emissão.
--   - Busca textual opcional (FTS) sobre chave, documentos e campos principais.
--   - Paginação e ordenação dinâmica via pg-format.
--
-- Parâmetros:
--   $1 - cpf_cnpj_filter (TEXT)       - Documento principal (NULL = sem filtro)
--   $2 - emission_start_date (DATE)    - Data inicial (NULL = sem filtro)
--   $3 - emission_end_date (DATE)      - Data final (NULL = sem filtro)
--   $4 - search_query (TEXT)           - Busca FTS (NULL = sem filtro)
--   Coluna de ordenação (interpolado via pg_format - identificador)
--   Direção da ordenação ASC/DESC (interpolado via pg_format - string)
--   LIMIT (interpolado via pg_format - literal)
--   OFFSET (interpolado via pg_format - literal)
--
-- Retorno:
--   emit_cpf_cnpj, dest_cpf_cnpj, emit_x_nome, dest_x_nome,
--   n_nf, serie, dh_emi, ch_nf, v_prod, v_nf,
--   v_st, xml_id, is_synced, rows_number
-- ============================================================================

WITH synced_nf AS (
    SELECT
        b01.cpf_cnpj                      AS emit_cpf_cnpj,
        b01.dest_cpf_cnpj                 AS dest_cpf_cnpj,
        emit.nome                         AS emit_x_nome,
        dest.nome                         AS dest_x_nome,
        b01.num_doc::text                 AS n_nf,
        b01.ser::text                     AS serie,
        COALESCE(b01.dh_emi, b01.dt_doc::timestamptz) AS dh_emi,
        b01.ch_nf                         AS ch_nf,
        tot.v_prod                        AS v_prod,
        tot.v_nf                          AS v_nf,
        tot.v_st                          AS v_st,
        b01.xml_id                        AS xml_id,
        TRUE                              AS is_synced
    FROM nota_fiscal.b01_ide b01
    LEFT JOIN nota_fiscal.c01_emit_c05_ender emit
        ON emit.ch_nf = b01.ch_nf
    LEFT JOIN nota_fiscal.e01_dest_e05_ender dest
        ON dest.ch_nf = b01.ch_nf
    LEFT JOIN nota_fiscal.w02_icms_tot tot
        ON tot.ch_nf = b01.ch_nf
    WHERE
        ($1::text IS NULL OR b01.cpf_cnpj = $1 OR b01.dest_cpf_cnpj = $1)
),
xml_only AS (
    SELECT
        x.cpf_cnpj AS emit_cpf_cnpj,
        x.dest_cpf_cnpj AS dest_cpf_cnpj,
        NULL::text AS emit_x_nome,
        NULL::text AS dest_x_nome,
        NULL::text AS n_nf,
        NULL::text AS serie,
        NULL::timestamptz AS dh_emi,
        x.ch_nf AS ch_nf,
        NULL::numeric AS v_prod,
        NULL::numeric AS v_nf,
        NULL::numeric AS v_st,
        x.xml_id AS xml_id,
        FALSE AS is_synced
    FROM xml.xml_storage x
    LEFT JOIN nota_fiscal.b01_ide b01
        ON b01.xml_id = x.xml_id
    WHERE
        b01.ch_nf IS NULL
        AND ($1::text IS NULL OR x.cpf_cnpj = $1 OR x.dest_cpf_cnpj = $1)
),
base_data AS (
    SELECT * FROM synced_nf
    UNION ALL
    SELECT * FROM xml_only
)
SELECT
    b.emit_cpf_cnpj,
    b.dest_cpf_cnpj,
    b.emit_x_nome,
    b.dest_x_nome,
    b.n_nf,
    b.serie,
    CASE
        WHEN b.dh_emi IS NULL THEN NULL
        ELSE to_char(b.dh_emi AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    END AS dh_emi,
    b.ch_nf,
    b.v_prod,
    b.v_nf,
    b.v_st,
    b.xml_id,
    b.is_synced,
    COUNT(*) OVER () AS rows_number
FROM base_data b
WHERE
    ($2::date IS NULL OR b.dh_emi::date >= $2::date)
    AND ($3::date IS NULL OR b.dh_emi::date <= $3::date)
    AND (
        $4::text IS NULL
        OR to_tsvector(
            'public.simple_portuguese',
            concat_ws(
                ' ',
                COALESCE(b.ch_nf, ''),
                COALESCE(b.emit_cpf_cnpj, ''),
                COALESCE(b.dest_cpf_cnpj, ''),
                COALESCE(b.emit_x_nome, ''),
                COALESCE(b.dest_x_nome, ''),
                COALESCE(b.n_nf, ''),
                COALESCE(b.serie, '')
            )
        ) @@ to_tsquery('simple', public.fn_format_tsquery($4::text))
    )
ORDER BY
    %I %s NULLS LAST,
    b.dh_emi DESC NULLS LAST
LIMIT
    %L
OFFSET
    %L;