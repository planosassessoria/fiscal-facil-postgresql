-- ============================================================================
-- Arquivo: select-all-cnaes.sql
-- Operação: SELECT
-- Schema/Tabela: partner.cnaes
-- Descrição: Lista todos os códigos CNAE cadastrados no sistema.
--            Usado para popular selects e autocompletes no frontend.
--
-- Parâmetros: Nenhum
--
-- Retorno: cnae, cnae_description, rows_number
-- ============================================================================
SELECT
    cnae,
    cnae_description,
    COUNT(*) OVER() as rows_number
FROM partner.cnaes
ORDER BY cnae ASC;
