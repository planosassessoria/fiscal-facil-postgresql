-- ============================================================================
-- Arquivo: select-user-roles.sql
-- Operação: SELECT
-- Schema/Tabela: account.roles
-- Descrição: Lista todos os perfis de acesso cadastrados no sistema.
--            Inclui contagem total de registros via window function.
--
-- Parâmetros: Nenhum
--
-- Retorno: role_id, role_name, account_type, is_owner, modules,
--          permissions, is_system, created_at, updated_at, rows_number
-- ============================================================================
SELECT
	role_id,
	role_name,
	account_type,
	is_owner,
	modules,
	permissions,
	is_system,
	created_at,
	updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.roles;
