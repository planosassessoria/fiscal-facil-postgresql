-- ============================================================================
-- Arquivo: /sped/select-sped-job-status-type-by-code.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_job_status_types
-- Descrição: Busca um tipo de status do catálogo de roadmap/timeline SPED
--            pelo seu status_code. Retorna NULL se não existir.
--
-- Parâmetros:
--   $1 - status_code (VARCHAR 60) - Código do status (case-insensitive)
--
-- Retorno: status_id, status_code, status_label_pt, is_system, created_at
-- ============================================================================
SELECT
    status_id,
    status_code,
    status_label_pt,
    is_system,
    created_at
FROM sped.sped_job_status_types
WHERE status_code = UPPER($1)
LIMIT 1;
