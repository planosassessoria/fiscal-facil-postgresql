-- =============================================================================
-- SCHEMA: xml
-- PROJETO: Fiscal Fácil
-- DESCRIÇÃO: Repositório de XMLs fiscais originais e controle de importações.
--
-- Tabelas:
--   xml.xml_storage       — "Nuvem" de XMLs. Armazena o XML original de cada NF-e/NFC-e.
--                           Particionado por ano de emissão para escala com milhões de registros.
--                           Usado para download do XML, geração de DANFE e re-extração para nota_fiscal.
--
--   xml.import_job        — Log de controle de importações (XML unitário ou pacote ZIP).
--                           Registros têm TTL (expires_at) e são removidos por job agendado.
--
--   xml.import_job_step   — Etapas de cada job. Permite rastrear o progresso e tempo de cada fase.
--
--   xml.import_job_error  — Erros individuais ocorridos durante a importação.
--
-- Fluxos de importação:
--   SINGLE_XML  →  STORE_XML  →  PROCESS_NF
--   BATCH_ZIP   →  UPLOAD_BUCKET  →  EXTRACT_ZIP  →  STORE_XML  →  PROCESS_NF
--
-- Particionamento de xml_storage:
--   O ch_nf (44 dígitos) carrega nas posições 3-4 os dois últimos dígitos do ano de emissão.
--   Layout: cUF(2) + AA(2) + MM(2) + CNPJ(14) + mod(2) + serie(3) + nNF(9) + tpEmis(1) + cNF(8) + cDV(1)
--   A coluna emission_year é preenchida automaticamente via trigger BEFORE INSERT como (2000 + CAST(SUBSTRING(ch_nf FROM 3 FOR 2) AS SMALLINT)).
--   Para adicionar uma nova partição a cada ano:
--     CREATE TABLE xml.xml_storage_YYYY PARTITION OF xml.xml_storage FOR VALUES FROM (YYYY) TO (YYYY+1);
--
-- TTL de import_job:
--   Limpeza via job agendado (pg_cron ou equivalente):
--   DELETE FROM xml.import_job WHERE expires_at < NOW()
--     AND job_status IN ('COMPLETED', 'PARTIAL', 'FAILED', 'CANCELLED');
--   import_job_step e import_job_error são removidos em CASCADE automaticamente.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS xml;
ALTER SCHEMA xml OWNER TO dorcilio;

COMMENT ON SCHEMA xml IS
    'Repositório permanente de XMLs fiscais originais (NF-e/NFC-e) e controle de importações '
    'em lote ou unitárias. xml_storage é particionado por ano de emissão para escala com milhões '
    'de registros. import_job, import_job_step e import_job_error têm TTL e são removidos '
    'periodicamente para não ocupar espaço desnecessário.';

-- -----------------------------------------------------------------------------
-- 1. FUNÇÕES
-- -----------------------------------------------------------------------------

-- Atualiza o vetor FTS do import_job a partir de file_name, cpf_cnpj, job_type e job_status.
CREATE OR REPLACE FUNCTION xml.fn_update_job_fts()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.job_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.file_name,   '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cpf_cnpj,    '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.user_email,  '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.job_type,    '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.job_status,  '')), 'B');
    RETURN NEW;
END;
$$;
ALTER FUNCTION xml.fn_update_job_fts() OWNER TO dorcilio;
COMMENT ON FUNCTION xml.fn_update_job_fts() IS
    'Atualiza o vetor FTS de import_job. Pesos: file_name e cpf_cnpj = A; user_email, job_type e job_status = B.';

-- emission_year e emission_month são calculados inline em xml.fn_validate_and_store_xml
-- durante o INSERT, evitando o erro do PostgreSQL:
--   "moving row to another partition during a BEFORE FOR EACH ROW trigger is not supported"
-- A função fn_set_emission_year e o trigger tr_set_xml_storage_emission_year foram removidos.

