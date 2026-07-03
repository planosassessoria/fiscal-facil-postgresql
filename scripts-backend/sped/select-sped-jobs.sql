-- ============================================================================
-- Arquivo: /sped/select-sped-jobs.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_jobs + sped.sped_files
-- Descrição: Lista jobs SPED de um tenant com suporte a:
--            - Controle RBAC (root vê todos, demais vêem só seu tenant)
--            - Filtro por workflow_status
--            - Filtro por estabelecimento (est_id)
--            - Filtro apenas jobs solicitados pelo usuário logado (mine_only)
--            - Paginação dinâmica (LIMIT/OFFSET)
--            - Ordenação dinâmica (via pg_format)
--            - Estágios ativos embutidos via JSON aggregation
--
-- Parâmetros:
--   $1 - is_root (BOOLEAN)         - Root vê todos os tenants
--   $2 - tenant_id (UUID)          - Filtro de segurança por tenant
--   $3 - workflow_status (TEXT)    - Filtro por status (NULL = todos)
--   $4 - est_id (UUID)             - Filtro por estabelecimento (NULL = todos)
--   $5 - mine_only (BOOLEAN)       - Se true, retorna apenas jobs do usuário logado
--   $6 - session_user_email (TEXT) - E-mail do usuário logado (para mine_only)
--   Coluna de ordenação            (interpolado via pg_format - identificador)
--   Direção da ordenação           (interpolado via pg_format - string ASC|DESC)
--   LIMIT                          (interpolado via pg_format - literal)
--   OFFSET                         (interpolado via pg_format - literal)
--
-- Retorno: Lista de jobs com metadados do arquivo e contagem total para paginação
-- ============================================================================
SELECT
    j.sped_job_id,
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
    j.created_at,
    j.updated_at,
    f.source_file_name,
    f.document,
    f.reference_period,
    f.total_lines,
    f.imported_at,
    COALESCE(
        json_agg(
            json_build_object(
                'spedJobStageId',   s.sped_job_stage_id,
                'stageCode',        s.stage_code,
                'stageOrder',       s.stage_order,
                'stageStatus',      s.stage_status,
                'stageSummary',     s.stage_summary,
                'startedAt',        s.started_at,
                'finishedAt',       s.finished_at
            ) ORDER BY s.stage_order
        ) FILTER (WHERE s.sped_job_stage_id IS NOT NULL),
        '[]'::json
    ) AS stages,
    COUNT(*) OVER () AS rows_number
FROM sped.sped_jobs j
INNER JOIN sped.sped_files f ON f.sped_file_id = j.sped_file_id
LEFT JOIN sped.sped_job_stages s ON s.sped_job_id = j.sped_job_id
WHERE
    -- 1. Filtro de segurança (RBAC)
    (
        $1 = TRUE
        OR j.tenant_id = $2
    )
    -- 2. Filtro por workflow_status
    AND (
        $3::text IS NULL
        OR j.workflow_status = $3
    )
    -- 3. Filtro por estabelecimento
    AND (
        $4::uuid IS NULL
        OR j.est_id = $4
    )
    -- 4. Filtro apenas jobs do usuário logado
    AND (
        $5::boolean = FALSE
        OR j.requested_by_email = $6
    )
GROUP BY
    j.sped_job_id,
    f.sped_file_id
ORDER BY
    %I %s
LIMIT
    %L
OFFSET
    %L;
