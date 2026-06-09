-- =============================================================================
-- SCHEMA: sped
-- PROJETO: Fiscal Fácil
-- DATA: 2026-06-09
-- DESCRIÇÃO: Estrutura do módulo SPED Fiscal (EFD ICMS/IPI) com:
--            1) armazenamento flexível de registros (JSONB + hierarquia física)
--            2) controle operacional por protocolo/job
--            3) rastreabilidade por etapas e eventos de workflow
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sped;
ALTER SCHEMA sped OWNER TO dorcilio;

COMMENT ON SCHEMA sped IS
    'Schema do módulo SPED Fiscal (EFD ICMS/IPI). Contém armazenamento de linhas do SPED em JSONB, '
    'controle de jobs/protocolos e trilha de execução para importação, auditoria, correções, exportação e transmissão.';

-- -----------------------------------------------------------------------------
-- 1. FUNÇÕES
-- -----------------------------------------------------------------------------

-- Valida consistência pai-filho dentro de um arquivo SPED:
-- 1) o registro pai deve existir
-- 2) o registro pai deve pertencer ao mesmo arquivo
-- 3) a line_number do pai deve ser menor que a line_number do filho
CREATE OR REPLACE FUNCTION sped.fn_validate_sped_record_parent()
RETURNS trigger AS $$
DECLARE
    v_parent_sped_file_id BIGINT;
    v_parent_line_number INTEGER;
BEGIN
    IF NEW.parent_sped_record_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT r.sped_file_id, r.line_number
      INTO v_parent_sped_file_id, v_parent_line_number
      FROM sped.sped_records r
     WHERE r.sped_record_id = NEW.parent_sped_record_id;

    IF v_parent_sped_file_id IS NULL THEN
        RAISE EXCEPTION 'Registro pai (%) não foi encontrado.', NEW.parent_sped_record_id;
    END IF;

    IF v_parent_sped_file_id <> NEW.sped_file_id THEN
        RAISE EXCEPTION
            'Registro pai (%) pertence ao sped_file_id %, diferente do sped_file_id %.',
            NEW.parent_sped_record_id, v_parent_sped_file_id, NEW.sped_file_id;
    END IF;

    IF v_parent_line_number >= NEW.line_number THEN
        RAISE EXCEPTION
            'Ordem física inválida: registro pai (%) linha % deve vir antes da linha %.',
            NEW.parent_sped_record_id, v_parent_line_number, NEW.line_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sped.fn_validate_sped_record_parent() IS
    'Valida integridade hierárquica em sped.sped_records: mesmo sped_file_id e ordem física de linhas (pai antes do filho).';

-- -----------------------------------------------------------------------------
-- 2. TABELAS
-- -----------------------------------------------------------------------------

-- Metadados do arquivo de origem (sem status de processamento)
CREATE TABLE IF NOT EXISTS sped.sped_files (
    sped_file_id BIGSERIAL NOT NULL,
    document VARCHAR(14) NOT NULL,
    ie VARCHAR(20),
    reference_period DATE NOT NULL,
    layout_version VARCHAR(4),
    source_file_name VARCHAR(255),
    source_file_sha256 CHAR(64),
    total_lines INTEGER,
    imported_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT sped_files_pkey PRIMARY KEY (sped_file_id),
    CONSTRAINT ck_sped_files_document_numeric CHECK (document ~ '^([0-9]{11}|[0-9]{14})$'),
    CONSTRAINT ck_sped_files_total_lines_non_negative CHECK (
        total_lines IS NULL OR total_lines >= 0
    ),
    CONSTRAINT uk_sped_files_file_hash UNIQUE (source_file_sha256)
);

ALTER TABLE sped.sped_files OWNER TO dorcilio;

COMMENT ON TABLE sped.sped_files IS
    'Arquivos de origem do SPED importados por clientes. Armazena metadados imutáveis do arquivo e identificação da ingestão.';
COMMENT ON COLUMN sped.sped_files.sped_file_id IS
    'Identificador interno do arquivo SPED importado.';
COMMENT ON COLUMN sped.sped_files.document IS
    'Documento do declarante (CPF ou CNPJ, somente dígitos).';
