-- ============================================================================
-- Arquivo: select-full-user-with-tenant.sql
-- Operação: SELECT
-- Schema/Tabela: account.users + account.users_tenants + account.roles +
--               partner.tenants + partner.establishments
-- Descrição: Retorna o perfil completo do usuário com dados de tenant,
--            perfil de acesso e estabelecimento vinculado. Usado após
--            autenticação para montar o contexto do usuário logado.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--
-- Retorno: Dados do usuário, gênero, tenant, role e estabelecimento
-- ============================================================================
SELECT
	u.email,
	u.email_confirmed,
	u.full_name,
	u.display_name,
	u.gender_id,
	g.gender_name,
	u.birth_date,
	u.avatar,
	u.cpf,
	u.telefone,
	u.change_password,
	u.accept_terms,
	u.root,
	ut.role_id,
	r.role_name,
	r.account_type,
	r.is_owner,
	r.modules,
	r.permissions,
	ut.tenant_id,
	ut.is_active,
	t.est_id,
	e.document,
	e.document_type,
	e.situacao,
	e.ie,
	e.uf,
	e.razao_social,
	e.fantasia,
	e.telefone AS est_telefone,
	e.telefone_secundario,
	e.email AS est_email
FROM account.users u
JOIN account.genders g USING (gender_id)
LEFT JOIN account.users_tenants ut USING (email)
LEFT JOIN account.roles r USING (role_id)
LEFT JOIN partner.tenants t USING (tenant_id)
LEFT JOIN partner.establishments e USING (est_id)
WHERE u.email = $1;
