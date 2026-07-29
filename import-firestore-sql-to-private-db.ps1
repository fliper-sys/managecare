param(
  [string]$HostName = "root@backend.managecare.info",
  [string]$SqlFile = ".\firestore-postgres-import.sql"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $SqlFile)) {
  throw "SQL import file not found: $SqlFile"
}

$remoteFile = "/opt/managecare-backend/firestore-postgres-import.sql"

Write-Host "== Copying Firestore import SQL to VPS =="
scp $SqlFile "${HostName}:${remoteFile}"
if ($LASTEXITCODE -ne 0) {
  throw "Failed to copy $SqlFile"
}

Write-Host "== Applying import to private Postgres database =="
ssh $HostName "sudo -u postgres psql -v ON_ERROR_STOP=1 -d managecare -f $remoteFile"
if ($LASTEXITCODE -ne 0) {
  throw "Firestore SQL import failed"
}

Write-Host "== Imported row counts =="
ssh $HostName "sudo -u postgres psql -d managecare -c `"SELECT 'profiles' AS table_name, COUNT(*) FROM profiles UNION ALL SELECT 'businesses', COUNT(*) FROM businesses UNION ALL SELECT 'business_members', COUNT(*) FROM business_members UNION ALL SELECT 'inventory', COUNT(*) FROM inventory UNION ALL SELECT 'customers', COUNT(*) FROM customers UNION ALL SELECT 'workers', COUNT(*) FROM workers UNION ALL SELECT 'sales', COUNT(*) FROM sales UNION ALL SELECT 'sale_items', COUNT(*) FROM sale_items UNION ALL SELECT 'expenses', COUNT(*) FROM expenses ORDER BY table_name;`""
