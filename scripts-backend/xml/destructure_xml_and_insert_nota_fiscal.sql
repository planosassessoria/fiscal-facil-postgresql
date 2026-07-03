-- ============================================================================
-- Arquivo: destructure_xml_and_insert_nota_fiscal.sql
-- Operação: FUNCTION CALL
-- Schema/Função: xml.fn_destructure_xml_to_nota_fiscal_record
-- Descrição: Chama a função que desestrutura um XML fiscal e insere os dados
--            nas tabelas do schema nota_fiscal. Transforma o XML bruto em
--            registros estruturados para consulta.
--
-- Parâmetros:
--   $1 - _xml_id (BIGINT) - ID do XML armazenado na xml.xml_storage
--   $2 - _replace_if_exists (BOOLEAN) - Se TRUE, substitui registro existente (DEFAULT FALSE)
--
-- Retorno: JSONB com resultado da desestruturação (sucesso/skipped/erros)
-- ============================================================================
SELECT xml.fn_destructure_xml_to_nota_fiscal_record(
	$1,
	$2
) AS result;