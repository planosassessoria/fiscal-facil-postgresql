-- This file contains the SQL query for confirming a user's email address.
-- Updates the email_confirmed flag to TRUE for the given email.
UPDATE account.users
SET email_confirmed = TRUE,
    updated_at = NOW()
WHERE email = $1
  AND email_confirmed = FALSE
RETURNING email, email_confirmed, change_password, accept_terms, updated_at;