COMMENT ON COLUMN sped.sped_files.ie IS
    'Inscrição Estadual do declarante, quando aplicável.';
COMMENT ON COLUMN sped.sped_files.reference_period IS
    'Período fiscal de referência declarado no arquivo SPED.';
COMMENT ON COLUMN sped.sped_files.layout_version IS
    'Versão do leiaute do SPED (exemplo: 019).';
COMMENT ON COLUMN sped.sped_files.source_file_name IS
    'Nome original do arquivo de origem enviado pelo usuário.';
COMMENT ON COLUMN sped.sped_files.source_file_sha256 IS
    'Hash SHA-256 do conteúdo do arquivo para deduplicação e rastreabilidade.';
COMMENT ON COLUMN sped.sped_files.total_lines IS
    'Quantidade total de linhas físicas encontradas no TXT de origem.';
COMMENT ON COLUMN sped.sped_files.imported_at IS
    'Timestamp de conclusão do parsing bruto da importação.';
COMMENT ON COLUMN sped.sped_files.created_at IS
    'Timestamp de criação.';
COMMENT ON COLUMN sped.sped_files.updated_at IS
    'Timestamp da última atualização.';

-- Estratégia de tabela única para todos os registros SPED
CREATE TABLE IF NOT EXISTS sped.sped_records (
    sped_record_id BIGSERIAL NOT NULL,
    sped_file_id BIGINT NOT NULL,
    block_code CHAR(1) NOT NULL,
    record_code CHAR(4) NOT NULL,
    line_number INTEGER NOT NULL,
    parent_sped_record_id BIGINT,
    record_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    line_sha256 CHAR(64),
    hierarchy_level SMALLINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT sped_records_pkey PRIMARY KEY (sped_record_id),
    CONSTRAINT fk_sped_records_file FOREIGN KEY (sped_file_id)
        REFERENCES sped.sped_files(sped_file_id) ON DELETE CASCADE,
    CONSTRAINT fk_sped_records_parent FOREIGN KEY (parent_sped_record_id)
        REFERENCES sped.sped_records(sped_record_id) ON DELETE CASCADE,
    CONSTRAINT uk_sped_records_file_line UNIQUE (sped_file_id, line_number),
    CONSTRAINT ck_sped_records_block_code CHECK (block_code ~ '^[0-9A-Z]$'),
    CONSTRAINT ck_sped_records_record_code CHECK (record_code ~ '^[0-9A-Z]{4}$'),
    CONSTRAINT ck_sped_records_line_number_positive CHECK (line_number > 0),
    CONSTRAINT ck_sped_records_record_payload_object CHECK (jsonb_typeof(record_payload) = 'object'),
    CONSTRAINT ck_sped_records_hierarchy_level_non_negative CHECK (
        hierarchy_level IS NULL OR hierarchy_level >= 0
    )
);

ALTER TABLE sped.sped_records OWNER TO dorcilio;

COMMENT ON TABLE sped.sped_records IS
    'Armazenamento em tabela única para linhas do SPED. Preserva ordem física e relacionamento hierárquico pai-filho.';
COMMENT ON COLUMN sped.sped_records.sped_record_id IS
    'Identificador interno da linha de registro SPED.';
COMMENT ON COLUMN sped.sped_records.sped_file_id IS
    'Identificador do arquivo SPED de origem (FK para sped.sped_files).';
COMMENT ON COLUMN sped.sped_records.block_code IS
    'SPED logical block code (0, C, D, E, G, H, K, 1, 9).';
COMMENT ON COLUMN sped.sped_records.record_code IS
    'SPED register code (example: C100, C170, 0000).';
COMMENT ON COLUMN sped.sped_records.line_number IS
    'Número original da linha física no arquivo de origem.';
COMMENT ON COLUMN sped.sped_records.parent_sped_record_id IS
    'Parent line reference in hierarchy (self-reference).';
COMMENT ON COLUMN sped.sped_records.record_payload IS
    'Payload dinâmico do registro mapeado em pares chave-valor JSON.';
COMMENT ON COLUMN sped.sped_records.line_sha256 IS
    'SHA-256 hash of normalized line content for reconciliation.';
COMMENT ON COLUMN sped.sped_records.hierarchy_level IS
    'Optional parser-calculated hierarchy depth for diagnostics and auditing.';
