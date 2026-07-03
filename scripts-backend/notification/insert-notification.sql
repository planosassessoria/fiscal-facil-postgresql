-- ============================================================================
-- Arquivo: insert-notification.sql
-- Operação: INSERT
-- Schema/Tabela: notification.notifications
-- Descrição: Insere uma nova notificação no sistema. Chamado pelo
--            SendNotificationUseCase antes de popular os destinatários.
--            O campo notif_type é livre (sem CHECK) — seguir o padrão
--            {CATEGORIA}_{ACAO} definido em NOTIFICATION_TYPES.
--
-- Parâmetros:
--   $1  - tenant_id (UUID|NULL)        - Tenant alvo. NULL em BROADCAST/ACCOUNT_TYPE
--   $2  - est_id (UUID|NULL)           - Estabelecimento alvo. NULL em BROADCAST/ACCOUNT_TYPE/TENANT
--   $3  - created_by (VARCHAR|NULL)    - E-mail do remetente. NULL = sistema
--   $4  - notif_scope (VARCHAR)        - USER|TENANT|ESTABLISHMENT|ACCOUNT_TYPE|BROADCAST
--   $5  - target_user_email (VARCHAR|NULL) - Obrigatório quando notif_scope = 'USER'
--   $6  - target_account_type (VARCHAR|NULL) - Obrigatório quando notif_scope = 'ACCOUNT_TYPE'
--   $7  - notif_type (VARCHAR)         - Tipo da notificação (ex: IMPORT_NFE_NFCE)
--   $8  - notif_title (VARCHAR)        - Título exibido no painel
--   $9  - notif_message (TEXT)         - Mensagem completa
--   $10 - notif_metadata (JSONB)       - Dados livres por tipo (ex: { importJobId })
--   $11 - notif_action_url (VARCHAR|NULL) - Rota interna opcional (ex: /relatorios/123)
--   $12 - expires_at (TIMESTAMPTZ|NULL) - Data de expiração. NULL = sem expiração
--
-- Retorno: notification_id, notif_type, notif_scope e created_at da notificação criada
-- ============================================================================
INSERT INTO notification.notifications (
	tenant_id,
	est_id,
	created_by,
	notif_scope,
	target_user_email,
	target_account_type,
	notif_type,
	notif_title,
	notif_message,
	notif_metadata,
	notif_action_url,
	expires_at
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10::JSONB,
	$11,
	$12
)
RETURNING
	notification_id,
	notif_type,
	notif_title,
	notif_message,
	notif_scope,
	target_user_email,
	target_account_type,
	notif_metadata,
	notif_action_url,
	created_at;
