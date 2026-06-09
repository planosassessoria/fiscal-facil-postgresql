-- ============================================================================
-- Arquivo: select-all-emails.sql
-- Operação: SELECT
-- Schema/Tabela: account.users
-- Descrição: Retorna os e-mails de todos os usuários com e-mail confirmado.
--            Usado pelo SendNotificationUseCase para resolver destinatários
--            quando notif_scope = 'BROADCAST'.
--
--            Critério de "usuário válido para broadcast": email_confirmed = TRUE.
--            Usuários com e-mail não confirmado ainda não concluíram o cadastro
--            e não devem receber notificações do sistema.
--
-- Parâmetros: Nenhum
--
-- Retorno: Lista de e-mails de todos os usuários com e-mail confirmado
-- ============================================================================
SELECT
	email
FROM account.users
WHERE
	email_confirmed = TRUE;
