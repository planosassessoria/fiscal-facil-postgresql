-- ============================================================================
-- Arquivo: validate-and-insert-xml-storage.sql
-- Operação: FUNCTION CALL
-- Schema/Função: xml.fn_validate_and_store_xml
-- Descrição: Chama a função de validação e armazenamento de XMLs fiscais.
--            Realiza todas as validações necessárias e insere o XML se válido.
--            Retorna JSONB indicando sucesso ou erros de validação.
--
-- Parâmetros:
--   $1 - _est_id (UUID) - ID do estabelecimento (validação de participante)
--   $2 - _import_job_id (UUID) - ID do job de importação (opcional, DEFAULT NULL)
--   $3 - _xml_content (XML) - Conteúdo do XML fiscal NF-e/NFC-e
--
-- Retorno: JSONB com resultado da operação (sucesso/erros)
-- ============================================================================
SELECT xml.fn_validate_and_store_xml(
	$1,
	$2,
	$3
) AS result;