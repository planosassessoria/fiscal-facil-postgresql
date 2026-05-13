-- ============================================================================
-- Arquivo: insert-user-tenant.sql
-- Operação: INSERT
-- Schema/Tabela: account.users_tenants
-- Descrição: Associa um usuário a um tenant (escritório/empresa) com um
--            perfil de acesso específico.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--   $2 - tenant_id (UUID) - ID do tenant (escritório/empresa)
--   $3 - role_id (UUID) - ID do perfil de acesso atribuído
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO account.users_tenants (
	email,
	tenant_id,
	role_id
)
VALUES (
	$1,
	$2,
	$3
);
