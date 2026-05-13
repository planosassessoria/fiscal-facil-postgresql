-- ============================================================================
-- Arquivo: select-tax-entity-exists.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tax_entities
-- Descrição: Verifica se já existe um vínculo entre um tenant e um
--            estabelecimento na carteira. Evita duplicidade de parceiro.
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant (escritório)
--   $2 - est_id (UUID) - ID do estabelecimento
--
-- Retorno: tax_id, tenant_id, est_id, display_name, document (LIMIT 1)
-- ============================================================================
SELECT
    tax_id,
    tenant_id,
    est_id,
    display_name,
    document
FROM partner.tax_entities
WHERE tenant_id = $1
  AND est_id = $2
LIMIT 1;
