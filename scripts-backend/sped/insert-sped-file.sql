-- ============================================================================
-- Arquivo: /sped/insert-sped-file.sql
-- Operação: INSERT ... ON CONFLICT
-- Schema/Tabela: sped.sped_files
-- Descrição: Cria o registro de metadados do arquivo de origem SPED.
--            Se um arquivo com o mesmo SHA-256 já existe (uk_sped_files_file_hash),
--            retorna o registro existente sem alteração — permitindo que um novo
--            job seja criado sobre o mesmo arquivo (reprocessamento).
--
-- Parâmetros:
--   $1  - document (VARCHAR 14) - CPF/CNPJ do declarante (somente dígitos)
--   $2  - ie (VARCHAR 20) - Inscrição Estadual (nullable)
--   $3  - reference_period (DATE) - Período fiscal de referência
--   $4  - layout_version (VARCHAR 4) - Versão do leiaute SPED (ex: '019')
--   $5  - source_file_name (VARCHAR 255) - Nome original do arquivo
--   $6  - source_file_sha256 (CHAR 64) - Hash SHA-256 do conteúdo
--
-- Retorno: sped_file_id (BIGINT) - ID interno do arquivo (novo ou existente)
-- ============================================================================
INSERT INTO sped.sped_files (
    document,
    ie,
    reference_period,
    layout_version,
    source_file_name,
    source_file_sha256
)
VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6
)
ON CONFLICT (source_file_sha256)
DO UPDATE SET updated_at = clock_timestamp()
RETURNING sped_file_id;
