-- ============================================================================
-- Arquivo: insert-user.sql
-- Operação: INSERT
-- Schema/Tabela: account.users
-- Descrição: Insere um novo usuário na tabela de usuários do sistema.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário (identificador único)
--   $2 - full_name (VARCHAR) - Nome completo do usuário
--   $3 - gender_id (INT) - ID do gênero
--   $4 - telefone (VARCHAR) - Número de telefone
--   $5 - password (VARCHAR) - Senha criptografada
--   $6 - accept_terms (BOOLEAN) - Aceite dos termos de uso
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO account.users (
	email,
	full_name,
	gender_id,
	telefone,
	password,
	accept_terms
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6
);
