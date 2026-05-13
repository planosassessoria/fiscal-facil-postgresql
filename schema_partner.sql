-- =============================================================================
-- SCHEMA: partner
-- PROJETO: Fiscal Fácil
-- DATA: 2026-03-19
-- DESCRIÇÃO: Schema de gestão de parceiros fiscais. Contém estabelecimentos,
--            endereços, tenants, entidades fiscais e o catálogo de CNAEs.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS partner;
ALTER SCHEMA partner OWNER TO dorcilio;

COMMENT ON SCHEMA partner IS
    'Schema de gestão de parceiros fiscais. Contém estabelecimentos (CNPJ/CPF), endereços, '
    'tenants (assinantes do sistema), entidades fiscais (carteira de clientes) e o catálogo de CNAEs.';

-- -----------------------------------------------------------------------------
-- 1. FUNÇÕES
-- -----------------------------------------------------------------------------

-- Atualização do Full Text Search para Entidades Fiscais
CREATE OR REPLACE FUNCTION partner.fn_refresh_tax_entity_fts()
RETURNS trigger AS $$
BEGIN
    NEW.tax_entity_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.display_name, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.document, '')), 'B');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION partner.fn_refresh_tax_entity_fts() IS
    'Atualiza o vetor FTS de partner.tax_entities. Pesos: display_name = A, document = B.';

-- Atualização automática do FTS e Timestamp para o Catálogo de CNAEs
CREATE OR REPLACE FUNCTION partner.fn_refresh_cnae_fts()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    NEW.cnae_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cnae, '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cnae_description, '')), 'B');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION partner.fn_refresh_cnae_fts() IS
    'Atualiza updated_at e o vetor FTS de partner.cnaes. Pesos: cnae (código) = A, cnae_description = B.';

-- Atualização do Full Text Search para Estabelecimentos
CREATE OR REPLACE FUNCTION partner.fn_refresh_establishment_fts()
RETURNS trigger AS $$
BEGIN
    NEW.est_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.document, '')),      'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.razao_social, '')),  'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.ie, '')),            'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.fantasia, '')),      'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.email, '')),         'C') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.telefone, '')),      'D') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cnae, '')),          'D');
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION partner.fn_refresh_establishment_fts() IS
    'Atualiza o vetor FTS de partner.establishments. Pesos: document e razao_social = A, ie e fantasia = B, email = C, telefone e cnae = D.';

-- -----------------------------------------------------------------------------
-- 2. TABELAS
-- -----------------------------------------------------------------------------

