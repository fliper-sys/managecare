param(
  [string]$HostName = "root@backend.managecare.info"
)

$ErrorActionPreference = "Stop"

$remoteScript = @'
set -e

SITE=/etc/nginx/sites-enabled/backend.managecare.info
BACKUP="/root/backend.managecare.info.nginx.realtime.$(date +%Y%m%d-%H%M%S).bak"

echo "=== Backup current nginx site ==="
cp "$SITE" "$BACKUP"
echo "backup: $BACKUP"

echo "=== Add /realtime/ websocket proxy when missing ==="
if ! grep -q "location /realtime/" "$SITE"; then
  python3 - <<'PY'
from pathlib import Path

site = Path("/etc/nginx/sites-enabled/backend.managecare.info")
text = site.read_text()
marker = "    location /socket.io/ {"
block = """    location /realtime/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
    }

"""

if marker not in text:
    raise SystemExit("Could not find socket.io location marker")

site.write_text(text.replace(marker, block + marker))
PY
else
  echo "/realtime/ location already exists"
fi

echo "=== Validate and reload nginx ==="
nginx -t
systemctl reload nginx

echo "=== Verify Node health still works ==="
curl -skSI --max-time 8 https://backend.managecare.info/api/health
echo

echo "=== Verify realtime route reaches Kong instead of Node ==="
curl -skSI --max-time 8 \
  "https://backend.managecare.info/realtime/v1/websocket?apikey=check&vsn=2.0.0" || true
echo
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-fix-realtime.sh && bash /tmp/managecare-fix-realtime.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Realtime routing fix failed"
}