COMMENT ON COLUMN sped.sped_records.created_at IS
    'Timestamp de criação.';
COMMENT ON COLUMN sped.sped_records.updated_at IS
    'Timestamp da última atualização.';

-- Tabela de job/protocolo: máquina de estados operacional central de um arquivo SPED
CREATE TABLE IF NOT EXISTS sped.sped_jobs (
    sped_job_id BIGSERIAL NOT NULL,
    sped_file_id BIGINT NOT NULL,
    tenant_id UUID,
    est_id UUID,
    protocol_code VARCHAR(50) NOT NULL,
    job_type VARCHAR(30) NOT NULL,
    workflow_status VARCHAR(40) NOT NULL DEFAULT 'RECEIVED',
    current_stage_code VARCHAR(60) NOT NULL DEFAULT 'FILE_RECEIVED',
    progress_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    requested_by_email VARCHAR(320),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    last_heartbeat_at TIMESTAMPTZ,
    job_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT sped_jobs_pkey PRIMARY KEY (sped_job_id),
    CONSTRAINT uk_sped_jobs_protocol_code UNIQUE (protocol_code),
    CONSTRAINT fk_sped_jobs_file FOREIGN KEY (sped_file_id)
        REFERENCES sped.sped_files(sped_file_id) ON DELETE CASCADE,
    CONSTRAINT fk_sped_jobs_tenant FOREIGN KEY (tenant_id)
        REFERENCES partner.tenants(tenant_id) ON DELETE SET NULL,
    CONSTRAINT fk_sped_jobs_establishment FOREIGN KEY (est_id)
        REFERENCES partner.establishments(est_id) ON DELETE SET NULL,
    CONSTRAINT fk_sped_jobs_requested_by FOREIGN KEY (requested_by_email)
        REFERENCES account.users(email) ON DELETE SET NULL,
    CONSTRAINT ck_sped_jobs_job_type CHECK (job_type IN (
        'IMPORT',
        'AUDIT',
        'CORRECTION',
        'EXPORT',
        'TRANSMISSION',
        'RETIFICATION'
    )),
    CONSTRAINT ck_sped_jobs_workflow_status CHECK (workflow_status IN (
        'RECEIVED',
        'IMPORTED',
        'IN_AUDIT',
        'AUDIT_PARTIAL',
        'AUDIT_COMPLETED',
        'CORRECTED',
        'READY_TO_EXPORT',
        'EXPORTED',
        'EXPORTED_DOMAIN',
        'READY_TO_TRANSMIT',
        'TRANSMITTED',
        'READY_TO_RECTIFY',
        'RECTIFICATION_REQUESTED',
        'COMPLETED',
        'DELETED',
        'FAILED'
    )),
    CONSTRAINT ck_sped_jobs_progress_percent_range CHECK (
        progress_percent >= 0 AND progress_percent <= 100
    )
);

ALTER TABLE sped.sped_jobs OWNER TO dorcilio;

COMMENT ON TABLE sped.sped_jobs IS
    'Controle de protocolo/job para o ciclo de vida de cada arquivo SPED. Rastreia status operacional da importação até transmissão/retificação.';
COMMENT ON COLUMN sped.sped_jobs.sped_job_id IS
    'Identificador interno do job/protocolo SPED.';
COMMENT ON COLUMN sped.sped_jobs.sped_file_id IS
    'Arquivo SPED de origem vinculado a este job.';
COMMENT ON COLUMN sped.sped_jobs.tenant_id IS
    'Tenant context of the execution.';
COMMENT ON COLUMN sped.sped_jobs.est_id IS
    'Primary establishment context for this execution.';
COMMENT ON COLUMN sped.sped_jobs.protocol_code IS
    'Código de protocolo legível compartilhado com usuários para acompanhamento.';
COMMENT ON COLUMN sped.sped_jobs.job_type IS
    'Tipo principal da operação: IMPORT, AUDIT, CORRECTION, EXPORT, TRANSMISSION, RETIFICATION.';
COMMENT ON COLUMN sped.sped_jobs.workflow_status IS
    'Status atual de alto nível do ciclo de vida do protocolo/job.';
