-- This file contains the SQL query for checking if an establishment exists in the database.
-- It is used to verify if an establishment with the given document and state registration already exists in the partner.establishments table.
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
