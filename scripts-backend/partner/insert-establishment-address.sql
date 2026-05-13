-- ============================================================================
-- Arquivo: insert-establishment-address.sql
-- Operação: INSERT
-- Schema/Tabela: partner.addresses
-- Descrição: Insere o endereço de um estabelecimento.
--            Cada estabelecimento possui um único endereço vinculado.
--
-- Parâmetros:
--   $1 - est_id (UUID) - ID do estabelecimento
--   $2 - zip_code (VARCHAR) - CEP
--   $3 - street (VARCHAR) - Logradouro
--   $4 - street_number (VARCHAR) - Número
--   $5 - neighborhood (VARCHAR) - Bairro
--   $6 - city (VARCHAR) - Cidade
--   $7 - ibge (VARCHAR) - Código IBGE do município
--   $8 - uf (VARCHAR) - UF (sigla)
--   $9 - complement (VARCHAR) - Complemento
--
-- Retorno: Registro completo do endereço criado (RETURNING *)
-- ============================================================================
INSERT INTO partner.addresses (
	est_id,
	zip_code,
	street,
	street_number,
	neighborhood,
	city,
	ibge,
	uf,
	complement
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
	$9
) RETURNING *;
