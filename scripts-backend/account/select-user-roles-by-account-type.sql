-- This file contains the SQL query for selecting user roles by account type.
-- It is used to retrieve the role information for a specific account type, allowing for the differentiation between ROOT and non-ROOT roles. The query filters roles based on the provided account type and includes a condition to show owner roles only to ROOT accounts. The result includes the role ID, role name, account type, system flag, modules, and permissions, ordered by role name.
SELECT
    role_id,
    role_name,
    account_type,
    is_system,
    modules,
    permissions
FROM account.roles
WHERE
    -- Se for ROOT, traz tudo. Se não, filtra pelo tipo da conta.
    ($1 = 'ROOT' OR account_type = $1)

    -- Se for ROOT, permite ver Owners. Se não, oculta todos os is_owner = true.
    AND ($1 = 'ROOT' OR is_owner IS FALSE)
ORDER BY role_name;