-- -----------------------------------------------------------------------------
-- 2. TABELA: xml.xml_storage
-- "Nuvem" de XMLs fiscais originais. Volume esperado: dezenas de milhões de registros.
--
-- Estratégia de escala:
--   • Particionamento por emission_year — permite partition pruning em queries por ano e
--     possibilita arquivar/mover partições antigas sem afetar dados recentes.
--   • emission_month — mês de emissão derivado deterministicamente das posições 5-6 do ch_nf.
--     Permite filtros por período (mês/ano) sem custo de manutenção: preenchido pelo mesmo trigger
--     que já calcula emission_year. Fundamental para downloads de pacotes de XML por período.
--   • UNIQUE (ch_nf, emission_year) — inclui a coluna de partição conforme exigência do
--     PostgreSQL para constraints UNIQUE em tabelas particionadas. Como emission_year é
--     derivado deterministicamente de ch_nf, a unicidade sobre ch_nf é garantida globalmente.
--   • BRIN index em created_at — extremamente compacto para dados com inserção append-only
--     (muito menor que btree, adequado para tabelas com dezenas de milhões de linhas).
--   • Índices parciais (WHERE IS NOT NULL) — evitam indexar NULLs em colunas opcionais.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS xml.xml_storage (

    -- Chaves
    xml_id              BIGSERIAL       NOT NULL,
    emission_year       SMALLINT        NOT NULL,
    emission_month      SMALLINT        NOT NULL,

    -- Identificação fiscal
    ch_nf               VARCHAR(44)     NOT NULL,
    cpf_cnpj            VARCHAR(14)     NOT NULL,
    ie                  VARCHAR(15),
    dest_cpf_cnpj       VARCHAR(14),
    dest_ie             VARCHAR(15),

    -- Conteúdo original do XML
    xml_content         XML             NOT NULL,

    -- Rastreabilidade da importação (sem FK — import_job tem TTL e pode ser excluído)
    import_job_id       UUID,

    -- Timestamp de armazenamento (sem updated_at — tabela append-only)
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT xml_storage_pkey     PRIMARY KEY (xml_id, emission_year),
    CONSTRAINT uk_xml_storage_ch_nf UNIQUE (ch_nf, emission_year)

) PARTITION BY RANGE (emission_year);

ALTER TABLE xml.xml_storage OWNER TO dorcilio;

COMMENT ON TABLE xml.xml_storage IS
    'Repositório permanente ("nuvem") dos XMLs originais de NF-e e NFC-e. '
    'Utilizado para download do XML original, geração de DANFE e re-extração de dados para nota_fiscal. '
    'Particionado por emission_year (derivado de ch_nf) para escala com dezenas de milhões de registros. '
    'Tabela append-only — registros não são atualizados após a inserção.';

COMMENT ON COLUMN xml.xml_storage.xml_id IS
    'Identificador sequencial numérico da linha. Parte da PK composta com emission_year '
    '(exigência do PostgreSQL para PKs em tabelas particionadas).';

COMMENT ON COLUMN xml.xml_storage.emission_year IS
    'Ano de emissão do documento fiscal, extraído das posições 3-4 do ch_nf (AA → 20AA). '
    'Calculado inline por xml.fn_validate_and_store_xml no momento do INSERT. '
    'Define a partição onde o registro é armazenado. '
    'Exemplo: ch_nf iniciando "3524..." → emission_year = 2024.'

COMMENT ON COLUMN xml.xml_storage.emission_month IS
    'Mês de emissão do documento fiscal (1–12), extraído das posições 5-6 do ch_nf (MM). '
    'Calculado inline por xml.fn_validate_and_store_xml no momento do INSERT. '
    'Combinado com emission_year e cpf_cnpj, viabiliza downloads de pacotes de XML por período '
    '(ex: "todos os XMLs do CNPJ X em janeiro/2025") com partition pruning + índice composto, '
    'sem necessidade de varrer o xml_content ou fazer JOIN com nota_fiscal.b01_ide.'

COMMENT ON COLUMN xml.xml_storage.ch_nf IS
    'Chave de acesso da NF-e/NFC-e (44 dígitos numéricos). '
    'Identificador único nacional do documento fiscal emitido pela SEFAZ. '
    'A unicidade em xml_storage é garantida pelo UNIQUE (ch_nf, emission_year).';

