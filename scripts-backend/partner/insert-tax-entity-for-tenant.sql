-- ============================================================================
-- Arquivo: insert-tax-entity-for-tenant.sql
-- Operação: INSERT
-- Schema/Tabela: partner.tax_entities
-- Descrição: Vincula um estabelecimento à carteira de clientes de um tenant.
--            Tax entities representam a relação contador-cliente no sistema.
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant (escritório contábil)
--   $2 - est_id (UUID) - ID do estabelecimento vinculado
--   $3 - display_name (VARCHAR) - Nome de exibição na carteira
--   $4 - document (VARCHAR) - Documento do estabelecimento
--
-- Retorno: Registro completo do vínculo criado (RETURNING *)
-- ============================================================================
INSERT INTO partner.tax_entities (
	tenant_id,
	est_id,
	display_name,
	document
)
VALUES (
	$1,
	$2,
	$3,
	$4
)
RETURNING *;
