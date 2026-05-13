-- ============================================================================
-- Arquivo: select-est-id-by-tenant-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tenants
-- Descrição: Busca o est_id do estabelecimento matriz de um tenant.
--            Usado para resolver o establishment sem receber estId na rota.
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant
--
-- Retorno: est_id (UUID) - LIMIT 1
-- ============================================================================
SELECT est_id
FROM partner.tenants
WHERE tenant_id = $1
LIMIT 1;
