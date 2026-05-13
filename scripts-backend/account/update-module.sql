-- This file contains the SQL query for updating a module in the account.modules table. The query updates the module information, including the module name, module key, and description based on the provided module ID. The module ID is used as a condition in the WHERE clause to ensure that only the specified module is updated. The query does not return any results, as it is an UPDATE statement.
-- This query is used in the account package to update a module's information in the database.
UPDATE
	account.modules
SET
	module_name = $2,
	module_key = $3,
	description = $4
WHERE
	module_id = $1;
