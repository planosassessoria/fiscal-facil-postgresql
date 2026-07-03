-- ============================================================================
-- Arquivo: /sped/select-selectable-sped-job-status-types.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_job_status_types
-- Descrição: Lista os tipos de status do catálogo que podem ser selecionados
--            manualmente pelo contador na timeline/roadmap do SPED.
--            Retorna apenas status com is_system = FALSE.
--
-- Parâmetros: nenhum
--
-- Retorno: status_id, status_code, status_label_pt, is_system, created_at
-- ============================================================================
SELECT
    status_id,
    status_code,
    status_label_pt,
    is_system,
    created_at
FROM sped.sped_job_status_types
WHERE is_system = FALSE
ORDER BY status_label_pt ASC;
