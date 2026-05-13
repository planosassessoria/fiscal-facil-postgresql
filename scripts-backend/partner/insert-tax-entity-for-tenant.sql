-- This file contains the SQL query for inserting a new tax entity for a tenant into the partner.tax_entities table.
-- It is used to create a new tax entity with the provided details such as tenant ID, establishment ID, display name, and document number.
INSERT INTO partner.tax_entities (
	tenant_id,
	est_id,
	display_name,
	document
)
VALUES (
	$1,
	$2,
	$3,
	$4
)
RETURNING *;
