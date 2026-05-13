-- ============================================================================
-- Arquivo: update-user-role.sql
-- Operação: UPDATE
-- Schema/Tabela: account.roles
-- Descrição: Atualiza os dados de um perfil de acesso (role), incluindo
--            módulos, permissões e flags de sistema.
--
-- Parâmetros:
--   $1 - role_id (UUID) - ID do perfil a ser atualizado
--   $2 - role_name (VARCHAR) - Novo nome do perfil
--   $3 - account_type (VARCHAR) - Tipo da conta
--   $4 - is_owner (BOOLEAN) - Flag de proprietário
--   $5 - modules (JSONB) - Lista de módulos atribuídos
--   $6 - permissions (JSONB) - Lista de permissões atribuídas
--   $7 - is_system (BOOLEAN) - Flag de perfil de sistema
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE
	account.roles
SET
	role_name = $2,
	account_type = $3,
	is_owner = $4,
	modules = $5,
	permissions = $6,
	is_system = $7
WHERE
	role_id = $1;
