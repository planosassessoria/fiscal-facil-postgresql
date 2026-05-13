-- This file contains the SQL query for inserting a new establishment address into the partner.addresses table.
-- It is used to create a new address for an establishment with the provided details such as establishment ID, zip code, street, street number, neighborhood, city, IBGE code, state (UF), and complement.
INSERT INTO partner.addresses (
	est_id,
	zip_code,
	street,
	street_number,
	neighborhood,
	city,
	ibge,
	uf,
	complement
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9
) RETURNING *;
