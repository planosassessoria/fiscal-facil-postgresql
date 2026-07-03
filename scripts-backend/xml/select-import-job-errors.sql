-- ============================================================================
-- Arquivo: select-import-job-errors.sql
-- Operação: SELECT
-- Schema/Tabela: xml.import_job_error
-- Descrição: Lista erros de um job de importação com suporte a:
--            - Filtro por job_id (obrigatório)
--            - Filtro por step_name (opcional)
--            - Filtro por error_code (opcional)
--            - Busca textual em error_message, file_reference e ch_nf
--            - Paginação dinâmica (LIMIT/OFFSET)
--            - Ordenação dinâmica (via pg_format)
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job de importação (obrigatório)
--   $2 - step_name (TEXT) - Filtro por etapa (NULL = todas)
--   $3 - error_code (TEXT) - Filtro por código de erro (NULL = todos)
--   $4 - search_query (TEXT) - Busca textual (NULL = sem filtro)
--   Coluna de ordenação (interpolado via pg_format - identificador)
--   Direção da ordenação ASC/DESC (interpolado via pg_format - string)
--   LIMIT (interpolado via pg_format - literal)
--   OFFSET (interpolado via pg_format - literal)
--
-- Retorno: Lista de erros com rows_number para paginação
-- ============================================================================
SELECT
    e.error_id,
    e.job_id,
    e.step_name,
    e.file_reference,
    e.ch_nf,
    e.error_code,
    e.error_message,
    e.error_detail,
    e.created_at,
    COUNT(*) OVER () AS rows_number
FROM xml.import_job_error e
WHERE
    -- 1. Filtro obrigatório por job_id
    e.job_id = $1
    -- 2. Filtro por step_name
    AND (
        $2::text IS NULL
        OR e.step_name = $2
    )
    -- 3. Filtro por error_code
    AND (
        $3::text IS NULL
        OR e.error_code = $3
    )
    -- 4. Busca textual em campos relevantes
    AND (
        $4::text IS NULL
        OR e.error_message ILIKE '%' || $4 || '%'
        OR e.file_reference ILIKE '%' || $4 || '%'
        OR e.ch_nf ILIKE '%' || $4 || '%'
    )
ORDER BY
    %I %s
LIMIT
    %L
OFFSET
    %L;
