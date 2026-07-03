-- ============================================================================
-- Arquivo: /sped/select-imported-sped-files.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_files + sped.sped_jobs + sped.sped_records + sped.sped_job_timeline
-- Descrição: Lista arquivos SPED importados para exibição no frontend.
--            Inclui período do 0000 (dt_ini/dt_fin) e último status de timeline.
--            Prioriza status manual (is_system = false); se não houver, traz o último do sistema.
--
-- Parâmetros:
--   $1 - is_root (BOOLEAN)  - Root vê todos os tenants
--   $2 - tenant_id (UUID)   - Filtro de segurança por tenant
--   $3 - est_id (UUID)      - Filtro opcional por estabelecimento
--   Coluna de ordenação     (interpolado via pg_format)
--   Direção da ordenação    (interpolado via pg_format)
--   LIMIT                   (interpolado via pg_format)
--   OFFSET                  (interpolado via pg_format)
-- ============================================================================
SELECT
    f.sped_file_id,
    f.document,
    f.ie,
    f.reference_period,
    to_date(NULLIF(r0000.record_payload->>'dt_ini', ''), 'DDMMYYYY') AS data_inicial,
    to_date(NULLIF(r0000.record_payload->>'dt_fin', ''), 'DDMMYYYY') AS data_final,
    f.layout_version,
    f.source_file_name,
    f.total_lines,
    f.imported_at,
    f.created_at,
    f.updated_at,
    jlast.sped_job_id AS latest_sped_job_id,
    jlast.protocol_code AS latest_protocol_code,
    jlast.workflow_status AS latest_workflow_status,
    tlast.sped_job_id AS timeline_sped_job_id,
    tlast.status_code AS timeline_status_code,
    tlast.status_label_pt AS timeline_status_label_pt,
    tlast.is_system AS timeline_is_system,
    tlast.notes AS timeline_notes,
    tlast.recorded_at AS timeline_recorded_at,
    COUNT(*) OVER () AS rows_number
FROM sped.sped_files f
INNER JOIN LATERAL (
    SELECT j.*
    FROM sped.sped_jobs j
    WHERE j.sped_file_id = f.sped_file_id
      AND (
        $1 = TRUE
        OR j.tenant_id = $2
      )
      AND (
        $3::uuid IS NULL
        OR j.est_id = $3
      )
    ORDER BY j.created_at DESC
    LIMIT 1
) jlast ON TRUE
LEFT JOIN LATERAL (
    SELECT r.record_payload
    FROM sped.sped_records r
    WHERE r.sped_file_id = f.sped_file_id
      AND r.record_code = '0000'
    ORDER BY r.line_number ASC
    LIMIT 1
) r0000 ON TRUE
LEFT JOIN LATERAL (
    SELECT
        t.sped_job_id,
        st.status_code,
        st.status_label_pt,
        st.is_system,
        t.notes,
        t.recorded_at
    FROM sped.sped_job_timeline t
    INNER JOIN sped.sped_job_status_types st ON st.status_id = t.status_id
    WHERE t.document = f.document
      AND t.reference_period = f.reference_period
      AND NULLIF(BTRIM(t.ie), '') IS NOT DISTINCT FROM NULLIF(BTRIM(f.ie), '')
    ORDER BY st.is_system ASC, t.recorded_at DESC
    LIMIT 1
) tlast ON TRUE
WHERE f.imported_at IS NOT NULL
ORDER BY %I %s
LIMIT %L
OFFSET %L;
