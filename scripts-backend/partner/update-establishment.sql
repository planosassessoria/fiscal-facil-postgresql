-- ============================================================================
-- Arquivo: update-establishment.sql
-- Operação: UPDATE
-- Schema/Tabela: partner.establishments
-- Descrição: Atualiza parcialmente os dados de um estabelecimento.
--            Usa COALESCE para preservar valores existentes quando o
--            parâmetro é NULL (patch parcial).
--
-- Parâmetros:
--   $1  - est_id (UUID) - ID do estabelecimento (identifica o registro)
--   $2  - ie (VARCHAR) - Inscrição Estadual (opcional)
--   $3  - uf (VARCHAR) - UF (opcional)
--   $4  - razao_social (VARCHAR) - Razão social (opcional)
--   $5  - fantasia (VARCHAR) - Nome fantasia (opcional)
--   $6  - cnae (VARCHAR) - CNAE principal (opcional)
--   $7  - cnaes (JSONB) - CNAEs secundários (opcional)
--   $8  - telefone (VARCHAR) - Telefone principal (opcional)
--   $9  - situacao (VARCHAR) - Situação cadastral (opcional)
--   $10 - last_sync_at (TIMESTAMPTZ) - Data da última sincronização (opcional)
--   $11 - telefone_secundario (VARCHAR) - Telefone secundário (opcional)
--   $12 - email (VARCHAR) - E-mail (opcional)
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE partner.establishments
SET
    ie = COALESCE($2, ie),
    uf = COALESCE($3, uf),
    razao_social = COALESCE($4, razao_social),
    fantasia = COALESCE($5, fantasia),
    cnae = COALESCE($6, cnae),
    cnaes = COALESCE($7, cnaes),
    telefone = COALESCE($8, telefone),
    situacao = COALESCE($9, situacao),
    last_sync_at = COALESCE($10, last_sync_at),
    telefone_secundario = COALESCE($11, telefone_secundario),
    email = COALESCE($12, email)
WHERE est_id = $1;
