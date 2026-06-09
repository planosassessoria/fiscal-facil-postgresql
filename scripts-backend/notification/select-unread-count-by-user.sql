-- ============================================================================
-- Arquivo: select-unread-count-by-user.sql
-- Operação: SELECT
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Retorna a contagem de notificações não lidas do usuário.
--            Endpoint leve (GET /unread-count) — usado como fallback quando
--            o socket reconecta para sincronizar o badge sem recarregar a lista.
--
-- Parâmetros:
--   $1 - user_email (VARCHAR) - E-mail do usuário autenticado (do JWT)
--
-- Retorno: { count: INT }
-- ============================================================================
SELECT
	COUNT(*)::INT AS count
FROM notification.notification_recipients nr
JOIN notification.notifications n ON n.notification_id = nr.notification_id
WHERE
	nr.user_email = $1
	AND nr.is_read = FALSE
	AND (n.expires_at IS NULL OR n.expires_at > clock_timestamp());
