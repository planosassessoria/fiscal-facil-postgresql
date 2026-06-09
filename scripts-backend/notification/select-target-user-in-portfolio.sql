-- ============================================================================
-- Arquivo: select-target-user-in-portfolio.sql
-- Operação: SELECT
-- Schema/Tabela: account.users_tenants + partner.tenants + partner.tax_entities
-- Descrição: Verifica se o usuário destinatário pertence a algum tenant que
--            está na carteira do escritório remetente (tax_entities).
--            Usado pelo CreateUserNotificationUseCase para autorizar envios de
--            notificações entre escritório → empresa cliente.
--
--            Lógica:
--              1. O destinatário ($2) pertence a algum tenant via users_tenants
--              2. Esse tenant tem um est_id associado (partner.tenants)
--              3. Esse est_id está na carteira do escritório remetente ($1)
--                 via partner.tax_entities(tenant_id = $1, est_id = ...)
--
-- Parâmetros:
--   $1 - portfolio_tenant_id (UUID)  - tenant_id do escritório remetente
--   $2 - target_user_email (VARCHAR) - E-mail do usuário destinatário
--
-- Retorno: { exists: BOOLEAN }
--   TRUE  → o destinatário é cliente do escritório, envio autorizado
--   FALSE → sem vínculo de carteira, envio negado (ForbiddenError)
-- ============================================================================
SELECT EXISTS (
	SELECT 1
	FROM account.users_tenants ut
	JOIN partner.tenants       t  ON t.tenant_id  = ut.tenant_id
	JOIN partner.tax_entities  te ON te.est_id     = t.est_id
	                              AND te.tenant_id  = $1
	WHERE
		ut.email     = $2
		AND ut.is_active = TRUE
		AND te.is_active = TRUE
) AS exists;
