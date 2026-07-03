-- ============================================================================
-- Arquivo: insert-notification-recipients-bulk.sql
-- Operação: INSERT (bulk)
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Insere múltiplos destinatários de uma notificação em lote.
--            Chamado pelo SendNotificationUseCase após resolução do notif_scope
--            e obtenção da lista de e-mails destinatários.
--
--            Montagem do VALUES via pg-format no backend:
--              const rows = emails.map(email => [notificationId, email])
--              const sql  = format(query, rows)   // substitui %%L
--
--            ON CONFLICT DO NOTHING: idempotente — reenvios não duplicam.
--
-- Parâmetros:
--   %%L - Array de pares [notification_id (UUID), user_email (VARCHAR)]
--        Interpolado pelo backend via pg-format antes de executar.
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO notification.notification_recipients (notification_id, user_email)
VALUES %L
ON CONFLICT (notification_id, user_email) DO NOTHING;
