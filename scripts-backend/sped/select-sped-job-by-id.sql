-- ============================================================================
-- Arquivo: /sped/select-sped-job-by-id.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_jobs + sped.sped_files + sped.sped_job_stages + sped.sped_job_timeline
-- Descrição: Retorna os detalhes completos de um job SPED pelo seu ID,
--            incluindo metadados do arquivo, etapas ordenadas e timeline de status
--            timeline em ordem cronológica.
--            Verifica acesso por tenant_id (exceto root).
--
-- Parâmetros:
--   $1 - sped_job_id (BIGINT) - PK do job
--   $2 - is_root (BOOLEAN)    - Root ignora verificação de tenant
--   $3 - tenant_id (UUID)     - Tenant do usuário autenticado
--
-- Retorno: Um único registro com stages[] e timeline[] embutidos via JSON
-- ============================================================================
SELECT
    j.sped_job_id,
    j.sped_file_id,
    j.tenant_id,
    j.est_id,
    j.protocol_code,
    j.job_type,
    j.workflow_status,
    j.current_stage_code,
    j.progress_percent,
    j.requested_by_email,
    j.started_at,
    j.finished_at,
    j.last_heartbeat_at,
    j.job_metadata,
    j.created_at,
    j.updated_at,
    f.document,
    f.ie,
    f.reference_period,
    f.layout_version,
    f.source_file_name,
    f.source_file_sha256,
    f.total_lines,
    f.imported_at,
    COALESCE(
        (
            SELECT json_agg(
                json_build_object(
                    'spedJobStageId',     s.sped_job_stage_id,
                    'stageCode',          s.stage_code,
                    'stageOrder',         s.stage_order,
                    'stageStatus',        s.stage_status,
                    'responsibleByEmail', s.responsible_by_email,
                    'stageSummary',       s.stage_summary,
                    'stagePayload',       s.stage_payload,
                    'startedAt',          s.started_at,
                    'finishedAt',         s.finished_at,
                    'createdAt',          s.created_at,
                    'updatedAt',          s.updated_at
                ) ORDER BY s.stage_order
            )
            FROM sped.sped_job_stages s
            WHERE s.sped_job_id = j.sped_job_id
        ),
        '[]'::json
    ) AS stages,
    COALESCE(
        (
            SELECT json_agg(
                json_build_object(
                    'timelineId',              t.timeline_id,
                    'statusId',                t.status_id,
                    'statusCode',              st.status_code,
                    'statusLabelPT',           st.status_label_pt,
                    'isSystem',                st.is_system,
                    'recordedByEmail',         t.recorded_by_email,
                    'notes',                   t.notes,
                    'recordedAt',              t.recorded_at,
                    'createdAt',               t.created_at
                ) ORDER BY t.recorded_at DESC
            )
            FROM sped.sped_job_timeline t
            INNER JOIN sped.sped_job_status_types st ON st.status_id = t.status_id
            WHERE
                t.document = f.document
                AND t.reference_period = f.reference_period
                AND (
                    (t.ie IS NULL AND f.ie IS NULL)
                    OR t.ie = f.ie
                )
        ),
        '[]'::json
    ) AS timeline
FROM sped.sped_jobs j
INNER JOIN sped.sped_files f ON f.sped_file_id = j.sped_file_id
WHERE
    j.sped_job_id = $1
    AND (
        $2 = TRUE
        OR j.tenant_id = $3
    );
