-- ============================================================================
-- Arquivo: /sped/insert-sped-job.sql
-- Operação: INSERT
-- Schema/Tabela: sped.sped_jobs
-- Descrição: Cria um novo job/protocolo para o ciclo de vida de um arquivo SPED.
--            O protocol_code é único e compartilhado com o usuário para acompanhamento.
--
-- Parâmetros:
--   $1  - sped_file_id (BIGINT) - FK para sped.sped_files
--   $2  - tenant_id (UUID) - Tenant contexto da execução (nullable)
--   $3  - est_id (UUID) - Estabelecimento alvo (nullable)
--   $4  - protocol_code (VARCHAR 50) - Código de protocolo único
--   $5  - job_type (VARCHAR 30) - Tipo: IMPORT | AUDIT | CORRECTION | EXPORT | ...
--   $6  - workflow_status (VARCHAR 40) - Status inicial (ex: 'RECEIVED')
--   $7  - current_stage_code (VARCHAR 60) - Etapa atual (ex: 'IMPORT_UPLOAD')
--   $8  - requested_by_email (VARCHAR 320) - E-mail do solicitante (nullable)
--   $9  - job_metadata (JSONB) - Metadados extras
--
-- Retorno: sped_job_id (BIGINT) - ID interno do job criado
-- ============================================================================
INSERT INTO sped.sped_jobs (
    sped_file_id,
    tenant_id,
    est_id,
    protocol_code,
    job_type,
    workflow_status,
    current_stage_code,
    requested_by_email,
    job_metadata
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
)
RETURNING sped_job_id;
