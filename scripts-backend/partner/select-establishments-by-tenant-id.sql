-- ============================================================================
-- Arquivo: select-establishments-by-tenant-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.establishments + partner.tenants + partner.tax_entities
-- Descrição: Lista estabelecimentos vinculados a um tenant com controle RBAC.
--            ROOT visualiza todos; demais veem apenas sua carteira ativa.
--            Identifica se cada estabelecimento já é contratante (has_tenant).
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant atual (para filtro tax_entities)
--   $2 - is_root (BOOLEAN) - Se o usuário é root
--
-- Retorno: est_id, document, razao_social, display_name, fantasia,
--          telefone, email, uf, situacao, tenant_id, account_type,
--          has_tenant, rows_number
-- ============================================================================
SELECT
    e.est_id,
    e.document,
    e.razao_social,
    te.display_name,
    e.fantasia,
    e.telefone,
    e.email,
    e.uf,
    e.situacao,
    t.tenant_id,
    t.account_type,
    (t.tenant_id IS NOT NULL) AS has_tenant,
    COUNT(*) OVER () AS rows_number
FROM partner.establishments e
-- Identifica se o estabelecimento é um contratante (Tenant)
LEFT JOIN partner.tenants t ON e.est_id = t.est_id
-- Vincula com a carteira de clientes do contador
LEFT JOIN partner.tax_entities te ON e.est_id = te.est_id AND te.tenant_id = $1 -- $1: current_tenant_id
WHERE (
    CASE
        -- 1. ROOT: Enxerga tudo
        WHEN $2 = TRUE THEN TRUE
        -- 2. DEMAIS: Apenas o que está na carteira ativa
        ELSE te.tax_id IS NOT NULL AND te.is_active = TRUE
    END
)
ORDER BY
  e.razao_social ASC;
