-- ============================================================================
-- Arquivo: update-all-notifications-read.sql
-- Operação: UPDATE
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Marca todas as notificações não lidas do usuário como lidas.
--            Corresponde à ação "Marcar todas como lidas" no painel.
--            Filtra apenas is_read = FALSE para evitar writes desnecessários
--            em registros já lidos.
--
-- Parâmetros:
--   $1 - user_email (VARCHAR) - E-mail do usuário autenticado (do JWT)
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE notification.notification_recipients
SET
	is_read = TRUE,
	read_at = clock_timestamp()
WHERE
	user_email = $1
	AND is_read = FALSE;
