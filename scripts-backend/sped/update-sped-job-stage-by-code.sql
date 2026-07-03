-- ============================================================================
-- Arquivo: /sped/update-sped-job-stage-by-code.sql
-- Operação: UPDATE
-- Schema/Tabela: sped.sped_job_stages
-- Descrição: Atualiza uma etapa identificada pelo sped_job_id + stage_code.
--            Útil para o consumer que não armazena o sped_job_stage_id.
--
-- Parâmetros:
--   $1  - sped_job_id (BIGINT) - FK do job
--   $2  - stage_code (VARCHAR 60) - Código da etapa
--   $3  - stage_status (VARCHAR 20) - Novo status (nullable)
--   $4  - stage_summary (TEXT) - Resumo (nullable)
--   $5  - stage_payload (JSONB) - Payload técnico (nullable)
--   $6  - started_at (TIMESTAMPTZ) - Timestamp de início (nullable)
--   $7  - finished_at (TIMESTAMPTZ) - Timestamp de término (nullable)
-- ============================================================================
UPDATE sped.sped_job_stages
SET
    stage_status  = COALESCE($3::varchar, stage_status),
    stage_summary = COALESCE($4::text, stage_summary),
    stage_payload = CASE WHEN $5::jsonb IS NOT NULL THEN $5::jsonb ELSE stage_payload END,
    started_at    = COALESCE($6::timestamptz, started_at),
    finished_at   = COALESCE($7::timestamptz, finished_at)
WHERE sped_job_id = $1
  AND stage_code  = $2;
