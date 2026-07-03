-- ============================================================================
-- Arquivo: /sped/select-sped-file-by-id.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_files + sped.sped_jobs
-- Descrição: Retorna a chave de identificação da declaração (document, ie,
--            reference_period) de um arquivo SPED pelo seu sped_file_id,
--            além do job mais recente vinculado para amarração na timeline.
--            Verifica acesso por tenant_id (exceto root).
--
-- Parâmetros:
--   $1 - sped_file_id (BIGINT) - PK do arquivo
--   $2 - is_root (BOOLEAN)     - Root ignora verificação de tenant
--   $3 - tenant_id (UUID)      - Tenant do usuário autenticado
--
-- Retorno: NULL se não encontrado ou sem permissão de acesso.
-- ============================================================================
SELECT
    f.sped_file_id,
    f.document,
    f.ie,
    f.reference_period,
    (
        SELECT j2.sped_job_id
        FROM sped.sped_jobs j2
        WHERE j2.sped_file_id = f.sped_file_id
        ORDER BY j2.sped_job_id DESC
        LIMIT 1
    ) AS sped_job_id
FROM sped.sped_files f
WHERE f.sped_file_id = $1
  AND (
    $2 = TRUE
    OR EXISTS (
        SELECT 1
        FROM sped.sped_jobs j
        WHERE j.sped_file_id = f.sped_file_id
          AND j.tenant_id = $3
    )
  )
LIMIT 1;
