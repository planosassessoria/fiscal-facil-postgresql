-- ============================================================================
-- Arquivo: select-xml-storage-by-job-id.sql
-- Operação: SELECT
-- Schema/Tabela: xml.xml_storage
-- Descrição: Busca todos os XMLs armazenados vinculados a um import_job.
--            Retorna xml_id e ch_nf para reprocessamento da etapa PROCESS_NF.
--
-- Parâmetros:
--   $1 - import_job_id (UUID) - ID do job de importação
--
-- Retorno: Lista de { xml_id, ch_nf } ordenada por xml_id
-- ============================================================================
SELECT
    xml_id,
    ch_nf
FROM xml.xml_storage
WHERE import_job_id = $1
ORDER BY xml_id;
