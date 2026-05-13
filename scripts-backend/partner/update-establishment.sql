-- This file contains the SQL query for updating an existing establishment in the partner.establishments table.
-- It is used to update the details of an establishment with the provided information such as establishment ID, IE, UF, Razão Social, Fantasia, CNAE, CNAEs, telefone, situação, last_sync_at, telefone_secundario, and email. The COALESCE function is used to ensure that only the provided fields are updated, while the existing values are retained for any fields that are not provided (i.e., those that are NULL). The query identifies the establishment to update using the est_id.
UPDATE partner.establishments
SET
    ie = COALESCE($2, ie),
    uf = COALESCE($3, uf),
    razao_social = COALESCE($4, razao_social),
    fantasia = COALESCE($5, fantasia),
    cnae = COALESCE($6, cnae),
    cnaes = COALESCE($7, cnaes),
    telefone = COALESCE($8, telefone),
    situacao = COALESCE($9, situacao),
    last_sync_at = COALESCE($10, last_sync_at),
    telefone_secundario = COALESCE($11, telefone_secundario),
    email = COALESCE($12, email)
WHERE est_id = $1;