COMMENT ON COLUMN sped.sped_jobs.current_stage_code IS
    'Código detalhado da etapa ativa (exemplo: AUDIT_PARTICIPANTS, AUDIT_PRODUCTS, EXPORT_FILE_GENERATION).';
COMMENT ON COLUMN sped.sped_jobs.progress_percent IS
    'Progresso geral de 0 a 100.';
COMMENT ON COLUMN sped.sped_jobs.requested_by_email IS
    'Usuário que solicitou ou iniciou o workflow.';
COMMENT ON COLUMN sped.sped_jobs.started_at IS
    'Timestamp de início efetivo do processamento.';
COMMENT ON COLUMN sped.sped_jobs.finished_at IS
    'Timestamp de término bem-sucedido do workflow.';
COMMENT ON COLUMN sped.sped_jobs.failed_at IS
    'Timestamp em que o workflow foi para estado FAILED.';
COMMENT ON COLUMN sped.sped_jobs.last_heartbeat_at IS
    'Último heartbeat de execução para monitorar jobs travados.';
COMMENT ON COLUMN sped.sped_jobs.job_metadata IS
    'Additional execution metadata in JSON format.';
COMMENT ON COLUMN sped.sped_jobs.created_at IS
    'Timestamp de criação.';
COMMENT ON COLUMN sped.sped_jobs.updated_at IS
    'Timestamp da última atualização.';

-- Rastreio detalhado de etapas por protocolo/job
CREATE TABLE IF NOT EXISTS sped.sped_job_stages (
    sped_job_stage_id BIGSERIAL NOT NULL,
    sped_job_id BIGINT NOT NULL,
    stage_code VARCHAR(60) NOT NULL,
    stage_order SMALLINT NOT NULL,
    stage_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    responsible_by_email VARCHAR(320),
    stage_summary TEXT,
    stage_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT sped_job_stages_pkey PRIMARY KEY (sped_job_stage_id),
    CONSTRAINT fk_sped_job_stages_job FOREIGN KEY (sped_job_id)
        REFERENCES sped.sped_jobs(sped_job_id) ON DELETE CASCADE,
    CONSTRAINT fk_sped_job_stages_responsible_by FOREIGN KEY (responsible_by_email)
        REFERENCES account.users(email) ON DELETE SET NULL,
    CONSTRAINT uk_sped_job_stages_job_stage UNIQUE (sped_job_id, stage_code),
    CONSTRAINT uk_sped_job_stages_job_order UNIQUE (sped_job_id, stage_order),
    CONSTRAINT ck_sped_job_stages_stage_status CHECK (stage_status IN (
        'PENDING',
        'RUNNING',
        'COMPLETED',
        'FAILED',
        'SKIPPED'
    )),
    CONSTRAINT ck_sped_job_stages_stage_order_positive CHECK (stage_order > 0)
);

ALTER TABLE sped.sped_job_stages OWNER TO dorcilio;

COMMENT ON TABLE sped.sped_job_stages IS
    'Etapas detalhadas do pipeline de um job SPED, permitindo monitoramento granular e auditorias futuras por etapa.';
COMMENT ON COLUMN sped.sped_job_stages.sped_job_stage_id IS
    'Identificador interno de uma etapa do job.';
COMMENT ON COLUMN sped.sped_job_stages.sped_job_id IS
    'Job/protocolo SPED relacionado.';
COMMENT ON COLUMN sped.sped_job_stages.stage_code IS
    'Chave da etapa (exemplo: IMPORT_PARSE_FILE, AUDIT_PARTICIPANTS, AUDIT_PRODUCTS, EXPORT_TXT).';
COMMENT ON COLUMN sped.sped_job_stages.stage_order IS
    'Ordem de execução dentro do mesmo protocolo.';
COMMENT ON COLUMN sped.sped_job_stages.stage_status IS
    'Status de execução da etapa: PENDING, RUNNING, COMPLETED, FAILED, SKIPPED.';
COMMENT ON COLUMN sped.sped_job_stages.responsible_by_email IS
    'E-mail do responsável pela etapa específica (quando aplicável).';
COMMENT ON COLUMN sped.sped_job_stages.stage_summary IS
    'Resumo legível do resultado da etapa.';
