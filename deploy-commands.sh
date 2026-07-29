cd /opt/managecare-backend && \
echo "=== Pulling Latest Backend ===" && \
git pull && \
echo "=== Running Migration 008 (Push Notifications) ===" && \
psql -U postgres -d managecare -f managecare-1/migrations/008_notifications_and_devices.sql && \
echo "=== Running Migration 009 (Missing Objects) ===" && \
psql -U postgres -d managecare -f managecare-1/migrations/009_missing_objects.sql && \
echo "=== Restarting Backend ===" && \
pm2 restart managecare-backend && \
pm2 save && \
echo "=== Health Check ===" && \
curl -s http://localhost:3000/api/health && \
echo "" && \
echo "=== Testing GoTrue Signup ===" && \
curl -s -X POST https://backend.managecare.info/auth/v1/signup -H "Content-Type: application/json" -d '{"email":"test@example.com","password":"Test1234!","data":{"full_name":"Test User"}}' && \
echo "" && \
echo "=== DONE ==="
