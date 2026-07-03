-- ============================================================================
-- Arquivo: /sped/relink-sped-job-timeline.sql
-- Operação: UPDATE
-- Schema/Tabela: sped.sped_job_timeline
-- Descrição: Religa registros históricos com sped_job_id NULL ao novo job
--            durante reimportação da mesma declaração fiscal.
--
-- Parâmetros:
--   $1 - sped_job_id (BIGINT) - novo job criado na reimportação
--   $2 - document (VARCHAR 14) - CPF/CNPJ da declaração
--   $3 - reference_period (DATE) - Período fiscal
--   $4 - ie (VARCHAR 20) - Inscrição estadual (nullable)
-- ============================================================================
UPDATE sped.sped_job_timeline
   SET sped_job_id = $1
 WHERE sped_job_id IS NULL
   AND document = $2
   AND reference_period = $3
   AND NULLIF(BTRIM(ie), '') IS NOT DISTINCT FROM NULLIF(BTRIM($4::varchar), '');
