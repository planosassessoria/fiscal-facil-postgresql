-- =============================================================================
-- SCHEMA: nota_fiscal
-- Descrição: Schema de armazenamento de Notas Fiscais Eletrônicas (NF-e)
-- Hierarquia: b01_ide (raiz) → i01_prod (itens) → tabelas de tributos por item
-- Deleção: sempre pela raiz b01_ide com CASCADE para todas as filhas
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS nota_fiscal;

ALTER SCHEMA nota_fiscal OWNER TO dorcilio;

COMMENT ON SCHEMA nota_fiscal IS
    'Schema de armazenamento estruturado de Notas Fiscais Eletrônicas (NF-e e NFC-e). '
    'A tabela raiz b01_ide representa a identificação do documento fiscal; todas as demais '
    'tabelas são filhas via ch_nf com ON DELETE CASCADE. '
    'A deleção deve sempre partir de b01_ide para garantir a integridade referencial em cascata.';

-- =============================================================================
-- FUNÇÃO: Atualiza FTS da tabela b01_ide
-- =============================================================================

CREATE OR REPLACE FUNCTION nota_fiscal.ts_vector_update_b01_ide()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_reference_date date;
    v_month_name_pt text;
BEGIN
    v_reference_date := COALESCE(NEW.dh_emi::date, NEW.dt_doc);

    v_month_name_pt := CASE EXTRACT(MONTH FROM v_reference_date)::integer
        WHEN 1 THEN 'janeiro'
        WHEN 2 THEN 'fevereiro'
        WHEN 3 THEN 'marco'
        WHEN 4 THEN 'abril'
        WHEN 5 THEN 'maio'
        WHEN 6 THEN 'junho'
        WHEN 7 THEN 'julho'
        WHEN 8 THEN 'agosto'
        WHEN 9 THEN 'setembro'
        WHEN 10 THEN 'outubro'
        WHEN 11 THEN 'novembro'
        WHEN 12 THEN 'dezembro'
    END;

    NEW.nota_fiscal_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.ch_nf, '')),                        'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cpf_cnpj, '')),                     'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.dest_cpf_cnpj, '')),                'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(TO_CHAR(v_reference_date, 'MM/YYYY'), '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(v_month_name_pt || ' ' || TO_CHAR(v_reference_date, 'YYYY'), '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.ie, '')),                           'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.dest_ie, '')),                      'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.num_doc::TEXT, '')),                'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.nat_oper, '')),                     'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(TO_CHAR(v_reference_date, 'DD/MM/YYYY'), '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(v_month_name_pt, '')),                  'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(TO_CHAR(v_reference_date, 'YYYY-MM-DD'), '')), 'C');
    RETURN NEW;
END;
$$;

ALTER FUNCTION nota_fiscal.ts_vector_update_b01_ide() OWNER TO dorcilio;

COMMENT ON FUNCTION nota_fiscal.ts_vector_update_b01_ide() IS
    'Atualiza o vetor FTS de nota_fiscal.b01_ide. '
    'Pesos: ch_nf, cpf_cnpj, dest_cpf_cnpj, MM/YYYY e mes+ano = A | ie, dest_ie, num_doc, nat_oper, DD/MM/YYYY e mes = B | YYYY-MM-DD = C.';

-- =============================================================================
-- FUNÇÃO: Atualiza FTS da tabela i01_prod
-- =============================================================================

CREATE OR REPLACE FUNCTION nota_fiscal.fn_update_i01_prod_fts()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.i01_prod_fts :=
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.descr_item,  '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cod_item,    '')), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cod_ncm,     '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cnpj_fab,    '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.c_benef,     '')), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.cod_barra,   '')), 'C') ||
        setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.inf_ad_prod, '')), 'D');
    RETURN NEW;
END;
$$;

ALTER FUNCTION nota_fiscal.fn_update_i01_prod_fts() OWNER TO dorcilio;

COMMENT ON FUNCTION nota_fiscal.fn_update_i01_prod_fts() IS
    'Atualiza o vetor FTS de nota_fiscal.i01_prod. '
    'Pesos: descr_item e cod_item = A | cod_ncm, cnpj_fab, c_benef = B | cod_barra = C | inf_ad_prod = D.';

-- =============================================================================
-- NÍVEL 0: TABELA RAIZ — b01_ide
-- Identificação da NF-e. Todas as demais tabelas referenciam ch_nf desta tabela.
-- =============================================================================

