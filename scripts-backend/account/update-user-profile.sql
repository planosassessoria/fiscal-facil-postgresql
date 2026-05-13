-- ============================================================================
-- Arquivo: update-user-profile.sql
-- Operação: UPDATE
-- Schema/Tabela: account.users
-- Descrição: Atualiza os dados do perfil do usuário (nome, gênero, avatar,
--            telefone, etc). Retorna o registro atualizado.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário (identifica o registro)
--   $2 - full_name (VARCHAR) - Nome completo
--   $3 - display_name (VARCHAR) - Nome de exibição
--   $4 - gender_id (INT) - ID do gênero
--   $5 - birth_date (DATE) - Data de nascimento
--   $6 - avatar (VARCHAR) - URL do avatar
--   $7 - cpf (VARCHAR) - CPF do usuário
--   $8 - telefone (VARCHAR) - Número de telefone
--
-- Retorno: Registro completo do usuário atualizado (RETURNING *)
-- ============================================================================
UPDATE account.users
SET
	full_name = $2,
	display_name = $3,
	gender_id = $4,
	birth_date = $5,
	avatar = $6,
	cpf = $7,
	telefone = $8
WHERE
	email = $1
RETURNING *;
