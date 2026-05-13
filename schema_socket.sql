-- =============================================================================
-- SCHEMA: socket
-- PROJETO: Fiscal Fácil
-- DATA: 2026-05-06
-- DESCRIÇÃO: Gestão de conexões em tempo real via WebSockets (Socket.io).
--            Registra e controla as sessões ativas de cada usuário/tenant.
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
    user_email      character varying(320)   NOT NULL,
    tenant_id       uuid                     NOT NULL,
    current_est_id  uuid,

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
        ON DELETE SET NULL
);

ALTER TABLE socket.connections OWNER TO dorcilio;

COMMENT ON TABLE socket.connections IS
    'Controle de sessões ativas do Socket.io. Mapeia o ID do socket para o e-mail do usuário e o contexto do tenant.';

COMMENT ON COLUMN socket.connections.socket_id IS
    'ID único da conexão gerado pelo servidor Socket.io.';

COMMENT ON COLUMN socket.connections.user_email IS
    'E-mail do usuário proprietário da conexão (FK para account.users).';

COMMENT ON COLUMN socket.connections.tenant_id IS
    'ID do tenant (escritório/empresa) onde a conexão foi estabelecida.';

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

COMMENT ON COLUMN socket.connections.updated_at IS
    'Data e hora da última atividade ou atualização da sessão.';

-- -----------------------------------------------------------------------------
-- 2. ÍNDICES
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_connections_user_email
    ON socket.connections USING btree (user_email);

CREATE INDEX IF NOT EXISTS idx_connections_tenant_id
    ON socket.connections USING btree (tenant_id);

-- -----------------------------------------------------------------------------
-- 3. TRIGGERS
-- -----------------------------------------------------------------------------

CREATE TRIGGER tr_upd_connections
    BEFORE UPDATE ON socket.connections
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();
