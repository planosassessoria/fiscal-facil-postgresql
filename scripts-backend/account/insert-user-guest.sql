-- This file contains the SQL query for inserting a new guest user into the account.users table.
-- The query takes the email, email confirmation status, full name, gender ID, birth date, telefone, password, change password status, and acceptance of terms as parameters to create a new guest user record in the database.
INSERT INTO account.users (
	email,
	email_confirmed,
	full_name,
	gender_id,
	birth_date,
	telefone,
	password,
	change_password,
	accept_terms
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
	$9
);
