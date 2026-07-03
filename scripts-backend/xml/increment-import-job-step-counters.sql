-- ============================================================================
-- Arquivo: increment-import-job-step-counters.sql
-- Operacao: UPDATE
-- Schema/Tabela: xml.import_job_step
-- Descricao: Incrementa contadores de uma etapa de forma atomica.
--
-- Parametros:
--   $1 - step_id (UUID)
--   $2 - success_delta (INT)
--   $3 - error_delta (INT)
--
-- Retorno: Registro atualizado da etapa.
-- ============================================================================
UPDATE xml.import_job_step
SET
    success_count = GREATEST(0, success_count + COALESCE($2, 0)),
    error_count   = GREATEST(0, error_count + COALESCE($3, 0))
WHERE step_id = $1
RETURNING
    step_id,
    job_id,
    step_order,
    step_name,
    step_status,
    total_count,
    success_count,
    error_count,
    started_at,
    completed_at,
    updated_at;
