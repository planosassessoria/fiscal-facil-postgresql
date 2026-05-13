-- This file contains the SQL query for inserting a new user into the account.users table.
-- The query takes the email, email confirmation status, full name, display name, gender ID, birth date, CPF, telefone, password, acceptance of terms, and root status as parameters to create a new user record in the database.
INSERT INTO account.users (
	email,
	email_confirmed,
	full_name,
	display_name,
	gender_id,
	birth_date,
	cpf,
	telefone,
	password,
	accept_terms,
	root
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10,
	$11
);