CREATE TABLE nota_fiscal.b01_ide (
    -- Chave primária natural
    ch_nf               VARCHAR(44)             NOT NULL,

    -- Dados de identificação
    xml_id              INTEGER,
    cpf_cnpj            VARCHAR(14)             NOT NULL,
    ie                  VARCHAR(15),
    num_doc             INTEGER                 NOT NULL,
    ser                 VARCHAR(3)              NOT NULL,
    cod_mod             VARCHAR(2)              NOT NULL,
    dest_cpf_cnpj       VARCHAR(14),
    dest_ie             VARCHAR(15),
    cod_uf              INTEGER                 NOT NULL,
    nat_oper            VARCHAR(60)             NOT NULL,
    ind_pag             INTEGER,
    dt_doc              DATE,
    dt_e_s              DATE,
    tp_nf               INTEGER                 NOT NULL,
    cod_mun             VARCHAR(7)              NOT NULL,
    tp_imp              INTEGER                 NOT NULL,
    tp_emis             INTEGER                 NOT NULL,
    c_dv                INTEGER                 NOT NULL,
    tp_amb              INTEGER                 NOT NULL,
    fin_nfe             INTEGER                 NOT NULL,
    proc_emi            INTEGER                 NOT NULL,
    ver_proc            VARCHAR(20)             NOT NULL,
    dh_cont             TIMESTAMPTZ,
    x_just              VARCHAR(256),
    dh_emi              TIMESTAMPTZ             NOT NULL,
    dh_sai_ent          TIMESTAMPTZ,
    id_dest             INTEGER                 NOT NULL,
    ind_final           INTEGER                 NOT NULL,
    ind_pres            INTEGER                 NOT NULL,

    -- Metadados de controle
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT clock_timestamp(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT clock_timestamp(),

    -- Full Text Search
    nota_fiscal_fts     TSVECTOR,

    -- Constraints
    CONSTRAINT b01_ide_pkey PRIMARY KEY (ch_nf)
);

ALTER TABLE nota_fiscal.b01_ide OWNER TO dorcilio;

COMMENT ON TABLE nota_fiscal.b01_ide IS 'Tabela raiz da NF-e. Toda deleção deve partir desta tabela e propagar em cascade.';
COMMENT ON COLUMN nota_fiscal.b01_ide.ch_nf         IS 'Chave de acesso da NF-e (44 dígitos). PK natural — identificador único nacional.';
COMMENT ON COLUMN nota_fiscal.b01_ide.xml_id        IS 'Referência ao ID do XML original importado (campo legado, sem FK formal).';
COMMENT ON COLUMN nota_fiscal.b01_ide.cpf_cnpj      IS 'CPF (11 dígitos numéricos) ou CNPJ (14 caracteres alfanuméricos: 12 posições [0-9A-Z] + 2 verificadores) do emitente. Conforme IN RFB nº 2.229/2024.';
COMMENT ON COLUMN nota_fiscal.b01_ide.ie            IS 'Inscrição Estadual do emitente.';
COMMENT ON COLUMN nota_fiscal.b01_ide.num_doc       IS 'Número da nota fiscal (nNF), compõe a chave de acesso.';
COMMENT ON COLUMN nota_fiscal.b01_ide.ser           IS 'Série da NF-e (1–3 dígitos).';
COMMENT ON COLUMN nota_fiscal.b01_ide.cod_mod       IS 'Modelo do documento fiscal: 55=NF-e, 65=NFC-e.';
COMMENT ON COLUMN nota_fiscal.b01_ide.tp_nf         IS 'Tipo da NF-e: 0=Entrada, 1=Saída.';
COMMENT ON COLUMN nota_fiscal.b01_ide.tp_amb        IS 'Ambiente: 1=Produção, 2=Homologação.';
COMMENT ON COLUMN nota_fiscal.b01_ide.fin_nfe       IS 'Finalidade: 1=Normal, 2=Complementar, 3=Ajuste, 4=Devolução.';
COMMENT ON COLUMN nota_fiscal.b01_ide.nat_oper      IS 'Natureza da operação descritiva (ex: Venda de mercadoria).';
COMMENT ON COLUMN nota_fiscal.b01_ide.dh_emi        IS 'Data e hora de emissão da NF-e (com fuso horário).';
COMMENT ON COLUMN nota_fiscal.b01_ide.dh_sai_ent    IS 'Data e hora de saída ou entrada da mercadoria.';
COMMENT ON COLUMN nota_fiscal.b01_ide.dh_cont       IS 'Data e hora de entrada em contingência.';
COMMENT ON COLUMN nota_fiscal.b01_ide.x_just        IS 'Justificativa de entrada em contingência (mín. 15 caracteres).';
COMMENT ON COLUMN nota_fiscal.b01_ide.dest_cpf_cnpj IS 'CPF (11 dígitos numéricos) ou CNPJ (14 caracteres alfanuméricos: 12 posições [0-9A-Z] + 2 verificadores) do destinatário. Conforme IN RFB nº 2.229/2024.';
COMMENT ON COLUMN nota_fiscal.b01_ide.dest_ie       IS 'Inscrição Estadual do destinatário.';
COMMENT ON COLUMN nota_fiscal.b01_ide.created_at    IS 'Timestamp de importação do registro no banco.';
COMMENT ON COLUMN nota_fiscal.b01_ide.updated_at    IS 'Timestamp da última atualização do registro.';
COMMENT ON COLUMN nota_fiscal.b01_ide.nota_fiscal_fts IS 'Vetor FTS calculado sobre ch_nf, cpf_cnpj, dest_cpf_cnpj, periodo MM/YYYY e mes+ano (peso A), ie, dest_ie, num_doc, nat_oper, DD/MM/YYYY e mes (peso B), alem de YYYY-MM-DD (peso C).';
COMMENT ON COLUMN nota_fiscal.b01_ide.cod_uf      IS 'Código da UF do emitente segundo tabela IBGE (B02 cUF).';
COMMENT ON COLUMN nota_fiscal.b01_ide.ind_pag     IS 'Indicador da forma de pagamento: 0=À Vista, 1=A Prazo, 2=Outros. Campo excluído no leiaute 4.0 (NT2016.002).';
COMMENT ON COLUMN nota_fiscal.b01_ide.dt_doc      IS 'Data de emissão da NF-e — somente data, sem hora (B09 dhEmi parcial).';
COMMENT ON COLUMN nota_fiscal.b01_ide.dt_e_s      IS 'Data de saída ou entrada da mercadoria — somente data, sem hora (B10 dhSaiEnt parcial).';
COMMENT ON COLUMN nota_fiscal.b01_ide.cod_mun     IS 'Código do município de ocorrência do fato gerador do ICMS, tabela IBGE 7 dígitos (B12 cMunFG).';
COMMENT ON COLUMN nota_fiscal.b01_ide.tp_imp      IS 'Formato de impressão do DANFE: 0=Sem DANFE, 1=Normal Retrato, 2=Normal Paisagem, 3=Simplificado, 4=NFC-e, 5=NFC-e mensagem eletrônica (B21 tpImp).';
COMMENT ON COLUMN nota_fiscal.b01_ide.tp_emis     IS 'Tipo de emissão: 1=Normal, 2=FS-IA, 4=EPEC, 5=FS-DA, 6=SVC-AN, 7=SVC-RS, 9=Contingência off-line NFC-e (B22 tpEmis).';
COMMENT ON COLUMN nota_fiscal.b01_ide.c_dv        IS 'Dígito verificador da chave de acesso, calculado pelo algoritmo módulo 11 base 2,9 (B23 cDV).';
COMMENT ON COLUMN nota_fiscal.b01_ide.proc_emi    IS 'Processo de emissão: 0=Aplicativo do contribuinte, 1=Avulsa pelo Fisco, 2=Avulsa pelo contribuinte, 3=Aplicativo do Fisco (B26 procEmi).';
COMMENT ON COLUMN nota_fiscal.b01_ide.ver_proc    IS 'Versão do aplicativo emissor da NF-e (B27 verProc, 1–20 caracteres).';
COMMENT ON COLUMN nota_fiscal.b01_ide.id_dest     IS 'Identificador do local de destino da operação: 1=Interna, 2=Interestadual, 3=Exterior (B11a idDest).';
COMMENT ON COLUMN nota_fiscal.b01_ide.ind_final   IS 'Indica operação com consumidor final: 0=Normal, 1=Consumidor final (B25a indFinal).';
COMMENT ON COLUMN nota_fiscal.b01_ide.ind_pres    IS 'Indicador de presença do comprador: 0=Não aplicável, 1=Presencial, 2=Internet, 3=Teleatendimento, 4=NFC-e domicílio, 5=Presencial fora do estabelecimento, 9=Outros (B25b indPres).';

-- Índices de b01_ide
CREATE INDEX idx_b01_ide_cpf_cnpj       ON nota_fiscal.b01_ide (cpf_cnpj);
CREATE INDEX idx_b01_ide_dh_emi         ON nota_fiscal.b01_ide (dh_emi DESC);
CREATE INDEX idx_b01_ide_cpf_cnpj_emi   ON nota_fiscal.b01_ide (cpf_cnpj, dh_emi DESC);
CREATE INDEX idx_b01_ide_num_doc        ON nota_fiscal.b01_ide (num_doc);
CREATE INDEX idx_b01_ide_tp_amb         ON nota_fiscal.b01_ide (tp_amb);
CREATE INDEX idx_b01_ide_fts            ON nota_fiscal.b01_ide USING GIN (nota_fiscal_fts);
-- JOIN com xml.xml_storage para download de XML, geração de DANFE e re-extração.
-- Parcial: xml_id é opcional em b01_ide (nem toda NF foi importada com rastreio de xml_id).
CREATE INDEX idx_b01_ide_xml_id         ON nota_fiscal.b01_ide (xml_id) WHERE xml_id IS NOT NULL;

-- Trigger FTS
CREATE TRIGGER tr_fts_b01_ide
    BEFORE INSERT OR UPDATE OF ch_nf, cpf_cnpj, dest_cpf_cnpj, ie, dest_ie, num_doc, nat_oper, dh_emi, dt_doc
    ON nota_fiscal.b01_ide
    FOR EACH ROW
    EXECUTE FUNCTION nota_fiscal.ts_vector_update_b01_ide();

CREATE TRIGGER tr_upd_b01_ide
    BEFORE UPDATE ON nota_fiscal.b01_ide
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();

-- =============================================================================
-- NÍVEL 1: FILHAS DIRETAS DE b01_ide  (ON DELETE CASCADE via ch_nf)
-- =============================================================================

-- Referências a outras NF-e / CT-e
CREATE TABLE nota_fiscal.ba01_nf_ref (
    id_nf_ref   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ch_nf       VARCHAR(44) NOT NULL, -- FK para b01_ide
    ref_nfe     VARCHAR(44),          -- Chave de acesso da NF-e referenciada
    ref_cte     VARCHAR(44),          -- Chave de acesso do CT-e referenciado
    c_uf         VARCHAR(2),           -- Código da UF do emitente
    aamm        VARCHAR(4),           -- Ano e mês de emissão
    cnpj        VARCHAR(14),          -- CNPJ do emitente
    cpf         VARCHAR(11),          -- CPF do emitente
    ie          VARCHAR(14),          -- IE do emitente
    mod         VARCHAR(2),           -- Modelo do documento fiscal
    serie       VARCHAR(3),           -- Série do documento fiscal
    n_nf         VARCHAR(9),           -- Número do documento fiscal
    n_ecf        VARCHAR(3),           -- Número de ordem sequencial do ECF
    n_coo        VARCHAR(6),           -- Número do Contador de Ordem de Operação
    CONSTRAINT fk_ba01_nf_ref_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ba01_nf_ref OWNER TO dorcilio;

COMMENT ON TABLE nota_fiscal.ba01_nf_ref IS 'Referências a documentos fiscais relacionados (NF-e, CT-e, NF modelo 1/1A, produtor, ECF, etc). Grupo BA01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.id_nf_ref IS 'Chave surrogate para múltiplas referências por NF-e.';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.ch_nf IS 'Chave de acesso da NF-e principal (emissora).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.ref_nfe IS 'Chave de acesso da NF-e/NFC-e referenciada (modelo 55 ou 65, tag <refNFe>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.ref_cte IS 'Chave de acesso do CT-e referenciado (tag <refCTe>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.c_uf IS 'Código da UF do emitente da referência (tag <cUF> em <refNF>, <refNFP>, <refECF>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.aamm IS 'Ano e mês de emissão da referência (AAMM, tag <AAMM> em <refNF>, <refNFP>, <refECF>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.cnpj IS 'CNPJ do emitente da referência (tag <CNPJ> em <refNF>, <refNFP>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.cpf IS 'CPF do emitente da referência (tag <CPF> em <refNFP>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.ie IS 'IE do emitente da referência (tag <IE> em <refNFP>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.mod IS 'Modelo do documento fiscal referenciado (tag <mod> em <refNF>, <refNFP>, <refECF>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.serie IS 'Série do documento fiscal referenciado (tag <serie> em <refNF>, <refNFP>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.n_nf IS 'Número do documento fiscal referenciado (tag <nNF> em <refNF>, <refNFP>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.n_ecf IS 'Número de ordem sequencial do ECF (tag <nECF> em <refECF>).';
COMMENT ON COLUMN nota_fiscal.ba01_nf_ref.n_coo IS 'Número do Contador de Ordem de Operação (COO, tag <nCOO> em <refECF>).';

-- Índices para performance e busca
CREATE INDEX idx_ba01_nf_ref_ch_nf    ON nota_fiscal.ba01_nf_ref (ch_nf);
CREATE INDEX idx_ba01_nf_ref_ref_nfe  ON nota_fiscal.ba01_nf_ref (ref_nfe);
CREATE INDEX idx_ba01_nf_ref_ref_cte  ON nota_fiscal.ba01_nf_ref (ref_cte);
CREATE INDEX idx_ba01_nf_ref_c_uf     ON nota_fiscal.ba01_nf_ref (c_uf);
CREATE INDEX idx_ba01_nf_ref_cnpj     ON nota_fiscal.ba01_nf_ref (cnpj);
CREATE INDEX idx_ba01_nf_ref_cpf      ON nota_fiscal.ba01_nf_ref (cpf);
CREATE INDEX idx_ba01_nf_ref_mod      ON nota_fiscal.ba01_nf_ref (mod);
CREATE INDEX idx_ba01_nf_ref_n_nf     ON nota_fiscal.ba01_nf_ref (n_nf);
CREATE INDEX idx_ba01_nf_ref_n_ecf    ON nota_fiscal.ba01_nf_ref (n_ecf);
CREATE INDEX idx_ba01_nf_ref_n_coo    ON nota_fiscal.ba01_nf_ref (n_coo);

-- Emitente e endereço
CREATE TABLE nota_fiscal.c01_emit_c05_ender (
    ch_nf               VARCHAR(44)             NOT NULL,
    cpf_cnpj            VARCHAR(14)             NOT NULL,
    ie                  VARCHAR(15)             NOT NULL,
    nome                VARCHAR(60)             NOT NULL,
    fantasia            VARCHAR(60),
    iest                VARCHAR(14),
    im                  VARCHAR(15),
    cnae                VARCHAR(7),
    crt                 INTEGER                 NOT NULL,
    "end"               TEXT                    NOT NULL,
    num                 VARCHAR(60),
    compl               VARCHAR(60),
    bairro              VARCHAR(60)             NOT NULL,
    cod_mun             INTEGER                 NOT NULL,
    descr_mun           VARCHAR(60)             NOT NULL,
    uf                  VARCHAR(2)              NOT NULL,
    cep                 VARCHAR(8)              NOT NULL,
    cod_pais            INTEGER,
    descr_pais          VARCHAR(60),
    fone                VARCHAR(14),

    CONSTRAINT c01_emit_c05_ender_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_c01_emit_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.c01_emit_c05_ender OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.c01_emit_c05_ender IS 'Dados do emitente e seu endereço. Grupos C01 e C05 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.cpf_cnpj  IS 'CPF ou CNPJ do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.ie        IS 'Inscrição Estadual do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.nome      IS 'Razão social ou nome do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.fantasia  IS 'Nome fantasia do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.crt       IS 'Código do Regime Tributário: 1=Simples Nacional, 2=SN Excesso, 3=Normal.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.cnae      IS 'Código CNAE fiscal principal do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.uf        IS 'Sigla da UF do endereço do emitente.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.cep       IS 'CEP do endereço do emitente (8 dígitos).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.ch_nf      IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.iest       IS 'IE do Substituto Tributário da UF de destino da mercadoria, quando há retenção ICMS ST (C18 IEST).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.im         IS 'Inscrição Municipal do Prestador de Serviço, informada em NF-e conjugada com itens de ISSQN (C19 IM).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender."end"      IS 'Logradouro do endereço do emitente (C06 xLgr).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.num        IS 'Número do logradouro do emitente (C07 nro).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.compl      IS 'Complemento do endereço do emitente (C08 xCpl).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.bairro     IS 'Bairro do endereço do emitente (C09 xBairro).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.cod_mun    IS 'Código do município do emitente, tabela IBGE 7 dígitos (C10 cMun).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.descr_mun  IS 'Nome do município do emitente (C11 xMun).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.cod_pais   IS 'Código do País do emitente, tabela IBGE (C14 cPais). 1058=Brasil.';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.descr_pais IS 'Nome do País do emitente (C15 xPais).';
COMMENT ON COLUMN nota_fiscal.c01_emit_c05_ender.fone       IS 'Telefone do emitente com DDD (C16 fone, 6–14 dígitos).';

CREATE INDEX idx_c01_emit_cpf_cnpj ON nota_fiscal.c01_emit_c05_ender (cpf_cnpj);

-- NF-e Avulsa
CREATE TABLE nota_fiscal.d01_avulsa (
    ch_nf               VARCHAR(44)             NOT NULL,
    cnpj                VARCHAR(14)             NOT NULL,
    descr_orgao         VARCHAR(60)             NOT NULL,
    matr                VARCHAR(60)             NOT NULL,
    descr_agente        VARCHAR(60)             NOT NULL,
    fone                VARCHAR(14),
    uf                  VARCHAR(2)              NOT NULL,
    n_dar               VARCHAR(60),
    dt_doc              DATE,
    v_dar               NUMERIC(15,2),
    rep_emi             VARCHAR(60)             NOT NULL,
    dt_pag              DATE,

    CONSTRAINT d01_avulsa_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_d01_avulsa_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.d01_avulsa OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.d01_avulsa IS 'Dados da NF-e avulsa emitida por órgão da Fazenda. Grupo D01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.cnpj        IS 'CNPJ do órgão emitente da NF-e avulsa.';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.descr_orgao IS 'Descrição do órgão emissor.';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.n_dar       IS 'Número do DAR (Documento de Arrecadação).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.v_dar       IS 'Valor do DAR.';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.dt_pag      IS 'Data de pagamento do DAR (D12 dPag).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.ch_nf       IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.matr        IS 'Matrícula do agente do Fisco (D04 matr).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.descr_agente IS 'Nome do agente do Fisco (D05 xAgente).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.fone        IS 'Telefone com DDD do agente do Fisco (D06 fone, 6–14 dígitos).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.uf          IS 'Sigla da UF do agente do Fisco (D07 UF).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.dt_doc      IS 'Data de emissão do Documento de Arrecadação — DAR (D09 dEmi).';
COMMENT ON COLUMN nota_fiscal.d01_avulsa.rep_emi     IS 'Repartição Fiscal emitente do DAR (D11 repEmi).';

-- Destinatário e endereço
CREATE TABLE nota_fiscal.e01_dest_e05_ender (
    ch_nf               VARCHAR(44)             NOT NULL,
    cpf_cnpj            VARCHAR(14)             NOT NULL,
    ie                  VARCHAR(15)             NOT NULL,
    nome                VARCHAR(60)             NOT NULL,
    fantasia            VARCHAR(60),
    id_estrangeiro      VARCHAR(20),
    ind_ie_dest         INTEGER                 NOT NULL,
    isuf                VARCHAR(9),
    im                  VARCHAR(15),
    email               VARCHAR(60),
    "end"               TEXT                    NOT NULL,
    num                 VARCHAR(60),
    compl               VARCHAR(60),
    bairro              VARCHAR(60)             NOT NULL,
    cod_mun             INTEGER                 NOT NULL,
    descr_mun           VARCHAR(60)             NOT NULL,
    uf                  VARCHAR(2)              NOT NULL,
    cep                 VARCHAR(8)              NOT NULL,
    cod_pais            INTEGER,
    descr_pais          VARCHAR(60),
    fone                VARCHAR(14),

    CONSTRAINT e01_dest_e05_ender_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_e01_dest_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.e01_dest_e05_ender OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.e01_dest_e05_ender IS 'Dados do destinatário e seu endereço. Grupos E01 e E05 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.cpf_cnpj       IS 'CPF ou CNPJ do destinatário.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.ie              IS 'Inscrição Estadual do destinatário.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.nome            IS 'Razão social ou nome do destinatário.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.ind_ie_dest     IS 'Indicador da IE do destinatário: 1=Contribuinte, 2=Isento, 9=Não contribuinte.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.email           IS 'E-mail do destinatário.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.id_estrangeiro  IS 'Identificação do destinatário no exterior.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.uf              IS 'Sigla da UF do endereço do destinatário.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.cep             IS 'CEP do endereço do destinatário (8 dígitos).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.ch_nf           IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.fantasia         IS 'Nome fantasia do destinatário (campo interno/complementar ao leiaute).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.isuf            IS 'Inscrição na SUFRAMA do destinatário (E18 ISUF, 8–9 dígitos). Obrigatório para operações com incentivos fiscais na Amazônia.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.im              IS 'Inscrição Municipal do Tomador do Serviço (E18a IM), utilizada em NF-e conjugada com itens de ISSQN.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender."end"           IS 'Logradouro do endereço do destinatário (E06 xLgr).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.num             IS 'Número do logradouro do destinatário (E07 nro).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.compl           IS 'Complemento do endereço do destinatário (E08 xCpl).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.bairro          IS 'Bairro do endereço do destinatário (E09 xBairro).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.cod_mun         IS 'Código do município do destinatário, tabela IBGE 7 dígitos (E10 cMun).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.descr_mun       IS 'Nome do município do destinatário (E11 xMun). Informar EXTERIOR para operações com o exterior.';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.cod_pais        IS 'Código do País do destinatário, tabela BACEN (E14 cPais).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.descr_pais      IS 'Nome do País do destinatário (E15 xPais).';
COMMENT ON COLUMN nota_fiscal.e01_dest_e05_ender.fone            IS 'Telefone do destinatário com DDD (E16 fone, 6–14 dígitos).';

CREATE INDEX idx_e01_dest_cpf_cnpj ON nota_fiscal.e01_dest_e05_ender (cpf_cnpj);

-- Totais ICMS
CREATE TABLE nota_fiscal.w02_icms_tot (
    ch_nf               VARCHAR(44)             NOT NULL,
    v_bc                NUMERIC(15,2)           NOT NULL,
    v_icms              NUMERIC(15,2)           NOT NULL,
    v_bc_st             NUMERIC(15,2)           NOT NULL,
    v_st                NUMERIC(15,2)           NOT NULL,
    v_prod              NUMERIC(15,2)           NOT NULL,
    v_frete             NUMERIC(15,2)           NOT NULL,
    v_seg               NUMERIC(15,2)           NOT NULL,
    v_desc              NUMERIC(15,2)           NOT NULL,
    v_ii                NUMERIC(15,2)           NOT NULL,
    v_ipi               NUMERIC(15,2)           NOT NULL,
    v_pis               NUMERIC(15,2)           NOT NULL,
    v_cofins            NUMERIC(15,2)           NOT NULL,
    v_outro             NUMERIC(15,2)           NOT NULL,
    v_nf                NUMERIC(15,2)           NOT NULL,
    v_tot_trib          NUMERIC(15,2),
    v_icms_deson        NUMERIC(15,2),
    v_fcp_uf_dest       NUMERIC(15,2),
    v_icms_uf_dest      NUMERIC(15,2),
    v_icms_uf_remet     NUMERIC(15,2),
    v_fcp               NUMERIC(15,2),
    v_fcp_st            NUMERIC(15,2),
    v_fcp_st_ret        NUMERIC(15,2),
    v_ipi_devol         NUMERIC(15,2),

    CONSTRAINT w02_icms_tot_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_w02_icms_tot_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.w02_icms_tot OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.w02_icms_tot IS 'Totais de ICMS da NF-e. Grupo W02 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_nf      IS 'Valor total da NF-e.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_prod    IS 'Valor total dos produtos/serviços.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_icms    IS 'Valor total do ICMS.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_st      IS 'Valor total do ICMS ST.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_pis     IS 'Valor total do PIS.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_cofins  IS 'Valor total da COFINS.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_frete   IS 'Valor total do frete.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_desc    IS 'Valor total do desconto.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_ipi     IS 'Valor total do IPI (W12 vIPI).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.ch_nf          IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_bc           IS 'Base de cálculo total do ICMS (W03 vBC).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_bc_st        IS 'Base de cálculo total do ICMS ST (W05 vBCST).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_seg          IS 'Valor total do seguro (W09 vSeg).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_ii           IS 'Valor total do Imposto de Importação (W11 vII).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_outro        IS 'Outras despesas acessórias totais (W15 vOutro).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_tot_trib     IS 'Valor aproximado total de tributos federais, estaduais e municipais (W16a vTotTrib — NT 2013/003).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_icms_deson   IS 'Valor total do ICMS desonerado (W04a vICMSDeson).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_fcp_uf_dest  IS 'Valor total do FCP da UF de destino em operações interestaduais (W04c vFCPUFDest — NT 2015/003).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_icms_uf_dest IS 'Valor total do ICMS Interestadual para a UF de destino (W04e vICMSUFDest — NT 2015/003).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_icms_uf_remet IS 'Valor total do ICMS Interestadual para a UF remetente (W04g vICMSUFRemet). A partir de 2019 este valor é zero.';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_fcp          IS 'Valor total do FCP — Fundo de Combate à Pobreza (W04h vFCP — NT2016.002).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_fcp_st       IS 'Valor total do FCP retido por substituição tributária (W06a vFCPST — NT2016.002).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_fcp_st_ret   IS 'Valor total do FCP retido anteriormente por ST (W06b vFCPSTRet — NT2016.002).';
COMMENT ON COLUMN nota_fiscal.w02_icms_tot.v_ipi_devol    IS 'Valor total do IPI devolvido em notas de devolução para não contribuintes do IPI (W12a vIPIDevol — NT2016.002).';

-- Totais ISSQN
CREATE TABLE nota_fiscal.w17_issqn_tot (
    ch_nf               VARCHAR(44)             NOT NULL,
    v_serv              NUMERIC(15,2),
    v_bc                NUMERIC(15,2),
    v_iss               NUMERIC(15,2),
    v_pis               NUMERIC(15,2),
    v_cofins            NUMERIC(15,2),
    dt_compet           DATE                    NOT NULL,
    v_deducao           NUMERIC(15,2),
    v_outro             NUMERIC(15,2),
    v_desc_incond       NUMERIC(15,2),
    v_desc_cond         NUMERIC(15,2),
    v_iss_ret           NUMERIC(15,2),
    c_reg_trib          INTEGER,

    CONSTRAINT w17_issqn_tot_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_w17_issqn_tot_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.w17_issqn_tot OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.w17_issqn_tot IS 'Totais de ISSQN da NF-e de serviços. Grupo W17 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.dt_compet   IS 'Mês de competência do ISSQN (data de referência).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_serv      IS 'Valor total dos serviços sujeitos ao ISSQN.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_iss       IS 'Valor total do ISSQN.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_iss_ret   IS 'Valor total do ISSQN retido.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.c_reg_trib  IS 'Código do regime tributário: 1=Microempresa Municipal, 2=Estimativa, 3=Sociedade Profissional, etc.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.ch_nf        IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_bc         IS 'Valor total da base de cálculo do ISSQN (W19 vBC).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_pis        IS 'Valor total do PIS sobre serviços (W21 vPIS).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_cofins     IS 'Valor total da COFINS sobre serviços (W22 vCOFINS).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_deducao    IS 'Valor total de deduções para redução da base de cálculo do ISSQN (W22b vDeducao).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_outro      IS 'Valor total de outras retenções (W22c vOutro — declaratório).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_desc_incond IS 'Valor total de desconto incondicionado sobre serviços (W22d vDescIncond).';
COMMENT ON COLUMN nota_fiscal.w17_issqn_tot.v_desc_cond  IS 'Valor total de desconto condicionado sobre serviços (W22e vDescCond).';

-- Retenção de tributos
CREATE TABLE nota_fiscal.w23_ret_trib (
    ch_nf               VARCHAR(44)             NOT NULL,
    v_ret_pis           NUMERIC(15,2),
    v_ret_cofins        NUMERIC(15,2),
    v_ret_csll          NUMERIC(15,2),
    v_bc_irrf           NUMERIC(15,2),
    v_irrf              NUMERIC(15,2),
    v_bc_ret_prev       NUMERIC(15,2),
    v_ret_prev          NUMERIC(15,2),

    CONSTRAINT w23_ret_trib_pkey PRIMARY KEY (ch_nf),
    CONSTRAINT fk_w23_ret_trib_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.w23_ret_trib OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.w23_ret_trib IS 'Retenções de tributos federais da NF-e. Grupo W23 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_ret_pis    IS 'Valor retido de PIS.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_ret_cofins IS 'Valor retido de COFINS.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_ret_csll   IS 'Valor retido de CSLL.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_bc_irrf    IS 'Base de cálculo do IRRF.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_irrf       IS 'Valor retido de IRRF.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_ret_prev   IS 'Valor retido de Previdência Social (W30 vRetPrev).';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.ch_nf         IS 'Chave de acesso da NF-e. PK e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.w23_ret_trib.v_bc_ret_prev IS 'Base de cálculo da retenção da Previdência Social (W29 vBCRetPrev).';

-- Protocolo de autorização
CREATE TABLE nota_fiscal.pr03_inf_prot (
    ch_nf               VARCHAR(44)             NOT NULL,
    tp_amb              INTEGER                 NOT NULL,
    ch_nfe              VARCHAR(44)             NOT NULL,
    dh_recbto           TIMESTAMPTZ             NOT NULL,
    n_prot              VARCHAR(15),
    dig_val             VARCHAR(28),
    c_stat              INTEGER                 NOT NULL,
    x_motivo            VARCHAR(255)            NOT NULL,

    CONSTRAINT pr03_inf_prot_pkey PRIMARY KEY (ch_nf, ch_nfe),
    CONSTRAINT fk_pr03_inf_prot_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.pr03_inf_prot OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.pr03_inf_prot IS 'Protocolo de autorização ou denegação da SEFAZ. Grupo PR03 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.n_prot    IS 'Número do protocolo de autorização emitido pela SEFAZ.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.c_stat    IS 'Código do status da resposta (100=Autorizada, 110=Denegada, 205=Cancelada, etc.).';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.x_motivo  IS 'Descrição do status retornado pela SEFAZ.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.dh_recbto IS 'Data e hora do recebimento pela SEFAZ.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.tp_amb    IS 'Ambiente da autorização: 1=Produção, 2=Homologação.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.dig_val   IS 'Digest value do XML assinado.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.ch_nf     IS 'Chave de acesso da NF-e. Parte da PK composta com ch_nfe e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.pr03_inf_prot.ch_nfe    IS 'Chave de acesso da NF-e informada no protocolo — pode diferir em reprocessamentos (campo de rastreabilidade).';

CREATE INDEX idx_pr03_inf_prot_c_stat ON nota_fiscal.pr03_inf_prot (c_stat);

-- Duplicatas (cobrança)
CREATE TABLE nota_fiscal.y07_dup (
    id_dup              BIGINT                  GENERATED ALWAYS AS IDENTITY,
    ch_nf               VARCHAR(44)             NOT NULL,
    n_dup               VARCHAR(60),
    dt_venc             DATE,
    v_dup               NUMERIC(15,2)           NOT NULL,

    CONSTRAINT y07_dup_pkey PRIMARY KEY (id_dup),
    CONSTRAINT fk_y07_dup_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.y07_dup OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.y07_dup IS 'Duplicatas da cobrança da NF-e. Grupo Y07 do leiaute NF-e. Surrogate BIGINT para alta cardinalidade.';
COMMENT ON COLUMN nota_fiscal.y07_dup.id_dup   IS 'Chave surrogate gerada automaticamente (BIGINT IDENTITY).';
COMMENT ON COLUMN nota_fiscal.y07_dup.n_dup    IS 'Número da duplicata.';
COMMENT ON COLUMN nota_fiscal.y07_dup.dt_venc  IS 'Data de vencimento da duplicata.';
COMMENT ON COLUMN nota_fiscal.y07_dup.v_dup    IS 'Valor da duplicata (Y10 vDup).';
COMMENT ON COLUMN nota_fiscal.y07_dup.ch_nf    IS 'Chave de acesso da NF-e. FK para b01_ide.';

CREATE INDEX idx_y07_dup_ch_nf    ON nota_fiscal.y07_dup (ch_nf);
CREATE INDEX idx_y07_dup_dt_venc  ON nota_fiscal.y07_dup (dt_venc);

-- Pagamento (header)
CREATE TABLE nota_fiscal.ya01_pag (
    id_pag              BIGINT                  GENERATED ALWAYS AS IDENTITY,
    ch_nf               VARCHAR(44)             NOT NULL,
    cnpj_pag            VARCHAR(14),
    uf_pag              VARCHAR(2),
    v_troco             NUMERIC(15,2),

    CONSTRAINT ya01_pag_pkey PRIMARY KEY (id_pag),
    CONSTRAINT fk_ya01_pag_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ya01_pag OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.ya01_pag IS 'Cabeçalho do grupo de pagamento da NF-e. Grupo YA01 do leiaute NF-e. Surrogate BIGINT para suportar múltiplos registros por ch_nf.';
COMMENT ON COLUMN nota_fiscal.ya01_pag.id_pag   IS 'Chave surrogate gerada automaticamente (BIGINT IDENTITY).';
COMMENT ON COLUMN nota_fiscal.ya01_pag.ch_nf    IS 'Chave de acesso da NF-e. FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.ya01_pag.cnpj_pag IS 'CNPJ do beneficiário do pagamento.';
COMMENT ON COLUMN nota_fiscal.ya01_pag.uf_pag   IS 'UF do beneficiário do pagamento.';
COMMENT ON COLUMN nota_fiscal.ya01_pag.v_troco  IS 'Valor do troco.';

CREATE INDEX idx_ya01_pag_ch_nf ON nota_fiscal.ya01_pag (ch_nf);

-- Pagamento (detalhes)
-- Hierarquia XML: pag (ya01_pag) → detPag (ya01a_det_pag) → card (ya04_card)
CREATE TABLE nota_fiscal.ya01a_det_pag (
    id_det_pag          BIGINT                  GENERATED ALWAYS AS IDENTITY,
    id_pag              BIGINT                  NOT NULL,
    ch_nf               VARCHAR(44)             NOT NULL,
    ind_pag             INTEGER,
    t_pag               VARCHAR(2)              NOT NULL,
    x_pag               VARCHAR(60),
    v_pag               NUMERIC(15,2)           NOT NULL,
    dt_pag              DATE,

    CONSTRAINT ya01a_det_pag_pkey PRIMARY KEY (id_det_pag),
    CONSTRAINT fk_ya01a_det_pag_ya01_pag FOREIGN KEY (id_pag)
        REFERENCES nota_fiscal.ya01_pag (id_pag)
        ON DELETE CASCADE,
    CONSTRAINT fk_ya01a_det_pag_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ya01a_det_pag OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.ya01a_det_pag IS 'Detalhamento de cada forma de pagamento. Grupo YA01a do leiaute NF-e. Filho de ya01_pag. Surrogate BIGINT.';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.id_det_pag IS 'Chave surrogate gerada automaticamente (BIGINT IDENTITY).';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.id_pag     IS 'FK para ya01_pag(id_pag). Mantém a hierarquia XML: pag → detPag.';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.ch_nf      IS 'Chave de acesso da NF-e. Desnormalizado de ya01_pag para consulta direta por NF-e sem JOIN.';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.t_pag      IS 'Tipo de pagamento: 01=Dinheiro, 02=Cheque, 03=Cartão Crédito, 04=Cartão Débito, 05=Crédito Loja, etc.';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.v_pag      IS 'Valor do pagamento nesta forma.';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.ind_pag    IS 'Indicador de pagamento: 0=À Vista, 1=A Prazo (YA01b indPag — NT2016.002).';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.x_pag      IS 'Descrição textual do meio de pagamento (campo interno/complementar).';
COMMENT ON COLUMN nota_fiscal.ya01a_det_pag.dt_pag     IS 'Data do pagamento, utilizada em pagamentos instantâneos (PIX) e similares (NT2020.006).';

CREATE INDEX idx_ya01a_det_pag_id_pag ON nota_fiscal.ya01a_det_pag (id_pag);
CREATE INDEX idx_ya01a_det_pag_ch_nf  ON nota_fiscal.ya01a_det_pag (ch_nf);

-- Informações adicionais
CREATE TABLE nota_fiscal.z01_inf_adic (
    id_inf_adic         BIGINT                  GENERATED ALWAYS AS IDENTITY,
    ch_nf               VARCHAR(44),
    inf_ad_fisco        VARCHAR(2000),
    inf_cpl             VARCHAR(5000),

    CONSTRAINT z01_inf_adic_pkey PRIMARY KEY (id_inf_adic),
    CONSTRAINT fk_z01_inf_adic_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.z01_inf_adic OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.z01_inf_adic IS 'Informações adicionais da NF-e. Grupo Z01 do leiaute NF-e. Surrogate BIGINT.';
COMMENT ON COLUMN nota_fiscal.z01_inf_adic.id_inf_adic  IS 'Chave surrogate gerada automaticamente (BIGINT IDENTITY).';
COMMENT ON COLUMN nota_fiscal.z01_inf_adic.inf_ad_fisco IS 'Informações adicionais de interesse do fisco (até 2000 caracteres).';
COMMENT ON COLUMN nota_fiscal.z01_inf_adic.inf_cpl      IS 'Informações complementares do contribuinte (até 5000 caracteres).';

CREATE INDEX idx_z01_inf_adic_ch_nf ON nota_fiscal.z01_inf_adic (ch_nf);

-- Observações do contribuinte
CREATE TABLE nota_fiscal.z04_obs_cont (
    ch_nf               VARCHAR(44)             NOT NULL,
    id_inf_adic         BIGINT,
    x_campo             VARCHAR(20)             NOT NULL,
    x_texto             VARCHAR(60)             NOT NULL,

    CONSTRAINT z04_obs_cont_pkey PRIMARY KEY (ch_nf, x_texto),
    CONSTRAINT fk_z04_obs_cont_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.z04_obs_cont OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.z04_obs_cont IS 'Observações de uso livre do contribuinte em formato campo/valor. Grupo Z04 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.z04_obs_cont.x_campo IS 'Identificação do campo de observação (até 20 caracteres).';
COMMENT ON COLUMN nota_fiscal.z04_obs_cont.x_texto IS 'Texto da observação (até 60 caracteres). Compõe a PK.';

-- Observações do fisco
CREATE TABLE nota_fiscal.z07_obs_fisco (
    ch_nf               VARCHAR(44)             NOT NULL,
    id_inf_adic         BIGINT,
    x_campo             VARCHAR(20)             NOT NULL,
    x_texto             VARCHAR(60)             NOT NULL,

    CONSTRAINT z07_obs_fisco_pkey PRIMARY KEY (ch_nf, x_campo),
    CONSTRAINT fk_z07_obs_fisco_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.z07_obs_fisco OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.z07_obs_fisco IS 'Observações do fisco em formato campo/valor. Grupo Z07 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.z07_obs_fisco.x_campo IS 'Identificação do campo de uso do fisco (PK parcial).';
COMMENT ON COLUMN nota_fiscal.z07_obs_fisco.x_texto IS 'Texto da observação do fisco (até 60 caracteres).';

-- =============================================================================
-- NÍVEL 1 → NÍVEL 2: i01_prod — Itens da NF-e
-- Referencia b01_ide via ch_nf. Todas as tabelas de tributos por item
-- referenciam esta tabela via (ch_nf, num_item) com ON DELETE CASCADE.
-- =============================================================================

CREATE TABLE nota_fiscal.i01_prod (
    ch_nf                       VARCHAR(44)     NOT NULL,
    num_item                    VARCHAR(3)      NOT NULL,
    cod_item                    VARCHAR(60)     NOT NULL,
    num_doc                     INTEGER         NOT NULL,
    ser                         VARCHAR(3)      NOT NULL,
    cod_mod                     VARCHAR(2)      NOT NULL,
    descr_item                  TEXT            NOT NULL,
    cod_ncm                     VARCHAR(10)     NOT NULL,
    ex_ipi                      VARCHAR(3),
    cfop                        INTEGER         NOT NULL,
    unid                        VARCHAR(10)     NOT NULL,
    v_item                      NUMERIC(15,2)   NOT NULL,
    unid_trib                   VARCHAR(10)     NOT NULL,
    v_frt                       NUMERIC(15,2),
    v_seg                       NUMERIC(15,2),
    v_desc                      NUMERIC(15,2),
    v_outro                     NUMERIC(15,2),
    ind_tot                     INTEGER         NOT NULL,
    x_ped                       VARCHAR(15),
    num_item_ped                VARCHAR(10),
    v_unit                      VARCHAR(32),
    v_unit_trib                 VARCHAR(32),
    qtd                         NUMERIC(15,3)   NOT NULL,
    qtd_trib                    NUMERIC(15,4)   NOT NULL,
    n_fci                       TEXT,
    nve                         VARCHAR(10),
    cest                        BIGINT,
    cod_barra                   VARCHAR(14),
    cod_barra_not_gtin          VARCHAR(30),
    cod_barra_trib              VARCHAR(14),
    cod_barra_trib_not_gtin     VARCHAR(30),
    inf_ad_prod                 TEXT,
    ind_escala                  VARCHAR(1),
    cnpj_fab                    VARCHAR(14),
    c_benef                     VARCHAR(10),
    v_tot_trib                  NUMERIC(15,2),

    -- Full Text Search
    i01_prod_fts                TSVECTOR,

    CONSTRAINT i01_prod_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_i01_prod_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.i01_prod OWNER TO dorcilio;

-- idx_i01_prod_ch_nf omitido: PK (ch_nf, num_item) cobre prefix scan por ch_nf com igual eficiência.
CREATE INDEX idx_i01_prod_cod_ncm  ON nota_fiscal.i01_prod (cod_ncm);
CREATE INDEX idx_i01_prod_cfop     ON nota_fiscal.i01_prod (cfop);
CREATE INDEX idx_i01_prod_cod_item ON nota_fiscal.i01_prod (cod_item);
CREATE INDEX idx_i01_prod_fts      ON nota_fiscal.i01_prod USING GIN (i01_prod_fts);

CREATE TRIGGER tr_fts_i01_prod
    BEFORE INSERT OR UPDATE OF descr_item, cod_item, cod_ncm, cnpj_fab, c_benef, cod_barra, inf_ad_prod
    ON nota_fiscal.i01_prod
    FOR EACH ROW
    EXECUTE FUNCTION nota_fiscal.fn_update_i01_prod_fts();

COMMENT ON TABLE nota_fiscal.i01_prod IS 'Itens da NF-e. A deleção de b01_ide propaga em cascade para esta tabela e para todas as tabelas de tributos por item.';
COMMENT ON COLUMN nota_fiscal.i01_prod.num_item     IS 'Número sequencial do item na NF-e (01–990). Compõe a PK composta com ch_nf.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_item     IS 'Código do produto/serviço do emitente.';
COMMENT ON COLUMN nota_fiscal.i01_prod.descr_item   IS 'Descrição do produto/serviço.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_ncm      IS 'Código NCM (Nomenclatura Comum do Mercosul) da mercadoria.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cfop         IS 'Código Fiscal de Operações e Prestações.';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_item       IS 'Valor bruto total do item (qtd * v_unit).';
COMMENT ON COLUMN nota_fiscal.i01_prod.qtd          IS 'Quantidade comercial do item.';
COMMENT ON COLUMN nota_fiscal.i01_prod.unid         IS 'Unidade comercial (ex: UN, KG, CX, L).';
COMMENT ON COLUMN nota_fiscal.i01_prod.cest         IS 'Código Especificador da Substituição Tributária (CEST).';
COMMENT ON COLUMN nota_fiscal.i01_prod.ind_tot      IS 'Indica se o item compõe o valor total da NF-e: 0=Não, 1=Sim.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_barra    IS 'Código de barras do produto (GTIN-8/12/13/14).';
COMMENT ON COLUMN nota_fiscal.i01_prod.inf_ad_prod  IS 'Informações adicionais do produto.';
COMMENT ON COLUMN nota_fiscal.i01_prod.i01_prod_fts IS 'Vetor FTS calculado sobre descr_item, cod_item (peso A), cod_ncm, cnpj_fab, c_benef (peso B), cod_barra (peso C) e inf_ad_prod (peso D).';
COMMENT ON COLUMN nota_fiscal.i01_prod.ch_nf                   IS 'Chave de acesso da NF-e. Parte da PK composta e FK para b01_ide.';
COMMENT ON COLUMN nota_fiscal.i01_prod.num_doc                 IS 'Número da NF-e (nNF) — redundante para facilitar consultas sem JOIN com b01_ide.';
COMMENT ON COLUMN nota_fiscal.i01_prod.ser                     IS 'Série da NF-e — redundante para facilitar consultas sem JOIN com b01_ide.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_mod                 IS 'Modelo do documento fiscal: 55=NF-e, 65=NFC-e — redundante para facilitar consultas.';
COMMENT ON COLUMN nota_fiscal.i01_prod.ex_ipi                  IS 'Código EX da TIPI (Excessão Tarifária do IPI), 2–3 dígitos (I06 EXTIPI).';
COMMENT ON COLUMN nota_fiscal.i01_prod.unid_trib               IS 'Unidade tributável do item (I13 uTrib, 1–6 caracteres).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_frt                   IS 'Valor do frete do item (I15 vFrete).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_seg                   IS 'Valor do seguro do item (I16 vSeg).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_desc                  IS 'Valor do desconto do item (I17 vDesc).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_outro                 IS 'Outras despesas acessórias do item (I17a vOutro).';
COMMENT ON COLUMN nota_fiscal.i01_prod.x_ped                   IS 'Número do pedido de compra associado ao item, controle B2B (I60 xPed, 1–15 caracteres).';
COMMENT ON COLUMN nota_fiscal.i01_prod.num_item_ped            IS 'Número do item dentro do pedido de compra, controle B2B (I61 nItemPed, até 6 dígitos).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_unit                  IS 'Valor unitário de comercialização — campo meramente informativo, precisão 0–10 decimais (I10a vUnCom).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_unit_trib             IS 'Valor unitário de tributação — campo informativo, precisão 0–10 decimais (I14a vUnTrib).';
COMMENT ON COLUMN nota_fiscal.i01_prod.qtd_trib                IS 'Quantidade tributável do item na unidade tributária (I14 qTrib).';
COMMENT ON COLUMN nota_fiscal.i01_prod.n_fci                   IS 'Número de controle da FCI — Ficha de Conteúdo de Importação, UUID (I70 nFCI — Resolução Senado 13/2012).';
COMMENT ON COLUMN nota_fiscal.i01_prod.nve                     IS 'Codificação NVE — Nomenclatura de Valor Aduaneiro e Estatística, 2 letras + 4 dígitos (I05a NVE). Até 8 ocorrências.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_barra_not_gtin      IS 'Código de barras do produto quando não possui GTIN — armazenado o literal ''SEM GTIN'' conforme leiaute.';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_barra_trib          IS 'Código de barras GTIN da unidade tributável — menor unidade comercializável com GTIN (I12 cEANTrib).';
COMMENT ON COLUMN nota_fiscal.i01_prod.cod_barra_trib_not_gtin IS 'Código de barras da unidade tributável quando não possui GTIN.';
COMMENT ON COLUMN nota_fiscal.i01_prod.ind_escala              IS 'Indicador de produção em escala relevante: S=Sim, N=Não. Obrigatório para NCMs do Convênio ICMS 52/2017 (I05d indEscala).';
COMMENT ON COLUMN nota_fiscal.i01_prod.cnpj_fab                IS 'CNPJ do fabricante da mercadoria. Obrigatório quando ind_escala=N (I05e CNPJFab).';
COMMENT ON COLUMN nota_fiscal.i01_prod.c_benef                 IS 'Código de benefício fiscal da UF aplicado ao item, 8 ou 10 caracteres (I05f cBenef — NT2016.002).';
COMMENT ON COLUMN nota_fiscal.i01_prod.v_tot_trib              IS 'Valor aproximado total de tributos federais, estaduais e municipais do item (M02 vTotTrib — NT 2013/003).';

-- =============================================================================
-- NÍVEL 2: FILHAS DE i01_prod — Tributos por item (ON DELETE CASCADE via ch_nf, num_item)
-- =============================================================================

-- ICMS por item
CREATE TABLE nota_fiscal.n01_icms (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    orig                INTEGER,
    cst                 VARCHAR(3),
    cso_sn              VARCHAR(3),
    p_cred_sn           NUMERIC(5,2),
    v_cred_icms_sn      NUMERIC(15,2),
    mod_bc              INTEGER,
    mod_bc_st           INTEGER,
    p_red_bc            NUMERIC(15,4),
    p_red_bc_st         NUMERIC(15,4),
    p_mva_st            NUMERIC(15,4),
    v_bc                NUMERIC(15,2),
    v_bc_st             NUMERIC(15,2),
    v_bc_st_ret         NUMERIC(15,2),
    p_icms              NUMERIC(15,4),
    v_icms              NUMERIC(15,2),
    p_icms_st           NUMERIC(15,4),
    v_icms_st           NUMERIC(15,2),
    v_icms_st_ret       NUMERIC(15,2),
    mot_des_icms        INTEGER,
    p_bc_op             NUMERIC(15,4),
    v_icms_deson        NUMERIC(15,2),
    v_icms_op           NUMERIC(15,2),
    p_dif               NUMERIC(15,4),
    v_icms_dif          NUMERIC(15,2),
    p_st                NUMERIC(15,4),
    uf_st               VARCHAR(2),
    v_bc_st_dest        NUMERIC(15,2),
    v_icms_st_dest      NUMERIC(15,2),
    v_bc_fcp            NUMERIC(15,2),
    p_fcp               NUMERIC(15,4),
    v_bc_fcp_st         NUMERIC(15,2),
    p_fcp_st            NUMERIC(15,4),
    v_fcp_st            NUMERIC(15,2),
    v_bc_fcp_st_ret     NUMERIC(15,2),
    p_fcp_st_ret        NUMERIC(15,4),
    v_fcp_st_ret        NUMERIC(15,2),
    v_fcp               NUMERIC(15,2),
    v_icms_substituto   NUMERIC(15,2),
    p_red_bc_efet       NUMERIC(15,4),
    v_bc_efet           NUMERIC(15,2),
    p_icms_efet         NUMERIC(15,4),
    v_icms_efet         NUMERIC(15,2),

    CONSTRAINT n01_icms_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_n01_icms_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.n01_icms OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.n01_icms IS 'Tributação de ICMS por item da NF-e (todos os CSTs/CSOSNs). Grupo N01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.n01_icms.orig         IS 'Origem da mercadoria: 0=Nacional, 1=Estrangeira direta, 2=Estrangeira indireto, etc.';
COMMENT ON COLUMN nota_fiscal.n01_icms.cst          IS 'Código de Situação Tributária do ICMS (regime normal).';
COMMENT ON COLUMN nota_fiscal.n01_icms.cso_sn       IS 'Código de Situação da Operação no Simples Nacional (CSOSN).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms       IS 'Valor do ICMS.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_st    IS 'Valor do ICMS por Substituição Tributária.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc         IS 'Base de cálculo do ICMS.';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_icms           IS 'Alíquota do ICMS (%%) sem o FCP.';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_cred_sn        IS 'Alíquota aplicável de cálculo do crédito no Simples Nacional (N29 pCredSN).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_cred_icms_sn   IS 'Valor do crédito de ICMS aproveitável no Simples Nacional conforme art. 23 LC 123/2006 (N30 vCredICMSSN).';
COMMENT ON COLUMN nota_fiscal.n01_icms.mod_bc            IS 'Modalidade de determinação da BC do ICMS: 0=MVA, 1=Pauta, 2=Preço Tabelado Máx., 3=Valor da operação.';
COMMENT ON COLUMN nota_fiscal.n01_icms.mod_bc_st         IS 'Modalidade de determinação da BC do ICMS ST: 0=Preço Tabelado, 1=Lista Negativa, 2=Lista Positiva, 3=Lista Neutra, 4=MVA, 5=Pauta, 6=Valor da Operação (NT 2019.001).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_red_bc          IS 'Percentual de redução da base de cálculo do ICMS.';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_red_bc_st       IS 'Percentual de redução da base de cálculo do ICMS ST.';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_mva_st          IS 'Percentual da margem de valor adicionado do ICMS ST (N19 pMVAST).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_st           IS 'Valor da base de cálculo do ICMS ST.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_st_ret       IS 'Valor da base de cálculo do ICMS ST retido anteriormente (N26 vBCSTRet).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_icms_st         IS 'Alíquota do ICMS ST sem o FCP (N22 pICMSST).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_st_ret     IS 'Valor do ICMS ST retido anteriormente (N27 vICMSSTRet).';
COMMENT ON COLUMN nota_fiscal.n01_icms.mot_des_icms      IS 'Motivo da desoneração do ICMS: 1=Táxi, 3=Agropecuária, 4=Frotista, 7=SUFRAMA, 8=Órgão Público, 9=Outros, etc. (N28 motDesICMS).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_bc_op           IS 'Percentual da BC da operação própria no grupo de partilha do ICMS interestadual (N25 pBCOp).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_op         IS 'Valor do ICMS da operação como se não houvesse o diferimento (N16a vICMSOp).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_dif             IS 'Percentual do diferimento do ICMS (N16b pDif). No diferimento total informar 100.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_dif        IS 'Valor do ICMS diferido (N16c vICMSDif).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_st              IS 'Alíquota suportada pelo consumidor final incluindo FCP, usada no cálculo do ICMS-ST (N26a pST).';
COMMENT ON COLUMN nota_fiscal.n01_icms.uf_st             IS 'Sigla da UF para a qual é devido o ICMS ST (N24 UFST). Informar EX para exterior.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_st_dest      IS 'Valor da base de cálculo do ICMS ST da UF destino no repasse interestadual (N31 vBCSTDest).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_st_dest    IS 'Valor do ICMS ST da UF de destino no repasse interestadual (N32 vICMSSTDest).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_fcp          IS 'Valor da base de cálculo do FCP — Fundo de Combate à Pobreza (N17a vBCFCP).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_fcp             IS 'Percentual do FCP sobre o ICMS (N17b pFCP). Máximo 2%%.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_fcp_st       IS 'Valor da base de cálculo do FCP retido por ST (N23a vBCFCPST).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_fcp_st          IS 'Percentual do FCP retido por ST (N23b pFCPST). Máximo 2%%.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_fcp_st_ret   IS 'Valor da base de cálculo do FCP retido anteriormente por ST (N27a vBCFCPSTRet).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_fcp_st_ret      IS 'Percentual do FCP retido anteriormente por ST (N27b pFCPSTRet). Máximo 2%%.';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_substituto IS 'Valor do ICMS próprio do substituto tributário cobrado em operação anterior (N26b vICMSSubstituto — NT 2018.005).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_red_bc_efet     IS 'Percentual de redução da base de cálculo efetiva para ICMS cobrado por ST (N34 pRedBCEfet — opcional por UF).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_bc_efet         IS 'Valor da base de cálculo efetiva = vProd × (1 - pRedBCEfet) (N35 vBCEfet — opcional por UF).';
COMMENT ON COLUMN nota_fiscal.n01_icms.p_icms_efet       IS 'Alíquota do ICMS efetiva na operação a consumidor final (N36 pICMSEfet — opcional por UF).';
COMMENT ON COLUMN nota_fiscal.n01_icms.v_icms_efet       IS 'Valor do ICMS efetivo = pICMSEfet × vBCEfet (N37 vICMSEfet — opcional por UF).';

-- ICMS UF Destino (difal)
CREATE TABLE nota_fiscal.na01_icms_uf_dest (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    v_bc_uf_dest        NUMERIC(15,2),
    p_fcp_uf_dest       NUMERIC(5,2),
    p_icms_uf_dest      NUMERIC(5,2),
    p_icms_inter        NUMERIC(5,2),
    p_icms_inter_part   NUMERIC(5,2),
    v_fcp_uf_dest       NUMERIC(15,2),
    v_icms_uf_dest      NUMERIC(15,2),
    v_icms_uf_remet     NUMERIC(15,2),

    CONSTRAINT na01_icms_uf_dest_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_na01_icms_uf_dest_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.na01_icms_uf_dest OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.na01_icms_uf_dest IS 'ICMS partilhado para operações interestaduais (DIFAL). Grupo NA01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.p_icms_inter       IS 'Alíquota interestadual do ICMS.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.p_icms_inter_part  IS 'Percentual provisório de partilha do ICMS interestadual.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.v_icms_uf_dest     IS 'Valor do ICMS de competência da UF de destino.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.v_icms_uf_remet    IS 'Valor do ICMS de competência da UF remetente.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.v_fcp_uf_dest      IS 'Valor do FCP da UF de destino (NA13 vFCPUFDest).';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.ch_nf              IS 'Chave de acesso da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.num_item           IS 'Número do item da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.v_bc_uf_dest       IS 'Valor da base de cálculo do ICMS na UF de destino (NA03 vBCUFDest).';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.p_fcp_uf_dest      IS 'Percentual do FCP na UF de destino (NA05 pFCPUFDest). Máximo 2%%.';
COMMENT ON COLUMN nota_fiscal.na01_icms_uf_dest.p_icms_uf_dest     IS 'Aliqüota interna da UF de destino para o produto, sem incluir FCP (NA07 pICMSUFDest).';

-- IPI por item
CREATE TABLE nota_fiscal.o01_ipi (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    v_bc                NUMERIC(15,2),
    p_ipi               NUMERIC(5,2),
    q_unid              NUMERIC(16,4),
    v_unid              NUMERIC(15,4),
    v_ipi               NUMERIC(15,2),
    cl_enq              VARCHAR(5),
    cnpj_prod           VARCHAR(14),
    c_selo              VARCHAR(60),
    q_selo              VARCHAR(12),
    c_enq               VARCHAR(3),

    CONSTRAINT o01_ipi_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_o01_ipi_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.o01_ipi OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.o01_ipi IS 'IPI (Imposto sobre Produtos Industrializados) por item. Grupo O01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.o01_ipi.c_enq   IS 'Código de enquadramento legal do IPI (3 dígitos).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.p_ipi   IS 'Alíquota do IPI (%%).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.v_ipi   IS 'Valor do IPI.';
COMMENT ON COLUMN nota_fiscal.o01_ipi.v_bc    IS 'Base de cálculo do IPI.';
COMMENT ON COLUMN nota_fiscal.o01_ipi.ch_nf    IS 'Chave de acesso da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.o01_ipi.num_item IS 'Número do item da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.o01_ipi.cl_enq   IS 'Classe de enquadramento do IPI para cigarros e bebidas (O02 clEnq — excluído no leiaute 4.0 NT2016.002).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.cnpj_prod IS 'CNPJ do produtor da mercadoria quando diferente do emitente, somente exportação direta ou indireta (O03 CNPJProd).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.c_selo   IS 'Código do selo de controle IPI conforme Anexo II-A da IN RFB 770/2007 (O04 cSelo).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.q_selo   IS 'Quantidade de selos de controle IPI (O05 qSelo).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.q_unid   IS 'Quantidade total na unidade padrão de tributação — somente para IPI calculado por unidade (O11 qUnid).';
COMMENT ON COLUMN nota_fiscal.o01_ipi.v_unid   IS 'Valor por unidade tributável — somente para IPI calculado por unidade (O12 vUnid).';

-- Imposto de Importação por item
CREATE TABLE nota_fiscal.p01_ii (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    v_bc                NUMERIC(15,2),
    v_desp_adu          NUMERIC(15,2),
    v_ii                NUMERIC(15,2),
    v_iof               NUMERIC(15,2),

    CONSTRAINT p01_ii_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_p01_ii_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.p01_ii OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.p01_ii IS 'Imposto de Importação por item. Grupo P01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.p01_ii.v_bc       IS 'Base de cálculo do II.';
COMMENT ON COLUMN nota_fiscal.p01_ii.v_desp_adu IS 'Valor das despesas aduaneiras.';
COMMENT ON COLUMN nota_fiscal.p01_ii.v_ii       IS 'Valor do Imposto de Importação.';
COMMENT ON COLUMN nota_fiscal.p01_ii.v_iof      IS 'Valor do Imposto sobre Operações Financeiras.';

-- PIS e COFINS por item
CREATE TABLE nota_fiscal.q01_pis_s01_cofins (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    cst_pis             VARCHAR(2),
    quant_bc_pis        NUMERIC(16,4),
    aliq_pis_quant      NUMERIC(15,4),
    v_bc_pis            NUMERIC(15,2),
    aliq_pis            NUMERIC(5,2),
    v_pis               NUMERIC(15,2),
    cst_cofins          VARCHAR(2),
    quant_bc_cofins     NUMERIC(16,4),
    aliq_cofins_quant   NUMERIC(15,4),
    v_bc_cofins         NUMERIC(15,2),
    aliq_cofins         NUMERIC(5,2),
    v_cofins            NUMERIC(15,2),

    CONSTRAINT q01_pis_s01_cofins_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_q01_pis_s01_cofins_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.q01_pis_s01_cofins OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.q01_pis_s01_cofins IS 'PIS e COFINS por item da NF-e. Grupos Q01 e S01 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.cst_pis           IS 'Código de Situação Tributária do PIS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.cst_cofins        IS 'Código de Situação Tributária da COFINS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.v_bc_pis          IS 'Base de cálculo do PIS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.v_pis             IS 'Valor do PIS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.v_bc_cofins       IS 'Base de cálculo da COFINS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.v_cofins          IS 'Valor da COFINS.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.aliq_pis          IS 'Alíquota do PIS (%%).';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.aliq_cofins       IS 'Alíquota da COFINS (%%).';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.ch_nf              IS 'Chave de acesso da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.num_item           IS 'Número do item da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.quant_bc_pis       IS 'Quantidade vendida para cálculo do PIS por quantidade — somente CST 03 (Q10 qBCProd).';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.aliq_pis_quant     IS 'Alíquota do PIS em reais por unidade — somente para cálculo por quantidade (Q11 vAliqProd).';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.quant_bc_cofins    IS 'Quantidade vendida para cálculo da COFINS por quantidade — somente CST 03 (S09 qBCProd).';
COMMENT ON COLUMN nota_fiscal.q01_pis_s01_cofins.aliq_cofins_quant  IS 'Alíquota da COFINS em reais por unidade — somente para cálculo por quantidade (S10 vAliqProd).';

-- Imposto devolvido / IPI devolução
CREATE TABLE nota_fiscal.ua01_imposto_devol_ua03_ipi (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    p_devol             NUMERIC(5,2),
    v_ipi_devol         NUMERIC(15,2),

    CONSTRAINT ua01_imposto_devol_ua03_ipi_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_ua01_imposto_devol_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ua01_imposto_devol_ua03_ipi OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.ua01_imposto_devol_ua03_ipi IS 'Imposto devolvido em operações de devolução e IPI devolução. Grupos UA01/UA03 do leiaute NF-e.';
COMMENT ON COLUMN nota_fiscal.ua01_imposto_devol_ua03_ipi.p_devol    IS 'Percentual da mercadoria devolvida.';
COMMENT ON COLUMN nota_fiscal.ua01_imposto_devol_ua03_ipi.v_ipi_devol IS 'Valor do IPI devolvido.';

-- IBS / CBS — Reforma Tributária (LC 214/2025)
CREATE TABLE nota_fiscal.ub12_ibs_cbs (
    ch_nf                           VARCHAR(44)     NOT NULL,
    num_item                        VARCHAR(3)      NOT NULL,
    cst                             VARCHAR(3)      NOT NULL,
    c_class_trib                    VARCHAR(6)      NOT NULL,
    ind_doacao                      VARCHAR(1),
    v_bc                            NUMERIC(15,2)   NOT NULL,
    p_ibs_uf                        NUMERIC(15,4)   NOT NULL,
    p_dif_ibs                       NUMERIC(15,4),
    v_dif_ibs                       NUMERIC(15,2),
    v_dev_trib_ibs                  NUMERIC(15,2),
    p_red_aliq_ibs                  NUMERIC(15,4),
    p_aliq_efet_ibs                 NUMERIC(15,4),
    v_ibs_uf                        NUMERIC(15,2)   NOT NULL,
    p_ibs_mun                       NUMERIC(15,4)   NOT NULL,
    p_dif_ibs_mun                   NUMERIC(15,4),
    v_dif_ibs_mun                   NUMERIC(15,2),
    v_dev_trib_ibs_mun              NUMERIC(15,2),
    p_red_aliq_ibs_mun              NUMERIC(15,4),
    p_aliq_efet_ibs_mun             NUMERIC(15,4),
    v_ibs_mun                       NUMERIC(15,2)   NOT NULL,
    v_ibs                           NUMERIC(15,2)   NOT NULL,
    p_cbs                           NUMERIC(15,4)   NOT NULL,
    p_dif_cbs                       NUMERIC(15,4),
    v_dif_cbs                       NUMERIC(15,2),
    v_dev_trib_cbs                  NUMERIC(15,2),
    p_red_aliq_cbs                  NUMERIC(15,2),
    p_aliq_efet_cbs                 NUMERIC(15,4),
    v_cbs                           NUMERIC(15,2)   NOT NULL,
    cst_reg                         VARCHAR(3),
    c_class_trib_reg                VARCHAR(6),
    p_aliq_efet_reg_ibs_uf          NUMERIC(15,4),
    v_trib_reg_ibs_uf               NUMERIC(15,2),
    p_aliq_efet_reg_ibs_mun         NUMERIC(15,4),
    v_trib_reg_ibs_mun              NUMERIC(15,2),
    p_aliq_efet_reg_cbs             NUMERIC(15,4),
    v_trib_reg_cbs                  NUMERIC(15,2),
    p_aliq_ibs_uf                   NUMERIC(15,4),
    v_trib_ibs_uf                   NUMERIC(15,2),
    p_aliq_ibs_mun                  NUMERIC(15,4),
    v_trib_ibs_mun                  NUMERIC(15,2),
    p_aliq_cbs                      NUMERIC(15,4),
    v_trib_cbs                      NUMERIC(15,2),
    q_bc_mono                       NUMERIC(15,4),
    ad_rem_ibs                      NUMERIC(15,4),
    ad_rem_cbs                      NUMERIC(15,4),
    v_ibs_mono                      NUMERIC(15,2),
    v_cbs_mono                      NUMERIC(15,2),
    q_bc_mono_reten                 NUMERIC(15,4),
    ad_rem_ibs_reten                NUMERIC(15,4),
    v_ibs_mono_reten                NUMERIC(15,2),
    ad_rem_cbs_reten                NUMERIC(15,4),
    v_cbs_mono_reten                NUMERIC(15,2),
    q_bc_mono_ret                   NUMERIC(15,4),
    ad_rem_ibs_ret                  NUMERIC(15,4),
    v_ibs_mono_ret                  NUMERIC(15,2),
    ad_rem_cbs_ret                  NUMERIC(15,4),
    v_cbs_mono_ret                  NUMERIC(15,2),
    p_dif_ibs_mono                  NUMERIC(15,4),
    v_ibs_mono_dif                  NUMERIC(15,2),
    p_dif_cbs_mono                  NUMERIC(15,4),
    v_cbs_mono_dif                  NUMERIC(15,2),
    v_tot_ibs_mono_item             NUMERIC(15,2),
    v_tot_cbs_mono_item             NUMERIC(15,2),
    v_ibs_trans_cred                NUMERIC(15,2),
    v_cbs_trans_cred                NUMERIC(15,2),
    compet_apur_ajuste_compet       VARCHAR(7),
    v_ibs_ajuste_compet             NUMERIC(15,2),
    v_cbs_ajuste_compet             NUMERIC(15,2),
    v_ibs_est_cred                  NUMERIC(15,2),
    v_cbs_est_cred                  NUMERIC(15,2),
    v_bc_cred_pres                  NUMERIC(15,2),
    c_cred_pres                     VARCHAR(2),
    p_cred_pres_ibs                 NUMERIC(15,4),
    v_cred_pres_ibs                 NUMERIC(15,2),
    v_cred_pres_cond_sus_ibs        NUMERIC(15,2),
    p_cred_pres_cbs                 NUMERIC(15,4),
    v_cred_pres_cbs                 NUMERIC(15,2),
    v_cred_pres_cond_sus_cbs        NUMERIC(15,2),
    compet_apur_ibs_zfm             VARCHAR(7),
    tp_cred_pres_ibs_zfm            VARCHAR(1),
    v_cred_pres_ibs_zfm             NUMERIC(15,2),

    CONSTRAINT ub12_ibs_cbs_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_ub12_ibs_cbs_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ub12_ibs_cbs OWNER TO dorcilio;

COMMENT ON TABLE nota_fiscal.ub12_ibs_cbs IS 'IBS (Imposto sobre Bens e Serviços) e CBS (Contribuição sobre Bens e Serviços) — Reforma Tributária LC 214/2025.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ch_nf                       IS 'Chave de acesso da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.num_item                    IS 'Número do item da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.cst                         IS 'Código de Situação Tributária do IBS e CBS, 3 dígitos (UB13 CST — tabela CST IBS/CBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.c_class_trib                IS 'Código de Classificação Tributária do IBS e CBS, 6 dígitos (UB14 cClassTrib).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ind_doacao                  IS 'Indica doação: "1"=Doação. Orienta a apuração e geração de débitos ou estornos conforme o cenário (UB14a indDoacao).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_bc                        IS 'Base de cálculo do IBS e CBS (UB16 vBC).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_ibs_uf                    IS 'Alíquota vigente do IBS de competência da UF, em percentual (UB18 pIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_dif_ibs                   IS 'Percentual do diferimento do IBS UF (UB22 pDif). Condicionado ao indicador ind_gDif da tabela CST IBS/CBS.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dif_ibs                   IS 'Valor do diferimento do IBS UF (UB23 vDif).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dev_trib_ibs              IS 'Valor do IBS UF devolvido (cashback) no fornecimento de energia elétrica, água, esgoto, gás natural, etc. (UB25 vDevTrib).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_red_aliq_ibs              IS 'Percentual de redução de alíquota do IBS UF conforme cClassTrib (UB27 pRedAliq). Condicionado ao ind_gRed.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_ibs             IS 'Alíquota efetiva do IBS UF após redução, incluindo gCompraGov/pRedutor quando houver (UB28 pAliqEfet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_uf                    IS 'Valor do IBS de competência da UF (UB35 vIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_ibs_mun                   IS 'Alíquota vigente do IBS de competência do Município, em percentual (UB37 pIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_dif_ibs_mun               IS 'Percentual do diferimento do IBS Município (UB41 pDif). Condicionado ao indicador ind_gDif.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dif_ibs_mun               IS 'Valor do diferimento do IBS Município (UB42 vDif).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dev_trib_ibs_mun          IS 'Valor do IBS Município devolvido (cashback) no fornecimento de energia elétrica, água, esgoto, gás natural, etc. (UB44 vDevTrib).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_red_aliq_ibs_mun          IS 'Percentual de redução de alíquota do IBS Município conforme cClassTrib (UB46 pRedAliq). Condicionado ao ind_gRed.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_ibs_mun         IS 'Alíquota efetiva do IBS Município após redução, incluindo gCompraGov/pRedutor quando houver (UB47 pAliqEfet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_mun                   IS 'Valor do IBS de competência do Município (UB54 vIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs                       IS 'Valor total do IBS = vIBSUF + vIBSMun. Quando houver crédito presumido com IndDeduzCredPres=1, o vCredPres deve ser abatido (UB54a vIBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_cbs                       IS 'Alíquota vigente da CBS, em percentual (UB56 pCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_dif_cbs                   IS 'Percentual do diferimento da CBS (UB60 pDif). Condicionado ao indicador ind_gDif.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dif_cbs                   IS 'Valor do diferimento da CBS (UB61 vDif).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_dev_trib_cbs              IS 'Valor da CBS devolvida (cashback) no fornecimento de energia elétrica, água, esgoto, gás natural, etc. (UB63 vDevTrib).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_red_aliq_cbs              IS 'Percentual de redução de alíquota da CBS conforme cClassTrib (UB65 pRedAliq). Condicionado ao ind_gRed.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_cbs             IS 'Alíquota efetiva da CBS após redução, incluindo gCompraGov/pRedutor quando houver (UB66 pAliqEfet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs                       IS 'Valor da CBS (UB67 vCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.cst_reg                     IS 'CST do IBS/CBS para tributação regular — como seria tributado sem condição resolutória/suspensiva (UB69 CSTReg). Condicionado ao ind_gTribRegular.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.c_class_trib_reg            IS 'Código de classificação tributária para tributação regular, ex.: ZFM, suspensão (UB70 cClassTribReg).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_reg_ibs_uf     IS 'Alíquota efetiva do IBS UF na tributação regular (UB71 pAliqEfetRegIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_reg_ibs_uf          IS 'Valor do IBS UF na tributação regular (UB72 vTribRegIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_reg_ibs_mun    IS 'Alíquota efetiva do IBS Município na tributação regular (UB72a pAliqEfetRegIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_reg_ibs_mun         IS 'Valor do IBS Município na tributação regular (UB72b vTribRegIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_efet_reg_cbs        IS 'Alíquota efetiva da CBS na tributação regular (UB72c pAliqEfetRegCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_reg_cbs             IS 'Valor da CBS na tributação regular (UB72d vTribRegCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_ibs_uf              IS 'Alíquota do IBS UF no cálculo de compra governamental, sem aplicação do Art. 473 LC 214/2025 (UB82b pAliqIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_ibs_uf              IS 'Valor do IBS UF calculado em compra governamental sem aplicação do Art. 473 LC 214/2025 (UB82c vTribIBSUF).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_ibs_mun             IS 'Alíquota do IBS Município no cálculo de compra governamental, sem aplicação do Art. 473 LC 214/2025 (UB82d pAliqIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_ibs_mun             IS 'Valor do IBS Município calculado em compra governamental sem aplicação do Art. 473 LC 214/2025 (UB82e vTribIBSMun).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_aliq_cbs                 IS 'Alíquota da CBS no cálculo de compra governamental, sem aplicação do Art. 473 LC 214/2025 (UB82f pAliqCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_trib_cbs                 IS 'Valor da CBS calculada em compra governamental sem aplicação do Art. 473 LC 214/2025 (UB82g vTribCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.q_bc_mono                  IS 'Quantidade tributada na monofasia IBS/CBS conforme unidade de medida definida na legislação (UB85 qBCMono).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_ibs                 IS 'Alíquota ad rem do IBS na tributação monofásica padrão (UB86 adRemIBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_cbs                 IS 'Alíquota ad rem da CBS na tributação monofásica padrão (UB87 adRemCBS).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_mono                 IS 'Valor do IBS monofásico = adRemIBS × qBCMono (UB88 vIBSMono).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_mono                 IS 'Valor da CBS monofásica = adRemCBS × qBCMono (UB89 vCBSMono).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.q_bc_mono_reten            IS 'Quantidade sujeita à retenção na monofasia (UB91 qBCMonoReten). Uso em combustíveis — art. 178 LC 214/2025.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_ibs_reten           IS 'Alíquota ad rem do IBS sujeito à retenção na monofasia (UB92 adRemIBSReten).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_mono_reten           IS 'Valor do IBS monofásico sujeito à retenção, a somar ao IBS a recolher (UB93 vIBSMonoReten).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_cbs_reten           IS 'Alíquota ad rem da CBS sujeita à retenção na monofasia (UB93a adRemCBSReten).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_mono_reten           IS 'Valor da CBS monofásica sujeita à retenção, a somar à CBS a recolher (UB93b vCBSMonoReten).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.q_bc_mono_ret              IS 'Quantidade tributada retida anteriormente na monofasia — tributação própria cobrada anteriormente (UB95 qBCMonoRet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_ibs_ret             IS 'Alíquota ad rem do IBS retido anteriormente na monofasia (UB96 adRemIBSRet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_mono_ret             IS 'Valor do IBS monofásico retido anteriormente (UB97 vIBSMonoRet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.ad_rem_cbs_ret             IS 'Alíquota ad rem da CBS retida anteriormente na monofasia (UB98 adRemCBSRet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_mono_ret             IS 'Valor da CBS monofásica retida anteriormente (UB98a vCBSMonoRet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_dif_ibs_mono             IS 'Percentual do diferimento do IBS monofásico aplicado sobre vIBSMono (UB100 pDifIBS). Uso em operações com biocombustíveis.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_mono_dif             IS 'Valor do IBS monofásico diferido, a deduzir do valor total do IBS (UB101 vIBSMonoDif).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_dif_cbs_mono             IS 'Percentual do diferimento da CBS monofásica aplicado sobre vCBSMono (UB102 pDifCBS). Uso em operações com biocombustíveis.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_mono_dif             IS 'Valor da CBS monofásica diferida, a deduzir do valor total da CBS (UB103 vCBSMonoDif).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_tot_ibs_mono_item        IS 'Total do IBS monofásico do item (UB104 vTotIBSMonoItem).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_tot_cbs_mono_item        IS 'Total da CBS monofásica do item (UB105 vTotCBSMonoItem).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_trans_cred           IS 'Valor do IBS a ser transferido via crédito (UB107 vIBS — grupo gTransfCred).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_trans_cred           IS 'Valor da CBS a ser transferida via crédito (UB108 vCBS — grupo gTransfCred).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.compet_apur_ajuste_compet  IS 'Período de apuração AAAA-MM para ajuste de competência atual ou retroativo (UB113 competApur — grupo gAjusteCompet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_ajuste_compet        IS 'Valor do IBS para o período de ajuste de competência indicado (UB114 vIBS — grupo gAjusteCompet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_ajuste_compet        IS 'Valor da CBS para o período de ajuste de competência indicado (UB115 vCBS — grupo gAjusteCompet).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_ibs_est_cred             IS 'Valor do IBS a ser estornado (UB117 vIBSEstCred — grupo gEstornoCred). Condicionado ao ind_gEstornoCred.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cbs_est_cred             IS 'Valor da CBS a ser estornada (UB118 vCBSEstCred — grupo gEstornoCred).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_bc_cred_pres             IS 'Valor da base de cálculo do crédito presumido da operação (UB121 vBCCredPres — grupo gCredPresOper).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.c_cred_pres                IS 'Código de classificação do crédito presumido (UB122 cCredPres): 1=Prod. Rural não contrib., 2=TAC PF, 3=Reciclagem, 4=Bem móvel PF, 5=Cooperativa.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_cred_pres_ibs            IS 'Percentual do crédito presumido referente ao IBS (UB124 pCredPres — grupo gIBSCredPres).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cred_pres_ibs            IS 'Valor do crédito presumido de IBS aproveitado pelo emitente (UB125 vCredPres).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cred_pres_cond_sus_ibs   IS 'Valor do crédito presumido de IBS em condição suspensiva (UB126 vCredPresCondSus). Preencher somente para cCredPres com condição suspensiva.';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.p_cred_pres_cbs            IS 'Percentual do crédito presumido referente à CBS (UB128 pCredPres — grupo gCBSCredPres).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cred_pres_cbs            IS 'Valor do crédito presumido de CBS aproveitado pelo emitente (UB129 vCredPres).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cred_pres_cond_sus_cbs   IS 'Valor do crédito presumido de CBS em condição suspensiva (UB130 vCredPresCondSus).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.compet_apur_ibs_zfm        IS 'Período de apuração AAAA-MM para crédito presumido IBS na ZFM, art. 450 §1º LC 214/25 (UB132 competApur — grupo gCredPresIBSZFM).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.tp_cred_pres_ibs_zfm       IS 'Tipo de classificação para crédito presumido ZFM: 0=Sem, 1=Consumo final 55%%, 2=Capital 75%%, 3=Intermediários 90,25%%, 4=Informática 100%% (UB133 tpCredPresIBSZFM).';
COMMENT ON COLUMN nota_fiscal.ub12_ibs_cbs.v_cred_pres_ibs_zfm        IS 'Valor do crédito presumido de IBS calculado sobre o saldo devedor apurado na ZFM (UB134 vCredPresIBSZFM).';

-- IS — Imposto Seletivo (Reforma Tributária LC 214/2025)
CREATE TABLE nota_fiscal.ub01_is (
    ch_nf               VARCHAR(44)             NOT NULL,
    num_item            VARCHAR(3)              NOT NULL,
    cst_is              VARCHAR(3)              NOT NULL,
    c_class_trib_is     VARCHAR(6)              NOT NULL,
    v_bc_is             NUMERIC(15,2)           NOT NULL,
    p_is                NUMERIC(15,4)           NOT NULL,
    p_is_espec          NUMERIC(15,4),
    u_trib              VARCHAR(6)              NOT NULL,
    q_trib              NUMERIC(15,4)           NOT NULL,
    v_is                NUMERIC(15,2)           NOT NULL,

    CONSTRAINT ub01_is_pkey PRIMARY KEY (ch_nf, num_item),
    CONSTRAINT fk_ub01_is_i01_prod FOREIGN KEY (ch_nf, num_item)
        REFERENCES nota_fiscal.i01_prod (ch_nf, num_item)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ub01_is OWNER TO dorcilio;

COMMENT ON TABLE nota_fiscal.ub01_is IS 'Imposto Seletivo (IS) — Reforma Tributária LC 214/2025.';
COMMENT ON COLUMN nota_fiscal.ub01_is.ch_nf           IS 'Chave de acesso da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.ub01_is.num_item         IS 'Número do item da NF-e. Parte da PK composta e FK para i01_prod.';
COMMENT ON COLUMN nota_fiscal.ub01_is.cst_is           IS 'Código de Situação Tributária do Imposto Seletivo, 3 dígitos (UB02 CSTIS — tabela CST IS).';
COMMENT ON COLUMN nota_fiscal.ub01_is.c_class_trib_is  IS 'Código de Classificação Tributária do Imposto Seletivo, 6 dígitos (UB03 cClassTribIS).';
COMMENT ON COLUMN nota_fiscal.ub01_is.v_bc_is          IS 'Valor da base de cálculo do Imposto Seletivo (UB05 vBCIS).';
COMMENT ON COLUMN nota_fiscal.ub01_is.p_is             IS 'Alíquota do Imposto Seletivo em percentual (UB06 pIS).';
COMMENT ON COLUMN nota_fiscal.ub01_is.p_is_espec       IS 'Alíquota específica por unidade de medida apropriada do IS, em percentual (UB07 pISEspec). Opcional.';
COMMENT ON COLUMN nota_fiscal.ub01_is.u_trib           IS 'Unidade de medida tributável do IS, 1 a 6 caracteres (UB09 uTrib).';
COMMENT ON COLUMN nota_fiscal.ub01_is.q_trib           IS 'Quantidade tributável do IS na unidade de medida definida na legislação (UB10 qTrib).';
COMMENT ON COLUMN nota_fiscal.ub01_is.v_is             IS 'Valor do Imposto Seletivo (UB11 vIS).';

-- =============================================================================
-- NÍVEL 3: FILHA DE ya01a_det_pag — Cartão de pagamento
-- Hierarquia completa: b01_ide → ya01_pag → ya01a_det_pag → ya04_card
-- =============================================================================

CREATE TABLE nota_fiscal.ya04_card (
    id_card             BIGINT                  GENERATED ALWAYS AS IDENTITY,
    id_det_pag          BIGINT                  NOT NULL,
    ch_nf               VARCHAR(44)             NOT NULL,
    tp_integra          INTEGER                 NOT NULL,
    cnpj                VARCHAR(14),
    t_band              VARCHAR(2),
    c_aut               VARCHAR(128),
    cnpj_receb          VARCHAR(14),
    id_term_pag         VARCHAR(40),

    CONSTRAINT ya04_card_pkey PRIMARY KEY (id_card),
    CONSTRAINT fk_ya04_card_ya01a_det_pag FOREIGN KEY (id_det_pag)
        REFERENCES nota_fiscal.ya01a_det_pag (id_det_pag)
        ON DELETE CASCADE,
    CONSTRAINT fk_ya04_card_b01_ide FOREIGN KEY (ch_nf)
        REFERENCES nota_fiscal.b01_ide (ch_nf)
        ON DELETE CASCADE
);

ALTER TABLE nota_fiscal.ya04_card OWNER TO dorcilio;
COMMENT ON TABLE nota_fiscal.ya04_card IS 'Dados de cartão de crédito/débito do pagamento. Grupo YA04 do leiaute NF-e. Filho de ya01a_det_pag. Surrogate BIGINT.';
COMMENT ON COLUMN nota_fiscal.ya04_card.id_card     IS 'Chave surrogate gerada automaticamente (BIGINT IDENTITY).';
COMMENT ON COLUMN nota_fiscal.ya04_card.id_det_pag  IS 'FK para ya01a_det_pag(id_det_pag). Mantém a hierarquia XML: detPag → card.';
COMMENT ON COLUMN nota_fiscal.ya04_card.ch_nf       IS 'Chave de acesso da NF-e. Desnormalizado de ya01a_det_pag para consulta direta por NF-e sem JOINs.';
COMMENT ON COLUMN nota_fiscal.ya04_card.tp_integra  IS 'Tipo de integração: 1=Integrado ao sistema de pagamento, 2=Não Integrado.';
COMMENT ON COLUMN nota_fiscal.ya04_card.t_band      IS 'Bandeira do cartão: 01=Visa, 02=Mastercard, 03=Amex, 04=Sorocred, etc.';
COMMENT ON COLUMN nota_fiscal.ya04_card.c_aut       IS 'Número de autorização da operação de cartão.';
COMMENT ON COLUMN nota_fiscal.ya04_card.cnpj_receb  IS 'CNPJ da credenciadora/administradora do cartão.';
COMMENT ON COLUMN nota_fiscal.ya04_card.id_term_pag IS 'Identificação do terminal de pagamento (POS).';
COMMENT ON COLUMN nota_fiscal.ya04_card.cnpj        IS 'CNPJ da instituição de pagamento, adquirente ou subadquirente. Se processado por intermediador, informar CNPJ deste (YA05 CNPJ — NT 2020.006).';

CREATE INDEX idx_ya04_card_id_det_pag ON nota_fiscal.ya04_card (id_det_pag);
CREATE INDEX idx_ya04_card_ch_nf      ON nota_fiscal.ya04_card (ch_nf);