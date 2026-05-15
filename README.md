# Fiscal Fácil — Scripts PostgreSQL

Repositório oficial de scripts SQL do banco de dados do **Fiscal Fácil**, um sistema de gestão fiscal e contábil. Contém schemas, funções, triggers, índices e scripts de backend organizados por domínio.

---

## Sumário

- [Sobre o Projeto](#sobre-o-projeto)
- [Requisitos](#requisitos)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Schemas](#schemas)
- [Como Aplicar os Scripts](#como-aplicar-os-scripts)
- [Guia de Nomenclatura de Arquivos](#guia-de-nomenclatura-de-arquivos)
- [Guia de Comentários em SQL](#guia-de-comentários-em-sql)
- [Convenções Adotadas](#convenções-adotadas)
- [Licença](#licença)

---

## Sobre o Projeto

O **Fiscal Fácil** é um sistema de gestão fiscal e contábil que utiliza PostgreSQL como banco de dados principal. Este repositório centraliza todos os scripts DDL e DML que compõem a infraestrutura de dados do sistema, incluindo:

- Definição de schemas e tabelas
- Funções e triggers (FTS, timestamps, validações)
- Scripts parametrizados para uso no backend
- Funções de processamento de XML (NF-e / NFC-e)

---

## Requisitos

| Dependência   | Versão mínima |
|---------------|---------------|
| PostgreSQL    | 15+           |
| Extensão `unaccent` | Incluída no PostgreSQL |
| Extensão `uuid-ossp` ou `pgcrypto` | Para `gen_random_uuid()` |

---

## Estrutura do Repositório

```
fiscal-facil-postgresql/
│
├── schema_public.sql           # Extensões, FTS e funções globais compartilhadas
├── schema_account.sql          # IAM: usuários, sessões, roles e permissões (RBAC)
├── schema_partner.sql          # Parceiros: estabelecimentos, endereços e CNAEs
├── schema_nota_fiscal.sql      # NF-e / NFC-e: estrutura principal das notas fiscais
├── schema_history.sql          # Auditoria e histórico de eventos (roadmap)
├── schema_socket.sql           # Comunicação em tempo real via WebSocket
├── schema_xml.sql              # Armazenamento e processamento de XMLs fiscais
│
├── functions/                  # Funções complexas de processamento
│   └── validate_and_store_xml.sql
│
├── scripts-backend/            # Scripts parametrizados consumidos pela API
│   ├── account/                # Operações de usuários, sessões e permissões
│   ├── common/                 # Saúde e métricas do banco
│   ├── history/                # Registro de eventos
│   └── partner/                # Estabelecimentos e entidades fiscais
│
└── manuais_e_notas_tecnicas/   # PDFs de referência (SPED, NF-e, IBS/CBS/IS)
```

---

## Schemas

| Schema    | Responsabilidade                                                              |
|-----------|-------------------------------------------------------------------------------|
| `public`  | Extensões (`unaccent`), configuração FTS `simple_portuguese` e funções utilitárias globais |
| `account` | Gestão de identidade e acesso (IAM): usuários, sessões, roles e RBAC         |
| `partner` | Estabelecimentos (CNPJ/CPF), endereços, tenants, entidades fiscais e CNAEs   |
| `nota_fiscal`     | Estrutura de NF-e e NFC-e: cabeçalho, itens e totais das notas fiscais       |
| `history` | Auditoria e rastreabilidade de eventos do sistema                            |
| `socket`  | Infraestrutura de comunicação em tempo real                                   |
| `xml`     | Armazenamento, validação e processamento de XMLs fiscais (NF-e / NFC-e)      |

---

## Como Aplicar os Scripts

### Ordem de execução recomendada

Os schemas possuem dependências entre si. Aplique na seguinte sequência:

```bash
# 1. Objetos globais (extensões, FTS, funções utilitárias)
psql -U dorcilio -d fiscal_facil -f schema_public.sql

# 2. Schemas de domínio (sem dependências entre si)
psql -U dorcilio -d fiscal_facil -f schema_account.sql
psql -U dorcilio -d fiscal_facil -f schema_partner.sql
psql -U dorcilio -d fiscal_facil -f schema_xml.sql
psql -U dorcilio -d fiscal_facil -f schema_nota_fiscal.sql
psql -U dorcilio -d fiscal_facil -f schema_history.sql
psql -U dorcilio -d fiscal_facil -f schema_socket.sql

# 3. Funções complexas de processamento
psql -U dorcilio -d fiscal_facil -f functions/validate_and_store_xml.sql
psql -U dorcilio -d fiscal_facil -f functions/desestructure_xml_and_insert_nf.sql
```

> **Atenção:** Nunca execute scripts diretamente em produção sem antes testar em ambiente de homologação e preparar o script de rollback correspondente.

### Scripts de backend

Os scripts em `scripts-backend/` são parametrizados e destinados ao consumo pela API. Utilize seu driver de banco de dados para injetar os parâmetros nomeados (ex: `:est_id`, `:tenant_id`).

---

## Guia de Nomenclatura de Arquivos

Todos os arquivos em `scripts-backend/` seguem o padrão:

```
{operação}-{entidade}-{complemento}.sql
```

### Operações disponíveis

| Prefixo    | Uso                                                          |
|------------|--------------------------------------------------------------|
| `insert`   | Criação de um novo registro                                  |
| `select`   | Consulta/leitura de dados                                    |
| `update`   | Atualização de dados existentes                              |
| `delete`   | Remoção de registros (hard delete)                           |
| `upsert`   | Inserção ou atualização condicional (`ON CONFLICT DO UPDATE`) |

### Entidade

Nome do recurso principal que o script manipula, sempre no singular e em `kebab-case`:

```
user, session, establishment, tax-entity, module, permission, role
```

### Complemento (opcional)

Descreve o filtro, critério ou contexto da operação, unindo termos com hífen:

```
by-id, by-email, by-tenant-id, by-document, by-session-id
with-roles, with-permissions, with-tenant
email-confirmed, password, profile, status
```

### Exemplos práticos

```
# ✅ Correto
insert-user.sql
insert-user-tenant.sql
select-user-by-email.sql
select-users-by-tenant-id.sql
select-full-user-with-tenant.sql
update-user-password.sql
update-user-email-confirmed.sql
delete-session-by-session-id.sql
delete-sessions-by-email.sql
upsert-establishment-address.sql

# ❌ Incorreto
getUser.sql            -- camelCase não permitido
user_select.sql        -- operação deve vir primeiro
select_user_email.sql  -- usar hífen, não underscore
selectUserByEmail.sql  -- camelCase não permitido
userData.sql           -- sem operação definida
```

### Criação de subdiretórios

Cada subdiretório em `scripts-backend/` corresponde a um domínio do sistema. Crie um novo subdiretório apenas quando surgir um conjunto de scripts para um domínio ainda não representado. O nome do diretório deve ser o nome do schema em `kebab-case`:

```
scripts-backend/
├── account/       → schema account (IAM)
├── partner/       → schema partner (estabelecimentos)
├── history/       → schema history (eventos)
├── common/        → utilitários sem schema fixo
└── nota_fiscal/           → schema nfe (notas fiscais) — exemplo de novo domínio
```

### Schemas e funções complexas

Para arquivos fora de `scripts-backend/`:

| Tipo                        | Padrão de nome                                      | Exemplo                                              |
|-----------------------------|------------------------------------------------------|------------------------------------------------------|
| Schema completo             | `schema_{nome}.sql`                                  | `schema_partner.sql`                                 |
| Função de processamento     | `{schema}.fn_{verbo}_{descricao}.sql`                | `xml.fn_validate_and_store_xml.sql`                  |
| Função de desestruturação   | `{schema}.fn_{verbo}_{descricao}.sql`                | `xml.fn_destructure_xml_to_nota_fiscal_record.sql`   |
| Função de trigger           | `{schema}.fn_{acao}_{entidade}.sql`                  | `partner.fn_refresh_establishment_fts.sql`           |

---

## Guia de Comentários em SQL

### Cabeçalho obrigatório em schemas

Todo arquivo de schema deve iniciar com o seguinte bloco:

```sql
-- =============================================================================
-- SCHEMA: nome_do_schema
-- PROJETO: Fiscal Fácil
-- DATA: AAAA-MM-DD
-- DESCRIÇÃO: Descrição objetiva do schema e seu propósito no sistema.
-- =============================================================================
```

### Cabeçalho obrigatório em scripts de backend

```sql
-- =============================================================================
-- OPERAÇÃO : SELECT / INSERT / UPDATE / DELETE / UPSERT
-- ENTIDADE : nome_da_tabela (schema.tabela)
-- DESCRIÇÃO: O que este script faz em uma linha.
-- PARÂMETROS:
--   :param_1  tipo    Descrição do parâmetro
--   :param_2  tipo    Descrição do parâmetro
-- RETORNO  : Descrição das colunas retornadas (para SELECT) ou rows affected
-- =============================================================================
```

### Separadores de seção

Use separadores para organizar blocos dentro de um schema:

```sql
-- -----------------------------------------------------------------------------
-- 1. FUNÇÕES
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 2. TABELAS
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 4. TRIGGERS
-- -----------------------------------------------------------------------------
```

### Comentários inline

Use comentários de linha (`--`) para explicar decisões não óbvias. Evite comentar o óbvio:

```sql
-- ✅ Útil: explica decisão de negócio
-- Soft delete: registros fiscais não podem ser removidos permanentemente por exigência legal.
deleted_at TIMESTAMPTZ,

-- ✅ Útil: explica comportamento técnico
-- Peso A para CNPJ garante prioridade máxima no ranking FTS.
setweight(to_tsvector('public.simple_portuguese', COALESCE(NEW.document, '')), 'A')

-- ❌ Desnecessário: o próprio código já é claro
-- Atualiza o campo updated_at
NEW.updated_at = clock_timestamp();
```

### `COMMENT ON` obrigatório

Todo objeto que faz parte de um schema público deve ter seu `COMMENT ON` imediatamente após a criação:

```sql
-- Tabela
COMMENT ON TABLE partner.establishments IS
    'Cadastro de estabelecimentos (CNPJ/CPF). Núcleo do domínio partner.';

-- Coluna
COMMENT ON COLUMN partner.establishments.cnpj_number IS
    'CNPJ sem formatação (apenas dígitos). Validado por check constraint ck_establishments_cnpj_valid.';

-- Função
COMMENT ON FUNCTION partner.fn_refresh_establishment_fts() IS
    'Trigger: atualiza est_fts em INSERT e UPDATE de colunas de busca.';

-- Índice
COMMENT ON INDEX idx_establishments_fts IS
    'Índice GIN para busca full-text em estabelecimentos.';
```

---

## Convenções Adotadas

- **Nomenclatura de objetos:** `snake_case` para todos os objetos; prefixo descritivo em IDs (`est_id`, `user_id`) e campos FTS (`est_fts`, `user_fts`)
- **Nomenclatura de arquivos:** `kebab-case` com padrão `{operação}-{entidade}-{complemento}.sql`
- **Chaves primárias — estratégia por contexto:**
  - **Tabelas expostas ao frontend** (account, partner): `UUID` gerado via `gen_random_uuid()`. Evita exposição de sequências e facilita integração entre sistemas.
  - **Tabelas internas/não expostas** (nota_fiscal, xml): `BIGINT GENERATED ALWAYS AS IDENTITY` ou `BIGSERIAL`. Menor custo de armazenamento, indexação mais eficiente e melhor performance em JOINs de alto volume.
  - **Regra geral:** se o ID será visível em URLs, APIs ou no frontend, use `UUID`. Se o ID é apenas referência interna entre tabelas do banco, prefira `BIGINT`.
- **Timestamps:** `created_at` e `updated_at` como `TIMESTAMPTZ NOT NULL DEFAULT NOW()`, atualizados automaticamente por trigger
- **Soft delete:** campos `deleted_at` e `deleted_by` para dados críticos de auditoria
- **Full Text Search:** configuração `public.simple_portuguese` com `unaccent` para suporte a buscas sem acento em português
- **Constraints nomeadas:** `uk_`, `fk_`, `ck_` como prefixos de unique, foreign key e check constraints
- **Comentários:** todos os objetos públicos possuem `COMMENT ON`; scripts possuem cabeçalho padronizado

---

## Licença

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