COMMENT ON COLUMN sped.sped_job_stages.stage_payload IS
    'Payload técnico com métricas/erros/detalhes da etapa.';
COMMENT ON COLUMN sped.sped_job_stages.started_at IS
    'Timestamp de início da etapa.';
COMMENT ON COLUMN sped.sped_job_stages.finished_at IS
    'Timestamp de término da etapa.';
COMMENT ON COLUMN sped.sped_job_stages.created_at IS
    'Timestamp de criação.';
COMMENT ON COLUMN sped.sped_job_stages.updated_at IS
    'Timestamp da última atualização.';

-- Timeline de eventos atômicos por protocolo/job
CREATE TABLE IF NOT EXISTS sped.sped_job_events (
    sped_job_event_id BIGSERIAL NOT NULL,
    sped_job_id BIGINT NOT NULL,
    event_code VARCHAR(80) NOT NULL,
    event_title VARCHAR(160) NOT NULL,
    event_description TEXT,
    previous_workflow_status VARCHAR(40),
    new_workflow_status VARCHAR(40),
    created_by_email VARCHAR(320),
    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT sped_job_events_pkey PRIMARY KEY (sped_job_event_id),
    CONSTRAINT fk_sped_job_events_job FOREIGN KEY (sped_job_id)
        REFERENCES sped.sped_jobs(sped_job_id) ON DELETE CASCADE,
    CONSTRAINT fk_sped_job_events_created_by FOREIGN KEY (created_by_email)
        REFERENCES account.users(email) ON DELETE SET NULL
);

ALTER TABLE sped.sped_job_events OWNER TO dorcilio;

COMMENT ON TABLE sped.sped_job_events IS
    'Timeline orientada a append de eventos operacionais de cada protocolo/job SPED (roadmap/histórico).';
COMMENT ON COLUMN sped.sped_job_events.sped_job_event_id IS
    'Identificador interno do evento do job.';
COMMENT ON COLUMN sped.sped_job_events.sped_job_id IS
    'Job/protocolo SPED relacionado.';
COMMENT ON COLUMN sped.sped_job_events.event_code IS
    'Chave de evento legível por máquina (exemplo: FILE_IMPORTED, AUDIT_PRODUCTS_COMPLETED, FILE_EXPORTED).';
COMMENT ON COLUMN sped.sped_job_events.event_title IS
    'Título exibido ao usuário na timeline.';
COMMENT ON COLUMN sped.sped_job_events.event_description IS
    'Descrição detalhada do evento para auditoria e suporte.';
COMMENT ON COLUMN sped.sped_job_events.previous_workflow_status IS
    'Status do workflow antes deste evento, quando aplicável.';
COMMENT ON COLUMN sped.sped_job_events.new_workflow_status IS
    'Status do workflow após este evento, quando aplicável.';
COMMENT ON COLUMN sped.sped_job_events.created_by_email IS
    'Usuário que disparou o evento. NULL quando gerado pelo sistema.';
COMMENT ON COLUMN sped.sped_job_events.event_payload IS
    'Structured event metadata and contextual details in JSON.';
COMMENT ON COLUMN sped.sped_job_events.created_at IS
    'Timestamp de criação.';
COMMENT ON COLUMN sped.sped_job_events.updated_at IS
    'Timestamp da última atualização.';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------

-- Navegação principal de registros SPED
CREATE INDEX IF NOT EXISTS idx_sped_records_file_record_line
    ON sped.sped_records (sped_file_id, record_code, line_number);

CREATE INDEX IF NOT EXISTS idx_sped_records_hierarchy
    ON sped.sped_records (sped_file_id, parent_sped_record_id);

-- Índice parcial: análises de itens (C170)
CREATE INDEX IF NOT EXISTS idx_sped_records_c170_participant_product
    ON sped.sped_records (((record_payload->>'cnpj_part')), ((record_payload->>'cod_prod')))
    WHERE record_code = 'C170';

-- Índice parcial: busca de chave de documento (C100)
CREATE INDEX IF NOT EXISTS idx_sped_records_c100_document_key
    ON sped.sped_records (((record_payload->>'ch_cte_nfe')))
    WHERE record_code = 'C100' AND (record_payload->>'ch_cte_nfe') IS NOT NULL;

