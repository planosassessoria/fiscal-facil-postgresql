-- ============================================================================
-- Arquivo: select-import-jobs.sql
-- Operação: SELECT
-- Schema/Tabela: xml.import_job + xml.import_job_step
-- Descrição: Lista jobs de importação de um tenant com suporte a:
--            - Controle RBAC (root vê todos, demais vêem só seu tenant)
--            - Busca textual via Full Text Search (FTS) em job_fts
--            - Filtro por status do job
--            - Paginação dinâmica (LIMIT/OFFSET)
--            - Ordenação dinâmica (via pg_format)
--            - Etapa (step) atual com progresso agregado
--
-- Parâmetros:
--   $1 - is_root (BOOLEAN) - Se o usuário requisitante é root
--   $2 - tenant_id (UUID) - ID do tenant para filtro de segurança
--   $3 - search_query (TEXT) - Termo de busca FTS (NULL = sem filtro)
--   $4 - job_status (TEXT) - Filtro por status do job (NULL = todos)
--   $5 - est_id (UUID) - Filtro por estabelecimento (NULL = todos)
--   $6 - mine_only (BOOLEAN) - Se true, retorna apenas jobs do usuário logado
--   $7 - session_user_email (TEXT) - E-mail do usuário logado (para mine_only)
--   Coluna de ordenação (interpolado via pg_format - identificador)
--   Direção da ordenação ASC/DESC (interpolado via pg_format - string)
--   LIMIT (interpolado via pg_format - literal)
--   OFFSET (interpolado via pg_format - literal)
--
-- Retorno: Lista de jobs com steps agregados e rows_number para paginação
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
                'startedAt',    s.started_at,
                'completedAt',  s.completed_at
            ) ORDER BY s.step_order
        ) FILTER (WHERE s.step_id IS NOT NULL),
        '[]'::json
    ) AS steps,
    COUNT(*) OVER () AS rows_number
FROM xml.import_job j
LEFT JOIN xml.import_job_step s ON s.job_id = j.job_id
WHERE
    -- 1. Filtro de Segurança (RBAC)
    (
        $1 = TRUE
        OR j.tenant_id = $2
    )
    -- 2. Filtro por Status
    AND (
        $4::text IS NULL
        OR j.job_status = $4
    )
    -- 3. Filtro de Busca (FTS)
    AND (
        $3::text IS NULL
        OR j.job_fts @@ to_tsquery('simple', PUBLIC.fn_format_tsquery($3::text))
    )
    -- 4. Filtro por estabelecimento
    AND (
        $5::uuid IS NULL
        OR j.est_id = $5
    )
    -- 5. Filtro apenas jobs do usuário logado
    AND (
        $6::boolean = FALSE
        OR j.user_email = $7
    )
GROUP BY j.job_id
ORDER BY
    %I %s
LIMIT
    %L
OFFSET
    %L;