COMMENT ON COLUMN xml.xml_storage.cpf_cnpj IS
    'CPF ou CNPJ do emitente, somente dígitos, sem formatação.';

COMMENT ON COLUMN xml.xml_storage.ie IS
    'Inscrição Estadual do emitente.';

COMMENT ON COLUMN xml.xml_storage.dest_cpf_cnpj IS
    'CPF ou CNPJ do destinatário, somente dígitos. '
    'Pode ser NULL em operações sem identificação de destinatário.';

COMMENT ON COLUMN xml.xml_storage.dest_ie IS
    'Inscrição Estadual do destinatário.';

COMMENT ON COLUMN xml.xml_storage.xml_content IS
    'Conteúdo integral do arquivo XML da NF-e/NFC-e no tipo nativo XML do PostgreSQL. '
    'Valores grandes são comprimidos e armazenados via TOAST automaticamente pelo PostgreSQL.';

COMMENT ON COLUMN xml.xml_storage.import_job_id IS
    'UUID do import_job que originou este registro, para rastreabilidade. '
    'Sem FK — import_job tem TTL e pode ser excluído sem afetar xml_storage.';

COMMENT ON COLUMN xml.xml_storage.created_at IS
    'Timestamp de armazenamento do XML no repositório (instante da inserção).';

-- Partições por ano de emissão
-- Para adicionar um novo ano: CREATE TABLE xml.xml_storage_YYYY PARTITION OF xml.xml_storage FOR VALUES FROM (YYYY) TO (YYYY+1);
CREATE TABLE IF NOT EXISTS xml.xml_storage_2023    PARTITION OF xml.xml_storage FOR VALUES FROM (2023) TO (2024);
CREATE TABLE IF NOT EXISTS xml.xml_storage_2024    PARTITION OF xml.xml_storage FOR VALUES FROM (2024) TO (2025);
CREATE TABLE IF NOT EXISTS xml.xml_storage_2025    PARTITION OF xml.xml_storage FOR VALUES FROM (2025) TO (2026);
CREATE TABLE IF NOT EXISTS xml.xml_storage_2026    PARTITION OF xml.xml_storage FOR VALUES FROM (2026) TO (2027);
CREATE TABLE IF NOT EXISTS xml.xml_storage_2027    PARTITION OF xml.xml_storage FOR VALUES FROM (2027) TO (2028);
CREATE TABLE IF NOT EXISTS xml.xml_storage_default PARTITION OF xml.xml_storage DEFAULT;

-- Índices de xml.xml_storage
-- (criados na tabela pai e propagados automaticamente a todas as partições — PostgreSQL 11+)

-- Busca de XMLs pelo CNPJ/CPF do emitente.
CREATE INDEX IF NOT EXISTS idx_xml_storage_cpf_cnpj
    ON xml.xml_storage (cpf_cnpj);

-- Consultas de XMLs por emitente filtrando por ano — potencializa o partition pruning por emission_year.
CREATE INDEX IF NOT EXISTS idx_xml_storage_cpf_cnpj_year
    ON xml.xml_storage (cpf_cnpj, emission_year DESC);

-- Busca de XMLs pelo CNPJ/CPF do destinatário.
-- Parcial: ignora linhas sem destinatário (NULL), reduzindo o tamanho do índice significativamente.
CREATE INDEX IF NOT EXISTS idx_xml_storage_dest_cpf_cnpj
    ON xml.xml_storage (dest_cpf_cnpj)
    WHERE dest_cpf_cnpj IS NOT NULL;

-- Rastreamento de quais XMLs foram originados por um job de importação específico.
-- Parcial: ignora XMLs sem job vinculado.
CREATE INDEX IF NOT EXISTS idx_xml_storage_import_job_id
    ON xml.xml_storage (import_job_id)
    WHERE import_job_id IS NOT NULL;

-- BRIN: compacto e eficiente para consultas de range temporal em tabelas append-only de grande volume.
-- Ocupa ordens de magnitude menos espaço que um btree equivalente — ideal para dezenas de milhões de linhas.
CREATE INDEX IF NOT EXISTS idx_xml_storage_created_at
    ON xml.xml_storage USING BRIN (created_at);

