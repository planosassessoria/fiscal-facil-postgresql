-- ============================================================================
-- Arquivo: /sped/select-sped-file-timeline-by-id.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_files + sped.sped_jobs + sped.sped_job_timeline
-- Descrição: Retorna timeline completa de um arquivo SPED (por sped_file_id)
--            incluindo nome do usuário, status e metadados de exibição.
--
-- Parâmetros:
--   $1 - sped_file_id (BIGINT)
--   $2 - is_root (BOOLEAN)
--   $3 - tenant_id (UUID)
-- ============================================================================
WITH file_scope AS (
    SELECT
        f.sped_file_id,
        f.document,
        f.ie,
        f.reference_period
    FROM sped.sped_files f
    WHERE f.sped_file_id = $1
      AND (
        $2 = TRUE
        OR EXISTS (
            SELECT 1
            FROM sped.sped_jobs j
            WHERE j.sped_file_id = f.sped_file_id
              AND j.tenant_id = $3
        )
      )
)
SELECT
    fs.sped_file_id,
    fs.document,
    fs.ie,
    fs.reference_period,
    t.sped_job_id,
    st.status_code,
    st.status_label_pt,
    st.is_system,
    COALESCE(u.full_name, u.display_name, t.recorded_by_email) AS user_name,
    t.recorded_by_email,
    t.notes,
    t.recorded_at
FROM file_scope fs
INNER JOIN sped.sped_job_timeline t
    ON t.document = fs.document
   AND t.reference_period = fs.reference_period
  AND NULLIF(BTRIM(t.ie), '') IS NOT DISTINCT FROM NULLIF(BTRIM(fs.ie), '')
INNER JOIN sped.sped_job_status_types st ON st.status_id = t.status_id
LEFT JOIN account.users u ON u.email = t.recorded_by_email
ORDER BY t.recorded_at DESC;
