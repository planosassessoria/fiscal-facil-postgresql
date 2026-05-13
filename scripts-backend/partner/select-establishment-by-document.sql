-- Busca um estabelecimento pela chave de negócio (documento + IE),
-- diretamente na tabela establishments (sem verificar se é tenant).
-- Usado para reaproveitar um establishment que já existe globalmente.
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
