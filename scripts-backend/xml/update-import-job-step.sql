-- ============================================================================
-- Arquivo: update-import-job-step.sql
-- Operação: UPDATE
-- Schema/Tabela: xml.import_job_step
-- Descrição: Atualiza parcialmente o status e contadores de uma etapa.
--            Usa COALESCE para preservar valores quando NULL é passado,
--            permitindo atualizações parciais.
--
-- Parâmetros:
--   $1 - step_id (UUID) - ID da etapa (obrigatório)
--   $2 - step_status (TEXT) - Novo status (PENDING|RUNNING|COMPLETED|FAILED|SKIPPED)
--   $3 - total_count (INT) - Total de documentos desta etapa
--   $4 - success_count (INT) - Quantidade de sucessos acumulados
--   $5 - error_count (INT) - Quantidade de erros acumulados
--   $6 - started_at (TIMESTAMPTZ) - Momento de início da etapa
--   $7 - completed_at (TIMESTAMPTZ) - Momento de conclusão da etapa
--   $8 - step_message (TEXT) - Mensagem descritiva do resultado
--   $9 - step_metadata (JSONB) - Metadados adicionais da etapa
--
-- Retorno: Registro atualizado da etapa (step_id, job_id, step_order, etc.)
-- ============================================================================
UPDATE xml.import_job_step
SET
    step_status   = COALESCE($2, step_status),
    total_count   = COALESCE($3, total_count),
    success_count = COALESCE($4, success_count),
    error_count   = COALESCE($5, error_count),
    started_at    = COALESCE($6, started_at),
    completed_at  = COALESCE($7, completed_at),
    step_message  = COALESCE($8, step_message),
    step_metadata = COALESCE($9::jsonb, step_metadata)
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
