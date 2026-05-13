-- ============================================================================
-- Arquivo: insert-establishment-tenant.sql
-- Operação: INSERT
-- Schema/Tabela: partner.tenants
-- Descrição: Cria um novo tenant (contratante) vinculado a um estabelecimento.
--            Tenants representam escritórios contábeis ou empresas que
--            contratam o sistema.
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento matriz
--   $2 - owner_email (VARCHAR) - E-mail do proprietário da conta
--   $3 - account_type (VARCHAR) - Tipo da conta (COUNTER, CLIENT)
--
-- Retorno: Registro completo do tenant criado (RETURNING *)
-- ============================================================================
INSERT INTO partner.tenants (
	est_id,
	owner_email,
	account_type
)
VALUES (
	$1,
	$2,
	$3
) RETURNING *;
