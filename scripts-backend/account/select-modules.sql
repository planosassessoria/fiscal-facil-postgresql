-- This file contains the SQL query for selecting all modules from the account.modules table. It retrieves the module information, including the module ID, name, key, description, active status, creation date, and update date. Additionally, it includes a count of the total number of rows returned by the query using the COUNT(*) OVER() window function.
-- The query does not include any filtering conditions, so it will return all modules present in the account.modules table. The results are ordered by the module_id by default, but this can be modified as needed.
SELECT
	module_id,
	module_name,
	module_key,
	description,
	is_active,
	created_at,
	updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.modules;
