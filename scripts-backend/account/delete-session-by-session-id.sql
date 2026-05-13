-- This file contains the SQL query for deleting a user session from the database.
-- It is used in the account package to delete a session for a user.
DELETE
FROM account.users_sessions
WHERE session_id = $1;
