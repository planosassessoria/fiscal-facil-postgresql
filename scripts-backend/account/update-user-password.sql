-- ============================================================================
-- Arquivo: update-user-password.sql
-- Operação: UPDATE
-- Schema/Tabela: account.users
-- Descrição: Atualiza a senha do usuário e marca change_password como FALSE.
--            Opcionalmente atualiza accept_terms se ainda não foi aceito.
--
-- Parâmetros:
--   $1 - email (VARCHAR) - E-mail do usuário
--   $2 - password (VARCHAR) - Nova senha criptografada
--   $3 - accept_terms (BOOLEAN) - Aceite dos termos (só aplica se ainda FALSE)
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE account.users
SET
    password = $2,
    change_password = FALSE,
    -- Só muda para TRUE se o valor enviado for TRUE.
    -- Se o usuário já aceitou antes, o valor se mantém.
    accept_terms = CASE
        WHEN accept_terms = FALSE THEN $3
        ELSE accept_terms
    END
WHERE
    email = $1;
