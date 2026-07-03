-- ============================================================================
-- Arquivo: /sped/select-sped-file-by-declaration.sql
-- Operação: SELECT
-- Schema/Tabela: sped.sped_files
-- Descrição: Busca o registro de arquivo SPED pela chave de identificação
--            da declaração: (document, ie, reference_period).
--            Retorna NULL se não encontrado.
--
-- Parâmetros:
--   $1  - document (VARCHAR 14) - CPF/CNPJ do declarante
--   $2  - ie (VARCHAR 20) - Inscrição Estadual (pode ser NULL)
--   $3  - reference_period (DATE) - Período fiscal de referência
--
-- Retorno: sped_file_id, document, ie, reference_period, source_file_name, etc.
-- ============================================================================
SELECT
    sped_file_id,
    document,
    ie,
    reference_period,
    layout_version,
    source_file_name,
    source_file_sha256,
    total_lines,
    imported_at,
    created_at,
    updated_at
FROM sped.sped_files
WHERE
    document = $1
    AND reference_period = $3
    AND NULLIF(BTRIM(ie), '') IS NOT DISTINCT FROM NULLIF(BTRIM($2::varchar), '');
