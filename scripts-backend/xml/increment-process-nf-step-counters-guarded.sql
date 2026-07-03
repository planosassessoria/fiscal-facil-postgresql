-- ============================================================================
-- Arquivo: increment-process-nf-step-counters-guarded.sql
-- Operacao: UPDATE
-- Schema/Tabela: xml.import_job_step
-- Descricao:
--   Incrementa contadores do step PROCESS_NF somente quando ainda houver
--   XMLs efetivamente armazenados no STORE_XML para consumir.
--
-- Regras de guarda:
--   1) (process.success_count + process.error_count) < store.success_count
--   2) total_count = 0 OU (process.success_count + process.error_count) < process.total_count
--
-- Isso evita que PROCESS_NF ultrapasse STORE_XML em cenarios de replay/duplicata.
--
-- Parametros:
--   $1 - step_id (UUID) do PROCESS_NF
--   $2 - success_delta (INT)
--   $3 - error_delta (INT)
--
-- Retorno: Registro atualizado da etapa (0 linhas quando bloqueado pela guarda).
-- ============================================================================
WITH target AS (
    SELECT p.step_id
    FROM xml.import_job_step p
    INNER JOIN xml.import_job_step s
      ON s.job_id = p.job_id
     AND s.step_name = 'STORE_XML'
    WHERE p.step_id = $1
      AND p.step_name = 'PROCESS_NF'
      AND (COALESCE(p.success_count, 0) + COALESCE(p.error_count, 0)) < COALESCE(s.success_count, 0)
      AND (
      COALESCE(p.total_count, 0) = 0
      OR (COALESCE(p.success_count, 0) + COALESCE(p.error_count, 0)) < COALESCE(p.total_count, 0)
      )
)
UPDATE xml.import_job_step p
SET
    success_count = CASE
      WHEN COALESCE(p.total_count, 0) > 0 AND COALESCE($2, 0) > 0 THEN
        LEAST(
          COALESCE(p.total_count, 0) - COALESCE(p.error_count, 0),
          COALESCE(p.success_count, 0) + COALESCE($2, 0)
        )
      ELSE
        GREATEST(0, COALESCE(p.success_count, 0) + COALESCE($2, 0))
    END,
    error_count = CASE
      WHEN COALESCE(p.total_count, 0) > 0 AND COALESCE($3, 0) > 0 THEN
        LEAST(
          COALESCE(p.total_count, 0) - COALESCE(p.success_count, 0),
          COALESCE(p.error_count, 0) + COALESCE($3, 0)
        )
      ELSE
        GREATEST(0, COALESCE(p.error_count, 0) + COALESCE($3, 0))
    END
FROM target
WHERE p.step_id = target.step_id
RETURNING
    p.step_id,
    p.job_id,
    p.step_order,
    p.step_name,
    p.step_status,
    p.total_count,
    p.success_count,
    p.error_count,
    p.started_at,
    p.completed_at,
    p.updated_at;
