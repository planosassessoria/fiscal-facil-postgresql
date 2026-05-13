-- ============================================================================
-- Arquivo: select-user-by-email.sql
-- Operação: SELECT
-- Schema/Tabela: account.users + account.users_tenants
-- Descrição: Busca um usuário pelo e-mail, incluindo vínculo com tenant
--            e perfil de acesso. Usado no processo de autenticação.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--
-- Retorno: Dados do usuário com tenant_id e role_id (LIMIT 1)
-- ============================================================================
SELECT
	u.email,
	u.full_name,
	u.display_name,
	u.gender_id,
	u.birth_date,
	u.avatar,
	u.cpf,
	u.telefone,
	u.password,
	u.root,
	u.email_confirmed,
	u.change_password,
	u.accept_terms,
	u.created_at,
	u.updated_at,
	ut.tenant_id,
	ut.role_id
FROM account.users u
LEFT JOIN account.users_tenants ut USING(email)
WHERE u.email = $1
LIMIT 1;
