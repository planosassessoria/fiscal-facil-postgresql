-- ============================================================================
-- Arquivo: select-tax-entities-by-est-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tax_entities
-- Descrição: Busca todos os vínculos de tax_entities para um estabelecimento.
--            Usado para notificar escritórios quando o cliente altera
--            o próprio cadastro.
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento
--
-- Retorno: tax_id, tenant_id, est_id, display_name, document
-- ============================================================================
SELECT
    tax_id,
    tenant_id,
    est_id,
    display_name,
    document
FROM partner.tax_entities
WHERE est_id = $1;
