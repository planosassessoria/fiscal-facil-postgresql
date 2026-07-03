-- ============================================================================
-- Arquivo: select-users-by-tenant-id.sql
-- Operação: SELECT
-- Schema/Tabela: account.users + account.users_tenants + account.roles
-- Descrição: Lista usuários vinculados a um tenant com suporte a:
--            - Controle RBAC (root vê todos, demais vêem só seu tenant)
--            - Busca textual via Full Text Search (FTS)
--            - Paginação dinâmica (LIMIT/OFFSET)
--            - Ordenação dinâmica (via pg_format)
--
-- Parâmetros:
--   $1 - is_root (BOOLEAN) - Se o usuário requisitante é root
--   $2 - tenant_id (UUID) - ID do tenant para filtro de segurança
--   $3 - search_query (TEXT) - Termo de busca FTS (NULL = sem filtro)
--   [col] - Coluna de ordenação (interpolado via pg_format com %%I)
--   [dir] - Direção da ordenação ASC/DESC (interpolado via pg_format com %%s)
--   [limit] - LIMIT (interpolado via pg_format com %%L)
--   [offset] - OFFSET (interpolado via pg_format com %%L)
--
-- Retorno: Lista de usuários com tenant_id, role, status e rows_number
-- ============================================================================
SELECT
  ut.tenant_id,
  u.email,
  u.full_name,
  u.display_name,
  u.root,
  -- Caso seja root, atribuímos um valor fixo ou mantemos o da tabela de roles
  CASE
    WHEN u.root = TRUE THEN 'Root'
    ELSE r.role_name
  END AS role_name,
  CASE
    WHEN u.root = TRUE THEN 'ROOT'
    ELSE r.account_type
  END AS account_type,
  CASE
    WHEN u.root = TRUE THEN TRUE
    ELSE COALESCE(r.is_owner, FALSE)
  END AS is_owner,
  ut.role_id,
  u.email_confirmed,
  -- Para o root, forçamos is_active como TRUE, para os demais usamos o status do tenant
  CASE
    WHEN u.root = TRUE THEN TRUE
    ELSE COALESCE(ut.is_active, FALSE)
  END AS is_active,
  u.change_password,
  u.created_at,
  COUNT(*) OVER () AS rows_number
FROM account.users u
LEFT JOIN account.users_tenants ut USING (email)
LEFT JOIN account.roles r USING(role_id)
WHERE
  -- 1. Filtro de Segurança (RBAC)
  -- Root vê todos. Usuários comuns veem apenas os do seu tenant_id.
  (
    $1 = TRUE -- :is_root
    OR ut.tenant_id = $2 -- :tenant_id
  )
  -- 2. Filtro de Busca (FTS)
  AND (
    $3::text IS NULL -- :search_query
    OR u.user_fts @@ to_tsquery('public.simple_portuguese', PUBLIC.fn_format_tsquery($3::text))
  )
ORDER BY
  %I %s
LIMIT
  %L
OFFSET
  %L;
