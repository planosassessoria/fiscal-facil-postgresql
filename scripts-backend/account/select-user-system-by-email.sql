-- ============================================================================
-- Arquivo: select-user-system-by-email.sql
-- Operação: SELECT
-- Schema/Tabela: account.users + account.users_tenants + account.roles +
--               partner.tenants
-- Descrição: Busca dados do usuário para contexto de sistema, incluindo
--            informações de tenant e perfil. Trata usuários root com
--            valores fixos para role_name e account_type.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--
-- Retorno: Dados do usuário com tenant, role e timestamps (LIMIT 1)
-- ============================================================================
SELECT
	u.email,
	u.cpf,
	u.full_name,
	u.display_name,
	u.root,
	u.email_confirmed,
	u.change_password,
	u.accept_terms,
	ut.tenant_id,
	t.account_type,
	ut.role_id,
	CASE
		WHEN u.root = TRUE
			THEN 'Root'
		ELSE r.role_name
		END AS role_name,
	CASE
		WHEN u.root = TRUE
			THEN 'ROOT'
		ELSE r.account_type
		END AS account_type,
	COALESCE(r.is_owner, FALSE) AS is_owner,
	u.created_at,
	u.updated_at
FROM account.users u
LEFT JOIN account.users_tenants ut USING (email)
LEFT JOIN account.roles r USING (role_id)
LEFT JOIN partner.tenants t USING (tenant_id)
WHERE u.email = $1 LIMIT 1;
