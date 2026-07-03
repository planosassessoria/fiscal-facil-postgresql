-- ============================================================================
-- Arquivo: /sped/insert-sped-job-stage.sql
-- Operação: INSERT
-- Schema/Tabela: sped.sped_job_stages
-- Descrição: Cria uma etapa do pipeline de um job SPED.
--            Cada job possui N etapas com ordem e status próprios.
--
-- Parâmetros:
--   $1  - sped_job_id (BIGINT) - FK para sped.sped_jobs
--   $2  - stage_code (VARCHAR 60) - Chave da etapa (ex: 'IMPORT_UPLOAD')
--   $3  - stage_order (SMALLINT) - Ordem de execução (deve ser > 0)
--   $4  - stage_status (VARCHAR 20) - Status inicial: PENDING | RUNNING
--   $5  - responsible_by_email (VARCHAR 320) - Responsável (nullable)
--   $6  - stage_summary (TEXT) - Resumo descritivo (nullable)
--   $7  - stage_payload (JSONB) - Payload técnico
--
-- Retorno: sped_job_stage_id (BIGINT) - ID interno da etapa criada
-- ============================================================================
INSERT INTO sped.sped_job_stages (
    sped_job_id,
    stage_code,
    stage_order,
    stage_status,
    responsible_by_email,
    stage_summary,
    stage_payload
)
VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7
)
RETURNING sped_job_stage_id;
