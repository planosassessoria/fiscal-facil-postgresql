-- ============================================================================
-- Arquivo: select-establishment-tenant-exists.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tenants + partner.establishments
-- Descrição: Verifica se já existe um tenant vinculado a um estabelecimento
--            com determinado documento. Usado para evitar duplicidade de
--            contratantes. Regras de unicidade iguais ao select-by-document.
--
-- Parâmetros:
--   $1 - document (VARCHAR) - CNPJ ou CPF sem formatação
--   $2 - ie (TEXT) - Inscrição Estadual (pode ser NULL)
--
-- Retorno: tenant_id, razao_social, document, ie (LIMIT 1)
-- ============================================================================
SELECT
    t.tenant_id,
    e.razao_social,
    e.document,
    e.ie
FROM partner.tenants t
JOIN partner.establishments e ON t.est_id = e.est_id
WHERE e.document = $1
  AND (
    CASE
        -- CENÁRIO PJ: Se for CNPJ, ignora a IE na verificação (o CNPJ manda)
        WHEN length($1) = 14 THEN TRUE

        -- CENÁRIO PF COM IE: Se for CPF e veio IE, exige que a IE bata
        WHEN length($1) = 11 AND ($2::text IS NOT NULL AND $2::text <> '') THEN e.ie = $2::text

        -- CENÁRIO AUTÔNOMO: Se for CPF e não veio IE, busca onde a IE é nula
        WHEN length($1) = 11 AND ($2::text IS NULL OR $2::text = '') THEN e.ie IS NULL

        ELSE FALSE
    END
  )
LIMIT 1;
