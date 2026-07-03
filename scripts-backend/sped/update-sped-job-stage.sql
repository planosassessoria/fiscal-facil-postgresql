-- ============================================================================
-- Arquivo: /sped/update-sped-job-stage.sql
-- Operação: UPDATE
-- Schema/Tabela: sped.sped_job_stages
-- Descrição: Atualiza o status e resultado de uma etapa do pipeline SPED.
--            Usado para transições PENDING→RUNNING, RUNNING→COMPLETED/FAILED/SKIPPED.
--
-- Parâmetros:
--   $1  - sped_job_stage_id (BIGINT) - PK da etapa
--   $2  - stage_status (VARCHAR 20) - Novo status
--   $3  - stage_summary (TEXT) - Resumo do resultado (nullable)
--   $4  - stage_payload (JSONB) - Payload técnico atualizado (nullable)
--   $5  - started_at (TIMESTAMPTZ) - Timestamp de início (nullable)
--   $6  - finished_at (TIMESTAMPTZ) - Timestamp de término (nullable)
-- ============================================================================
UPDATE sped.sped_job_stages
SET
    stage_status      = COALESCE($2::varchar, stage_status),
    stage_summary     = COALESCE($3::text, stage_summary),
    stage_payload     = CASE WHEN $4::jsonb IS NOT NULL THEN $4::jsonb ELSE stage_payload END,
    started_at        = COALESCE($5::timestamptz, started_at),
    finished_at       = COALESCE($6::timestamptz, finished_at)
WHERE sped_job_stage_id = $1;
