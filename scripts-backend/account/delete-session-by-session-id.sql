-- ============================================================================
-- Arquivo: delete-session-by-session-id.sql
-- Operação: DELETE
-- Schema/Tabela: account.users_sessions
-- Descrição: Remove uma sessão específica do usuário (logout individual).
--
-- Parâmetros:
--   $1 - session_id (UUID) - ID da sessão a ser removida
--
-- Retorno: Nenhum
-- ============================================================================
DELETE
FROM account.users_sessions
WHERE session_id = $1;
