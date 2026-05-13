-- This file contains the SQL query for inserting a new module into the database.
-- It is used in the account package to create a new module for permissions management.
INSERT INTO account.modules (
	module_name,
	module_key,
	description
)
VALUES (
	$1,
	$2,
	$3
) RETURNING *;
