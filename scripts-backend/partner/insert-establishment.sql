-- ============================================================================
-- Arquivo: insert-establishment.sql
-- Operação: INSERT
-- Schema/Tabela: partner.establishments
-- Descrição: Insere um novo estabelecimento no cadastro global.
--            Registra dados fiscais como documento, IE, razão social e CNAE.
--
-- Parâmetros:
--   $1  - document_type (VARCHAR) - Tipo do documento (CNPJ ou CPF)
--   $2  - document (VARCHAR) - Número do documento sem formatação
--   $3  - ie (VARCHAR) - Inscrição Estadual
--   $4  - uf (VARCHAR) - Unidade Federativa (sigla)
--   $5  - razao_social (VARCHAR) - Razão social
--   $6  - fantasia (VARCHAR) - Nome fantasia
--   $7  - cnae (VARCHAR) - CNAE principal
--   $8  - cnaes (JSONB) - Lista de CNAEs secundários
--   $9  - telefone (VARCHAR) - Telefone principal
--   $10 - situacao (VARCHAR) - Situação cadastral (ATIVA, BAIXADA, etc.)
--
-- Retorno: Registro completo do estabelecimento criado (RETURNING *)
-- ============================================================================
INSERT INTO partner.establishments (
	document_type,
	document,
	ie,
	uf,
	razao_social,
	fantasia,
	cnae,
	cnaes,
	telefone,
	situacao
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
	$10
) RETURNING *;
