-- This file contains the SQL query for inserting a user-tenant relationship into the account.users_tenants table.
-- It is used to associate a user with a specific tenant (company/office) and assign a role within that tenant.
INSERT INTO account.users_tenants (
	email,
	tenant_id,
	role_id
)
VALUES (
	$1,
	$2,
	$3
);
