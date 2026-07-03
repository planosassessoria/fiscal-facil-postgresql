-- ============================================================================
-- Arquivo: /sped/insert-sped-job-status-type.sql
-- Operação: INSERT
-- Schema/Tabela: sped.sped_job_status_types
-- Descrição: Cria um novo tipo de status no catálogo de roadmap/timeline SPED.
--
-- Parâmetros:
--   $1 - status_code (VARCHAR 60)     - Código do status (UPPER_SNAKE_CASE)
--   $2 - status_label_pt (VARCHAR 160) - Rótulo de exibição em PT-BR (UPPERCASE)
--   $3 - is_system (BOOLEAN) - TRUE = gerado pelo sistema; FALSE = selecionável pelo contador
--
-- Retorno: status_id, status_code, status_label_pt, is_system, created_at
-- ============================================================================
INSERT INTO sped.sped_job_status_types (
    status_code,
    status_label_pt,
    is_system
)
VALUES (
    UPPER($1),
    UPPER($2),
    COALESCE($3, FALSE)
)
RETURNING
    status_id,
    status_code,
    status_label_pt,
    is_system,
    created_at;
