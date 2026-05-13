-- This file contains the SQL query for updating a permission in the account.permissions table. The query updates the permission information, including the module ID, permission name, permission key, and description based on the provided permission ID. The permission ID is used as a condition in the WHERE clause to ensure that only the specified permission is updated. The query does not return any results, as it is an UPDATE statement.
-- This query is used in the account package to update a permission's information in the database.
UPDATE
	account.permissions
SET
	module_id = $2,
	permission_name = $3,
	permission_key = $4,
	description = $5
WHERE
	permission_id = $1;
