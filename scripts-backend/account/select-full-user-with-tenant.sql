-- This is the SQL query for selecting a full user profile along with tenant and establishment information based on the user's email.
-- It retrieves user details such as email, full name, display name, gender, birth date, avatar, CPF, phone number, role information, tenant information, and associated establishment details.
SELECT
	u.email,
	u.email_confirmed,
	u.full_name,
	u.display_name,
	u.gender_id,
	g.gender_name,
	u.birth_date,
	u.avatar,
	u.cpf,
	u.telefone,
	u.change_password,
	u.accept_terms,
	u.root,
	ut.role_id,
	r.role_name,
	r.account_type,
	r.is_owner,
	r.modules,
	ut.tenant_id,
	ut.is_active,
	t.est_id,
	e.document,
	e.document_type,
	e.situacao,
	e.ie,
	e.uf,
	e.razao_social,
	e.fantasia,
	e.telefone AS est_telefone,
	e.telefone_secundario,
	e.email AS est_email
FROM account.users u
JOIN account.genders g USING (gender_id)
LEFT JOIN account.users_tenants ut USING (email)
LEFT JOIN account.roles r USING (role_id)
LEFT JOIN partner.tenants t USING (tenant_id)
LEFT JOIN partner.establishments e USING (est_id)
WHERE u.email = $1;
