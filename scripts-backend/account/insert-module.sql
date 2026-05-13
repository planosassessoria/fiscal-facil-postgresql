-- ============================================================================
-- Arquivo: insert-module.sql
-- Operação: INSERT
-- Schema/Tabela: account.modules
-- Descrição: Insere um novo módulo no sistema de controle de acesso.
--            Módulos agrupam permissões relacionadas.
--
-- Parâmetros:
--   $1 - module_name (VARCHAR) - Nome do módulo
--   $2 - module_key (VARCHAR) - Chave única do módulo
--   $3 - description (TEXT) - Descrição do módulo
--
-- Retorno: Registro completo do módulo criado (RETURNING *)
-- ============================================================================
INSERT INTO account.modules (
	module_name,
	module_key,
	description
)
VALUES (
	$1,
	$2,
	$3
) RETURNING *;
