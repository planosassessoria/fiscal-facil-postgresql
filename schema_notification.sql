-- =============================================================================
-- SCHEMA: notification
-- PROJETO: Fiscal Fácil
-- DATA: 2026-05-20
-- DESCRIÇÃO: Schema de notificações do sistema. Gerencia alertas em tempo real
--            e persistidos para usuários e tenants. Suporta múltiplos escopos
--            de entrega: usuário individual, tenant, estabelecimento, tipo de
--            conta (account_type) e broadcast para todos os usuários.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS notification;
ALTER SCHEMA notification OWNER TO dorcilio;

COMMENT ON SCHEMA notification IS
    'Schema de notificações do sistema. Gerencia alertas em tempo real e persistidos para '
    'usuários e tenants. Suporta escopos: USER, TENANT, ESTABLISHMENT, ACCOUNT_TYPE, BROADCAST.';

-- -----------------------------------------------------------------------------
-- 1. TABELAS
-- -----------------------------------------------------------------------------

-- Tabela: Notifications
--
-- Escopos de entrega (notif_scope):
--   USER          → target_user_email obrigatório + tenant_id obrigatório
--   TENANT        → tenant_id obrigatório
--   ESTABLISHMENT → tenant_id + est_id obrigatórios
--   ACCOUNT_TYPE  → target_account_type obrigatório (OFFICE|ACCOUNTANT|COMPANY|INDIVIDUAL)
--   BROADCAST     → todos os usuários em account.users (sem campos de alvo obrigatórios)
--
-- Resolução de destinatários: o backend expande o escopo para linhas individuais
-- em notification_recipients via account.users_tenants (ver SendNotificationUseCase).
--
-- notif_type: campo aberto (sem CHECK constraint) — extensível sem migração.
-- Padrão de nomenclatura: {CATEGORIA}_{ACAO} em UPPER_SNAKE_CASE.
-- Categorias: IMPORT_, REPORT_, CERTIFICATE_, TASK_, TEAM_, SYSTEM_
-- Ponto único de verdade: src/models/notification.js (NOTIFICATION_TYPES)
CREATE TABLE IF NOT EXISTS notification.notifications (
    -- Chaves e vínculos
    notification_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id           UUID,                                        -- NULL em BROADCAST e ACCOUNT_TYPE
    est_id              UUID,                                        -- NULL em BROADCAST, ACCOUNT_TYPE e TENANT
    created_by          VARCHAR(320),                                -- NULL = gerado automaticamente pelo sistema

    -- Escopo e alvo
    notif_scope         VARCHAR(30)  NOT NULL DEFAULT 'TENANT',
    target_user_email   VARCHAR(320),                                -- Obrigatório quando notif_scope = 'USER'
    target_account_type VARCHAR(30),                                 -- Obrigatório quando notif_scope = 'ACCOUNT_TYPE'

    -- Dados obrigatórios
    notif_type          VARCHAR(60)  NOT NULL,                       -- chave de NOTIFICATION_TYPES (aberto, sem CHECK)
    notif_title         VARCHAR(255) NOT NULL,
    notif_message       TEXT         NOT NULL,

    -- Dados opcionais
    notif_metadata      JSONB        NOT NULL DEFAULT '{}',
    notif_action_url    VARCHAR(500),
    expires_at          TIMESTAMPTZ,                                 -- NULL = não expira

    -- Timestamps
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),

    -- Chave primária
    CONSTRAINT notifications_pkey PRIMARY KEY (notification_id),

    -- Integridade referencial
    CONSTRAINT fk_notifications_tenant FOREIGN KEY (tenant_id)
        REFERENCES partner.tenants(tenant_id) ON DELETE CASCADE,

    CONSTRAINT fk_notifications_establishment FOREIGN KEY (est_id)
        REFERENCES partner.establishments(est_id) ON DELETE SET NULL,

    CONSTRAINT fk_notifications_created_by FOREIGN KEY (created_by)
        REFERENCES account.users(email) ON DELETE SET NULL,

    CONSTRAINT fk_notifications_target_user FOREIGN KEY (target_user_email)
        REFERENCES account.users(email) ON DELETE CASCADE,

    -- Domínio: escopos válidos (fechado — requer migração para adicionar novo escopo)
    CONSTRAINT ck_notifications_scope CHECK (notif_scope IN (
        'USER', 'TENANT', 'ESTABLISHMENT', 'ACCOUNT_TYPE', 'BROADCAST'
    )),

    -- Domínio: account_type válido quando preenchido
    CONSTRAINT ck_notifications_account_type CHECK (
        target_account_type IS NULL OR
        target_account_type IN ('OFFICE', 'ACCOUNTANT', 'COMPANY', 'INDIVIDUAL')
    ),

    -- Consistência de escopo: garantia no banco de que os campos de alvo estão corretos
    CONSTRAINT ck_scope_user_requires_email
        CHECK (notif_scope != 'USER' OR target_user_email IS NOT NULL),

    CONSTRAINT ck_scope_account_type_requires_type
        CHECK (notif_scope != 'ACCOUNT_TYPE' OR target_account_type IS NOT NULL),

    CONSTRAINT ck_scope_tenant_requires_tenant_id
        CHECK (notif_scope NOT IN ('TENANT', 'ESTABLISHMENT', 'USER') OR tenant_id IS NOT NULL),

    CONSTRAINT ck_scope_establishment_requires_est_id
        CHECK (notif_scope != 'ESTABLISHMENT' OR est_id IS NOT NULL)
);

