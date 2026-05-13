-- ============================================================================
-- Arquivo: insert-import-job-error.sql
-- Operação: INSERT
-- Schema/Tabela: xml.import_job_error
-- Descrição: Registra um erro ocorrido durante o processamento de um job
--            de importação. Permite rastreamento e depuração de falhas
--            na importação de XMLs fiscais.
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job de importação
--   $2 - step_name (VARCHAR) - Nome da etapa onde ocorreu o erro
--   $3 - file_reference (VARCHAR) - Referência ao arquivo com problema
--   $4 - ch_nf (VARCHAR) - Chave de acesso da NF-e (se aplicável)
--   $5 - error_code (VARCHAR) - Código do erro
--   $6 - error_message (TEXT) - Mensagem descritiva do erro
--   $7 - error_detail (JSONB) - Detalhes adicionais do erro
--
-- Retorno: error_id (UUID) - ID do registro de erro criado
-- ============================================================================
INSERT INTO XML.import_job_error (
	job_id,
	step_name,
	file_reference,
	ch_nf,
	error_code,
	error_message,
	error_detail
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7
) RETURNING error_id;