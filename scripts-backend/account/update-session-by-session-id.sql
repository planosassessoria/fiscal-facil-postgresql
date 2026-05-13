-- ============================================================================
-- Arquivo: update-session-by-session-id.sql
-- Operação: UPDATE
-- Schema/Tabela: account.users_sessions
-- Descrição: Atualiza o refresh_token de uma sessão ativa.
--            Usado no processo de renovação de tokens (token rotation).
--
-- Parâmetros:
--   $1 - session_id (UUID) - ID da sessão a ser atualizada
--   $2 - refresh_token (VARCHAR) - Novo token de atualização
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE account.users_sessions
SET
	refresh_token = $2,
	updated_at = clock_timestamp()
WHERE
	session_id = $1;
