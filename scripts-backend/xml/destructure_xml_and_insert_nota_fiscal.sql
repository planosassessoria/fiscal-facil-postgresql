-- ============================================================================
-- Arquivo: destructure_xml_and_insert_nota_fiscal.sql
-- Operação: FUNCTION CALL
-- Schema/Função: xml.fn_destructure_xml_to_nota_fiscal_record
-- Descrição: Chama a função que desestrutura um XML fiscal e insere os dados
--            na tabela de notas fiscais. Transforma o XML bruto em registros
--            estruturados para consulta.
--
-- Parâmetros:
--   $1 - xml_id (UUID) - ID do XML armazenado na xml_storage
--   $2 - user_email (VARCHAR) - E-mail do usuário que processou
--
-- Retorno: JSON com resultado da desestruturação (sucesso/erros)
-- ============================================================================
SELECT xml.fn_destructure_xml_to_nota_fiscal_record(
	$1,
	$2
);