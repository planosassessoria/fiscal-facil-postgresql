-- ============================================================================
-- Arquivo: insert-roadmap-event.sql
-- Operação: INSERT
-- Schema/Tabela: history.roadmap_events
-- Descrição: Registra um evento significativo no histórico de ações do
--            sistema (audit trail). Armazena payloads antes/depois para
--            rastreabilidade completa de mudanças.
--
-- Parâmetros:
--   $1  - tenant_id (UUID) - ID do tenant
--   $2  - user_email (VARCHAR) - E-mail do usuário que realizou a ação
--   $3  - tax_id (UUID) - ID da entidade fiscal relacionada (pode ser NULL)
--   $4  - est_id (UUID) - ID do estabelecimento relacionado (pode ser NULL)
--   $5  - category (VARCHAR) - Categoria do evento (ESTABLISHMENT, USER, etc.)
--   $6  - action_type (VARCHAR) - Tipo de ação (CREATE, UPDATE, DELETE, etc.)
--   $7  - description (TEXT) - Descrição legível do evento
--   $8  - payload_before (JSONB) - Estado anterior dos dados (NULL se criação)
--   $9  - payload_after (JSONB) - Estado posterior dos dados (NULL se exclusão)
--   $10 - metadata (JSONB) - Metadados adicionais (IP, user-agent, etc.)
--   $11 - event_scope (VARCHAR) - Escopo do evento (TENANT, SYSTEM)
--   $12 - redirect_url (VARCHAR) - URL de redirecionamento ao clicar no evento (pode ser NULL)
--
-- Retorno: Nenhum
-- ============================================================================
INSERT INTO history.roadmap_events (
	tenant_id,
	user_email,
	tax_id,
	est_id,
	category,
	action_type,
	description,
	payload_before,
	payload_after,
	metadata,
	event_scope,
	redirect_url
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10,
	$11,
	$12
);
