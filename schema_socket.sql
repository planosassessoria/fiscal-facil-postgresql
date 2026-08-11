-- =============================================================================
-- SCHEMA: socket
-- PROJETO: Fiscal Fácil
-- DATA: 2026-05-06
-- DESCRIÇÃO: Gestão de conexões em tempo real via WebSockets (Socket.io).
--            Registra e controla as sessões ativas de usuários e serviços externos (APIs).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS socket;
ALTER SCHEMA socket OWNER TO dorcilio;

COMMENT ON SCHEMA socket IS 'Schema responsável pela gestão de conexões em tempo real via WebSockets.';

-- -----------------------------------------------------------------------------
-- 1. TABELAS
-- -----------------------------------------------------------------------------

-- Tabela: Connections
CREATE TABLE IF NOT EXISTS socket.connections
(
    -- Identificadores e vínculos
    socket_id       character varying(60)    NOT NULL,
    user_email      character varying(320),
    tenant_id       uuid,
    current_est_id  uuid,

    -- Tipo de conexão
    is_system       boolean                  NOT NULL DEFAULT false,
    service_name    character varying(100),

    -- Estado e metadados da sessão
    is_connected    boolean                  DEFAULT true NOT NULL,
    user_agent      text,
    ip_address      inet,

    -- Timestamps
    created_at      timestamp with time zone DEFAULT clock_timestamp(),
    updated_at      timestamp with time zone DEFAULT clock_timestamp(),

    -- Constraints de integridade
    CONSTRAINT connections_pkey PRIMARY KEY (socket_id),

    CONSTRAINT fk_connections_user FOREIGN KEY (user_email)
        REFERENCES account.users (email)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_connections_tenant FOREIGN KEY (tenant_id)
        REFERENCES partner.tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,

    CONSTRAINT fk_connections_establishment FOREIGN KEY (current_est_id)
        REFERENCES partner.establishments (est_id)
        ON UPDATE NO ACTION
        ON DELETE SET NULL,

    -- Garante que conexões de usuário possuam email e tenant
    CONSTRAINT ck_connections_user_required CHECK (
        is_system = true OR (user_email IS NOT NULL AND tenant_id IS NOT NULL)
    ),
    -- Garante que conexões de sistema possuam um nome de serviço
    CONSTRAINT ck_connections_system_required CHECK (
        is_system = false OR service_name IS NOT NULL
    )
);

ALTER TABLE socket.connections OWNER TO dorcilio;

COMMENT ON TABLE socket.connections IS
    'Controle de sessões ativas do Socket.io. Suporta conexões de usuários (com tenant) e de serviços externos (is_system = true).';

COMMENT ON COLUMN socket.connections.socket_id IS
    'ID único da conexão gerado pelo servidor Socket.io.';

COMMENT ON COLUMN socket.connections.user_email IS
    'E-mail do usuário proprietário da conexão (FK para account.users). NULL quando is_system = true.';

COMMENT ON COLUMN socket.connections.tenant_id IS
    'ID do tenant onde a conexão foi estabelecida. NULL quando is_system = true.';

COMMENT ON COLUMN socket.connections.current_est_id IS
    'ID do estabelecimento que o usuário está visualizando no momento (opcional).';

COMMENT ON COLUMN socket.connections.is_connected IS
    'Sinaliza se a conexão via socket ainda é considerada ativa.';

COMMENT ON COLUMN socket.connections.user_agent IS
    'Informações do navegador ou dispositivo que originou a conexão.';

COMMENT ON COLUMN socket.connections.ip_address IS
    'Endereço IP de origem da conexão para fins de auditoria e segurança.';

COMMENT ON COLUMN socket.connections.created_at IS
    'Data e hora em que a conexão foi registrada no banco.';

COMMENT ON COLUMN socket.connections.is_system IS
    'Indica se a conexão pertence a um serviço externo ou API, sem vínculo com usuário ou tenant.';

COMMENT ON COLUMN socket.connections.service_name IS
    'Nome do serviço responsável pela conexão quando is_system = true (ex: "importador-xml", "bot-fiscal", "monolito"). NULL para conexões de usuário.';

COMMENT ON COLUMN socket.connections.updated_at IS
    'Data e hora da última atividade ou atualização da sessão.';

-- -----------------------------------------------------------------------------
-- 2. ÍNDICES
-- -----------------------------------------------------------------------------

-- Índices parciais: evitam incluir linhas de sistema nos índices de usuário
CREATE INDEX IF NOT EXISTS idx_connections_user_email
    ON socket.connections USING btree (user_email)
    WHERE is_system = false;

CREATE INDEX IF NOT EXISTS idx_connections_tenant_id
    ON socket.connections USING btree (tenant_id)
    WHERE is_system = false;

CREATE INDEX IF NOT EXISTS idx_connections_is_system
    ON socket.connections USING btree (is_system);

-- Índice parcial: cobre buscas por nome de serviço somente para conexões de sistema
CREATE INDEX IF NOT EXISTS idx_connections_service_name
    ON socket.connections USING btree (service_name)
    WHERE is_system = true;

-- -----------------------------------------------------------------------------
-- 3. TRIGGERS
-- -----------------------------------------------------------------------------

CREATE TRIGGER tr_upd_connections
    BEFORE UPDATE ON socket.connections
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();