-- Hash em xml_id: lookup direto por ID sem varrer todas as partições.
-- A PK (xml_id, emission_year) exige emission_year para pruning; este índice resolve buscas
-- por xml_id puro (ex: download do XML a partir de nota_fiscal.b01_ide.xml_id).
CREATE INDEX IF NOT EXISTS idx_xml_storage_xml_id
    ON xml.xml_storage USING HASH (xml_id);

-- Download de pacotes de XML por período (emitente + mês + ano).
-- Cobertura total das queries de "baixar XMLs de CNPJ X em MM/YYYY":
--   emission_year ativa o partition pruning → apenas 1 partição é lida;
--   emission_month filtra dentro da partição sem tocar xml_content;
--   cpf_cnpj como leading column suporta queries por emitente com ou sem filtro de período.
CREATE INDEX IF NOT EXISTS idx_xml_storage_cpf_cnpj_period
    ON xml.xml_storage (cpf_cnpj, emission_year, emission_month);

-- Mesmo padrão para downloads solicitados pela visão do destinatário.
CREATE INDEX IF NOT EXISTS idx_xml_storage_dest_period
    ON xml.xml_storage (dest_cpf_cnpj, emission_year, emission_month)
    WHERE dest_cpf_cnpj IS NOT NULL;

-- Trigger tr_set_xml_storage_emission_year removido.
-- emission_year e emission_month são fornecidos diretamente por xml.fn_validate_and_store_xml.

-- -----------------------------------------------------------------------------
-- 3. TABELA: xml.import_job
-- Log de controle de importações de XML (unitária ou em lote compactado).
-- Não possui FK para tenant/usuário — é um registro de log com ciclo de vida independente.
-- Deve ser limpo periodicamente via job agendado (ver cabeçalho do schema).
--
-- Transições de status:
--   PENDING → RUNNING → COMPLETED  (tudo ok)
--                      → PARTIAL   (success_count > 0 e error_count > 0)
--                      → FAILED    (error_count = total_count ou erro crítico)
--             RUNNING → CANCELLED  (cancelamento manual)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS xml.import_job (

    -- Chave primária
    job_id              UUID            NOT NULL DEFAULT gen_random_uuid(),

    -- Contexto do solicitante (referências soft — sem FK pois é tabela de log com TTL)
    tenant_id           UUID            NOT NULL,
    user_email          VARCHAR(320)    NOT NULL,
    cpf_cnpj            VARCHAR(14),

    -- Tipo e status do job
    job_type            VARCHAR(20)     NOT NULL,
    job_status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING',

    -- Arquivo de origem
    file_name           VARCHAR(512)    NOT NULL,
    file_size_bytes     BIGINT,
    bucket_path         VARCHAR(1024),

    -- Total de documentos do lote (preenchido após EXTRACT_ZIP ou na criação para SINGLE_XML)
    -- Contadores de sucesso/erro ficam em import_job_step, por etapa.
    total_count         INTEGER         NOT NULL DEFAULT 0,

    -- Observações livres
    notes               TEXT,

    -- Controle temporal de execução
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,

    -- TTL: data/hora após a qual este log pode ser removido
    expires_at          TIMESTAMPTZ     NOT NULL,

    -- Full Text Search
    job_fts             TSVECTOR,

    -- Timestamps
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT import_job_pkey          PRIMARY KEY (job_id),
    CONSTRAINT ck_import_job_type       CHECK (job_type   IN ('SINGLE_XML', 'BATCH_ZIP')),
    CONSTRAINT ck_import_job_status     CHECK (job_status IN ('PENDING', 'RUNNING', 'COMPLETED', 'PARTIAL', 'FAILED', 'CANCELLED')),
    CONSTRAINT ck_import_job_total      CHECK (total_count >= 0)
);

ALTER TABLE xml.import_job OWNER TO dorcilio;

