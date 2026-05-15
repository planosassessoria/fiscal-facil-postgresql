---
applyTo: "**/*.sql"
description: "Guia completo de boas práticas de DBA e desenvolvimento para o sistema Fiscal Fácil"
---

# 🧩 Fiscal Fácil - PostgreSQL Database Guidelines

## Contexto do Projeto

O **Fiscal Fácil** é um sistema de gestão fiscal e contábil robusto. O banco de dados PostgreSQL é o coração do projeto e deve priorizar:

- ✅ **Integridade dos dados** - Consistência através de constraints e validações
- ✅ **Performance otimizada** - Consultas rápidas e indexação estratégica  
- ✅ **Rastreabilidade completa** - Auditoria e histórico de mudanças
- ✅ **Escalabilidade** - Preparado para crescimento de volume de dados

---

## � Nomenclatura de Arquivos SQL

### Padrão geral para `scripts-backend/`

```
{operação}-{entidade}-{complemento}.sql
```

#### Operações disponíveis

| Prefixo  | Uso                                                           |
|----------|---------------------------------------------------------------|
| `insert` | Criação de um novo registro                                   |
| `select` | Consulta/leitura de dados                                     |
| `update` | Atualização de dados existentes                               |
| `delete` | Remoção de registros (hard delete)                            |
| `upsert` | Inserção ou atualização condicional (`ON CONFLICT DO UPDATE`) |

#### Entidade

Nome do recurso principal, sempre no singular e em `kebab-case`:
`user`, `session`, `establishment`, `tax-entity`, `module`, `permission`, `role`

#### Complemento (opcional)

Descreve filtro ou contexto da operação, termos unidos por hífen:
`by-id`, `by-email`, `by-tenant-id`, `by-document`, `with-roles`, `with-tenant`, `email-confirmed`, `password`, `profile`

#### Exemplos

```
✅ Correto                          ❌ Incorreto
insert-user.sql                     getUser.sql            (camelCase)
insert-user-tenant.sql              user_select.sql        (operação deve vir primeiro)
select-user-by-email.sql            select_user_email.sql  (usar hífen, não underscore)
select-users-by-tenant-id.sql       selectUserByEmail.sql  (camelCase)
select-full-user-with-tenant.sql    userData.sql           (sem operação definida)
update-user-password.sql
update-user-email-confirmed.sql
delete-session-by-session-id.sql
upsert-establishment-address.sql
```

### Subdiretórios de `scripts-backend/`

Cada subdiretório corresponde a um domínio/schema. Nome em `kebab-case`:

```
scripts-backend/
├── account/       → schema account (IAM)
├── partner/       → schema partner (estabelecimentos)
├── history/       → schema history (eventos)
├── common/        → utilitários sem schema fixo
└── nfe/           → schema nfe (notas fiscais)
```

### Arquivos de schema e funções complexas (raiz e `functions/`)

| Tipo                    | Padrão                                    | Exemplo                                              |
|-------------------------|--------------------------------------------|-------------------------------------------------|
| Schema completo         | `schema_{nome}.sql`                        | `schema_partner.sql`                                 |
| Função de processamento | `{schema}.fn_{verbo}_{descricao}.sql`      | `xml.fn_validate_and_store_xml.sql`                  |
| Função de trigger       | `{schema}.fn_{acao}_{entidade}.sql`        | `partner.fn_refresh_establishment_fts.sql`           |

---

## ⚠️ Padrões de Nomenclatura

### Resumo Rápido

| Elemento        | Padrão                          | Exemplo                          |
|-----------------|---------------------------------|----------------------------------|
| Tabela          | `snake_case` plural             | `establishments`, `tax_entities` |
| Coluna          | `snake_case` singular           | `created_at`, `cnpj_number`      |
| PK (exposta)    | `UUID` + `gen_random_uuid()`    | `est_id`, `user_id`              |
| PK (interna)    | `BIGINT GENERATED AS IDENTITY`  | `xml_id`, `id_nf_ref`            |
| ID              | Sempre com prefixo descritivo   | `est_id` (nunca apenas `id`)     |
| Campo comum     | Prefixo da entidade             | `est_description`, `est_fts`     |
| Constraint UK   | `uk_[tabela]_[colunas]`         | `uk_establishments_cnpj`         |
| Constraint FK   | `fk_[tabela]_[referencia]`      | `fk_establishments_address`      |
| Constraint CK   | `ck_[tabela]_[regra]`           | `ck_establishments_cnpj_valid`   |
| Termo fiscal BR | Português aceito (ver exceções) | `razao_social`, `fantasia`       |

