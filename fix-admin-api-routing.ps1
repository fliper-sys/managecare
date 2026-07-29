param(
  [string]$HostName = "root@backend.managecare.info"
)

$ErrorActionPreference = "Stop"

$remoteScript = @'
set -e

SITE=/etc/nginx/sites-enabled/backend.managecare.info
BACKUP="/root/backend.managecare.info.nginx.admin-api.$(date +%Y%m%d-%H%M%S).bak"

echo "=== Backup current nginx site ==="
cp "$SITE" "$BACKUP"
echo "backup: $BACKUP"

echo "=== Route /admin-api/ to main backend on 3000 ==="
python3 - <<'PY'
from pathlib import Path

site = Path("/etc/nginx/sites-enabled/backend.managecare.info")
text = site.read_text()
text = text.replace("proxy_pass http://127.0.0.1:3001;", "proxy_pass http://127.0.0.1:3000;")
site.write_text(text)
PY

echo "=== Validate and reload nginx ==="
nginx -t
systemctl reload nginx

echo "=== Verify admin-api now reaches main backend auth middleware ==="
curl -skSI --max-time 8 https://backend.managecare.info/admin-api/workers || true
echo

echo "=== Verify health still works ==="
curl -skS --max-time 8 https://backend.managecare.info/api/health
echo
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-fix-admin-api-routing.sh && bash /tmp/managecare-fix-admin-api-routing.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Admin API routing fix failed"
}
