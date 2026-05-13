-- Busca todos os vínculos de tax_entities para um estabelecimento.
-- Usado para notificar escritórios quando o tenant-cliente altera o próprio cadastro.
SELECT
    tax_id,
    tenant_id,
    est_id,
    display_name,
    document
FROM partner.tax_entities
WHERE est_id = $1;
