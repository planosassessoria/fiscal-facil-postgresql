-- ============================================================================
-- Arquivo: insert-user-root.sql
-- Operação: INSERT
-- Schema/Tabela: account.users
-- Descrição: Insere um novo usuário com permissão root (administrador geral).
--            Usuários root possuem acesso irrestrito a todo o sistema.
--
-- Parâmetros:
--   $1  - email (VARCHAR) - E-mail do usuário
--   $2  - email_confirmed (BOOLEAN) - Status de confirmação do e-mail
--   $3  - full_name (VARCHAR) - Nome completo
--   $4  - display_name (VARCHAR) - Nome de exibição
--   $5  - gender_id (INT) - ID do gênero
--   $6  - birth_date (DATE) - Data de nascimento
--   $7  - cpf (VARCHAR) - CPF do usuário
--   $8  - telefone (VARCHAR) - Número de telefone
--   $9  - password (VARCHAR) - Senha criptografada
--   $10 - accept_terms (BOOLEAN) - Aceite dos termos de uso
--   $11 - root (BOOLEAN) - Flag de administrador root
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO account.users (
	email,
	email_confirmed,
	full_name,
	display_name,
	gender_id,
	birth_date,
	cpf,
	telefone,
	password,
	accept_terms,
	root
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10,
	$11
);
