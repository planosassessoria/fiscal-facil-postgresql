-- This file contains the SQL query for selecting a user system by email. It retrieves the user's information along with their associated tenant and role details.
-- The query uses LEFT JOINs to ensure that it returns results even if the user does not have an associated tenant or role. The result includes the user's email, CPF, full name, display name, root status, email confirmation status, password change requirement, terms acceptance, tenant ID, account type, role ID, role name, account type based on root status, ownership status, and timestamps for creation and last update.
SELECT
	u.email,
	u.cpf,
	u.full_name,
	u.display_name,
	u.root,
	u.email_confirmed,
	u.change_password,
	u.accept_terms,
	ut.tenant_id,
	t.account_type,
	ut.role_id,
	CASE
		WHEN u.root = TRUE
			THEN 'Root'
		ELSE r.role_name
		END AS role_name,
	CASE
		WHEN u.root = TRUE
			THEN 'ROOT'
		ELSE r.account_type
		END AS account_type,
	COALESCE(r.is_owner, FALSE) AS is_owner,
	u.created_at,
	u.updated_at
FROM account.users u
LEFT JOIN account.users_tenants ut USING (email)
LEFT JOIN account.roles r USING (role_id)
LEFT JOIN partner.tenants t USING (tenant_id)
WHERE u.email = $1 LIMIT 1;
