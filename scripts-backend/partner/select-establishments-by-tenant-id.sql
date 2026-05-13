-- This file contains the SQL query for selecting establishments by tenant ID from the database.
-- It retrieves the establishment ID, document, social reason, display name, fantasy name, phone, email, state, situation, tenant ID, and whether the establishment has a tenant.
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
