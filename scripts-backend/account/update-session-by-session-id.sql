-- This file contains the SQL query for updating the refresh token and updated_at timestamp in the account.users_sessions table based on the session_id. The query takes two parameters: the session_id (used to identify the specific session to update) and the new refresh_token value. The updated_at column is set to the current timestamp using the clock_timestamp() function to reflect the time of the update.
-- This query is used in the account package to manage user sessions, allowing for the refresh token to be updated when necessary, such as during a token refresh process. The session_id is used as a condition in the WHERE clause to ensure that only the specified session is updated. The query does not return any results, as it is an UPDATE statement.
UPDATE account.users_sessions
SET
	refresh_token = $2,
	updated_at = clock_timestamp()
WHERE
	session_id = $1;
