-- =============================================================================
-- SCHEMA: history
-- PROJETO: Fiscal Fácil
-- DATA: 2026-03-17
-- DESCRIÇÃO: Repositório central de logs, auditoria e eventos (Roadmap).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS history;
ALTER SCHEMA history OWNER TO dorcilio;

COMMENT ON SCHEMA history IS
    'Schema central de auditoria e rastreabilidade. Registra todos os eventos relevantes do sistema '
    'em roadmap_events, segmentados por escopo (USER, TENANT, SYSTEM, PARTNER). '
    'Utilizado para timelines, auditorias de compliance e análise de comportamento.';

-- -----------------------------------------------------------------------------
-- 1. TABELAS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS history.roadmap_events (
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid,
    user_email character varying(320),
    tax_id uuid,
    est_id uuid,
    category character varying(50) NOT NULL,
    action_type character varying(100) NOT NULL,
    description text NOT NULL,
    payload_before jsonb,
    payload_after jsonb,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    event_scope character varying(20) NOT NULL,

    CONSTRAINT roadmap_events_pkey PRIMARY KEY (event_id),
    CONSTRAINT roadmap_events_event_scope_check CHECK (
        event_scope::text = ANY (ARRAY['USER'::text, 'TENANT'::text, 'SYSTEM'::text, 'PARTNER'::text])
    )
);

ALTER TABLE history.roadmap_events OWNER TO dorcilio;

-- -----------------------------------------------------------------------------
-- 2. DOCUMENTAÇÃO
-- -----------------------------------------------------------------------------

COMMENT ON TABLE history.roadmap_events IS 'Repositório central de eventos. Suporta auditoria de conta (USER) e de negócio (TENANT).';

COMMENT ON COLUMN history.roadmap_events.event_id IS 'Identificador único do evento de auditoria.';
COMMENT ON COLUMN history.roadmap_events.tenant_id IS 'ID do Tenant onde a ação ocorreu. Nulo para ações globais de sistema.';
COMMENT ON COLUMN history.roadmap_events.user_email IS 'E-mail do autor da ação. Rastro fundamental para auditoria.';
COMMENT ON COLUMN history.roadmap_events.tax_id IS 'Referência a uma entidade fiscal específica, se aplicável.';
COMMENT ON COLUMN history.roadmap_events.est_id IS 'Referência ao estabelecimento alvo da ação.';
COMMENT ON COLUMN history.roadmap_events.category IS 'Agrupador lógico: "AUTH", "FISCAL", "USER_MGMT", "ESTABLISHMENT".';
COMMENT ON COLUMN history.roadmap_events.action_type IS 'Ação específica: "LOGIN", "UPDATE_CNPJ", "DELETE_USER", etc.';
COMMENT ON COLUMN history.roadmap_events.description IS 'Texto humanizado descrevendo o que aconteceu.';
COMMENT ON COLUMN history.roadmap_events.payload_before IS 'Estado anterior do dado em formato JSON. Fundamental para "Undo" e auditoria.';
COMMENT ON COLUMN history.roadmap_events.payload_after IS 'Captura de tela dos dados após a alteração.';
COMMENT ON COLUMN history.roadmap_events.metadata IS 'Informações de contexto: { "ip": "1.1.1.1", "os": "Windows", "browser": "Chrome" }.';
COMMENT ON COLUMN history.roadmap_events.event_scope IS 'USER: Ações de conta. TENANT: Ações em empresas. SYSTEM: Robôs/Sincronização. PARTNER: Ações do escritório sobre parceiros.';
COMMENT ON COLUMN history.roadmap_events.created_at IS 'Data e hora exata da ocorrência do evento.';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------

-- Busca por categoria (ex: todos os logs de 'AUTH')
CREATE INDEX IF NOT EXISTS idx_history_category ON history.roadmap_events USING btree (category);

-- Busca dentro do JSON de metadados (ex: buscar ações de um IP específico)
CREATE INDEX IF NOT EXISTS idx_history_metadata_gin ON history.roadmap_events USING gin (metadata);

-- Busca combinada para filtros de dashboard
CREATE INDEX IF NOT EXISTS idx_history_scope_category ON history.roadmap_events USING btree (event_scope, category);

-- Busca por entidade fiscal (apenas onde existe tax_id)
CREATE INDEX IF NOT EXISTS idx_history_tax_entity ON history.roadmap_events USING btree (tax_id) WHERE (tax_id IS NOT NULL);

-- Otimizado para Timeline do Tenant (exibe os últimos eventos da empresa)
CREATE INDEX IF NOT EXISTS idx_history_tenant_date ON history.roadmap_events USING btree (tenant_id, created_at DESC);

-- Otimizado para Timeline do Usuário (exibe "Minhas Atividades")
CREATE INDEX IF NOT EXISTS idx_history_user_date ON history.roadmap_events USING btree (user_email, created_at DESC);

-- -----------------------------------------------------------------------------
-- 4. CONSTRAINTS
-- -----------------------------------------------------------------------------

-- Se o estabelecimento sumir, mantemos o log mas limpamos a referência
ALTER TABLE ONLY history.roadmap_events
    ADD CONSTRAINT roadmap_events_est_id_fkey FOREIGN KEY (est_id) REFERENCES partner.establishments(est_id) ON DELETE SET NULL;

-- Se o registro fiscal sumir, mantemos o log
ALTER TABLE ONLY history.roadmap_events
    ADD CONSTRAINT roadmap_events_tax_id_fkey FOREIGN KEY (tax_id) REFERENCES partner.tax_entities(tax_id) ON DELETE SET NULL;

-- Se o Tenant (conta paga) for deletado, os logs de auditoria de negócio somem (LGPD compliance)
ALTER TABLE ONLY history.roadmap_events
    ADD CONSTRAINT roadmap_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES partner.tenants(tenant_id) ON DELETE CASCADE;

-- Mantém o log mesmo que o usuário seja alterado
ALTER TABLE ONLY history.roadmap_events
    ADD CONSTRAINT roadmap_events_user_email_fkey FOREIGN KEY (user_email) REFERENCES account.users(email);
