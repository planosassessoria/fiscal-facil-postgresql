-- ============================================================================
-- Arquivo: insert-module-permission.sql
-- Operação: INSERT
-- Schema/Tabela: account.permissions
-- Descrição: Insere uma nova permissão associada a um módulo no sistema de
--            controle de acesso.
--
-- Parâmetros:
--   $1 - module_id (UUID) - ID do módulo ao qual a permissão pertence
--   $2 - permission_name (VARCHAR) - Nome da permissão
--   $3 - permission_key (VARCHAR) - Chave única da permissão
--   $4 - description (TEXT) - Descrição da permissão
--
-- Retorno: Registro completo da permissão criada (RETURNING *)
-- ============================================================================
INSERT INTO account.permissions (
	module_id,
	permission_name,
	permission_key,
	description
)
VALUES (
	$1,
	$2,
	$3,
	$4
) RETURNING *;
