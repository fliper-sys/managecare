param(
  [string]$HostName = "root@backend.managecare.info",
  [string]$RemoteDir = "/opt/managecare-backend"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Copy-ToServer {
  param(
    [string]$LocalPath,
    [string]$RemotePath
  )

  scp $LocalPath "${HostName}:${RemotePath}"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to copy $LocalPath to ${HostName}:${RemotePath}"
  }
}

Write-Host "== Preparing remote directories =="
ssh $HostName "mkdir -p $RemoteDir/routes $RemoteDir/middleware"

Write-Host "== Copying backend files =="
Copy-ToServer "$Root\functions\server.js" "$RemoteDir/server.js"
Copy-ToServer "$Root\functions\package.json" "$RemoteDir/package.json"
Copy-ToServer "$Root\functions\package-lock.json" "$RemoteDir/package-lock.json"
Copy-ToServer "$Root\functions\routes\inventory.js" "$RemoteDir/routes/inventory.js"
Copy-ToServer "$Root\functions\routes\sales.js" "$RemoteDir/routes/sales.js"
Copy-ToServer "$Root\functions\routes\customers.js" "$RemoteDir/routes/customers.js"
Copy-ToServer "$Root\functions\routes\workers.js" "$RemoteDir/routes/workers.js"
Copy-ToServer "$Root\functions\routes\expenses.js" "$RemoteDir/routes/expenses.js"
Copy-ToServer "$Root\functions\routes\upload.js" "$RemoteDir/routes/upload.js"
Copy-ToServer "$Root\functions\routes\push.js" "$RemoteDir/routes/push.js"
Copy-ToServer "$Root\functions\middleware\auth.js" "$RemoteDir/middleware/auth.js"
Copy-ToServer "$Root\functions\middleware\validation.js" "$RemoteDir/middleware/validation.js"
Copy-ToServer "$Root\functions\db\schema.sql" "$RemoteDir/schema.sql"
Copy-ToServer "$Root\managecare-1\migrations\008_notifications_and_devices.sql" "$RemoteDir/migration_008.sql"
Copy-ToServer "$Root\managecare-1\migrations\009_missing_objects.sql" "$RemoteDir/migration_009.sql"
Copy-ToServer "$Root\managecare-1\migrations\010_legacy_firestore_import_support.sql" "$RemoteDir/migration_010.sql"
if (Test-Path "$Root\server\managecare-backend\migration_050_petroleum_cash_tracking.sql") {
  Copy-ToServer "$Root\server\managecare-backend\migration_050_petroleum_cash_tracking.sql" "$RemoteDir/migration_050_petroleum_cash_tracking.sql"
} else {
  Write-Host "== Skipping optional petroleum migration file because it is not present locally =="
}

Write-Host "== Running remote install, migrations, restart, and smoke tests =="
$remoteScriptTemplate = @'
set -e
cd __REMOTE_DIR__
echo '=== Node dependency install ==='
npm install --omit=dev
echo '=== Server syntax check ==='
node --check server.js
echo '=== Stop backend during schema migration ==='
pm2 stop managecare-backend || true
echo '=== Base schema ==='
sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f schema.sql
echo '=== Verify base tables ==='
TABLE_COUNT=$(sudo -u postgres psql -d managecare -Atc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
echo "public base table count: $TABLE_COUNT"
if [ "$TABLE_COUNT" -eq 0 ]; then
  echo 'ERROR: schema.sql ran but created zero public tables'
  exit 1
fi
echo '=== Migration 008 ==='
sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f migration_008.sql
echo '=== Migration 009 ==='
sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f migration_009.sql
echo '=== Migration 010 ==='
sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f migration_010.sql
if [ -f migration_050_petroleum_cash_tracking.sql ]; then
  echo '=== Migration 050 petroleum cash tracking ==='
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f migration_050_petroleum_cash_tracking.sql
  echo '=== Verify petroleum cash tracking schema ==='
  PETROLEUM_SCHEMA_OK=$(sudo -u postgres psql -d managecare -Atc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('petroleum_bank_deposits', 'petroleum_cash_entries', 'petroleum_admin_cash_submissions');")
  if [ "$PETROLEUM_SCHEMA_OK" -ne 3 ]; then
    echo 'ERROR: petroleum cash tracking tables are incomplete'
    exit 1
  fi
  PETROLEUM_COLUMNS_OK=$(sudo -u postgres psql -d managecare -Atc "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'petroleum_bank_deposits' AND column_name IN ('deposited_cash_entry', 'balance_cash_at_hand', 'submitted_at');")
  if [ "$PETROLEUM_COLUMNS_OK" -ne 3 ]; then
    echo 'ERROR: petroleum bank deposit columns are incomplete'
    exit 1
  fi
fi
echo '=== Verify migration tables ==='
sudo -u postgres psql -d managecare -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
echo '=== Restart backend ==='
pm2 restart managecare-backend --update-env
pm2 save
echo '=== PM2 status ==='
pm2 status managecare-backend
echo '=== Local health ==='
HEALTH_OK=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 3 http://localhost:3000/api/health; then
    HEALTH_OK=1
    break
  fi
  echo "health attempt $i failed; waiting..."
  sleep 2
done
echo
if [ "$HEALTH_OK" -ne 1 ]; then
  echo 'ERROR: backend did not answer /api/health after restart'
  echo '=== PM2 describe ==='
  pm2 describe managecare-backend || true
  echo '=== Recent logs ==='
  pm2 logs managecare-backend --lines 80 --nostream || true
  exit 1
fi
echo '=== Local signup ==='
TEST_EMAIL="migration-check-$(date +%s)@example.com"
curl -s -X POST http://localhost:3000/auth/v1/signup \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"Test1234!\",\"data\":{\"full_name\":\"Migration Check\"}}"
echo
echo '=== Recent logs ==='
pm2 logs managecare-backend --lines 40 --nostream
'@

$remoteScript = $remoteScriptTemplate.Replace('__REMOTE_DIR__', $RemoteDir)
$remoteScript = $remoteScript -replace "`r",""
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-deploy.sh && chmod +x /tmp/managecare-deploy.sh && bash /tmp/managecare-deploy.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Remote deploy failed"
}
