-- =============================================================================
-- SCHEMA: tax_reform
-- PROJETO: Fiscal Fácil
-- DATA: 2026-09-14
-- DESCRIÇÃO: Schema do módulo "Simulador da Reforma Tributária" (IBS/CBS/IS).
--            Suporta dois modos de simulação:
--              1) Por Produto/Catálogo (EAN/GTIN + NCM);
--              2) Por Nota Fiscal (comparativo "Antes vs. Depois" -
--                 ICMS/PIS/COFINS/ISS x IBS/CBS/IS).
--            Consolida as tabelas de classificação (CST, cClassTrib), os
--            catálogos de NCM/uTrib, produtos e NBS (serviços), as regras/
--            exceções dos Anexos da LC 214/25, a incidência do Imposto Seletivo
--            por produto, as alíquotas de transição (2026-2033, com abrangência
--            nacional/UF/município) e o histórico de simulações.
-- FONTES:    cClassTrib 2026-06-22; CST_INDICADORES; IT2024.001 (NCM/uTrib);
--            Anexos LC 214; AnexoVIII (NBS x cClassTrib); LC 116; CFOP indExcIBSCBS.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS tax_reform;
ALTER SCHEMA tax_reform OWNER TO dorcilio;

COMMENT ON SCHEMA tax_reform IS
    'Módulo Simulador da Reforma Tributária (IBS/CBS/IS). Contém a base de '
    'classificação tributária (CST/cClassTrib), catálogos de NCM, produtos '
    '(EAN/GTIN) e NBS (serviços), regras e exceções dos Anexos da LC 214/2025, '
    'a incidência do Imposto Seletivo por produto, alíquotas de transição por '
    'ano (nacional/UF/município) e o histórico de simulações "Antes vs. Depois".';

-- -----------------------------------------------------------------------------
-- 1. TIPOS (ENUMS)
-- -----------------------------------------------------------------------------

-- Tipo do tributo do novo modelo (Reforma Tributária).
CREATE TYPE tax_reform.new_tax_kind AS ENUM (
    'IBS_ESTADUAL',   -- parcela estadual do IBS
    'IBS_MUNICIPAL',  -- parcela municipal do IBS
    'CBS',            -- Contribuição sobre Bens e Serviços (federal)
    'IS'              -- Imposto Seletivo
);

-- Natureza do benefício/tratamento tributário aplicado.
CREATE TYPE tax_reform.benefit_kind AS ENUM (
    'INTEGRAL',        -- tributação integral
    'REDUCED',         -- alíquota reduzida (ex.: 60%, 30%)
    'ZERO',            -- alíquota zero (ex.: Cesta Básica Nacional)
    'EXEMPT',          -- isenção
    'IMMUNE',          -- imunidade / não incidência
    'DEFERRED',        -- diferimento
    'SUSPENDED',       -- suspensão
    'MONOPHASIC',      -- tributação monofásica
    'FIXED_RATE',      -- alíquota fixa
    'SPECIFIC_REGIME'  -- regime específico / declaração
);

-- Escopo de correspondência de uma regra (por qual chave ela é encontrada).
CREATE TYPE tax_reform.rule_scope AS ENUM (
    'NCM',         -- correspondência por código NCM/SH (bens)
    'NBS',         -- correspondência por código NBS (serviços)
    'LC116_ITEM',  -- correspondência por item da lista de serviços (LC 116/03)
    'CEST',        -- correspondência por CEST
    'GTIN'         -- correspondência por código de barras específico
);

-- Estratégia de correspondência do alvo da regra.
CREATE TYPE tax_reform.match_kind AS ENUM (
    'EXACT',    -- código exato
    'PREFIX'    -- prefixo (ex.: NCM "1006" cobre "1006.20", "1006.30", ...)
);

-- Modo/estado de uma simulação.
CREATE TYPE tax_reform.simulation_kind AS ENUM (
    'PRODUCT',  -- simulação por produto/catálogo
    'INVOICE'   -- simulação por nota fiscal (Antes vs. Depois)
);

CREATE TYPE tax_reform.simulation_status AS ENUM (
    'DRAFT',
    'COMPLETED',
    'FAILED'
);

-- Abrangência territorial de uma alíquota (destino do IBS).
CREATE TYPE tax_reform.jurisdiction_kind AS ENUM (
    'NATIONAL',   -- alíquota de referência nacional
    'STATE',      -- alíquota específica por UF (parcela estadual do IBS)
    'MUNICIPAL'   -- alíquota específica por município (parcela municipal do IBS)
);

-- Forma de cobrança do Imposto Seletivo (IS).
CREATE TYPE tax_reform.is_rate_kind AS ENUM (
    'AD_VALOREM',  -- percentual sobre o valor (ex.: 0.1000 = 10%)
    'SPECIFIC'     -- valor fixo por unidade de medida (ad rem, ex.: R$/L)
);

-- -----------------------------------------------------------------------------
-- 2. FUNÇÕES (FTS)
-- -----------------------------------------------------------------------------

-- Atualiza o vetor FTS do catálogo de NCM.
CREATE OR REPLACE FUNCTION tax_reform.fn_refresh_ncm_fts()
RETURNS trigger AS $$
BEGIN
    NEW.ncm_fts :=
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.ncm_code, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.ncm_description, ''))), 'B');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tax_reform.fn_refresh_ncm_fts() IS
    'Atualiza o vetor FTS de tax_reform.ncms. Pesos: ncm_code = A, ncm_description = B.';

-- Atualiza o vetor FTS do catálogo de produtos (referência).
CREATE OR REPLACE FUNCTION tax_reform.fn_refresh_product_ref_fts()
RETURNS trigger AS $$
BEGIN
    NEW.product_fts :=
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.gtin, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.product_description, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.ncm_code, ''))), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.cest_code, ''))), 'C');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tax_reform.fn_refresh_product_ref_fts() IS
    'Atualiza o vetor FTS de tax_reform.products_ref. Pesos: gtin/descrição = A, ncm = B, cest = C.';

-- Atualiza o vetor FTS do catálogo de NBS (serviços).
CREATE OR REPLACE FUNCTION tax_reform.fn_refresh_nbs_fts()
RETURNS trigger AS $$
BEGIN
    NEW.nbs_fts :=
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.nbs_code, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.nbs_description, ''))), 'B');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tax_reform.fn_refresh_nbs_fts() IS
    'Atualiza o vetor FTS de tax_reform.nbs. Pesos: nbs_code = A, nbs_description = B.';

-- -----------------------------------------------------------------------------
-- 3. TABELAS DE REFERÊNCIA (CLASSIFICAÇÃO TRIBUTÁRIA)
-- -----------------------------------------------------------------------------

