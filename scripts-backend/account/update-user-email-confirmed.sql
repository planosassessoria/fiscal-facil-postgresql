-- ============================================================================
-- Arquivo: update-user-email-confirmed.sql
-- Operação: UPDATE
-- Schema/Tabela: account.users
-- Descrição: Confirma o e-mail de um usuário, alterando a flag
--            email_confirmed para TRUE. Só atualiza se ainda não confirmado.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário a ser confirmado
--
-- Retorno: email, email_confirmed, change_password, accept_terms, updated_at
-- ============================================================================
UPDATE account.users
SET email_confirmed = TRUE,
    updated_at = NOW()
WHERE email = $1
  AND email_confirmed = FALSE
RETURNING email, email_confirmed, change_password, accept_terms, updated_at;
