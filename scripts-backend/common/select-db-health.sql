-- ============================================================================
-- Arquivo: select-db-health.sql
-- Operação: SELECT
-- Schema/Tabela: pg_catalog (funções nativas)
-- Descrição: Verifica a saúde do banco de dados. Retorna status, horário
--            atual do servidor e versão do PostgreSQL.
--            Usado pelo health check da aplicação.
--
-- Parâmetros: Nenhum
--
-- Retorno: status ('healthy'), current_time, version
-- ============================================================================
SELECT
  'healthy' AS status,
  NOW() AS current_time,
  version() AS version;
