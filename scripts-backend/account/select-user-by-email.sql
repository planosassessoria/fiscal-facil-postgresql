-- This file contains the SQL query for selecting a user from the database by their email address.
-- It is used in the account package to retrieve user information based on their email, including their tenant and role associations.
SELECT
	u.email,
	u.full_name,
	u.display_name,
	u.gender_id,
	u.birth_date,
	u.avatar,
	u.cpf,
	u.telefone,
	u.password,
	u.root,
	u.email_confirmed,
	u.change_password,
	u.accept_terms,
	u.created_at,
	u.updated_at,
	ut.tenant_id,
	ut.role_id
FROM account.users u
LEFT JOIN account.users_tenants ut USING(email)
WHERE u.email = $1
LIMIT 1;
