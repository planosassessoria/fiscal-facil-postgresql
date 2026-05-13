-- ============================================================================
-- Arquivo: select-establishment-by-document.sql
-- Operação: SELECT
-- Schema/Tabela: partner.establishments
-- Descrição: Busca um estabelecimento pela chave de negócio (documento + IE).
--            Regras de unicidade:
--            - PJ (CNPJ): apenas pelo documento
--            - PF com IE: CPF + IE
--            - PF autônomo: CPF onde IE é nula
--
-- Parâmetros:
--   $1 - document (VARCHAR) - CNPJ ou CPF sem formatação
--   $2 - ie (TEXT) - Inscrição Estadual (pode ser NULL)
--
-- Retorno: est_id, document, document_type, ie, uf, razao_social,
--          fantasia, situacao (LIMIT 1)
-- ============================================================================
SELECT
    est_id,
    document,
    document_type,
    ie,
    uf,
    razao_social,
    fantasia,
    situacao
FROM partner.establishments
WHERE document = $1
  AND (
    CASE
        -- PJ (CNPJ): unicidade apenas pelo documento
        WHEN length($1) = 14 THEN TRUE

        -- PF com IE: unicidade por CPF + IE
        WHEN length($1) = 11 AND ($2::text IS NOT NULL AND $2::text <> '') THEN ie = $2::text

        -- PF autônomo (sem IE): unicidade pelo CPF onde IE é nula
        WHEN length($1) = 11 AND ($2::text IS NULL OR $2::text = '') THEN ie IS NULL

        ELSE FALSE
    END
  )
LIMIT 1;
