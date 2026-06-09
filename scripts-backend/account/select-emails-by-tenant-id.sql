-- ============================================================================
-- Arquivo: select-emails-by-tenant-id.sql
-- Operação: SELECT
-- Schema/Tabela: account.users_tenants
-- Descrição: Retorna os e-mails de todos os usuários ativos de um tenant.
--            Usado pelo SendNotificationUseCase para resolver os destinatários
--            quando notif_scope = 'TENANT'.
--
-- Parâmetros:
--   $1 - tenant_id (UUID) - ID do tenant alvo
--
-- Retorno: Lista de e-mails dos usuários vinculados ao tenant
-- ============================================================================
SELECT
	email
FROM account.users_tenants
WHERE
	tenant_id = $1
	AND is_active = TRUE;
