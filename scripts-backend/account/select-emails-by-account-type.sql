-- ============================================================================
-- Arquivo: select-emails-by-account-type.sql
-- Operação: SELECT
-- Schema/Tabela: partner.tenants + account.users_tenants
-- Descrição: Retorna os e-mails de todos os usuários ativos cujo tenant é do
--            tipo de conta informado.
--            Usado pelo SendNotificationUseCase para resolver destinatários
--            quando notif_scope = 'ACCOUNT_TYPE'.
--
--            Exemplos de uso:
--              $1 = 'OFFICE'      → todos usuários de escritórios contábeis
--              $1 = 'COMPANY'     → todos usuários de empresas PJ
--              $1 = 'ACCOUNTANT'  → todos usuários de contadores autônomos
--              $1 = 'INDIVIDUAL'  → todos usuários de profissionais liberais
--
-- Parâmetros:
--   $1 - account_type (VARCHAR) - Tipo de conta: OFFICE|ACCOUNTANT|COMPANY|INDIVIDUAL
--
-- Retorno: Lista distinta de e-mails dos usuários do tipo de conta informado
-- ============================================================================
SELECT DISTINCT
	ut.email
FROM partner.tenants t
JOIN account.users_tenants ut ON ut.tenant_id = t.tenant_id
WHERE
	t.account_type = $1
	AND ut.is_active = TRUE;
