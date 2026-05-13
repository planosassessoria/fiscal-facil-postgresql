-- ============================================================================
-- Arquivo: select-user-has-permission-role-id.sql
-- Operação: SELECT
-- Schema/Tabela: account.roles
-- Descrição: Verifica se um perfil (role) possui acesso a um determinado
--            módulo e, opcionalmente, a uma permissão específica.
--            Usado na autorização de rotas (middleware RBAC).
--
-- Parâmetros:
--   $1 - role_id (UUID) - ID do perfil a ser verificado
--   $2 - permission_key (TEXT) - Chave da permissão (NULL = apenas módulo)
--   $3 - module_key (TEXT) - Chave do módulo (obrigatório)
--
-- Retorno: authorized (BOOLEAN) - TRUE se possui acesso
-- ============================================================================
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