### Schemas e Objetos
```sql
-- ✅ Schemas lógicos por domínio
CREATE SCHEMA IF NOT EXISTS account;    -- Gestão de contas e usuários
CREATE SCHEMA IF NOT EXISTS partner;    -- Gestão de parceiros e estabelecimentos
CREATE SCHEMA IF NOT EXISTS history;    -- Histórico e logs (audit trail)
CREATE SCHEMA IF NOT EXISTS billing;    -- Faturamento
CREATE SCHEMA IF NOT EXISTS config;     -- Configurações
CREATE SCHEMA IF NOT EXISTS audit;      -- Auditoria
```

### Convenções de Nomes
- **Tabelas**: `snake_case` no plural (ex: `establishments`, `tax_entities`)
- **Colunas**: `snake_case` no singular (ex: `created_at`, `cnpj_number`)
- **Chaves Primárias (tabelas expostas ao frontend)**: `UUID` com `gen_random_uuid()` — para tabelas cujo ID aparece em APIs, URLs ou no frontend (ex: `account`, `partner`)
- **Chaves Primárias (tabelas internas)**: `BIGINT GENERATED ALWAYS AS IDENTITY` ou `BIGSERIAL` — para tabelas cujo ID é apenas referência interna no banco, sem exposição externa (ex: `nota_fiscal`, `xml`). Menor custo de armazenamento e melhor performance em JOINs de alto volume.
- **IDs**: NUNCA usar apenas `id` - sempre com prefixo descritivo:
  - ✅ `est_id`, `establishment_id`, `xml_id`, `user_id`
  - ❌ `id` (genérico demais)
- **Campos Comuns**: Usar prefixo para evitar ambiguidade:
  - ✅ `est_description`, `user_description`, `tax_description`
  - ❌ `description` (muito genérico)
- **Campos FTS**: Sempre com sufixo padronizado:
  - ✅ `est_fts`, `establishment_fts`, `user_fts`, `partner_fts`
  - ❌ `search_vector` (genérico demais)
- **Constraints**:
  - Unique: `uk_[tabela]_[colunas]`
  - Foreign Key: `fk_[tabela]_[referencia]`
  - Check: `ck_[tabela]_[regra]`

### ⚠️ Exceção: Nomenclatura Fiscal Brasileira
Para campos **específicos do contexto fiscal brasileiro**, é aceitável manter nomenclatura em português por serem termos consagrados na área:

```sql
-- ✅ Aceitável para contexto fiscal brasileiro
CREATE TABLE partner.establishments (
    est_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document VARCHAR(14) NOT NULL,        -- OK: termo neutro
    razao_social VARCHAR(255) NOT NULL,   -- OK: termo fiscal consagrado
    fantasia VARCHAR(115),                -- OK: termo fiscal consagrado  
    telefone VARCHAR(11),                 -- OK: amplamente conhecido
    situacao TEXT,                        -- OK: status fiscal específico
    -- Mas ainda recomende melhorias quando possível:
    est_email VARCHAR(320),               -- MELHOR: mantém padrão de prefixo
    est_fts TSVECTOR                      -- OBRIGATÓRIO: sempre com prefixo
);
```

**Termos fiscais aceitáveis em português:**
- `razao_social`, `fantasia`, `situacao`, `telefone`, `endereco`
- `cnae`, `cnpj`, `cpf`, `ie` (siglas oficiais)
- `d_emi`, `d_venc`, `v_prod` (padrão SPED)

**Ainda aplicar prefixos em campos comuns:**
- ✅ `est_fts`, `est_description`, `est_status` (quando não fiscal)
- ❌ `fts`, `description`, `status` (muito genéricos)

```sql
-- ✅ Exemplo de constraint bem nomeada
ALTER TABLE partner.establishments 
ADD CONSTRAINT uk_establishments_cnpj_ie UNIQUE (cnpj_number, state_registration),
ADD CONSTRAINT fk_establishments_address FOREIGN KEY (address_id) REFERENCES partner.addresses(address_id),
ADD CONSTRAINT ck_establishments_cnpj_valid CHECK (length(cnpj_number) = 14);
```

