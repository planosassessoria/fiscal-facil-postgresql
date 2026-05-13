-- ============================================================================
-- Arquivo: select-establishment-by-est-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.establishments + partner.addresses + partner.tenants
-- Descrição: Busca um estabelecimento pelo ID com dados completos de
--            endereço e vínculo com tenant. Usado para edição e sincronização.
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento
--
-- Retorno: Dados completos do estabelecimento, endereço e tenant (LIMIT 1)
-- ============================================================================
SELECT
    e.est_id,
    e.document,
    e.document_type,
    e.ie,
    e.uf,
    e.razao_social,
    e.fantasia,
    e.cnae,
    e.cnaes,
    e.telefone,
    e.telefone_secundario,
    e.email,
    e.situacao,
    e.created_at,
    e.updated_at,
    e.last_sync_at,
    a.address_id,
    a.zip_code,
    a.street,
    a.street_number,
    a.neighborhood,
    a.city,
    a.ibge,
    a.uf AS address_uf,
    a.complement,
    (t.tenant_id IS NOT NULL) AS has_tenant,
    t.tenant_id,
    t.account_type
FROM partner.establishments e
LEFT JOIN partner.addresses a ON e.est_id = a.est_id
LEFT JOIN partner.tenants t ON e.est_id = t.est_id
WHERE e.est_id = $1
LIMIT 1;
