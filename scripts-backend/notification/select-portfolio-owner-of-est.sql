-- ============================================================================
-- Arquivo: select-portfolio-owner-of-est.sql
-- Operação: SELECT
-- Schema/Tabela: account.users_tenants + partner.tax_entities
-- Descrição: Verifica se o usuário destinatário pertence a algum tenant que
--            tem o estabelecimento informado em sua carteira (tax_entities).
--            Usado pelo CreateUserNotificationUseCase para autorizar envios de
--            notificações entre empresa cliente → escritório contábil.
--
--            Lógica:
--              1. O destinatário ($1) pertence a algum tenant via users_tenants
--              2. Esse tenant tem o est_id ($2) em sua carteira (tax_entities)
--              Ou seja: "o destinatário é contador/escritório que atende
--              o estabelecimento do remetente empresa?"
--
-- Parâmetros:
--   $1 - target_user_email (VARCHAR) - E-mail do usuário destinatário (escritório)
--   $2 - est_id (UUID)               - est_id do estabelecimento remetente (empresa)
--
-- Retorno: { exists: BOOLEAN }
--   TRUE  → o destinatário é escritório que atende a empresa, envio autorizado
--   FALSE → sem vínculo de carteira, envio negado (ForbiddenError)
-- ============================================================================
SELECT EXISTS (
	SELECT 1
	FROM account.users_tenants ut
	JOIN partner.tax_entities  te ON te.tenant_id = ut.tenant_id
	WHERE
		ut.email     = $1
		AND te.est_id    = $2
		AND ut.is_active = TRUE
		AND te.is_active = TRUE
) AS exists;
