-- This file contains the SQL query for inserting a new tenant into the partner.tenants table.
-- It is used to create a new tenant with the provided details such as establishment ID, owner email, and account type.
INSERT INTO partner.tenants (
	est_id,
	owner_email,
	account_type
)
VALUES (
	$1,
	$2,
	$3
) RETURNING *;
