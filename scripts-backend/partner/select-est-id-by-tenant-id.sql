-- Busca o est_id do estabelecimento matriz de um tenant.
-- Usado nas rotas de tenant para resolver o establishment sem receber estId na rota.
SELECT est_id
FROM partner.tenants
WHERE tenant_id = $1
LIMIT 1;
