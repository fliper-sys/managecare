cd /opt/managecare-backend

# Grant schema permissions to managecare user
PGPASSWORD=BqHjAf8aMMmhHhOlW0j6bYIj4T7Owrya psql -h 127.0.0.1 -p 5432 -U managecare -d managecare <<'EOSQL'
GRANT ALL ON SCHEMA public TO managecare;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO managecare;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO managecare;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO managecare;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO managecare;
EOSQL
echo "GRANTS_OK"

# Run Migration 008 - Push Notifications
PGPASSWORD=BqHjAf8aMMmhHhOlW0j6bYIj4T7Owrya psql -h 127.0.0.1 -p 5432 -U managecare -d managecare -f migration_008.sql
echo "MIGRATION_008_DONE"

# Run Migration 009 - Missing Objects
PGPASSWORD=BqHjAf8aMMmhHhOlW0j6bYIj4T7Owrya psql -h 127.0.0.1 -p 5432 -U managecare -d managecare -f migration_009.sql
echo "MIGRATION_009_DONE"

# Restart backend
pm2 restart managecare-backend && pm2 save
echo "RESTART_DONE"

# Verify
sleep 2
curl -s http://localhost:3000/api/health
echo ""
echo "ALL_DONE"
