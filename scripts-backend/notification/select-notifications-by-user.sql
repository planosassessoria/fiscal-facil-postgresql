-- ============================================================================
-- Arquivo: select-notifications-by-user.sql
-- Operação: SELECT
-- Schema/Tabela: notification.notification_recipients + notification.notifications
-- Descrição: Lista notificações do usuário autenticado com paginação.
--            Retorna apenas notificações onde o usuário é destinatário.
--            Ordenação fixa: mais recentes primeiro.
--            rows_number: total de registros para controle de hasMore no frontend.
--
-- Parâmetros:
--   $1 - user_email (VARCHAR) - E-mail do usuário autenticado (do JWT)
--   $2 - limit (INT)          - Quantidade máxima de registros a retornar
--   $3 - offset (INT)         - Deslocamento para paginação (page - 1) * limit
--
-- Retorno: Lista paginada de notificações com estado de leitura + rows_number
-- ============================================================================
SELECT
	n.notification_id,
	n.notif_type,
	n.notif_title,
	n.notif_message,
	n.notif_metadata,
	n.notif_action_url,
	n.created_at,
	nr.is_read,
	nr.read_at,
	COUNT(*) OVER () AS rows_number
FROM notification.notification_recipients nr
JOIN notification.notifications n ON n.notification_id = nr.notification_id
WHERE
	nr.user_email = $1
	AND (n.expires_at IS NULL OR n.expires_at > clock_timestamp())
ORDER BY
	n.created_at DESC
LIMIT  $2
OFFSET $3;