-- 3.1. CST do IBS/CBS (Código de Situação Tributária).
--      Fonte: CST_INDICADORES_20250514_PUBLICACAO.xlsx.
CREATE TABLE tax_reform.cst (
    -- Chaves
    cst_code                VARCHAR(3) PRIMARY KEY,

    -- Dados obrigatórios
    cst_description         VARCHAR(255) NOT NULL,

    -- Indicadores (grupos exigidos no DFe)
    allowed_in_icms_dfe     BOOLEAN NOT NULL DEFAULT FALSE,
    ind_ibscbs              BOOLEAN NOT NULL DEFAULT FALSE,
    ind_ibscbs_mono         BOOLEAN NOT NULL DEFAULT FALSE,
    ind_reduction           BOOLEAN NOT NULL DEFAULT FALSE,
    ind_deferral            BOOLEAN NOT NULL DEFAULT FALSE,
    ind_regular_taxation    BOOLEAN,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT ck_cst_code_len CHECK (char_length(cst_code) = 3)
);

COMMENT ON TABLE tax_reform.cst IS
    'Códigos de Situação Tributária do IBS/CBS (ex.: 000 integral, 200 reduzida, '
    '400 isenção, 510 diferimento, 620 monofásica). Base para tax_reform.tax_classifications.';
COMMENT ON COLUMN tax_reform.cst.cst_code IS 'Código de Situação Tributária do IBS/CBS com 3 dígitos (ex.: 000, 200, 510).';
COMMENT ON COLUMN tax_reform.cst.cst_description IS 'Descrição oficial do CST (ex.: Tributação integral, Alíquota reduzida).';
COMMENT ON COLUMN tax_reform.cst.allowed_in_icms_dfe IS 'Indica se o CST é permitido em DFe modelo ICMS durante a fase de transição.';
COMMENT ON COLUMN tax_reform.cst.ind_ibscbs IS 'Indica se o grupo de tributação regular do IBS/CBS é exigido no DFe.';
COMMENT ON COLUMN tax_reform.cst.ind_ibscbs_mono IS 'Indica se o grupo de tributação monofásica do IBS/CBS é exigido.';
COMMENT ON COLUMN tax_reform.cst.ind_reduction IS 'Indica se há redução de alíquota associada ao CST.';
COMMENT ON COLUMN tax_reform.cst.ind_deferral IS 'Indica se o CST corresponde a diferimento do imposto.';
COMMENT ON COLUMN tax_reform.cst.ind_regular_taxation IS 'Indica tributação regular (pode exigir avaliação na cClassTrib quando nulo/condicional).';
COMMENT ON COLUMN tax_reform.cst.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.cst.updated_at IS 'Data da última alteração no registro.';

