-- ============================================================================
-- Arquivo: insert-import-job-step.sql
-- Operação: INSERT
-- Schema/Tabela: xml.import_job_step
-- Descrição: Registra uma nova etapa de processamento em um job de importação.
--            Etapas representam fases do pipeline (EXTRACT_ZIP, VALIDATE,
--            STORE, DESTRUCTURE).
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job de importação
--   $2 - step_order (INT) - Ordem sequencial da etapa
--   $3 - step_name (VARCHAR) - Nome da etapa
--   $4 - step_status (VARCHAR) - Status inicial (PENDING)
--   $5 - total_count (INT) - Total de itens a processar nesta etapa
--   $6 - success_count (INT) - Quantidade de sucessos (inicial: 0)
--   $7 - error_count (INT) - Quantidade de erros (inicial: 0)
--   $8 - step_message (TEXT) - Mensagem descritiva
--   $9 - step_metadata (JSONB) - Metadados adicionais da etapa
--
-- Retorno: step_id (UUID) - ID da etapa criada
-- ============================================================================
INSERT INTO XML.import_job_step (
	job_id,
	step_order,
	step_name,
	step_status,
	total_count,
	success_count,
	error_count,
	step_message,
	step_metadata
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
) RETURNING step_id;