---

## 🏗 Arquitetura de Tabelas

### Ordem Padrão de Colunas
```sql
-- Tabela exposta ao frontend (UUID)
CREATE TABLE schema.exemplo_tabela (
    -- 1. CHAVES
    exemplo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL,
    ...
);

-- Tabela interna/não exposta (BIGINT)
CREATE TABLE schema.exemplo_tabela_interna (
    -- 1. CHAVES
    exemplo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT NOT NULL,
    ...
);

-- Ordem geral de colunas (aplicável a ambos os tipos):
CREATE TABLE schema.exemplo (
    -- 1. CHAVES (UUID ou BIGINT conforme contexto)
    exemplo_id ... PRIMARY KEY,
    parent_id ...,
    
    -- 2. DADOS OBRIGATÓRIOS  
    exemplo_nome VARCHAR(100) NOT NULL,
    exemplo_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    
    -- 3. DADOS OPCIONAIS
    exemplo_description TEXT,
    exemplo_observations VARCHAR(500),
    
    -- 4. METADADOS DE BUSCA
    exemplo_fts TSVECTOR,
    
    -- 5. TIMESTAMPS (sempre por último)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Triggers Obrigatórios
```sql
-- Trigger para atualizar timestamp automaticamente
CREATE TRIGGER tr_upd_exemplo_tabela
    BEFORE UPDATE ON schema.exemplo_tabela
    FOR each ROW 
    EXECUTE FUNCTION fn_refresh_timestamp();
```

---

## 🔄 Estratégias de Atualização

### Patch Parcial com COALESCE
```sql
-- ✅ Permite atualizações parciais sem sobrescrever dados
UPDATE partner.establishments 
SET 
    est_name = COALESCE(:est_name, est_name),
    cnpj_number = COALESCE(:cnpj_number, cnpj_number),
    est_status = COALESCE(:est_status, est_status)
    -- ❌ NUNCA inclua updated_at manualmente - trigger cuida disso
WHERE est_id = :est_id;
```

### Upsert com ON CONFLICT
```sql
-- ✅ Inserir ou atualizar baseado em constraint única
INSERT INTO partner.establishments (cnpj_number, est_name) 
VALUES (:cnpj, :nome)
ON CONFLICT (cnpj_number) 
DO UPDATE SET 
    est_name = EXCLUDED.est_name,
    updated_at = NOW();
```

---

## 🔍 Full Text Search (FTS)

### Configuração Padrão
```sql
-- ✅ Usar configuração portuguesa com unaccent
CREATE INDEX idx_establishments_fts 
ON partner.establishments 
USING GIN(est_fts);

-- Trigger para manter FTS atualizado
CREATE TRIGGER tr_fts_establishments
    BEFORE INSERT OR UPDATE OF est_name, est_fantasy_name, cnpj_number
    ON partner.establishments
    FOR EACH ROW 
    EXECUTE FUNCTION update_establishment_fts();
