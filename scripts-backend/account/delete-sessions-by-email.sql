-- ============================================================================
-- Arquivo: delete-sessions-by-email.sql
-- Operação: DELETE
-- Schema/Tabela: account.users_sessions
-- Descrição: Remove todas as sessões de um usuário (logout de todos os
--            dispositivos). Usado para forçar re-autenticação global.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--
-- Retorno: Nenhum
-- ============================================================================
DELETE
FROM account.users_sessions
WHERE email = $1;