COMMENT ON TABLE xml.import_job IS
    'Log de controle de importações de XML (arquivo unitário ou pacote ZIP com múltiplos XMLs). '
    'Cada importação disparada pelo usuário gera um job_id único para rastreamento. '
    'Registros são removidos automaticamente após expires_at por job agendado — não possui FK '
    'para tenant ou usuário para não bloquear deleções e permitir limpeza independente. '
    'Contadores de sucesso/erro ficam em import_job_step (por etapa), não no job pai. '
    'import_job_step e import_job_error são removidos em CASCADE.';

COMMENT ON COLUMN xml.import_job.job_id IS
    'Identificador único do job de importação (UUID v4). Retornado ao frontend para polling de status.';

COMMENT ON COLUMN xml.import_job.tenant_id IS
    'UUID do tenant que originou a importação. '
    'Referência soft (sem FK) — o log sobrevive independentemente do ciclo de vida do tenant.';

COMMENT ON COLUMN xml.import_job.user_email IS
    'E-mail do usuário que disparou a importação. Referência soft (sem FK).';

COMMENT ON COLUMN xml.import_job.cpf_cnpj IS
    'CNPJ/CPF do emitente principal vinculado à importação. '
    'Relevante especialmente para importações SINGLE_XML.';

COMMENT ON COLUMN xml.import_job.job_type IS
    'Tipo de importação: '
    'SINGLE_XML = arquivo .xml único enviado diretamente; '
    'BATCH_ZIP  = pacote .zip contendo múltiplos XMLs, enviado para object storage.';

COMMENT ON COLUMN xml.import_job.job_status IS
    'Status geral do job. '
    'Progressão: PENDING → RUNNING → COMPLETED | PARTIAL | FAILED | CANCELLED. '
    'PARTIAL indica que ao menos uma etapa terminou com error_count > 0. '
    'Calculado pelo backend ao final da última etapa com base nos contadores de import_job_step.';

COMMENT ON COLUMN xml.import_job.file_name IS
    'Nome original do arquivo enviado pelo usuário (ex: notas_jan2026.zip, 35240712345...xml).';

COMMENT ON COLUMN xml.import_job.file_size_bytes IS
    'Tamanho do arquivo de entrada em bytes.';

COMMENT ON COLUMN xml.import_job.bucket_path IS
    'Caminho completo do arquivo no object storage (ex: s3://bucket/tenant-id/job-id/notas.zip). '
    'Preenchido para jobs do tipo BATCH_ZIP após o upload ser concluído.';

COMMENT ON COLUMN xml.import_job.total_count IS
    'Total de documentos XML do lote. '
    'Fixado em 1 para SINGLE_XML; atualizado após a etapa EXTRACT_ZIP para BATCH_ZIP. '
    'Contadores de sucesso/erro por fase ficam em import_job_step.';

COMMENT ON COLUMN xml.import_job.notes IS
    'Observações livres sobre o job (ex: motivo de cancelamento, mensagem de status final).';

COMMENT ON COLUMN xml.import_job.started_at IS
    'Momento em que o processamento efetivo do job iniciou (transição de PENDING para RUNNING).';

COMMENT ON COLUMN xml.import_job.completed_at IS
    'Momento em que o job atingiu um status final: COMPLETED, PARTIAL, FAILED ou CANCELLED.';

COMMENT ON COLUMN xml.import_job.expires_at IS
    'Data/hora após a qual este registro de log pode ser removido pelo job de limpeza agendado. '
    'Sugestão de TTL: 30 dias para COMPLETED/PARTIAL, 90 dias para FAILED/CANCELLED.';

COMMENT ON COLUMN xml.import_job.job_fts IS
    'Vetor FTS para busca por nome de arquivo, cpf_cnpj, tipo e status. '
    'Atualizado automaticamente pela trigger tr_fts_import_job.';

COMMENT ON COLUMN xml.import_job.created_at IS
    'Timestamp de criação do job (momento do recebimento da requisição de importação).';

COMMENT ON COLUMN xml.import_job.updated_at IS
    'Timestamp da última atualização do job. Gerenciado automaticamente pela trigger tr_upd_import_job.';

-- Índices de xml.import_job

-- Listagem e paginação de jobs por tenant, ordenados do mais recente ao mais antigo.
CREATE INDEX IF NOT EXISTS idx_import_job_tenant_id
    ON xml.import_job (tenant_id, created_at DESC);

