-- This file contains the SQL query for updating an existing establishment's address in the partner.addresses table.
-- It is used to update the details of an establishment's address with the provided information such as establishment ID, zip code, street, street number, neighborhood, city, IBGE code, state (UF), and complement. The COALESCE function is used to ensure that only the provided fields are updated, while the existing values are retained for any fields that are not provided (i.e., those that are NULL). The query identifies the address to update using the est_id, which is a foreign key linking the address to the establishment. The address_id is not updated here as it is a primary key and should remain unchanged.
UPDATE partner.addresses
SET
    zip_code = COALESCE($2, zip_code),
    street = COALESCE($3, street),
    street_number = COALESCE($4, street_number),
    neighborhood = COALESCE($5, neighborhood),
    city = COALESCE($6, city),
    ibge = COALESCE($7, ibge),
    uf = COALESCE($8, uf),
    complement = COALESCE($9, complement)
WHERE est_id = $1;
