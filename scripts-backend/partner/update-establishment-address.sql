-- ============================================================================
-- Arquivo: update-establishment-address.sql
-- Operação: UPDATE
-- Schema/Tabela: partner.addresses
-- Descrição: Atualiza parcialmente o endereço de um estabelecimento.
--            Usa COALESCE para preservar valores existentes quando o
--            parâmetro é NULL (patch parcial).
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento (identifica o endereço)
--   $2 - zip_code (VARCHAR) - CEP (opcional)
--   $3 - street (VARCHAR) - Logradouro (opcional)
--   $4 - street_number (VARCHAR) - Número (opcional)
--   $5 - neighborhood (VARCHAR) - Bairro (opcional)
--   $6 - city (VARCHAR) - Cidade (opcional)
--   $7 - ibge (VARCHAR) - Código IBGE (opcional)
--   $8 - uf (VARCHAR) - UF (opcional)
--   $9 - complement (VARCHAR) - Complemento (opcional)
--
-- Retorno: Nenhum
-- ============================================================================
UPDATE partner.addresses
SET
    zip_code = COALESCE($2, zip_code),
    street = COALESCE($3, street),
    street_number = COALESCE($4, street_number),
    neighborhood = COALESCE($5, neighborhood),
    city = COALESCE($6, city),
    ibge = COALESCE($7, ibge),
    uf = COALESCE($8, uf),
    complement = COALESCE($9, complement)
WHERE est_id = $1;
