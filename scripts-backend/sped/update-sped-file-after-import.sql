-- ============================================================================
-- Arquivo: /sped/update-sped-file-after-import.sql
-- Operação: UPDATE
-- Schema/Tabela: sped.sped_files
-- Descrição: Atualiza sped_file após conclusão do parsing:
--            preenche total_lines e imported_at.
--
-- Parâmetros:
--   $1  - sped_file_id (BIGINT) - PK do arquivo
--   $2  - total_lines (INTEGER) - Total de linhas físicas encontradas
--   $3  - imported_at (TIMESTAMPTZ) - Timestamp de conclusão do parsing
-- ============================================================================
UPDATE sped.sped_files
SET
    total_lines = $2,
    imported_at = $3
WHERE sped_file_id = $1;
