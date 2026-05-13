-- ============================================================================
-- Arquivo: select-user-roles-by-account-type.sql
-- Operação: SELECT
-- Schema/Tabela: account.roles
-- Descrição: Lista perfis de acesso filtrados por tipo de conta.
--            ROOT visualiza todos os perfis; demais contas veem apenas
--            os perfis do seu tipo, excluindo perfis owner.
--
-- Parâmetros:
--   $1 - account_type (VARCHAR) - Tipo da conta (ROOT, COUNTER, CLIENT)
--
-- Retorno: role_id, role_name, account_type, is_system, modules, permissions
-- ============================================================================
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