-- Índice parcial: auditorias futuras de NCM (C170)
CREATE INDEX IF NOT EXISTS idx_sped_records_c170_ncm
    ON sped.sped_records (((record_payload->>'cod_ncm')))
    WHERE record_code = 'C170' AND (record_payload->>'cod_ncm') IS NOT NULL;

-- Suporte genérico de busca em JSONB
CREATE INDEX IF NOT EXISTS idx_sped_records_payload_gin
    ON sped.sped_records USING gin (record_payload jsonb_path_ops);

-- Consultas em nível de arquivo
CREATE INDEX IF NOT EXISTS idx_sped_files_document_period
    ON sped.sped_files (document, reference_period DESC);

-- Consultas de workflow do job
CREATE INDEX IF NOT EXISTS idx_sped_jobs_file
    ON sped.sped_jobs (sped_file_id);

CREATE INDEX IF NOT EXISTS idx_sped_jobs_status_updated
    ON sped.sped_jobs (workflow_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_sped_jobs_tenant_status
    ON sped.sped_jobs (tenant_id, workflow_status)
    WHERE tenant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sped_jobs_protocol_code
    ON sped.sped_jobs (protocol_code);

CREATE INDEX IF NOT EXISTS idx_sped_jobs_requested_by
    ON sped.sped_jobs (requested_by_email)
    WHERE requested_by_email IS NOT NULL;

-- Consultas de monitoramento por etapa
CREATE INDEX IF NOT EXISTS idx_sped_job_stages_job_order
    ON sped.sped_job_stages (sped_job_id, stage_order);

CREATE INDEX IF NOT EXISTS idx_sped_job_stages_status
    ON sped.sped_job_stages (stage_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_sped_job_stages_responsible_by
    ON sped.sped_job_stages (responsible_by_email, updated_at DESC)
    WHERE responsible_by_email IS NOT NULL;

-- Consultas de timeline
CREATE INDEX IF NOT EXISTS idx_sped_job_events_job_date
    ON sped.sped_job_events (sped_job_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sped_job_events_code_date
    ON sped.sped_job_events (event_code, created_at DESC);

COMMENT ON INDEX sped.idx_sped_records_file_record_line IS
    'Acelera varredura de registros SPED por arquivo, tipo de registro e ordem física.';
COMMENT ON INDEX sped.idx_sped_records_hierarchy IS
    'Acelera reconstrução da árvore pai-filho dentro de um arquivo de origem.';
COMMENT ON INDEX sped.idx_sped_records_c170_participant_product IS
    'Índice parcial para análise de itens C170 por CNPJ do participante e código do produto.';
COMMENT ON INDEX sped.idx_sped_records_c100_document_key IS
    'Índice parcial para busca rápida de chave NF-e/CT-e em registros C100.';
COMMENT ON INDEX sped.idx_sped_records_c170_ncm IS
    'Índice parcial para auditoria focada em NCM nos registros de itens C170.';
COMMENT ON INDEX sped.idx_sped_records_payload_gin IS
    'Índice GIN para predicados dinâmicos em JSONB sobre payload de registros SPED.';
COMMENT ON INDEX sped.idx_sped_jobs_status_updated IS
    'Otimiza dashboards operacionais por status de workflow e atividade recente.';
COMMENT ON INDEX sped.idx_sped_job_events_job_date IS
    'Otimiza renderização de timeline para cada protocolo/job SPED.';

-- -----------------------------------------------------------------------------
-- 4. TRIGGERS
-- -----------------------------------------------------------------------------

CREATE TRIGGER tr_upd_sped_files
    BEFORE UPDATE ON sped.sped_files
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_sped_records
    BEFORE UPDATE ON sped.sped_records
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_sped_jobs
    BEFORE UPDATE ON sped.sped_jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_sped_job_stages
    BEFORE UPDATE ON sped.sped_job_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_sped_job_events
    BEFORE UPDATE ON sped.sped_job_events
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_validate_sped_record_parent
    BEFORE INSERT OR UPDATE OF sped_file_id, parent_sped_record_id, line_number
    ON sped.sped_records
    FOR EACH ROW
    EXECUTE FUNCTION sped.fn_validate_sped_record_parent();
