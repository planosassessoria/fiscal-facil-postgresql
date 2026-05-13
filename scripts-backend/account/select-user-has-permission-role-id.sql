-- This file contains the SQL query for checking if a user has a specific permission based on their role.
-- The query checks if a role with the given role_id has access to a specific module and, optionally, a specific permission within that module.
SELECT EXISTS (
    SELECT 1
    FROM account.roles
    WHERE role_id = $1
      -- 1. O Módulo é OBRIGATÓRIO (Ex: 'users')
      AND modules ? $3::TEXT

      -- 2. A Permissão é OPCIONAL
      -- Se $2 for NULL, a condição abaixo é verdadeira (acesso apenas ao módulo).
      -- Se $2 for informado, ele exige que a permissão também esteja no JSONB.
      AND (
          $2::TEXT IS NULL
          OR permissions ? $2::TEXT
      )
) AS authorized;