-- Filtro de jobs ativos por tenant (ex: polling de RUNNING, listagem de FAILED).
CREATE INDEX IF NOT EXISTS idx_import_job_tenant_status
    ON xml.import_job (tenant_id, job_status);

-- Índice parcial para o job de limpeza: localiza apenas registros finalizados com TTL vencido.
-- Parcial: evita varrer jobs ainda PENDING ou RUNNING no processo de limpeza periódica.
CREATE INDEX IF NOT EXISTS idx_import_job_expires_at
    ON xml.import_job (expires_at)
    WHERE job_status IN ('COMPLETED', 'PARTIAL', 'FAILED', 'CANCELLED');

-- Índice GIN para full-text search nos jobs de importação.
CREATE INDEX IF NOT EXISTS idx_import_job_fts
    ON xml.import_job USING GIN (job_fts);

-- Triggers de xml.import_job
CREATE TRIGGER tr_upd_import_job
    BEFORE UPDATE ON xml.import_job
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_fts_import_job
    BEFORE INSERT OR UPDATE OF file_name, cpf_cnpj, user_email, job_type, job_status
    ON xml.import_job
    FOR EACH ROW
    EXECUTE FUNCTION xml.fn_update_job_fts();

-- -----------------------------------------------------------------------------
-- 4. TABELA: xml.import_job_step
-- Etapas individuais de cada job de importação. Removidas em CASCADE com import_job.
--
-- Etapas por tipo de job:
--   SINGLE_XML : 1. STORE_XML → 2. PROCESS_NF
--   BATCH_ZIP  : 1. UPLOAD_BUCKET → 2. EXTRACT_ZIP → 3. STORE_XML → 4. PROCESS_NF
--
-- Contadores por etapa (granularidade correta):
--   STORE_XML   : total=500, success=490, error=10  → 10 XMLs não armazenados
--   PROCESS_NF  : total=490, success=480, error=10  → 10 falhas na extração para nota_fiscal
--   Dessa forma é possível saber exatamente em qual fase cada documento falhou.
--
-- Exemplos de step_metadata (JSONB) por etapa:
--   UPLOAD_BUCKET : { "bucket_key": "s3://...", "upload_duration_ms": 1230 }
--   EXTRACT_ZIP   : { "extracted_count": 312, "skipped_count": 2 }
--   STORE_XML     : { "duplicate_count": 3 }
--   PROCESS_NF    : { "already_exists_count": 2 }
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS xml.import_job_step (

    -- Chave primária
    step_id             UUID            NOT NULL DEFAULT gen_random_uuid(),

    -- Relacionamento
    job_id              UUID            NOT NULL,

    -- Definição da etapa
    step_order          SMALLINT        NOT NULL,
    step_name           VARCHAR(30)     NOT NULL,
    step_status         VARCHAR(20)     NOT NULL DEFAULT 'PENDING',

    -- Contadores de progresso desta etapa
    total_count         INTEGER         NOT NULL DEFAULT 0,
    success_count       INTEGER         NOT NULL DEFAULT 0,
    error_count         INTEGER         NOT NULL DEFAULT 0,

    -- Resultado da etapa
    step_message        TEXT,
    step_metadata       JSONB,

    -- Controle temporal
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,

    -- Timestamps
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT import_job_step_pkey         PRIMARY KEY (step_id),
    CONSTRAINT uq_import_job_step_order     UNIQUE (job_id, step_order),
    CONSTRAINT fk_import_job_step_job       FOREIGN KEY (job_id)
        REFERENCES xml.import_job (job_id) ON DELETE CASCADE,
    CONSTRAINT ck_import_job_step_name      CHECK (step_name   IN ('STORE_XML', 'PROCESS_NF', 'UPLOAD_BUCKET', 'EXTRACT_ZIP')),
    CONSTRAINT ck_import_job_step_status    CHECK (step_status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'SKIPPED')),
    CONSTRAINT ck_import_job_step_counts    CHECK (total_count >= 0 AND success_count >= 0 AND error_count >= 0)
);

