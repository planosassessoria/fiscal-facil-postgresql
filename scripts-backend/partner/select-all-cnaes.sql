-- This file contains the SQL query for selecting all CNAEs from the database.
-- It retrieves the CNAE code, its description, and the total number of rows in the result set from the partner.cnaes table, ordered by the CNAE code in ascending order.
SELECT
    cnae,
    cnae_description,
    COUNT(*) OVER() as rows_number
FROM partner.cnaes
ORDER BY cnae ASC;
