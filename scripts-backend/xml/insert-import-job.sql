-- ============================================================================
-- Arquivo: insert-import-job.sql
-- Operação: INSERT
-- Schema/Tabela: xml.import_job
-- Descrição: Cria um novo job de importação de XMLs fiscais.
--            Jobs rastreiam o progresso de importações em lote (ZIP)
--            de NF-e/NFC-e no sistema.
--
-- Parâmetros:
--   $1  - tenant_id (UUID) - ID do tenant proprietário
--   $2  - user_email (VARCHAR) - E-mail do usuário que iniciou
--   $3  - cpf_cnpj (VARCHAR) - Documento do emitente/destinatário
--   $4  - job_type (VARCHAR) - Tipo do job (IMPORT_ZIP, IMPORT_SINGLE)
--   $5  - job_status (VARCHAR) - Status inicial (PENDING)
--   $6  - file_name (VARCHAR) - Nome do arquivo enviado
--   $7  - file_size_bytes (BIGINT) - Tamanho do arquivo em bytes
--   $8  - bucket_path (VARCHAR) - Caminho no bucket de armazenamento
--   $9  - total_count (INT) - Total de documentos no lote
--   $10 - notes (TEXT) - Observações opcionais
--   $11 - expires_at (TIMESTAMPTZ) - Data de expiração do job
--
-- Retorno: job_id (UUID) - ID do job criado
-- ============================================================================
INSERT INTO XML.import_job (
	tenant_id,
	user_email,
	cpf_cnpj,
	job_type,
	job_status,
	file_name,
	file_size_bytes,
	bucket_path,
	total_count,
	notes,
	expires_at
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10,
	$11
) RETURNING job_id;