-- 3.2. Classificação Tributária (cClassTrib).
--      Fonte: cClassTrib 2026-06-22.xlsx (aba "cClass").
CREATE TABLE tax_reform.tax_classifications (
    -- Chaves
    tax_class_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cst_code                VARCHAR(3) NOT NULL,

    -- Dados obrigatórios
    class_trib_code         VARCHAR(6) NOT NULL,
    class_trib_name         VARCHAR(500) NOT NULL,
    benefit_type            tax_reform.benefit_kind NOT NULL DEFAULT 'INTEGRAL',

    -- Percentuais de redução da alíquota (0.0000 a 1.0000; ex.: 0.6000 = 60%)
    p_reduction_ibs         NUMERIC(15,4) NOT NULL DEFAULT 0,
    p_reduction_cbs         NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Dados opcionais / normativos
    class_trib_description   TEXT,
    rate_type                VARCHAR(50),          -- "Padrão", "Fixa", etc.
    legal_basis              TEXT,                 -- artigo LC 214/25
    cbs_regulation           TEXT,
    ibs_regulation           TEXT,
    anexo_ref                VARCHAR(50),          -- anexo relacionado (quando houver)
    source_link              TEXT,

    -- Snapshot dos indicadores/colunas originais da planilha oficial
    indicators              JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Vigência
    valid_from               DATE NOT NULL DEFAULT DATE '2026-01-01',
    valid_to                 DATE,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_tax_classifications_code UNIQUE (class_trib_code),
    CONSTRAINT fk_tax_classifications_cst FOREIGN KEY (cst_code)
        REFERENCES tax_reform.cst (cst_code) ON UPDATE CASCADE,
    CONSTRAINT ck_tax_classifications_code_len CHECK (char_length(class_trib_code) = 6),
    CONSTRAINT ck_tax_classifications_pred_ibs CHECK (p_reduction_ibs BETWEEN 0 AND 1),
    CONSTRAINT ck_tax_classifications_pred_cbs CHECK (p_reduction_cbs BETWEEN 0 AND 1),
    CONSTRAINT ck_tax_classifications_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

COMMENT ON TABLE tax_reform.tax_classifications IS
    'Classificação Tributária (cClassTrib) do IBS/CBS. Detalha, por CST, o código '
    'de 6 dígitos, o percentual de redução aplicável e a base normativa (LC 214/25).';
COMMENT ON COLUMN tax_reform.tax_classifications.tax_class_id IS 'Identificador interno da classificação (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.tax_classifications.cst_code IS 'CST ao qual a classificação pertence (FK para tax_reform.cst).';
COMMENT ON COLUMN tax_reform.tax_classifications.class_trib_code IS 'Código cClassTrib de 6 dígitos (ex.: 000001, 200038).';
COMMENT ON COLUMN tax_reform.tax_classifications.class_trib_name IS 'Nome/título da classificação tributária.';
COMMENT ON COLUMN tax_reform.tax_classifications.benefit_type IS 'Natureza do tratamento tributário (integral, reduzido, zero, isento, etc.).';
COMMENT ON COLUMN tax_reform.tax_classifications.p_reduction_ibs IS
    'Percentual de redução da alíquota do IBS (0.6000 = redução de 60%; 1.0000 = alíquota zero).';
COMMENT ON COLUMN tax_reform.tax_classifications.p_reduction_cbs IS
    'Percentual de redução da alíquota da CBS (0.6000 = redução de 60%; 1.0000 = alíquota zero).';
COMMENT ON COLUMN tax_reform.tax_classifications.class_trib_description IS 'Descrição detalhada da situação abrangida pela classificação.';
COMMENT ON COLUMN tax_reform.tax_classifications.rate_type IS 'Tipo de alíquota (ex.: Padrão, Fixa).';
COMMENT ON COLUMN tax_reform.tax_classifications.legal_basis IS 'Base legal na LC 214/2025 (artigo/redação).';
COMMENT ON COLUMN tax_reform.tax_classifications.cbs_regulation IS 'Referência ao regulamento da CBS.';
COMMENT ON COLUMN tax_reform.tax_classifications.ibs_regulation IS 'Referência ao regulamento do IBS.';
COMMENT ON COLUMN tax_reform.tax_classifications.anexo_ref IS 'Anexo da LC 214/2025 relacionado (quando houver).';
COMMENT ON COLUMN tax_reform.tax_classifications.source_link IS 'URL da fonte normativa oficial.';
COMMENT ON COLUMN tax_reform.tax_classifications.indicators IS
    'Snapshot JSONB dos indicadores originais (ind_gTribRegular, ind_gCredPresOper, ind_gMono*, etc.).';
COMMENT ON COLUMN tax_reform.tax_classifications.valid_from IS 'Data de início de vigência da classificação.';
COMMENT ON COLUMN tax_reform.tax_classifications.valid_to IS 'Data de fim de vigência (nulo = vigente por prazo indeterminado).';
COMMENT ON COLUMN tax_reform.tax_classifications.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.tax_classifications.updated_at IS 'Data da última alteração no registro.';

-- 3.3. Catálogo de NCM/SH.
--      Fonte: IT2024.001 - Tabela NCM 2022 com uTrib.
CREATE TABLE tax_reform.ncms (
    -- Chaves
    ncm_id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dados obrigatórios
    ncm_code                 VARCHAR(8) NOT NULL,
    ncm_description          TEXT NOT NULL,

    -- Unidade tributável (comércio exterior)
    utrib_export_abbr        VARCHAR(10),
    utrib_export_description VARCHAR(100),

    -- Classificação tributária padrão do NCM (fallback do simulador)
    default_class_trib_code  VARCHAR(6),

    -- Vigência
    valid_from               DATE,
    valid_to                 DATE,

    -- Busca
    ncm_fts                  TSVECTOR,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_ncms_code UNIQUE (ncm_code),
    CONSTRAINT fk_ncms_class_trib FOREIGN KEY (default_class_trib_code)
        REFERENCES tax_reform.tax_classifications (class_trib_code) ON UPDATE CASCADE,
    CONSTRAINT ck_ncms_code_numeric CHECK (ncm_code ~ '^[0-9]{8}$')
);

COMMENT ON TABLE tax_reform.ncms IS
    'Catálogo de códigos NCM/SH (8 dígitos) com unidade tributável de exportação. '
    'Chave de busca principal do simulador por produto.';
COMMENT ON COLUMN tax_reform.ncms.ncm_id IS 'Identificador interno do NCM (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.ncms.ncm_code IS 'Código NCM/SH de 8 dígitos sem máscara.';
COMMENT ON COLUMN tax_reform.ncms.ncm_description IS 'Descrição oficial da mercadoria segundo a NCM/SH.';
COMMENT ON COLUMN tax_reform.ncms.utrib_export_abbr IS 'Abreviatura da unidade tributável usada em exportação (ex.: UN, KG).';
COMMENT ON COLUMN tax_reform.ncms.utrib_export_description IS 'Descrição da unidade tributável de exportação.';
COMMENT ON COLUMN tax_reform.ncms.default_class_trib_code IS 'Classificação tributária padrão do NCM (fallback quando não há produto/regra específica).';
COMMENT ON COLUMN tax_reform.ncms.valid_from IS 'Data de início de vigência do código NCM.';
COMMENT ON COLUMN tax_reform.ncms.valid_to IS 'Data de fim de vigência do código NCM (nulo = vigente).';
COMMENT ON COLUMN tax_reform.ncms.ncm_fts IS 'Vetor de busca textual para localização rápida por código ou descrição.';
COMMENT ON COLUMN tax_reform.ncms.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.ncms.updated_at IS 'Data da última alteração no registro.';

-- 3.4. Catálogo de produtos (referência EAN/GTIN -> NCM -> classificação padrão).
CREATE TABLE tax_reform.products_ref (
    -- Chaves
    product_ref_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ncm_id                   BIGINT,

    -- Dados obrigatórios
    gtin                     VARCHAR(14) NOT NULL,      -- EAN/GTIN
    ncm_code                 VARCHAR(8) NOT NULL,       -- desnormalizado p/ busca rápida
    product_description      VARCHAR(500) NOT NULL,

    -- Dados opcionais
    cest_code                VARCHAR(7),
    default_class_trib_code  VARCHAR(6),

    -- Busca
    product_fts              TSVECTOR,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_products_ref_gtin UNIQUE (gtin),
    CONSTRAINT fk_products_ref_ncm FOREIGN KEY (ncm_id)
        REFERENCES tax_reform.ncms (ncm_id) ON DELETE SET NULL,
    CONSTRAINT fk_products_ref_class_trib FOREIGN KEY (default_class_trib_code)
        REFERENCES tax_reform.tax_classifications (class_trib_code) ON UPDATE CASCADE,
    CONSTRAINT ck_products_ref_gtin CHECK (gtin ~ '^[0-9]{8,14}$')
);

COMMENT ON TABLE tax_reform.products_ref IS
    'Catálogo de produtos por código de barras (EAN/GTIN), vinculando NCM e a '
    'classificação tributária padrão. Alimenta o modo de simulação por produto.';
COMMENT ON COLUMN tax_reform.products_ref.product_ref_id IS 'Identificador interno do produto (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.products_ref.ncm_id IS 'NCM vinculado ao produto (FK para tax_reform.ncms).';
COMMENT ON COLUMN tax_reform.products_ref.gtin IS 'Código de barras EAN/GTIN (8 a 14 dígitos).';
COMMENT ON COLUMN tax_reform.products_ref.ncm_code IS 'Código NCM desnormalizado para busca rápida.';
COMMENT ON COLUMN tax_reform.products_ref.product_description IS 'Descrição comercial do produto.';
COMMENT ON COLUMN tax_reform.products_ref.cest_code IS 'Código CEST (7 dígitos) quando aplicável.';
COMMENT ON COLUMN tax_reform.products_ref.default_class_trib_code IS 'Classificação tributária padrão do produto (FK para tax_classifications).';
COMMENT ON COLUMN tax_reform.products_ref.product_fts IS 'Vetor de busca textual por GTIN, descrição, NCM ou CEST.';
COMMENT ON COLUMN tax_reform.products_ref.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.products_ref.updated_at IS 'Data da última alteração no registro.';

-- 3.5. Catálogo de NBS (serviços) -> LC 116 -> classificação padrão.
--      Fonte: nbs.csv / AnexoVIII (correlação NBS x cClassTrib) / LC 116.
--      Habilita o modo de simulação de serviços (Fase 2 do planejamento).
CREATE TABLE tax_reform.nbs (
    -- Chaves
    nbs_id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dados obrigatórios
    nbs_code                 VARCHAR(9) NOT NULL,       -- NBS de 9 dígitos (sem máscara)
    nbs_description          TEXT NOT NULL,

    -- Correlação com a lista de serviços e classificação padrão
    lc116_item               VARCHAR(10),               -- item da LC 116 (ex.: 0101)
    indop_code               VARCHAR(6),                -- indicador de local de incidência (ex.: 100301)
    default_class_trib_code  VARCHAR(6),

    -- Vigência
    valid_from               DATE,
    valid_to                 DATE,

    -- Busca
    nbs_fts                  TSVECTOR,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_nbs_code UNIQUE (nbs_code),
    CONSTRAINT fk_nbs_class_trib FOREIGN KEY (default_class_trib_code)
        REFERENCES tax_reform.tax_classifications (class_trib_code) ON UPDATE CASCADE
);

COMMENT ON TABLE tax_reform.nbs IS
    'Catálogo da Nomenclatura Brasileira de Serviços (NBS), correlacionado à lista '
    'de serviços da LC 116 e à classificação tributária padrão. Chave de busca do '
    'simulador de serviços.';
COMMENT ON COLUMN tax_reform.nbs.nbs_id IS 'Identificador interno do NBS (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.nbs.nbs_code IS 'Código NBS de 9 dígitos sem máscara.';
COMMENT ON COLUMN tax_reform.nbs.nbs_description IS 'Descrição oficial do serviço segundo a NBS.';
COMMENT ON COLUMN tax_reform.nbs.lc116_item IS 'Item correspondente da lista de serviços da LC 116 (ex.: 0101).';
COMMENT ON COLUMN tax_reform.nbs.indop_code IS 'Indicador do local de incidência do IBS (ex.: 100301 = domicílio do adquirente).';
COMMENT ON COLUMN tax_reform.nbs.default_class_trib_code IS 'Classificação tributária padrão do serviço (FK para tax_classifications).';
COMMENT ON COLUMN tax_reform.nbs.nbs_fts IS 'Vetor de busca textual por código ou descrição do serviço.';
COMMENT ON COLUMN tax_reform.nbs.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.nbs.updated_at IS 'Data da última alteração no registro.';

-- -----------------------------------------------------------------------------
-- 4. REGRAS, EXCEÇÕES E ALVOS (ANEXOS LC 214/2025)
-- -----------------------------------------------------------------------------

-- 4.1. Regras condicionais (cesta básica, saúde, educação, insumos agro, etc.).
CREATE TABLE tax_reform.rules_and_exceptions (
    -- Chaves
    rule_id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_class_id             BIGINT,

    -- Dados obrigatórios
    rule_code                VARCHAR(50) NOT NULL,
    rule_name                VARCHAR(500) NOT NULL,
    benefit_type             tax_reform.benefit_kind NOT NULL,
    scope_type               tax_reform.rule_scope NOT NULL,

    -- Efeito sobre alíquotas (0.0000 a 1.0000)
    p_reduction_ibs          NUMERIC(15,4) NOT NULL DEFAULT 0,
    p_reduction_cbs          NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Vínculos de classificação
    cst_code                 VARCHAR(3),
    class_trib_code          VARCHAR(6),

    -- Normativo / origem
    anexo_ref                VARCHAR(50),               -- ex.: "Anexo I", "Anexo IX"
    legal_basis              TEXT,                      -- ex.: "Art. 125 LC 214/25"

    -- Condições adicionais avaliadas em runtime (regras compostas)
    conditions               JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Vigência
    valid_from               DATE NOT NULL DEFAULT DATE '2026-01-01',
    valid_to                 DATE,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_rules_code UNIQUE (rule_code),
    CONSTRAINT fk_rules_tax_class FOREIGN KEY (tax_class_id)
        REFERENCES tax_reform.tax_classifications (tax_class_id) ON DELETE SET NULL,
    CONSTRAINT fk_rules_cst FOREIGN KEY (cst_code)
        REFERENCES tax_reform.cst (cst_code) ON UPDATE CASCADE,
    CONSTRAINT fk_rules_class_trib FOREIGN KEY (class_trib_code)
        REFERENCES tax_reform.tax_classifications (class_trib_code) ON UPDATE CASCADE,
    CONSTRAINT ck_rules_pred_ibs CHECK (p_reduction_ibs BETWEEN 0 AND 1),
    CONSTRAINT ck_rules_pred_cbs CHECK (p_reduction_cbs BETWEEN 0 AND 1),
    CONSTRAINT ck_rules_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

COMMENT ON TABLE tax_reform.rules_and_exceptions IS
    'Regras condicionais e exceções dos Anexos da LC 214/2025 (Cesta Básica '
    'Nacional - alíquota zero; saúde/educação - redução de 60%; medicamentos; '
    'insumos agropecuários; regimes específicos). O campo conditions permite '
    'regras compostas avaliadas em runtime.';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.rule_id IS 'Identificador único da regra (UUID).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.tax_class_id IS 'Classificação tributária resultante da regra (FK para tax_classifications).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.rule_code IS 'Código interno único da regra (ex.: CESTA_BASICA_ANEXO_I).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.rule_name IS 'Nome descritivo da regra/exceção.';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.benefit_type IS 'Natureza do benefício aplicado (zero, reduzido, isento, etc.).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.scope_type IS 'Escopo pelo qual a regra é localizada (NCM, NBS, item LC116, CEST, GTIN).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.p_reduction_ibs IS 'Percentual de redução da alíquota do IBS aplicado pela regra (1.0000 = alíquota zero).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.p_reduction_cbs IS 'Percentual de redução da alíquota da CBS aplicado pela regra (1.0000 = alíquota zero).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.cst_code IS 'CST associado à regra (FK para tax_reform.cst).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.class_trib_code IS 'Código cClassTrib associado à regra (FK para tax_classifications).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.anexo_ref IS 'Anexo da LC 214/2025 que originou a regra (ex.: Anexo I, Anexo IX).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.legal_basis IS 'Base legal da regra (ex.: Art. 125 LC 214/25).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.conditions IS 'Condições adicionais em JSONB avaliadas em runtime (regras compostas).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.valid_from IS 'Data de início de vigência da regra.';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.valid_to IS 'Data de fim de vigência da regra (nulo = vigente).';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.rules_and_exceptions.updated_at IS 'Data da última alteração no registro.';

-- 4.2. Alvos de correspondência das regras (NCM/NBS/LC116/CEST/GTIN).
CREATE TABLE tax_reform.rule_targets (
    -- Chaves
    rule_target_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id                  UUID NOT NULL,

    -- Dados obrigatórios
    target_scope             tax_reform.rule_scope NOT NULL,
    target_code              VARCHAR(30) NOT NULL,      -- NCM/NBS/item LC116/CEST/GTIN
    match_type               tax_reform.match_kind NOT NULL DEFAULT 'EXACT',

    -- Dados opcionais
    target_description        TEXT,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_rule_targets UNIQUE (rule_id, target_scope, target_code, match_type),
    CONSTRAINT fk_rule_targets_rule FOREIGN KEY (rule_id)
        REFERENCES tax_reform.rules_and_exceptions (rule_id) ON DELETE CASCADE
);

COMMENT ON TABLE tax_reform.rule_targets IS
    'Mapeia cada regra aos códigos que a acionam (NCM, NBS, item LC 116, CEST ou '
    'GTIN). match_type=PREFIX permite cobrir famílias de NCM (ex.: prefixo "1006").';
COMMENT ON COLUMN tax_reform.rule_targets.rule_target_id IS 'Identificador interno do alvo (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.rule_targets.rule_id IS 'Regra à qual o alvo pertence (FK para rules_and_exceptions).';
COMMENT ON COLUMN tax_reform.rule_targets.target_scope IS 'Tipo do código de correspondência (NCM, NBS, LC116_ITEM, CEST, GTIN).';
COMMENT ON COLUMN tax_reform.rule_targets.target_code IS 'Código que aciona a regra (valor do NCM/NBS/item/CEST/GTIN).';
COMMENT ON COLUMN tax_reform.rule_targets.match_type IS 'Estratégia de correspondência: EXACT (exato) ou PREFIX (família de códigos).';
COMMENT ON COLUMN tax_reform.rule_targets.target_description IS 'Descrição opcional do item alvo.';
COMMENT ON COLUMN tax_reform.rule_targets.created_at IS 'Data de criação do registro.';

-- -----------------------------------------------------------------------------
-- 5. ALÍQUOTAS DE TRANSIÇÃO (2026-2033+)
-- -----------------------------------------------------------------------------

CREATE TABLE tax_reform.transition_rates (
    -- Chaves
    transition_rate_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dados obrigatórios
    reference_year           SMALLINT NOT NULL,
    tax_kind                 tax_reform.new_tax_kind NOT NULL,
    standard_rate            NUMERIC(15,4) NOT NULL,    -- alíquota de referência

    -- Abrangência territorial da alíquota (destino do IBS)
    jurisdiction_scope       tax_reform.jurisdiction_kind NOT NULL DEFAULT 'NATIONAL',
    uf                       CHAR(2),                   -- UF (parcela estadual do IBS)
    ibge_city_code           VARCHAR(7),                -- código IBGE (parcela municipal)

    -- Fator de manutenção dos tributos antigos na transição
    -- (1.0000 = 100% do ICMS/ISS/PIS/COFINS ainda devido; 0.0000 = extinto)
    legacy_icms_iss_factor   NUMERIC(15,4) NOT NULL DEFAULT 1,
    legacy_pis_cofins_factor NUMERIC(15,4) NOT NULL DEFAULT 1,

    -- Dados opcionais
    phase_description        VARCHAR(255),

    -- Vigência
    valid_from               DATE NOT NULL,
    valid_to                 DATE,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT ck_transition_year CHECK (reference_year BETWEEN 2026 AND 2100),
    CONSTRAINT ck_transition_rate CHECK (standard_rate >= 0),
    CONSTRAINT ck_transition_legacy_icms CHECK (legacy_icms_iss_factor BETWEEN 0 AND 1),
    CONSTRAINT ck_transition_legacy_pis CHECK (legacy_pis_cofins_factor BETWEEN 0 AND 1),
    CONSTRAINT ck_transition_jurisdiction CHECK (
        (jurisdiction_scope = 'NATIONAL' AND uf IS NULL AND ibge_city_code IS NULL) OR
        (jurisdiction_scope = 'STATE' AND uf IS NOT NULL AND ibge_city_code IS NULL) OR
        (jurisdiction_scope = 'MUNICIPAL' AND uf IS NOT NULL AND ibge_city_code IS NOT NULL)
    )
);

COMMENT ON TABLE tax_reform.transition_rates IS
    'Alíquotas de referência e fatores de transição por ano (2026-2033+). '
    'Parametriza a projeção gradual do novo modelo e a redução dos tributos '
    'antigos (ICMS/ISS/PIS/COFINS) durante o período de transição.';
COMMENT ON COLUMN tax_reform.transition_rates.transition_rate_id IS 'Identificador interno da alíquota de transição (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.transition_rates.reference_year IS 'Ano de referência da alíquota (2026 a 2100).';
COMMENT ON COLUMN tax_reform.transition_rates.tax_kind IS 'Tributo do novo modelo (IBS estadual, IBS municipal, CBS ou IS).';
COMMENT ON COLUMN tax_reform.transition_rates.standard_rate IS 'Alíquota de referência do tributo no ano.';
COMMENT ON COLUMN tax_reform.transition_rates.jurisdiction_scope IS 'Abrangência da alíquota: NATIONAL (referência), STATE (por UF) ou MUNICIPAL (por município).';
COMMENT ON COLUMN tax_reform.transition_rates.uf IS 'UF do destino quando a alíquota é estadual/municipal (nulo quando nacional).';
COMMENT ON COLUMN tax_reform.transition_rates.ibge_city_code IS 'Código IBGE do município quando a alíquota é municipal (nulo caso contrário).';
COMMENT ON COLUMN tax_reform.transition_rates.legacy_icms_iss_factor IS
    'Fração do ICMS/ISS ainda devida no ano (1.0000 = integral; 0.0000 = extinto).';
COMMENT ON COLUMN tax_reform.transition_rates.legacy_pis_cofins_factor IS
    'Fração do PIS/COFINS ainda devida no ano (1.0000 = integral; 0.0000 = extinto).';
COMMENT ON COLUMN tax_reform.transition_rates.phase_description IS 'Descrição da fase de transição (ex.: ano-teste, início da CBS).';
COMMENT ON COLUMN tax_reform.transition_rates.valid_from IS 'Data de início de vigência da alíquota.';
COMMENT ON COLUMN tax_reform.transition_rates.valid_to IS 'Data de fim de vigência da alíquota (nulo = vigente).';
COMMENT ON COLUMN tax_reform.transition_rates.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.transition_rates.updated_at IS 'Data da última alteração no registro.';

-- 5.1. Incidência do Imposto Seletivo (IS) por produto.
--      O IS é seletivo (ex.: cigarros, bebidas açucaradas) e pode ser ad valorem
--      (percentual) ou específico (valor por unidade). Inicia em 2027.
CREATE TABLE tax_reform.is_incidences (
    -- Chaves
    is_incidence_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Alvo (por qual código o IS é localizado)
    scope_type               tax_reform.rule_scope NOT NULL DEFAULT 'NCM',
    target_code              VARCHAR(30) NOT NULL,
    match_type               tax_reform.match_kind NOT NULL DEFAULT 'EXACT',

    -- Dados obrigatórios
    description              VARCHAR(500) NOT NULL,
    rate_kind                tax_reform.is_rate_kind NOT NULL DEFAULT 'AD_VALOREM',

    -- Alíquota conforme rate_kind
    ad_valorem_rate          NUMERIC(15,4),   -- fração (0.1000 = 10%) quando AD_VALOREM
    specific_amount          NUMERIC(15,4),   -- valor por unidade quando SPECIFIC
    unit_of_measure          VARCHAR(10),     -- unidade base do valor específico (ex.: L, UN)

    -- Ano de referência (opcional; IS pode variar por ano)
    reference_year           SMALLINT,

    -- Normativo
    anexo_ref                VARCHAR(50),
    legal_basis              TEXT,

    -- Vigência
    valid_from               DATE NOT NULL DEFAULT DATE '2027-01-01',
    valid_to                 DATE,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT ck_is_incidences_rate CHECK (
        (rate_kind = 'AD_VALOREM' AND ad_valorem_rate IS NOT NULL AND ad_valorem_rate BETWEEN 0 AND 1) OR
        (rate_kind = 'SPECIFIC' AND specific_amount IS NOT NULL AND specific_amount >= 0)
    ),
    CONSTRAINT ck_is_incidences_year CHECK (reference_year IS NULL OR reference_year BETWEEN 2027 AND 2100),
    CONSTRAINT ck_is_incidences_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

COMMENT ON TABLE tax_reform.is_incidences IS
    'Mapeia os produtos sujeitos ao Imposto Seletivo (IS) e a respectiva alíquota '
    '(ad valorem ou específica). Sem registro correspondente, o IS do item é zero.';
COMMENT ON COLUMN tax_reform.is_incidences.is_incidence_id IS 'Identificador interno da incidência de IS (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.is_incidences.scope_type IS 'Tipo do código alvo (NCM, NBS, CEST, GTIN).';
COMMENT ON COLUMN tax_reform.is_incidences.target_code IS 'Código que aciona o IS (valor do NCM/CEST/GTIN).';
COMMENT ON COLUMN tax_reform.is_incidences.match_type IS 'Estratégia de correspondência: EXACT (exato) ou PREFIX (família de códigos).';
COMMENT ON COLUMN tax_reform.is_incidences.description IS 'Descrição do produto/grupo sujeito ao IS.';
COMMENT ON COLUMN tax_reform.is_incidences.rate_kind IS 'Forma de cobrança: AD_VALOREM (percentual) ou SPECIFIC (valor por unidade).';
COMMENT ON COLUMN tax_reform.is_incidences.ad_valorem_rate IS 'Alíquota percentual do IS (fração) quando ad valorem.';
COMMENT ON COLUMN tax_reform.is_incidences.specific_amount IS 'Valor do IS por unidade quando específico (ad rem).';
COMMENT ON COLUMN tax_reform.is_incidences.unit_of_measure IS 'Unidade de medida base do valor específico (ex.: L, UN, MAÇO).';
COMMENT ON COLUMN tax_reform.is_incidences.reference_year IS 'Ano de referência da alíquota do IS (nulo = vigente por prazo indeterminado).';
COMMENT ON COLUMN tax_reform.is_incidences.anexo_ref IS 'Anexo/norma que originou a incidência do IS.';
COMMENT ON COLUMN tax_reform.is_incidences.legal_basis IS 'Base legal da incidência do IS.';
COMMENT ON COLUMN tax_reform.is_incidences.valid_from IS 'Data de início de vigência (IS inicia em 2027).';
COMMENT ON COLUMN tax_reform.is_incidences.valid_to IS 'Data de fim de vigência (nulo = vigente).';
COMMENT ON COLUMN tax_reform.is_incidences.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.is_incidences.updated_at IS 'Data da última alteração no registro.';

-- -----------------------------------------------------------------------------
-- 6. SIMULAÇÕES (HISTÓRICO)
-- -----------------------------------------------------------------------------

-- 6.1. Cabeçalho da simulação.
CREATE TABLE tax_reform.simulations (
    -- Chaves
    simulation_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    est_id                   UUID,                      -- estabelecimento (partner)
    tenant_id                UUID,                      -- assinante (partner)
    user_id                  UUID,                      -- usuário que simulou (account)

    -- Dados obrigatórios
    simulation_type          tax_reform.simulation_kind NOT NULL,
    reference_year           SMALLINT NOT NULL,
    status                   tax_reform.simulation_status NOT NULL DEFAULT 'DRAFT',

    -- Origem (modo NOTA FISCAL)
    source_model             VARCHAR(2),                -- 55 (NF-e) / 65 (NFC-e)
    source_access_key        VARCHAR(44),               -- chave de acesso da NF-e
    input_payload            JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Totais consolidados (comparativo)
    total_old_tax            NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_new_tax            NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_difference         NUMERIC(15,4) NOT NULL DEFAULT 0,
    difference_percent       NUMERIC(15,4),

    -- Diagnóstico (status FAILED)
    error_reason             TEXT,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT fk_simulations_est FOREIGN KEY (est_id)
        REFERENCES partner.establishments (est_id) ON DELETE SET NULL,
    CONSTRAINT ck_simulations_year CHECK (reference_year BETWEEN 2026 AND 2100),
    CONSTRAINT ck_simulations_access_key CHECK (
        source_access_key IS NULL OR source_access_key ~ '^[0-9]{44}$'
    ),
    CONSTRAINT ck_simulations_model CHECK (
        source_model IS NULL OR source_model IN ('55', '65')
    )
);

COMMENT ON TABLE tax_reform.simulations IS
    'Cabeçalho do histórico de simulações. Guarda o payload de entrada, os totais '
    'consolidados "Antes vs. Depois" e a origem (produto ou nota fiscal).';
COMMENT ON COLUMN tax_reform.simulations.simulation_id IS 'Identificador único da simulação (UUID).';
COMMENT ON COLUMN tax_reform.simulations.est_id IS 'Estabelecimento que realizou a simulação (FK para partner.establishments).';
COMMENT ON COLUMN tax_reform.simulations.tenant_id IS 'Tenant/assinante dono da simulação.';
COMMENT ON COLUMN tax_reform.simulations.user_id IS 'Usuário que executou a simulação.';
COMMENT ON COLUMN tax_reform.simulations.simulation_type IS 'Modo da simulação: PRODUCT (produto) ou INVOICE (nota fiscal).';
COMMENT ON COLUMN tax_reform.simulations.reference_year IS 'Ano de referência usado para aplicar as alíquotas de transição.';
COMMENT ON COLUMN tax_reform.simulations.status IS 'Estado da simulação (DRAFT, COMPLETED, FAILED).';
COMMENT ON COLUMN tax_reform.simulations.source_model IS 'Modelo do documento de origem: 55 (NF-e) ou 65 (NFC-e).';
COMMENT ON COLUMN tax_reform.simulations.source_access_key IS 'Chave de acesso da NF-e/NFC-e de origem (44 dígitos).';
COMMENT ON COLUMN tax_reform.simulations.input_payload IS 'Payload JSONB de entrada enviado pelo frontend.';
COMMENT ON COLUMN tax_reform.simulations.total_old_tax IS 'Total de tributos no regime antigo (ICMS/PIS/COFINS/ISS).';
COMMENT ON COLUMN tax_reform.simulations.total_new_tax IS 'Total de tributos no novo regime (IBS/CBS/IS).';
COMMENT ON COLUMN tax_reform.simulations.total_difference IS 'Diferença total entre novo e antigo (negativo = redução de carga).';
COMMENT ON COLUMN tax_reform.simulations.difference_percent IS 'Variação percentual da carga tributária (novo vs. antigo).';
COMMENT ON COLUMN tax_reform.simulations.error_reason IS 'Motivo da falha quando status = FAILED (observabilidade).';
COMMENT ON COLUMN tax_reform.simulations.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN tax_reform.simulations.updated_at IS 'Data da última alteração no registro.';

-- 6.2. Itens da simulação (detalhe "de/para").
CREATE TABLE tax_reform.simulation_items (
    -- Chaves
    simulation_item_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    simulation_id            UUID NOT NULL,

    -- Dados obrigatórios
    item_sequence            INTEGER NOT NULL,
    product_description      VARCHAR(500) NOT NULL,
    quantity                 NUMERIC(15,4) NOT NULL DEFAULT 1,
    unit_value               NUMERIC(15,4) NOT NULL DEFAULT 0,
    item_value               NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Classificação
    gtin                     VARCHAR(14),
    ncm_code                 VARCHAR(8),
    cst_code                 VARCHAR(3),
    class_trib_code          VARCHAR(6),
    applied_rule_id          UUID,

    -- Rótulos do regime ATUAL lidos do XML (sem catálogo; apenas contexto/auditoria)
    old_origem_cst           VARCHAR(4),   -- Origem+CST do ICMS (ex.: 000, 060 ST)
    old_cst_pis              VARCHAR(2),
    old_cst_cofins           VARCHAR(2),
    old_csosn                VARCHAR(4),   -- Simples Nacional (ex.: 101, 500)

    -- Regime ANTIGO (valores de tributos)
    old_icms_value           NUMERIC(15,4) NOT NULL DEFAULT 0,
    old_icms_st_value        NUMERIC(15,4) NOT NULL DEFAULT 0,
    old_pis_value            NUMERIC(15,4) NOT NULL DEFAULT 0,
    old_cofins_value         NUMERIC(15,4) NOT NULL DEFAULT 0,
    old_iss_value            NUMERIC(15,4) NOT NULL DEFAULT 0,
    old_total_tax            NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Regime NOVO (valores de tributos)
    new_ibs_estadual_value   NUMERIC(15,4) NOT NULL DEFAULT 0,
    new_ibs_municipal_value  NUMERIC(15,4) NOT NULL DEFAULT 0,
    new_cbs_value            NUMERIC(15,4) NOT NULL DEFAULT 0,
    new_is_value             NUMERIC(15,4) NOT NULL DEFAULT 0,
    new_total_tax            NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Comparativo
    difference               NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- Snapshot completo do cálculo "de/para" e da regra aplicada
    comparison_payload       JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Timestamps
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uk_simulation_items_seq UNIQUE (simulation_id, item_sequence),
    CONSTRAINT fk_simulation_items_sim FOREIGN KEY (simulation_id)
        REFERENCES tax_reform.simulations (simulation_id) ON DELETE CASCADE,
    CONSTRAINT fk_simulation_items_cst FOREIGN KEY (cst_code)
        REFERENCES tax_reform.cst (cst_code) ON UPDATE CASCADE,
    CONSTRAINT fk_simulation_items_class_trib FOREIGN KEY (class_trib_code)
        REFERENCES tax_reform.tax_classifications (class_trib_code) ON UPDATE CASCADE,
    CONSTRAINT fk_simulation_items_rule FOREIGN KEY (applied_rule_id)
        REFERENCES tax_reform.rules_and_exceptions (rule_id) ON DELETE SET NULL,
    CONSTRAINT ck_simulation_items_qty CHECK (quantity >= 0)
);

COMMENT ON TABLE tax_reform.simulation_items IS
    'Detalhe item a item da simulação. Guarda o "de/para": tributos do regime '
    'antigo (ICMS/PIS/COFINS/ISS) versus o novo (IBS estadual/municipal, CBS, IS), '
    'além do snapshot JSONB do cálculo e da regra aplicada.';
COMMENT ON COLUMN tax_reform.simulation_items.simulation_item_id IS 'Identificador interno do item (BIGINT sequencial).';
COMMENT ON COLUMN tax_reform.simulation_items.simulation_id IS 'Simulação à qual o item pertence (FK para tax_reform.simulations).';
COMMENT ON COLUMN tax_reform.simulation_items.item_sequence IS 'Número sequencial do item dentro da simulação.';
COMMENT ON COLUMN tax_reform.simulation_items.product_description IS 'Descrição do produto/serviço simulado.';
COMMENT ON COLUMN tax_reform.simulation_items.quantity IS 'Quantidade do item.';
COMMENT ON COLUMN tax_reform.simulation_items.unit_value IS 'Valor unitário do item.';
COMMENT ON COLUMN tax_reform.simulation_items.item_value IS 'Valor total do item (base de cálculo).';
COMMENT ON COLUMN tax_reform.simulation_items.gtin IS 'Código de barras EAN/GTIN do item, quando informado.';
COMMENT ON COLUMN tax_reform.simulation_items.ncm_code IS 'Código NCM do item.';
COMMENT ON COLUMN tax_reform.simulation_items.cst_code IS 'CST do IBS/CBS aplicado ao item (FK para tax_reform.cst).';
COMMENT ON COLUMN tax_reform.simulation_items.class_trib_code IS 'Classificação cClassTrib aplicada (FK para tax_classifications).';
COMMENT ON COLUMN tax_reform.simulation_items.applied_rule_id IS 'Regra/exceção aplicada ao item (FK para rules_and_exceptions).';
COMMENT ON COLUMN tax_reform.simulation_items.old_origem_cst IS 'Origem + CST do ICMS lido do XML (ex.: 000, 060 ST). Rótulo, sem catálogo.';
COMMENT ON COLUMN tax_reform.simulation_items.old_cst_pis IS 'CST do PIS lido do XML.';
COMMENT ON COLUMN tax_reform.simulation_items.old_cst_cofins IS 'CST do COFINS lido do XML.';
COMMENT ON COLUMN tax_reform.simulation_items.old_csosn IS 'CSOSN (Simples Nacional) lido do XML, quando aplicável.';
COMMENT ON COLUMN tax_reform.simulation_items.old_icms_value IS 'Valor de ICMS no regime antigo.';
COMMENT ON COLUMN tax_reform.simulation_items.old_icms_st_value IS 'Valor de ICMS-ST (substituição tributária) lido do XML; evita subestimar o "antes".';
COMMENT ON COLUMN tax_reform.simulation_items.old_pis_value IS 'Valor de PIS no regime antigo.';
COMMENT ON COLUMN tax_reform.simulation_items.old_cofins_value IS 'Valor de COFINS no regime antigo.';
COMMENT ON COLUMN tax_reform.simulation_items.old_iss_value IS 'Valor de ISS no regime antigo.';
COMMENT ON COLUMN tax_reform.simulation_items.old_total_tax IS 'Total de tributos do regime antigo para o item.';
COMMENT ON COLUMN tax_reform.simulation_items.new_ibs_estadual_value IS 'Valor da parcela estadual do IBS no novo regime.';
COMMENT ON COLUMN tax_reform.simulation_items.new_ibs_municipal_value IS 'Valor da parcela municipal do IBS no novo regime.';
COMMENT ON COLUMN tax_reform.simulation_items.new_cbs_value IS 'Valor da CBS no novo regime.';
COMMENT ON COLUMN tax_reform.simulation_items.new_is_value IS 'Valor do Imposto Seletivo (IS) no novo regime.';
COMMENT ON COLUMN tax_reform.simulation_items.new_total_tax IS 'Total de tributos do novo regime para o item.';
COMMENT ON COLUMN tax_reform.simulation_items.difference IS 'Diferença entre novo e antigo para o item (negativo = redução).';
COMMENT ON COLUMN tax_reform.simulation_items.comparison_payload IS 'Snapshot JSONB completo do cálculo "de/para" e da regra aplicada.';
COMMENT ON COLUMN tax_reform.simulation_items.created_at IS 'Data de criação do registro.';

-- -----------------------------------------------------------------------------
-- 7. ÍNDICES
-- -----------------------------------------------------------------------------

-- Classificação
CREATE INDEX idx_tax_classifications_cst ON tax_reform.tax_classifications (cst_code);
CREATE INDEX idx_tax_classifications_benefit ON tax_reform.tax_classifications (benefit_type);
CREATE INDEX idx_tax_classifications_indicators ON tax_reform.tax_classifications USING GIN (indicators);

-- NCM (busca instantânea)
CREATE INDEX idx_ncms_code ON tax_reform.ncms (ncm_code);
CREATE INDEX idx_ncms_code_prefix ON tax_reform.ncms (ncm_code text_pattern_ops); -- LIKE 'prefixo%'
CREATE INDEX idx_ncms_fts ON tax_reform.ncms USING GIN (ncm_fts);
CREATE INDEX idx_ncms_default_class_trib ON tax_reform.ncms (default_class_trib_code)
    WHERE default_class_trib_code IS NOT NULL;

-- NBS (busca de serviços)
CREATE INDEX idx_nbs_code ON tax_reform.nbs (nbs_code);
CREATE INDEX idx_nbs_lc116 ON tax_reform.nbs (lc116_item);
CREATE INDEX idx_nbs_fts ON tax_reform.nbs USING GIN (nbs_fts);

-- Produtos (busca por código de barras)
CREATE INDEX idx_products_ref_gtin ON tax_reform.products_ref (gtin);
CREATE INDEX idx_products_ref_ncm_code ON tax_reform.products_ref (ncm_code);
CREATE INDEX idx_products_ref_ncm_id ON tax_reform.products_ref (ncm_id);
CREATE INDEX idx_products_ref_fts ON tax_reform.products_ref USING GIN (product_fts);

-- Regras e alvos
CREATE INDEX idx_rules_scope ON tax_reform.rules_and_exceptions (scope_type);
CREATE INDEX idx_rules_conditions ON tax_reform.rules_and_exceptions USING GIN (conditions);
CREATE INDEX idx_rules_class_trib ON tax_reform.rules_and_exceptions (class_trib_code);
CREATE INDEX idx_rules_tax_class ON tax_reform.rules_and_exceptions (tax_class_id);
CREATE INDEX idx_rule_targets_lookup ON tax_reform.rule_targets (target_scope, target_code);
CREATE INDEX idx_rule_targets_rule ON tax_reform.rule_targets (rule_id);

-- Imposto Seletivo (IS)
CREATE INDEX idx_is_incidences_lookup ON tax_reform.is_incidences (scope_type, target_code);

-- Transição
CREATE INDEX idx_transition_rates_year ON tax_reform.transition_rates (reference_year);
CREATE UNIQUE INDEX uk_transition_rates ON tax_reform.transition_rates (
    reference_year, tax_kind, jurisdiction_scope,
    COALESCE(uf, ''), COALESCE(ibge_city_code, '')
);
CREATE INDEX idx_transition_rates_uf ON tax_reform.transition_rates (uf)
    WHERE uf IS NOT NULL;

-- Simulações
CREATE INDEX idx_simulations_est ON tax_reform.simulations (est_id);
CREATE INDEX idx_simulations_tenant ON tax_reform.simulations (tenant_id);
CREATE INDEX idx_simulations_user ON tax_reform.simulations (user_id);
CREATE INDEX idx_simulations_type_year ON tax_reform.simulations (simulation_type, reference_year);
CREATE INDEX idx_simulations_access_key ON tax_reform.simulations (source_access_key)
    WHERE source_access_key IS NOT NULL;
CREATE INDEX idx_simulation_items_sim ON tax_reform.simulation_items (simulation_id);
CREATE INDEX idx_simulation_items_ncm ON tax_reform.simulation_items (ncm_code);

-- -----------------------------------------------------------------------------
-- 8. TRIGGERS
-- -----------------------------------------------------------------------------

-- updated_at (função centralizada public.fn_update_timestamp)
CREATE TRIGGER tr_upd_cst
    BEFORE UPDATE ON tax_reform.cst
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_tax_classifications
    BEFORE UPDATE ON tax_reform.tax_classifications
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_rules
    BEFORE UPDATE ON tax_reform.rules_and_exceptions
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_transition_rates
    BEFORE UPDATE ON tax_reform.transition_rates
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_is_incidences
    BEFORE UPDATE ON tax_reform.is_incidences
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_upd_simulations
    BEFORE UPDATE ON tax_reform.simulations
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

-- FTS
CREATE TRIGGER tr_fts_ncms
    BEFORE INSERT OR UPDATE OF ncm_code, ncm_description ON tax_reform.ncms
    FOR EACH ROW EXECUTE FUNCTION tax_reform.fn_refresh_ncm_fts();

CREATE TRIGGER tr_upd_ncms
    BEFORE UPDATE ON tax_reform.ncms
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_fts_products_ref
    BEFORE INSERT OR UPDATE OF gtin, product_description, ncm_code, cest_code ON tax_reform.products_ref
    FOR EACH ROW EXECUTE FUNCTION tax_reform.fn_refresh_product_ref_fts();

CREATE TRIGGER tr_upd_products_ref
    BEFORE UPDATE ON tax_reform.products_ref
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER tr_fts_nbs
    BEFORE INSERT OR UPDATE OF nbs_code, nbs_description ON tax_reform.nbs
    FOR EACH ROW EXECUTE FUNCTION tax_reform.fn_refresh_nbs_fts();

CREATE TRIGGER tr_upd_nbs
    BEFORE UPDATE ON tax_reform.nbs
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();
