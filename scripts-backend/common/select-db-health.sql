-- src/infrastructure/database/queries/common/select-db-health.sql
--- SQL to check database health
SELECT
  'healthy' AS status,
  NOW() AS current_time,
  version() AS version;
