-- This file contains the SQL query for selecting a user role by account type and owner flag.
-- It is used to retrieve the role information for the owner role, which is a system-defined role with specific permissions.
SELECT
	role_id,
	role_name,
	account_type,
	is_owner,
	is_system
FROM account.roles
WHERE account_type = $1
	AND is_owner = TRUE
	AND is_system
LIMIT 1;