ALTER TABLE xml.import_job_step OWNER TO dorcilio;

COMMENT ON TABLE xml.import_job_step IS
    'Etapas individuais de cada job de importação. Cada etapa possui seus próprios contadores '
    '(total_count, success_count, error_count) permitindo rastrear com precisão em qual fase '
    'cada documento falhou. Ex: STORE_XML pode ter 490 sucessos e 10 erros; PROCESS_NF pode ter '
    '480 sucessos e 10 erros sobre os 490 que foram armazenados. '
    'Removida automaticamente em CASCADE quando o import_job é deletado no processo de limpeza por TTL.';

COMMENT ON COLUMN xml.import_job_step.step_id IS
    'Identificador único da etapa (UUID v4).';

COMMENT ON COLUMN xml.import_job_step.job_id IS
    'Job ao qual esta etapa pertence. FK com CASCADE — excluído junto com o job pai.';

COMMENT ON COLUMN xml.import_job_step.step_order IS
    'Ordem de execução da etapa dentro do job (1, 2, 3, 4). '
    'Determina a sequência de exibição no frontend.';

COMMENT ON COLUMN xml.import_job_step.step_name IS
    'Identificador da etapa: '
    'STORE_XML     = armazenar XML(s) em xml.xml_storage; '
    'PROCESS_NF    = extrair dados para nota_fiscal.b01_ide e tabelas filhas; '
    'UPLOAD_BUCKET = enviar arquivo ZIP para o object storage (somente BATCH_ZIP); '
    'EXTRACT_ZIP   = descompactar o ZIP e separar os XMLs individuais (somente BATCH_ZIP).';

COMMENT ON COLUMN xml.import_job_step.step_status IS
    'Status da etapa: PENDING | RUNNING | COMPLETED | FAILED | SKIPPED. '
    'SKIPPED é usado quando uma etapa anterior falhou completamente e as subsequentes são canceladas.';

COMMENT ON COLUMN xml.import_job_step.total_count IS
    'Total de documentos XML que esta etapa deveria processar. '
    'Para PROCESS_NF, corresponde ao success_count da etapa STORE_XML anterior.';

COMMENT ON COLUMN xml.import_job_step.success_count IS
    'Quantidade de documentos processados com sucesso nesta etapa. '
    'Incrementado atomicamente pelo backend a cada XML processado.';

COMMENT ON COLUMN xml.import_job_step.error_count IS
    'Quantidade de documentos que falharam nesta etapa. '
    'Detalhes individuais de cada falha ficam em import_job_error.';

COMMENT ON COLUMN xml.import_job_step.step_message IS
    'Mensagem descritiva sobre o resultado da etapa, exibida ao usuário '
    '(ex: "312 arquivos extraídos com sucesso", "Falha ao conectar ao bucket").';

COMMENT ON COLUMN xml.import_job_step.step_metadata IS
    'Dados adicionais da etapa em formato JSON livre. '
    'Ver exemplos no cabeçalho desta tabela.';

COMMENT ON COLUMN xml.import_job_step.started_at IS
    'Momento em que a execução desta etapa iniciou.';

COMMENT ON COLUMN xml.import_job_step.completed_at IS
    'Momento em que esta etapa foi concluída (qualquer status final).';

COMMENT ON COLUMN xml.import_job_step.created_at IS
    'Timestamp de criação da etapa (gerado junto com o job antes do processamento iniciar).';

COMMENT ON COLUMN xml.import_job_step.updated_at IS
    'Timestamp da última atualização da etapa.';

-- Índice de xml.import_job_step

-- Listagem ordenada das etapas de um job (consulta principal do frontend para exibir progresso).
CREATE INDEX IF NOT EXISTS idx_import_job_step_job_order
    ON xml.import_job_step (job_id, step_order);

-- Trigger de xml.import_job_step
CREATE TRIGGER tr_upd_import_job_step
    BEFORE UPDATE ON xml.import_job_step
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

