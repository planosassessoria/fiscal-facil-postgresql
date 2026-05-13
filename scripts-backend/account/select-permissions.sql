-- ============================================================================
-- Arquivo: select-permissions.sql
-- Operação: SELECT
-- Schema/Tabela: account.permissions + account.modules
-- Descrição: Lista todas as permissões do sistema com os dados do módulo
--            associado. Inclui contagem total de registros.
--
-- Parâmetros: Nenhum
--
-- Retorno: permission_id, module_id, module_name, module_key,
--          permission_name, permission_key, description,
--          created_at, updated_at, rows_number
-- ============================================================================
SELECT
	p.permission_id,
	p.module_id,
	m.module_name,
	m.module_key,
	p.permission_name,
	p.permission_key,
	p.description,
	p.created_at,
	p.updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.permissions p
JOIN account.modules m USING (module_id);
