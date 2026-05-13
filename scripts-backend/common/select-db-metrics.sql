-- src/infrastructure/database/queries/common/select-db-metrics.sql
-- Query para selecionar métricas do banco de dados
SELECT
	datname AS database_name,
	numbackends AS active_connections,
	xact_commit AS transactions_committed,
	xact_rollback AS transactions_rolled_back
FROM
	pg_stat_database
WHERE
	datname = current_database();