```

### Função de Atualização FTS
```sql
CREATE OR REPLACE FUNCTION update_establishment_fts()
RETURNS TRIGGER AS $$
BEGIN
    NEW.est_fts := 
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.cnpj_number, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.est_name, ''))), 'A') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.est_fantasy_name, ''))), 'B') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.est_email, ''))), 'C') ||
        setweight(to_tsvector('public.simple_portuguese', unaccent(COALESCE(NEW.est_city, ''))), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## ⚡ Performance e Indexação

### Estratégias de Índices
```sql
-- ✅ Índices compostos para consultas frequentes
CREATE INDEX idx_nfe_emit_date ON nfe.raiz_nfe (cpf_cnpj, d_emi DESC);
CREATE INDEX idx_nfe_status_mod ON nfe.raiz_nfe (status, mod) WHERE deleted_at IS NULL;

-- ✅ Índices parciais para otimizar espaço
CREATE INDEX idx_establishments_active ON partner.establishments (est_id) 
WHERE est_status = 'ACTIVE' AND deleted_at IS NULL;

-- ✅ Índices para foreign keys
CREATE INDEX idx_addresses_establishment ON partner.addresses (est_id);
```

### Particionamento para Grandes Volumes
```sql
-- ✅ Particionamento por data para tabelas históricas
CREATE TABLE nfe.raiz_nfe_2024 PARTITION OF nfe.raiz_nfe 
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE nfe.raiz_nfe_2025 PARTITION OF nfe.raiz_nfe 
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

---

## 🔐 Segurança e Integridade

### Soft Delete Estratégico
```sql
-- ✅ Soft delete para dados críticos de auditoria
ALTER TABLE partner.establishments 
ADD COLUMN deleted_at TIMESTAMPTZ,
ADD COLUMN deleted_by UUID REFERENCES auth.users(id);

-- ✅ Hard delete com CASCADE para dados relacionais
ALTER TABLE partner.addresses 
ADD CONSTRAINT fk_addresses_establishment 
FOREIGN KEY (est_id) 
REFERENCES partner.establishments(est_id) ON DELETE CASCADE;
```

### Validações de Dados Fiscais
```sql
-- ✅ Funções para validar documentos brasileiros
CREATE OR REPLACE FUNCTION validate_cnpj(cnpj TEXT) 
RETURNS BOOLEAN AS $$
BEGIN
    -- Remove formatação
    cnpj := regexp_replace(cnpj, '[^0-9]', '', 'g');
    
    -- Validações básicas
    IF length(cnpj) != 14 THEN RETURN FALSE; END IF;
    IF cnpj ~ '^(\d)\1{13}$' THEN RETURN FALSE; END IF;
    
    -- Algoritmo de validação do CNPJ
    -- [implementação completa do algoritmo]
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ✅ Check constraint usando a função
ALTER TABLE partner.establishments 
ADD CONSTRAINT ck_establishments_cnpj_valid 
CHECK (validate_cnpj(cnpj_number));
```

---

## 📊 Monitoramento e Manutenção

### Funções de Saúde do Banco
```sql
-- ✅ Monitorar performance de queries
CREATE VIEW admin.slow_queries AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    stddev_time
FROM pg_stat_statements 
WHERE mean_time > 1000 
ORDER BY mean_time DESC;

-- ✅ Monitorar crescimento de tabelas
CREATE VIEW admin.table_sizes AS
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_total_relation_size(schemaname||'.'||tablename) as bytes
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Procedure de Manutenção Automática
```sql
-- ✅ Manutenção noturna automatizada
CREATE OR REPLACE PROCEDURE admin.daily_maintenance()
LANGUAGE plpgsql AS $$
BEGIN
    -- Vacuum analyze nas tabelas críticas
    VACUUM ANALYZE nfe.raiz_nfe;
    VACUUM ANALYZE partner.establishments;
    
    -- Reindex semanal (apenas aos domingos)
    IF EXTRACT(DOW FROM NOW()) = 0 THEN
        REINDEX INDEX CONCURRENTLY idx_establishments_search;
        REINDEX INDEX CONCURRENTLY idx_nfe_emit_date;
    END IF;
    
    -- Log da execução
    INSERT INTO admin.maintenance_log (procedure_name, executed_at)
    VALUES ('daily_maintenance', NOW());
END;
$$;
```

---

## 🎯 Funções e Procedures Padronizadas

### Template para Funções de Negócio
```sql
CREATE OR REPLACE FUNCTION business.calculate_tax_amount(
    _base_value NUMERIC(15,2),
    _tax_rate NUMERIC(5,4),
    _discount_value NUMERIC(15,2) DEFAULT 0.00
)
RETURNS NUMERIC(15,2) 
LANGUAGE plpgsql 
IMMUTABLE 
STRICT
AS $$
DECLARE
    _result NUMERIC(15,2);
BEGIN
    -- Validações de entrada
    IF _base_value < 0 THEN
        RAISE EXCEPTION 'Base value cannot be negative: %', _base_value;
    END IF;
    
    -- Cálculo
    _result := (_base_value - _discount_value) * _tax_rate;
    
    -- Log para auditoria (se necessário)
    INSERT INTO audit.calculation_log (function_name, parameters, result, calculated_at)
    VALUES ('calculate_tax_amount', 
            json_build_object('base', _base_value, 'rate', _tax_rate, 'discount', _discount_value),
            _result, 
            NOW());
    
    RETURN ROUND(_result, 2);
END;
$$;

-- Comentário obrigatório
COMMENT ON FUNCTION business.calculate_tax_amount IS 
'Calcula valor de imposto considerando base, alíquota e desconto. Usado para NFe e NFCe.';
```

---

## 📋 Checklist de Desenvolvimento

### ✅ Antes de Criar Tabelas
- [ ] Schema apropriado definido
- [ ] Nomenclatura seguindo padrão snake_case
- [ ] PK como UUID com gen_random_uuid()
- [ ] Foreign keys com constraints nomeadas
- [ ] Campos obrigatórios com NOT NULL
- [ ] Timestamps created_at/updated_at
- [ ] Trigger de update timestamp
- [ ] Comentários nas tabelas e colunas

### ✅ Antes de Deploy
- [ ] Índices criados para FKs e consultas frequentes
- [ ] Funções de validação implementadas
- [ ] Check constraints para regras de negócio
- [ ] Permissões configuradas (owner: dorcilio)
- [ ] Backup testado antes de mudanças estruturais
- [ ] Scripts de rollback preparados

---

## 💡 Exemplo Completo

```sql
-- ✅ Exemplo seguindo todas as práticas
CREATE TABLE partner.establishments (
    -- Chaves
    est_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_id UUID,
    
    -- Dados obrigatórios
    cnpj_number VARCHAR(14) NOT NULL,
    est_corporate_name VARCHAR(150) NOT NULL,
    est_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    
    -- Dados opcionais  
    est_fantasy_name VARCHAR(150),
    est_state_registration VARCHAR(20),
    est_municipal_registration VARCHAR(20),
    est_email VARCHAR(100),
    est_phone VARCHAR(20),
    
    -- Soft delete
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Full text search
    est_fts TSVECTOR,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT uk_establishments_cnpj UNIQUE (cnpj_number),
    CONSTRAINT fk_establishments_address FOREIGN KEY (address_id) 
        REFERENCES partner.addresses(address_id) ON DELETE SET NULL,
    CONSTRAINT ck_establishments_cnpj_valid CHECK (validate_cnpj(cnpj_number)),
    CONSTRAINT ck_establishments_status CHECK (est_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
);

-- Índices
CREATE INDEX idx_establishments_cnpj ON partner.establishments (cnpj_number);
CREATE INDEX idx_establishments_status ON partner.establishments (est_status) 
    WHERE deleted_at IS NULL;
CREATE INDEX idx_establishments_fts ON partner.establishments 
    USING GIN(est_fts);

-- Triggers
CREATE TRIGGER tr_upd_establishments
    BEFORE UPDATE ON partner.establishments
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_timestamp();

CREATE TRIGGER tr_fts_establishments  
    BEFORE INSERT OR UPDATE OF cnpj_number, est_corporate_name, est_fantasy_name
    ON partner.establishments
    FOR EACH ROW EXECUTE FUNCTION update_establishment_fts();

-- Comentários
COMMENT ON TABLE partner.establishments IS 
'Cadastro de estabelecimentos/empresas parceiras do sistema fiscal';

COMMENT ON COLUMN partner.establishments.cnpj_number IS 
'CNPJ sem formatação, apenas números. Validado por check constraint';
```

---

## 🎯 Como Usar Este Guia

> **Para GitHub Copilot**: Sempre que eu pedir para criar uma função, tabela, procedure ou qualquer objeto de banco, siga rigorosamente todas as práticas descritas neste guia. Priorize a integridade dos dados, performance e facilidade de manutenção. Use os exemplos como template base.

### 🇧🇷 **Orientação Especial - Contexto Fiscal Brasileiro**

Para nomenclatura fiscal, aplique as regras da seção **"Exceção: Nomenclatura Fiscal Brasileira"** e a tabela de **"Regras de prioridade"** definidas em **Padrões de Nomenclatura** acima. Em resumo:

- Termos fiscais consagrados (`razao_social`, `fantasia`, `cnpj`, `ie`, `d_emi`) → usar português.
- Campos genéricos (`description`, `status`, `fts`) → usar prefixo da entidade (`est_description`, `est_fts`).
- IDs, FTS, constraints e triggers → seguir obrigatoriamente os padrões definidos neste guia.