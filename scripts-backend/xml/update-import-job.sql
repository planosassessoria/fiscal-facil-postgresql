-- ============================================================================
-- Arquivo: update-import-job.sql
-- Operação: UPDATE
-- Schema/Tabela: xml.import_job
-- Descrição: Atualiza parcialmente o status e campos de controle de um job
--            de importação. Usa COALESCE para preservar valores existentes
--            quando NULL é passado (patch parcial).
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job (obrigatório)
--   $2 - job_status (TEXT) - Novo status (PENDING|RUNNING|COMPLETED|PARTIAL|FAILED|CANCELLED)
--   $3 - total_count (INT) - Total de documentos do lote
--   $4 - started_at (TIMESTAMPTZ) - Momento de início do processamento
--   $5 - completed_at (TIMESTAMPTZ) - Momento de conclusão do job
--   $6 - notes (TEXT) - Observações livres
--
-- Retorno: job_id, job_status, total_count, started_at, completed_at,
--          notes, updated_at
-- ============================================================================
UPDATE xml.import_job
SET
    job_status   = COALESCE($2, job_status),
    total_count  = COALESCE($3, total_count),
    started_at   = COALESCE($4, started_at),
    completed_at = COALESCE($5, completed_at),
    notes        = COALESCE($6, notes)
WHERE job_id = $1
RETURNING
    job_id,
    job_status,
    total_count,
    started_at,
    completed_at,
    notes,
    updated_at;
