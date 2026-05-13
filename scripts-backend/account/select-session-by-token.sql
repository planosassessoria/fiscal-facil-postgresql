-- ============================================================================
-- Arquivo: select-session-by-token.sql
-- Operação: SELECT
-- Schema/Tabela: account.users_sessions
-- Descrição: Busca uma sessão de usuário pelo refresh_token.
--            Usado na validação e renovação de tokens JWT.
--
-- Parâmetros:
--   $1 - refresh_token (VARCHAR) - Token de atualização da sessão
--
-- Retorno: session_id, email, ip_address, country, region, city,
--          latitude, longitude, created_at
-- ============================================================================
SELECT
	session_id,
	email,
	ip_address,
	country,
	region,
	city,
	latitude,
	longitude,
	created_at
FROM account.users_sessions
WHERE refresh_token = $1;
