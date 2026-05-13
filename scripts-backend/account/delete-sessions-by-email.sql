-- This is the SQL query for deleting all user sessions associated with a specific email address.
-- It is used in the account package to log out a user from all devices by removing all their sessions.
DELETE
FROM account.users_sessions
WHERE email = $1;
