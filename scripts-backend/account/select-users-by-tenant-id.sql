-- This file contains the SQL query for selecting users by tenant ID from the database.
-- It retrieves the tenant ID, email, full name, display name, root status, role ID, role name, account type, is owner, email confirmation status, active status, change password status, created at timestamp, and the total number of rows in the result set from the account.users.
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
