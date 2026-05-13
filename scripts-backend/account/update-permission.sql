-- ============================================================================
-- Arquivo: update-permission.sql
-- Operação: UPDATE
-- Schema/Tabela: account.permissions
-- Descrição: Atualiza os dados de uma permissão no sistema de controle de acesso.
--
-- Parâmetros:
--   $1 - permission_id (UUID) - ID da permissão a ser atualizada
--   $2 - module_id (UUID) - ID do módulo associado
--   $3 - permission_name (VARCHAR) - Novo nome da permissão
--   $4 - permission_key (VARCHAR) - Nova chave da permissão
--   $5 - description (TEXT) - Nova descrição
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE
	account.permissions
SET
	module_id = $2,
	permission_name = $3,
	permission_key = $4,
	description = $5
WHERE
	permission_id = $1;