ALTER TABLE notification.notifications OWNER TO dorcilio;

COMMENT ON TABLE  notification.notifications                       IS 'Notificações do sistema. Suporta múltiplos escopos de entrega. Destinatários individuais ficam em notification_recipients.';
COMMENT ON COLUMN notification.notifications.notification_id      IS 'Identificador único da notificação (UUID).';
COMMENT ON COLUMN notification.notifications.tenant_id            IS 'Tenant relacionado. NULL nos escopos BROADCAST e ACCOUNT_TYPE.';
COMMENT ON COLUMN notification.notifications.est_id               IS 'Estabelecimento relacionado. Preenchido nos escopos ESTABLISHMENT e USER.';
COMMENT ON COLUMN notification.notifications.created_by           IS 'E-mail do usuário que gerou a notificação (FK para account.users). NULL quando gerada pelo sistema.';
COMMENT ON COLUMN notification.notifications.notif_scope          IS 'Escopo de entrega: USER | TENANT | ESTABLISHMENT | ACCOUNT_TYPE | BROADCAST.';
COMMENT ON COLUMN notification.notifications.target_user_email    IS 'Destinatário único (FK para account.users). Obrigatório quando notif_scope = USER.';
COMMENT ON COLUMN notification.notifications.target_account_type  IS 'Tipo de conta alvo. Obrigatório quando notif_scope = ACCOUNT_TYPE (OFFICE, ACCOUNTANT, COMPANY, INDIVIDUAL).';
COMMENT ON COLUMN notification.notifications.notif_type           IS 'Tipo da notificação. Campo aberto — sem CHECK constraint para permitir extensão sem migração. Padrão: {CATEGORIA}_{ACAO} em UPPER_SNAKE_CASE. Ex: IMPORT_NFE_NFCE, CERTIFICATE_EXPIRING. Ponto único de verdade: src/models/notification.js.';
COMMENT ON COLUMN notification.notifications.notif_title          IS 'Título resumido exibido no painel de notificações.';
COMMENT ON COLUMN notification.notifications.notif_message        IS 'Mensagem completa da notificação.';
COMMENT ON COLUMN notification.notifications.notif_metadata       IS 'Dados livres em JSON específicos por tipo. Ex: { importJobId, nfeKey, reportId, certAlias }.';
COMMENT ON COLUMN notification.notifications.notif_action_url     IS 'Rota interna opcional para navegação ao clicar no item. Ex: /relatorios/123, /importacoes/456.';
COMMENT ON COLUMN notification.notifications.expires_at           IS 'Data de expiração da notificação. NULL indica sem expiração.';
COMMENT ON COLUMN notification.notifications.created_at           IS 'Timestamp de criação da notificação.';


