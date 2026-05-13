-- ============================================================================
-- Arquivo: select-user-role-owner.sql
-- Operação: SELECT
-- Schema/Tabela: account.roles
-- Descrição: Busca o perfil de proprietário (owner) de um tipo de conta.
--            Perfis owner são roles de sistema com permissões completas.
--
-- Parâmetros:
--   $1 - account_type (VARCHAR) - Tipo da conta (COUNTER, CLIENT)
--
-- Retorno: role_id, role_name, account_type, is_owner, is_system (LIMIT 1)
-- ============================================================================
SELECT
	role_id,
	role_name,
	account_type,
	is_owner,
	is_system
FROM account.roles
WHERE account_type = $1
	AND is_owner = TRUE
	AND is_system
LIMIT 1;
