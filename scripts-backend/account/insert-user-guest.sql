-- ============================================================================
-- Arquivo: insert-user-guest.sql
-- Operação: INSERT
-- Schema/Tabela: account.users
-- Descrição: Insere um novo usuário convidado (guest) no sistema.
--            Usuários convidados são criados por um administrador e precisam
--            trocar a senha no primeiro acesso.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário convidado
--   $2 - email_confirmed (BOOLEAN) - Status de confirmação do e-mail
--   $3 - full_name (VARCHAR) - Nome completo
--   $4 - gender_id (INT) - ID do gênero
--   $5 - birth_date (DATE) - Data de nascimento
--   $6 - telefone (VARCHAR) - Número de telefone
--   $7 - password (VARCHAR) - Senha temporária criptografada
--   $8 - change_password (BOOLEAN) - Forçar troca de senha no próximo login
--   $9 - accept_terms (BOOLEAN) - Aceite dos termos de uso
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO account.users (
	email,
	email_confirmed,
	full_name,
	gender_id,
	birth_date,
	telefone,
	password,
	change_password,
	accept_terms
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
	$9
);