-- Tabela: Notification Recipients
--
-- Populada pelo backend (SendNotificationUseCase) após resolução do notif_scope.
-- Uma linha por usuário destinatário, independente de como a notificação foi endereçada.
-- Rastreia leitura individualmente por usuário.
-- ON DELETE CASCADE em notification_id e user_email: ao remover usuário ou notificação,
-- o vínculo é removido automaticamente sem deixar dados órfãos.
CREATE TABLE IF NOT EXISTS notification.notification_recipients (
    -- Chaves
    recipient_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID         NOT NULL,
    user_email      VARCHAR(320) NOT NULL,

    -- Estado de leitura
    is_read         BOOLEAN      NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ,

    -- Timestamps
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),

    -- Chave primária
    CONSTRAINT notification_recipients_pkey PRIMARY KEY (recipient_id),

    -- Garante que o mesmo usuário não seja inserido duas vezes para a mesma notificação
    CONSTRAINT uk_notification_recipients_notif_user UNIQUE (notification_id, user_email),

    CONSTRAINT fk_recipients_notification FOREIGN KEY (notification_id)
        REFERENCES notification.notifications(notification_id) ON DELETE CASCADE,

    CONSTRAINT fk_recipients_user FOREIGN KEY (user_email)
        REFERENCES account.users(email) ON DELETE CASCADE
);

ALTER TABLE notification.notification_recipients OWNER TO dorcilio;

COMMENT ON TABLE  notification.notification_recipients                  IS 'Destinatários individuais de cada notificação. Gerada pelo backend após resolução do notif_scope. Rastreia leitura por usuário.';
COMMENT ON COLUMN notification.notification_recipients.recipient_id    IS 'Identificador único do vínculo destinatário-notificação (UUID).';
COMMENT ON COLUMN notification.notification_recipients.notification_id IS 'Notificação vinculada (FK para notification.notifications). Cascade delete.';
COMMENT ON COLUMN notification.notification_recipients.user_email      IS 'E-mail do usuário destinatário (FK para account.users). Identificador natural no sistema. Cascade delete.';
COMMENT ON COLUMN notification.notification_recipients.is_read         IS 'Indica se o usuário visualizou a notificação.';
COMMENT ON COLUMN notification.notification_recipients.read_at         IS 'Timestamp exato do momento da leitura.';
COMMENT ON COLUMN notification.notification_recipients.created_at      IS 'Timestamp de criação do vínculo (quando a notificação foi entregue ao usuário).';
COMMENT ON COLUMN notification.notification_recipients.updated_at      IS 'Timestamp da última atualização (ex: marcação de leitura).';

-- -----------------------------------------------------------------------------
-- 2. ÍNDICES
-- -----------------------------------------------------------------------------

-- notifications: filtro por tenant + data (consulta mais frequente)
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_date
    ON notification.notifications (tenant_id, created_at DESC)
    WHERE tenant_id IS NOT NULL;

-- notifications: filtro por escopo + data (resolução de ACCOUNT_TYPE e BROADCAST)
CREATE INDEX IF NOT EXISTS idx_notifications_scope
    ON notification.notifications (notif_scope, created_at DESC);

-- notifications: filtro por account_type (scope ACCOUNT_TYPE)
CREATE INDEX IF NOT EXISTS idx_notifications_account_type
    ON notification.notifications (target_account_type)
    WHERE target_account_type IS NOT NULL;

-- notifications: filtro por estabelecimento (scope ESTABLISHMENT)
CREATE INDEX IF NOT EXISTS idx_notifications_est
    ON notification.notifications (est_id)
    WHERE est_id IS NOT NULL;

-- notifications: limpeza de notificações expiradas (job agendado)
CREATE INDEX IF NOT EXISTS idx_notifications_expires
    ON notification.notifications (expires_at)
    WHERE expires_at IS NOT NULL;

-- notification_recipients: consulta principal do usuário (badge + lista)
CREATE INDEX IF NOT EXISTS idx_notif_recipients_user_read
    ON notification.notification_recipients (user_email, is_read);

-- notification_recipients: join com notifications na busca paginada
CREATE INDEX IF NOT EXISTS idx_notif_recipients_notif
    ON notification.notification_recipients (notification_id);

-- -----------------------------------------------------------------------------
-- 3. TRIGGERS
-- -----------------------------------------------------------------------------

-- Atualização automática de updated_at em notification_recipients
CREATE TRIGGER tr_upd_notification_recipients
    BEFORE UPDATE ON notification.notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();
