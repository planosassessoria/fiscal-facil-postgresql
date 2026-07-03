-- ============================================================================
-- Arquivo: update-notification-read.sql
-- Operação: UPDATE
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Marca uma notificação específica como lida para o usuário.
--            A cláusula AND user_email garante que o usuário só pode marcar
--            notificações das quais é destinatário (proteção extra além da
--            verificação prévia via select-recipient-exists.sql).
--
-- Parâmetros:
--   $1 - notification_id (UUID)    - ID da notificação a marcar como lida
--   $2 - user_email (VARCHAR)      - E-mail do usuário autenticado (do JWT)
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE notification.notification_recipients
SET
	is_read = TRUE,
	read_at = clock_timestamp()
WHERE
	notification_id = $1
	AND user_email  = $2
	AND is_read     = FALSE;
