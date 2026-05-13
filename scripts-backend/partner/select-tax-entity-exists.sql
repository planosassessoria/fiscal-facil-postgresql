-- Verifica se já existe um vínculo ativo entre um tenant e um estabelecimento
-- na tabela tax_entities. Evita duplicidade de parceiro na carteira.
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