-- Tabela: CNAEs
CREATE TABLE IF NOT EXISTS partner.cnaes (
    cnae VARCHAR(7) NOT NULL,
    cnae_description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    cnae_fts tsvector,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT clock_timestamp(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT clock_timestamp(),

    CONSTRAINT cnaes_pkey PRIMARY KEY (cnae)
);

COMMENT ON TABLE partner.cnaes IS 'Catálogo de referência oficial de subclasses CNAE (IBGE).';
COMMENT ON COLUMN partner.cnaes.cnae IS 'Código numérico de 7 dígitos sem máscara.';
COMMENT ON COLUMN partner.cnaes.cnae_description IS 'Descrição oficial da atividade econômica.';
COMMENT ON COLUMN partner.cnaes.is_active IS 'Indica se o CNAE está ativo para novos cadastros.';
COMMENT ON COLUMN partner.cnaes.cnae_fts IS 'Vetor de busca textual para busca rápida por código ou nome.';
COMMENT ON COLUMN partner.cnaes.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN partner.cnaes.updated_at IS 'Data da última alteração no registro.';

-- Tabela: Establishments
CREATE TABLE IF NOT EXISTS partner.establishments (
    est_id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_type character varying(4) NOT NULL,
    document character varying(14) NOT NULL,
    ie character varying(20),
    uf character(2) NOT NULL,
    razao_social character varying(255) NOT NULL,
    fantasia character varying(115),
    cnae character varying(7),
    cnaes character varying(7)[],
    telefone character varying(11),
    telefone_secundario character varying(11),
    email character varying(320),
    situacao text,
    est_fts tsvector,
    last_sync_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp(),

    CONSTRAINT establishments_pkey PRIMARY KEY (est_id),
    CONSTRAINT uk_establishment_doc_ie_uf UNIQUE (document, ie, uf)
);

COMMENT ON TABLE partner.establishments IS 'Base central de dados fiscais (CNPJ/CPF) para evitar duplicidade no sistema.';
COMMENT ON COLUMN partner.establishments.est_id IS 'Identificador único do estabelecimento (UUID).';
COMMENT ON COLUMN partner.establishments.document_type IS 'Define se é CNPJ ou CPF.';
COMMENT ON COLUMN partner.establishments.document IS 'Número do documento sem pontuação.';
COMMENT ON COLUMN partner.establishments.ie IS 'Inscrição Estadual.';
COMMENT ON COLUMN partner.establishments.uf IS 'Unidade Federativa (sigla do estado com 2 caracteres).';
COMMENT ON COLUMN partner.establishments.razao_social IS 'Razão social oficial conforme Receita Federal.';
COMMENT ON COLUMN partner.establishments.fantasia IS 'Nome fantasia do estabelecimento.';
COMMENT ON COLUMN partner.establishments.cnae IS 'CNAE principal da empresa.';
COMMENT ON COLUMN partner.establishments.cnaes IS 'Lista de CNAEs secundários.';
COMMENT ON COLUMN partner.establishments.telefone IS 'Telefone principal sem máscara.';
COMMENT ON COLUMN partner.establishments.telefone_secundario IS 'Telefone secundário de contato.';
COMMENT ON COLUMN partner.establishments.email IS 'E-mail de contato do estabelecimento.';
COMMENT ON COLUMN partner.establishments.situacao IS 'Status cadastral na Receita Federal.';
COMMENT ON COLUMN partner.establishments.est_fts IS 'Vetor de busca textual para localização rápida de estabelecimentos.';
COMMENT ON COLUMN partner.establishments.last_sync_at IS 'Data da última sincronização com fontes externas (ex: Receita Federal).';
COMMENT ON COLUMN partner.establishments.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN partner.establishments.updated_at IS 'Data da última alteração no registro.';

-- Tabela: Addresses
CREATE TABLE IF NOT EXISTS partner.addresses (
    address_id uuid DEFAULT gen_random_uuid() NOT NULL,
    est_id uuid NOT NULL,
    zip_code character varying(8) NOT NULL,
    street character varying(60) NOT NULL,
    street_number integer,
    neighborhood character varying(60),
    city character varying(60) NOT NULL,
    ibge character varying(7) NOT NULL,
    uf character(2) NOT NULL,
    complement character varying(120),
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp(),

    CONSTRAINT addresses_pkey PRIMARY KEY (address_id),
    CONSTRAINT addresses_est_id_key UNIQUE (est_id),
    CONSTRAINT addresses_est_id_fkey FOREIGN KEY (est_id) REFERENCES partner.establishments(est_id) ON DELETE CASCADE
);

COMMENT ON TABLE partner.addresses IS 'Endereços físicos vinculados aos estabelecimentos.';
COMMENT ON COLUMN partner.addresses.address_id IS 'Identificador único do endereço (UUID).';
COMMENT ON COLUMN partner.addresses.est_id IS 'Estabelecimento ao qual o endereço está vinculado (FK).';
COMMENT ON COLUMN partner.addresses.zip_code IS 'CEP sem máscara.';
COMMENT ON COLUMN partner.addresses.street IS 'Logradouro (rua, avenida, etc).';
COMMENT ON COLUMN partner.addresses.street_number IS 'Número do imóvel.';
COMMENT ON COLUMN partner.addresses.neighborhood IS 'Bairro.';
COMMENT ON COLUMN partner.addresses.city IS 'Nome da cidade.';
COMMENT ON COLUMN partner.addresses.ibge IS 'Código IBGE do município para fins de emissão de notas e impostos.';
COMMENT ON COLUMN partner.addresses.uf IS 'Unidade Federativa (sigla do estado com 2 caracteres).';
COMMENT ON COLUMN partner.addresses.complement IS 'Complemento do endereço (sala, andar, bloco).';
COMMENT ON COLUMN partner.addresses.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN partner.addresses.updated_at IS 'Data da última alteração no registro.';

-- Tabela: Tenants
CREATE TABLE IF NOT EXISTS partner.tenants (
    tenant_id uuid DEFAULT gen_random_uuid() NOT NULL,
    est_id uuid NOT NULL,
    owner_email character varying(320) NOT NULL,
    account_type character varying(30) NOT NULL,
    plan_status character varying(20) DEFAULT 'TRIAL'::character varying,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp(),

    CONSTRAINT tenants_pkey PRIMARY KEY (tenant_id),
    CONSTRAINT tenants_est_id_fkey FOREIGN KEY (est_id) REFERENCES partner.establishments(est_id)
);

COMMENT ON TABLE partner.tenants IS 'Entidades assinantes do software (Escritórios de Contabilidade ou Empresas).';
COMMENT ON COLUMN partner.tenants.tenant_id IS 'Identificador único do tenant (UUID).';
COMMENT ON COLUMN partner.tenants.est_id IS 'Estabelecimento principal vinculado ao tenant (FK).';
COMMENT ON COLUMN partner.tenants.owner_email IS 'E-mail do proprietário da conta para gestão de licença.';
COMMENT ON COLUMN partner.tenants.account_type IS 'Tipo de conta: OFFICE, ACCOUNTANT, COMPANY, INDIVIDUAL.';
COMMENT ON COLUMN partner.tenants.plan_status IS 'Estado atual do plano financeiro do cliente.';
COMMENT ON COLUMN partner.tenants.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN partner.tenants.updated_at IS 'Data da última alteração no registro.';

-- Tabela: Tax Entities
CREATE TABLE IF NOT EXISTS partner.tax_entities (
    tax_id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid,
    est_id uuid,
    display_name character varying(120),
    document character varying(14) NOT NULL,
    tax_entity_fts tsvector,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp(),

    CONSTRAINT tax_entities_pkey PRIMARY KEY (tax_id),
    CONSTRAINT tax_entities_tenant_id_est_id_key UNIQUE (tenant_id, est_id),
    CONSTRAINT tax_entities_est_id_fkey FOREIGN KEY (est_id) REFERENCES partner.establishments(est_id),
    CONSTRAINT tax_entities_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES partner.tenants(tenant_id) ON DELETE CASCADE
);

COMMENT ON TABLE partner.tax_entities IS 'Carteira de clientes (empresas parceiras) de cada Tenant.';
COMMENT ON COLUMN partner.tax_entities.tax_id IS 'Identificador único da entidade fiscal (UUID).';
COMMENT ON COLUMN partner.tax_entities.tenant_id IS 'Tenant ao qual a entidade fiscal pertence (FK).';
COMMENT ON COLUMN partner.tax_entities.est_id IS 'Estabelecimento fiscal vinculado (FK).';
COMMENT ON COLUMN partner.tax_entities.display_name IS 'Nome fantasia ou apelido definido pelo contador para o cliente.';
COMMENT ON COLUMN partner.tax_entities.document IS 'CNPJ ou CPF da entidade fiscal sem pontuação.';
COMMENT ON COLUMN partner.tax_entities.tax_entity_fts IS 'Vetor de busca para localização rápida de clientes no dashboard.';
COMMENT ON COLUMN partner.tax_entities.is_active IS 'Flag que indica se a entidade fiscal está ativa na carteira.';
COMMENT ON COLUMN partner.tax_entities.created_at IS 'Data de criação do registro.';
COMMENT ON COLUMN partner.tax_entities.updated_at IS 'Data da última alteração no registro.';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_cnaes_fts ON partner.cnaes USING gin (cnae_fts);
CREATE INDEX IF NOT EXISTS idx_est_fts ON partner.establishments USING gin (est_fts);
CREATE INDEX IF NOT EXISTS idx_tax_entity_fts ON partner.tax_entities USING gin (tax_entity_fts);
CREATE INDEX IF NOT EXISTS idx_owner_email_on_tenants ON partner.tenants (owner_email);

-- -----------------------------------------------------------------------------
-- 4. TRIGGERS
-- -----------------------------------------------------------------------------

-- Auditoria de Timestamps
CREATE TRIGGER tr_upd_establishments BEFORE UPDATE ON partner.establishments FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();
CREATE TRIGGER tr_upd_addresses BEFORE UPDATE ON partner.addresses FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();
CREATE TRIGGER tr_upd_tenants BEFORE UPDATE ON partner.tenants FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();
CREATE TRIGGER tr_upd_tax_entities BEFORE UPDATE ON partner.tax_entities FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

-- Full Text Search & Metadata CNAEs
CREATE TRIGGER tr_upd_cnae_metadata BEFORE INSERT OR UPDATE OF cnae, cnae_description
ON partner.cnaes FOR EACH ROW EXECUTE FUNCTION partner.fn_refresh_cnae_fts();

-- Full Text Search Tax Entities
CREATE TRIGGER tr_upd_fts_tax_entities BEFORE INSERT OR UPDATE OF display_name, document
ON partner.tax_entities FOR EACH ROW EXECUTE FUNCTION partner.fn_refresh_tax_entity_fts();

-- Full Text Search Establishments
CREATE TRIGGER tr_upd_fts_establishments BEFORE INSERT OR UPDATE OF document, razao_social, ie, fantasia, email, telefone, cnae
ON partner.establishments FOR EACH ROW EXECUTE FUNCTION partner.fn_refresh_establishment_fts();
