-- ============================================================================
-- Arquivo: increment-import-job-step-counters-capped.sql
-- Operacao: UPDATE
-- Schema/Tabela: xml.import_job_step
-- Descricao:
--   Incrementa contadores de uma etapa de forma atomica, respeitando total_count
--   quando ele for maior que zero.
--
-- Regras:
--   - Quando total_count = 0, incrementa sem limite (fase ainda sem total definido).
--   - Quando total_count > 0, impede ultrapassar o total processado.
--
-- Parametros:
--   $1 - step_id (UUID)
--   $2 - success_delta (INT)
--   $3 - error_delta (INT)
--
-- Retorno: Registro atualizado da etapa (0 linhas quando ja atingiu total).
-- ============================================================================
UPDATE xml.import_job_step
SET
    success_count = CASE
        WHEN COALESCE(total_count, 0) > 0 AND COALESCE($2, 0) > 0 THEN
            LEAST(
                COALESCE(total_count, 0) - COALESCE(error_count, 0),
                COALESCE(success_count, 0) + COALESCE($2, 0)
            )
        ELSE
            GREATEST(0, COALESCE(success_count, 0) + COALESCE($2, 0))
    END,
    error_count = CASE
        WHEN COALESCE(total_count, 0) > 0 AND COALESCE($3, 0) > 0 THEN
            LEAST(
                COALESCE(total_count, 0) - COALESCE(success_count, 0),
                COALESCE(error_count, 0) + COALESCE($3, 0)
            )
        ELSE
            GREATEST(0, COALESCE(error_count, 0) + COALESCE($3, 0))
    END
WHERE step_id = $1
  AND (
    COALESCE(total_count, 0) = 0
    OR (COALESCE(success_count, 0) + COALESCE(error_count, 0)) < COALESCE(total_count, 0)
  )
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
