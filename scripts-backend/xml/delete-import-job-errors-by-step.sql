-- ============================================================================
-- Arquivo: delete-import-job-errors-by-step.sql
-- Operação: DELETE
-- Schema/Tabela: xml.import_job_error
-- Descrição: Remove todos os registros de erro de um job para um step específico.
--            Utilizado antes do reprocessamento para limpar erros obsoletos.
--
-- Parâmetros:
--   $1 - job_id (UUID) - ID do job de importação
--   $2 - step_name (VARCHAR) - Nome da etapa (ex: 'PROCESS_NF')
--
-- Retorno: Quantidade de registros removidos
-- ============================================================================
DELETE FROM xml.import_job_error
WHERE job_id = $1
  AND step_name = $2;
