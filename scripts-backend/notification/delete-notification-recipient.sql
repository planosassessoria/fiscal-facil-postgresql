-- ============================================================================
-- Arquivo: delete-notification-recipient.sql
-- Operação: DELETE
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Remove o vínculo entre o usuário e uma notificação específica
--            (equivale a "dispensar" a notificação do painel do usuário).
--            Não remove a notificação em si — apenas o destinatário.
--            A cláusula AND user_email garante isolamento: o usuário só
--            pode remover notificações das quais é destinatário.
--
-- Parâmetros:
--   $1 - notification_id (UUID)    - ID da notificação a remover
--   $2 - user_email (VARCHAR)      - E-mail do usuário autenticado (do JWT)
--
-- Retorno: Nenhum
-- ============================================================================
DELETE FROM notification.notification_recipients
WHERE
	notification_id = $1
	AND user_email  = $2;
