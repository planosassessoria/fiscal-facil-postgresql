-- This file contains the SQL query for inserting a new user into the account.users table.
-- This query is used in the account package to insert a new user into the database.
INSERT INTO account.users (
	email,
	full_name,
	gender_id,
	telefone,
	password,
	accept_terms
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6
);
