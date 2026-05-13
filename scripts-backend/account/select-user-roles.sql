-- This file contains the SQL query for selecting all user roles from the account.roles table. It retrieves the role information, including the role ID, name, account type, owner flag, modules, permissions, system status, creation date, and update date. Additionally, it includes a count of the total number of rows returned by the query using the COUNT(*) OVER() window function.
-- The query does not include any filtering conditions, so it will return all roles present in the account.roles table. The results are ordered by the role_id by default, but this can be modified as needed.
SELECT
	role_id,
	role_name,
	account_type,
	is_owner,
	modules,
	permissions,
	is_system,
	created_at,
	updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.roles;
