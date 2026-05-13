-- ============================================================================
-- Arquivo: insert-session.sql
-- Operação: INSERT
-- Schema/Tabela: account.users_sessions
-- Descrição: Cria uma nova sessão de usuário no sistema, registrando dados
--            de localização geográfica para auditoria e segurança.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--   $2 - refresh_token (VARCHAR) - Token de atualização da sessão
--   $3 - ip_address (VARCHAR) - Endereço IP do cliente
--   $4 - country (VARCHAR) - País de origem
--   $5 - region (VARCHAR) - Região/estado de origem
--   $6 - city (VARCHAR) - Cidade de origem
--   $7 - latitude (NUMERIC) - Latitude geográfica
--   $8 - longitude (NUMERIC) - Longitude geográfica
--
-- Retorno: Registro completo da sessão criada (RETURNING *)
-- ============================================================================
INSERT INTO account.users_sessions (
	email,
	refresh_token,
	ip_address,
	country,
	region,
	city,
	latitude,
	longitude
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8
) RETURNING *;
