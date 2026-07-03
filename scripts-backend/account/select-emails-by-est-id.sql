-- ============================================================================
-- Arquivo: select-emails-by-est-id.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tax_entities + account.users_tenants
-- Descrição: Retorna os e-mails de todos os usuários ativos vinculados a um
--            estabelecimento — alcançando todos os tenants que têm esse
--            estabelecimento em sua carteira (tax_entities).
--            Usado pelo SendNotificationUseCase para resolver destinatários
--            quando notif_scope = 'ESTABLISHMENT'.
--
--            Lógica: um estabelecimento pode estar na carteira de múltiplos
--            tenants (ex: empresa cliente de vários escritórios). Este script
--            retorna os usuários de TODOS esses tenants.
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento alvo
--
-- Retorno: Lista distinta de e-mails dos usuários vinculados ao estabelecimento
-- ============================================================================
SELECT DISTINCT
	ut.email
FROM partner.tax_entities te
JOIN account.users_tenants ut ON ut.tenant_id = te.tenant_id
WHERE
	te.est_id   = $1
	AND ut.is_active = TRUE;
