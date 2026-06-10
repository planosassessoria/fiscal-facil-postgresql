-- ============================================================================
-- Arquivo: select-import-job-by-id.sql
-- Operação: SELECT
-- Schema/Tabela: xml.import_job + xml.import_job_step
-- Descrição: Busca um job de importação pelo ID, incluindo suas etapas
--            (steps) agrupadas como array JSON ordenado por step_order.
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job de importação
--
-- Retorno: Dados completos do job com array JSON de etapas (steps)
-- ============================================================================
SELECT
    j.job_id,
    j.tenant_id,
    j.user_email,
    j.cpf_cnpj,
    j.est_id,
    j.job_type,
    j.job_status,
    j.file_name,
    j.file_size_bytes,
    j.bucket_path,
    j.total_count,
    j.notes,
    j.started_at,
    j.completed_at,
    j.expires_at,
    j.created_at,
    j.updated_at,
    COALESCE(
        json_agg(
            json_build_object(
                'stepId',       s.step_id,
                'stepOrder',    s.step_order,
                'stepName',     s.step_name,
                'stepStatus',   s.step_status,
                'totalCount',   s.total_count,
                'successCount', s.success_count,
                'errorCount',   s.error_count,
                'stepMessage',  s.step_message,
                'stepMetadata', s.step_metadata,
                'startedAt',    s.started_at,
                'completedAt',  s.completed_at
            ) ORDER BY s.step_order
        ) FILTER (WHERE s.step_id IS NOT NULL),
        '[]'::json
    ) AS steps
FROM xml.import_job j
LEFT JOIN xml.import_job_step s ON s.job_id = j.job_id
WHERE j.job_id = $1
GROUP BY j.job_id;
