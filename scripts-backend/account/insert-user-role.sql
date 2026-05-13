-- This file contains the SQL query for inserting a new user role into the database.
-- It is used in the account package to create a new role with associated modules and permissions.
INSERT INTO account.roles (
	role_name,
	account_type,
	is_owner,
	modules,
	permissions,
	is_system
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6
) RETURNING *;
