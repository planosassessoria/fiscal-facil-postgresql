-- ============================================================================
-- Arquivo: update-module.sql
-- Operação: UPDATE
-- Schema/Tabela: account.modules
-- Descrição: Atualiza os dados de um módulo do sistema de controle de acesso.
--
-- Parâmetros:
--   $1 - module_id (UUID) - ID do módulo a ser atualizado
--   $2 - module_name (VARCHAR) - Novo nome do módulo
--   $3 - module_key (VARCHAR) - Nova chave do módulo
--   $4 - description (TEXT) - Nova descrição
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE
	account.modules
SET
	module_name = $2,
	module_key = $3,
	description = $4
WHERE
	module_id = $1;
