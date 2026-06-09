-- ============================================================================
-- Arquivo: select-recipient-exists.sql
-- Operação: SELECT
-- Schema/Tabela: notification.notification_recipients
-- Descrição: Verifica se um usuário é destinatário de uma notificação específica.
--            Usado nos use cases de marcação de leitura e remoção para validar
--            posse antes de executar a operação (proteção contra acesso indevido).
--
-- Parâmetros:
--   $1 - notification_id (UUID)    - ID da notificação
--   $2 - user_email (VARCHAR)      - E-mail do usuário autenticado (do JWT)
--
-- Retorno: { exists: BOOLEAN }
-- ============================================================================
SELECT EXISTS (
	SELECT 1
	FROM notification.notification_recipients
	WHERE
		notification_id = $1
		AND user_email  = $2
) AS exists;
