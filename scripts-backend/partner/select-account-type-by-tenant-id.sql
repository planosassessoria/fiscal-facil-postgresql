-- ============================================================================
-- Arquivo: select-account-type-by-tenant-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tenants
-- Descrição: Retorna o tipo de conta (account_type) de um tenant.
--            Usado para determinar o contexto de operação (COUNTER ou CLIENT).
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant
--
-- Retorno: account_type (VARCHAR)
-- ============================================================================
SELECT account_type
FROM partner.tenants
WHERE tenant_id = $1;