-- -----------------------------------------------------------------------------
-- 5. TABELA: xml.import_job_error
-- Erros individuais ocorridos durante a importação. Um job pode ter múltiplos erros
-- (ex: 5 XMLs inválidos num lote de 300). Removida em CASCADE com import_job.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS xml.import_job_error (

    -- Chave primária
    error_id            UUID            NOT NULL DEFAULT gen_random_uuid(),

    -- Relacionamento
    job_id              UUID            NOT NULL,

    -- Contexto do erro
    step_name           VARCHAR(30),
    file_reference      VARCHAR(512),
    ch_nf               VARCHAR(44),

    -- Detalhes do erro
    error_code          VARCHAR(50),
    error_message       TEXT            NOT NULL,
    error_detail        TEXT,

    -- Timestamp
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT import_job_error_pkey        PRIMARY KEY (error_id),
    CONSTRAINT fk_import_job_error_job      FOREIGN KEY (job_id)
        REFERENCES xml.import_job (job_id) ON DELETE CASCADE,
    CONSTRAINT ck_import_job_error_step     CHECK (
        step_name IS NULL OR
        step_name IN ('STORE_XML', 'PROCESS_NF', 'UPLOAD_BUCKET', 'EXTRACT_ZIP')
    )
);

ALTER TABLE xml.import_job_error OWNER TO dorcilio;

COMMENT ON TABLE xml.import_job_error IS
    'Erros individuais registrados durante um job de importação. '
    'Permite que o usuário visualize exatamente quais XMLs falharam, em qual etapa e por qual motivo. '
    'Removida automaticamente em CASCADE quando o import_job é deletado no processo de limpeza por TTL.';

COMMENT ON COLUMN xml.import_job_error.error_id IS
    'Identificador único do registro de erro (UUID v4).';

COMMENT ON COLUMN xml.import_job_error.job_id IS
    'Job ao qual este erro pertence. FK com CASCADE — excluído junto com o job pai.';

COMMENT ON COLUMN xml.import_job_error.step_name IS
    'Etapa em que o erro ocorreu: STORE_XML | PROCESS_NF | UPLOAD_BUCKET | EXTRACT_ZIP. '
    'NULL quando o erro é genérico do job (ex: arquivo corrompido antes do processamento).';

COMMENT ON COLUMN xml.import_job_error.file_reference IS
    'Nome ou caminho do arquivo que gerou o erro '
    '(ex: nome do XML dentro do ZIP, caminho no bucket). '
    'Auxilia o usuário a identificar qual arquivo corrigir e reenviar.';

COMMENT ON COLUMN xml.import_job_error.ch_nf IS
    'Chave de acesso do documento fiscal (44 dígitos), quando disponível no momento do erro. '
    'Pode ser NULL se o XML estava malformado e não foi possível extrair o ch_nf.';

COMMENT ON COLUMN xml.import_job_error.error_code IS
    'Código de erro legível por máquina para tratamento no backend/frontend. '
    'Exemplos: DUPLICATE_CH_NF, INVALID_XML, NF_EXTRACT_FAILED, BUCKET_UPLOAD_FAILED, ZIP_CORRUPT.';

COMMENT ON COLUMN xml.import_job_error.error_message IS
    'Mensagem de erro legível pelo usuário, exibida na interface.';

COMMENT ON COLUMN xml.import_job_error.error_detail IS
    'Detalhe técnico completo do erro: stack trace, resposta de API externa, mensagem do banco, etc. '
    'Não exposto ao usuário final — usado para debugging pelo time técnico.';

COMMENT ON COLUMN xml.import_job_error.created_at IS
    'Timestamp do momento em que o erro foi registrado.';

-- Índices de xml.import_job_error

-- Listagem de todos os erros de um job específico (consulta principal para exibir relatório de erros).
CREATE INDEX IF NOT EXISTS idx_import_job_error_job_id
    ON xml.import_job_error (job_id);

-- Busca de erros por chave de acesso (ex: verificar se um ch_nf específico já falhou antes).
-- Parcial: ignora linhas onde ch_nf é NULL (XMLs malformados sem chave identificável).
CREATE INDEX IF NOT EXISTS idx_import_job_error_ch_nf
    ON xml.import_job_error (ch_nf)
    WHERE ch_nf IS NOT NULL;