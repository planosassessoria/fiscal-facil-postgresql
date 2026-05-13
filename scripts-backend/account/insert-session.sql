-- This file contains the SQL query for inserting a new user session into the database.
-- It is used in the account package to create a new session for a user.
INSERT INTO account.users_sessions (
	email,
	refresh_token,
	ip_address,
	country,
	region,
	city,
	latitude,
	longitude
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8
) RETURNING *;
