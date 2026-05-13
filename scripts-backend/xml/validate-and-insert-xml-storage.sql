-- ============================================================================
-- Arquivo: validate-and-insert-xml-storage.sql
-- Operação: FUNCTION CALL
-- Schema/Função: xml.fn_validate_and_store_xml
-- Descrição: Chama a função de validação e armazenamento de XMLs fiscais.
--            Realiza todas as validações necessárias e insere o XML se válido.
--            Retorna JSON indicando sucesso ou erros de validação.
--
-- Parâmetros:
--   $1 - xml_content (TEXT) - Conteúdo do XML fiscal
--   $2 - tenant_id (UUID) - ID do tenant proprietário
--   $3 - user_email (VARCHAR) - E-mail do usuário que importou
--
-- Retorno: JSON com resultado da operação (sucesso/erros)
-- ============================================================================
SELECT xml.fn_validate_and_store_xml(
	$1,
	$2,
	$3
) AS result;