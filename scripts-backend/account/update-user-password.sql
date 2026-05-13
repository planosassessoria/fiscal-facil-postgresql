-- This file contains the SQL query for updating a user's password and optionally setting the accept_terms flag.
-- The query updates the password for the user with the given email and sets change_password to FALSE after the password is changed.
UPDATE account.users
SET
    password = $2,
    change_password = FALSE,
    -- Só muda para TRUE se o valor enviado for TRUE.
    -- Se o usuário já aceitou antes, o valor se mantém.
    accept_terms = CASE
        WHEN accept_terms = FALSE THEN $3
        ELSE accept_terms
    END
WHERE
    email = $1;
