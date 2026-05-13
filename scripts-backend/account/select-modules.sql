-- ============================================================================
-- Arquivo: select-modules.sql
-- Operação: SELECT
-- Schema/Tabela: account.modules
-- Descrição: Lista todos os módulos do sistema de controle de acesso.
--            Inclui contagem total de registros via window function.
--
-- Parâmetros: Nenhum
--
-- Retorno: module_id, module_name, module_key, description, is_active,
--          created_at, updated_at, rows_number
-- ============================================================================
SELECT
	module_id,
	module_name,
	module_key,
	description,
	is_active,
	created_at,
	updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.modules;
