-- ============================================================================
-- Arquivo: /sped/update-sped-job.sql
-- Operação: UPDATE
-- Schema/Tabela: sped.sped_jobs
-- Descrição: Atualiza o estado operacional de um job/protocolo SPED.
--            Suporta transições de workflow_status e progresso.
--
-- Parâmetros:
--   $1  - sped_job_id (BIGINT) - PK do job
--   $2  - workflow_status (VARCHAR 40) - Novo status (nullable = sem alteração)
--   $3  - current_stage_code (VARCHAR 60) - Etapa corrente (nullable)
--   $4  - progress_percent (NUMERIC 5,2) - Progresso (nullable)
--   $5  - started_at (TIMESTAMPTZ) - Timestamp de início (nullable)
--   $6  - finished_at (TIMESTAMPTZ) - Timestamp de término (nullable)
--   $7  - last_heartbeat_at (TIMESTAMPTZ) - Último heartbeat (nullable)
--   $8  - job_metadata (JSONB) - Metadados extras (nullable = sem alteração)
-- ============================================================================
UPDATE sped.sped_jobs
SET
    workflow_status    = COALESCE($2::varchar, workflow_status),
    current_stage_code = COALESCE($3::varchar, current_stage_code),
    progress_percent   = COALESCE($4::numeric, progress_percent),
    started_at         = COALESCE($5::timestamptz, started_at),
    finished_at        = COALESCE($6::timestamptz, finished_at),
    last_heartbeat_at  = COALESCE($7::timestamptz, last_heartbeat_at),
    job_metadata       = CASE WHEN $8::jsonb IS NOT NULL THEN $8::jsonb ELSE job_metadata END
WHERE sped_job_id = $1;
