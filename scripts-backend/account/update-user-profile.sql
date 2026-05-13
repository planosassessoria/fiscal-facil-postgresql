-- This file contains the SQL query for updating a user's profile in the account.users table.
-- This query is used in the account package to update a user's profile information in the database.
UPDATE account.users
SET
	full_name = $2,
	display_name = $3,
	gender_id = $4,
	birth_date = $5,
	avatar = $6,
	cpf = $7,
	telefone = $8
WHERE
	email = $1
RETURNING *;
