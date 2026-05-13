-- ============================================================================
-- Arquivo: insert-user-role.sql
-- Operação: INSERT
-- Schema/Tabela: account.roles
-- Descrição: Insere um novo perfil de acesso (role) no sistema.
--            Perfis definem quais módulos e permissões um usuário possui.
--
-- Parâmetros:
--   $1 - role_name (VARCHAR) - Nome do perfil
--   $2 - account_type (VARCHAR) - Tipo da conta (COUNTER, CLIENT, ROOT)
--   $3 - is_owner (BOOLEAN) - Se é perfil de proprietário
--   $4 - modules (JSONB) - Lista de módulos atribuídos ao perfil
--   $5 - permissions (JSONB) - Lista de permissões atribuídas ao perfil
--   $6 - is_system (BOOLEAN) - Se é perfil de sistema (não editável)
--
-- Retorno: Registro completo do perfil criado (RETURNING *)
-- ============================================================================
INSERT INTO account.roles (
	role_name,
	account_type,
	is_owner,
	modules,
	permissions,
	is_system
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6
) RETURNING *;
