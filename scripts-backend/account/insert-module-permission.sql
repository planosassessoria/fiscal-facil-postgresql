-- This file contains the SQL query for inserting a new permission into the database.
-- It is used in the account package to create a new permission associated with a module for permissions management.
INSERT INTO account.permissions (
	module_id,
	permission_name,
	permission_key,
	description
)
VALUES (
	$1,
	$2,
	$3,
	$4
) RETURNING *;
