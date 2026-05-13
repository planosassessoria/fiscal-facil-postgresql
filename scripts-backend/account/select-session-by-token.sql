-- This is the SQL query for selecting a user session from the database using a refresh token.
-- It is used in the account package to retrieve session information for a user based on their refresh token.
SELECT
	session_id,
	email,
	ip_address,
	country,
	region,
	city,
	latitude,
	longitude,
	created_at
FROM account.users_sessions
WHERE refresh_token = $1;
