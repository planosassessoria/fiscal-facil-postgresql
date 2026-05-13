-- This file contains the SQL query for inserting a new establishment into the partner.establishments table.
-- It is used to create a new establishment with the provided details such as document type, document number, state registration, state, corporate name, trade name, CNAE, telefone number, and situation.
INSERT INTO partner.establishments (
	document_type,
	document,
	ie,
	uf,
	razao_social,
	fantasia,
	cnae,
	cnaes,
	telefone,
	situacao
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
	$9,
	$10
) RETURNING *;
