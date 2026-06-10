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
--   $4  - est_id (UUID) - ID do estabelecimento alvo da importação
--   $5  - job_type (VARCHAR) - Tipo do job (IMPORT_ZIP, IMPORT_SINGLE)
--   $6  - job_status (VARCHAR) - Status inicial (PENDING)
--   $7  - file_name (VARCHAR) - Nome do arquivo enviado
--   $8  - file_size_bytes (BIGINT) - Tamanho do arquivo em bytes
--   $9  - bucket_path (VARCHAR) - Caminho no bucket de armazenamento
--   $10 - total_count (INT) - Total de documentos no lote
--   $11 - notes (TEXT) - Observações opcionais
--   $12 - expires_at (TIMESTAMPTZ) - Data de expiração do job
--
-- Retorno: job_id (UUID) - ID do job criado
-- ============================================================================
INSERT INTO XML.import_job (
	tenant_id,
	user_email,
	cpf_cnpj,
	est_id,
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
	$11,
	$12
) RETURNING job_id;