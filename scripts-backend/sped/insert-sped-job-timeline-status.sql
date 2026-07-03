-- ============================================================================
-- Arquivo: /sped/insert-sped-job-timeline-status.sql
-- Operação: INSERT
-- Schema/Tabela: sped.sped_job_timeline
-- Descrição: Registra um status na timeline append-only do SPED.
--            Resolve status_id a partir de status_code no catálogo.
--
-- Parâmetros:
--   $1 - document (VARCHAR 14) - CPF/CNPJ da declaração
--   $2 - ie (VARCHAR 20) - Inscrição estadual (nullable)
--   $3 - reference_period (DATE) - Período fiscal
--   $4 - sped_job_id (BIGINT) - FK opcional para sped.sped_jobs
--   $5 - status_code (VARCHAR 60) - Código no catálogo (ex: IMPORTED)
--   $6 - recorded_by_email (VARCHAR 320) - Usuário que registrou (nullable)
--   $7 - notes (TEXT) - Observações (nullable)
--   $8 - recorded_at (TIMESTAMPTZ) - Data/hora efetiva (nullable, default NOW)
-- ============================================================================
INSERT INTO sped.sped_job_timeline (
    document,
    ie,
    reference_period,
    sped_job_id,
    status_id,
    recorded_by_email,
    notes,
    recorded_at
)
VALUES (
    $1,
    $2,
    $3,
    $4,
    (
        SELECT st.status_id
          FROM sped.sped_job_status_types st
         WHERE st.status_code = $5
    ),
    $6,
    $7,
    COALESCE($8, clock_timestamp())
);