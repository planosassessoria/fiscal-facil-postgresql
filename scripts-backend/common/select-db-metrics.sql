-- ============================================================================
-- Arquivo: select-db-metrics.sql
-- Operação: SELECT
-- Schema/Tabela: pg_stat_database
-- Descrição: Retorna métricas de performance do banco de dados atual.
--            Inclui conexões ativas, transações commitadas e rollbacks.
--            Usado para monitoramento e dashboards.
--
-- Parâmetros: Nenhum
--
-- Retorno: database_name, active_connections, transactions_committed,
--          transactions_rolled_back
-- ============================================================================
SELECT
	datname AS database_name,
	numbackends AS active_connections,
	xact_commit AS transactions_committed,
	xact_rollback AS transactions_rolled_back
FROM
	pg_stat_database
WHERE
	datname = current_database();
