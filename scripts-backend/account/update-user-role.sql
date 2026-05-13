-- This file contains the SQL query for updating a user role in the account.roles table. The query updates the role information, including the role name, account type, owner flag, modules, permissions, and system status based on the provided role ID.
-- This query is used in the account package to update a user role's information in the database. It allows for modifying the role's attributes while keeping the role ID unchanged.
UPDATE
	account.roles
SET
	role_name = $2,
	account_type = $3,
	is_owner = $4,
	modules = $5,
	permissions = $6,
	is_system = $7
WHERE
	role_id = $1;
