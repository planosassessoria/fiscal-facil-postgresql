-- This file contains the SQL query for selecting all permissions from the account.permissions table. It retrieves the permission information, including the permission ID, module ID, module name, module key, permission name, permission key, description, creation date, and update date. Additionally, it includes a count of the total number of rows returned by the query using the COUNT(*) OVER() window function.
-- The query joins the account.permissions table with the account.modules table using the module_id to retrieve the module name and module key associated with each permission. The results are ordered by the permission_id by default, but this can be modified as needed.
SELECT
	p.permission_id,
	p.module_id,
	m.module_name,
	m.module_key,
	p.permission_name,
	p.permission_key,
	p.description,
	p.created_at,
	p.updated_at,
	COUNT(*) OVER () AS rows_number
FROM account.permissions p
JOIN account.modules m USING (module_id);
