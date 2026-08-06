param(
  [string]$HostName = "root@backend.managecare.info"
)

$ErrorActionPreference = "Stop"

$remoteScript = @'
set +e

echo "=== DNS resolution from VPS ==="
getent ahosts backend.managecare.info || true
echo

echo "=== Enabled nginx sites ==="
ls -la /etc/nginx/sites-enabled || true
echo

echo "=== backend site symlink/content ==="
readlink -f /etc/nginx/sites-enabled/backend.managecare.info || true
sed -n '1,180p' /etc/nginx/sites-enabled/backend.managecare.info 2>/dev/null || true
echo

echo "=== Every nginx reference to backend.managecare.info / 8000 / basic auth ==="
grep -RInE 'backend\.managecare\.info|127\.0\.0\.1:8000|localhost:8000|auth_basic|WWW-Authenticate|realm="service"' /etc/nginx 2>/dev/null || true
echo

echo "=== Active nginx backend snippets ==="
nginx -T 2>/dev/null | grep -n -A60 -B10 -E 'server_name backend\.managecare\.info|proxy_pass http://127\.0\.0\.1:8000|auth_basic' || true
echo

echo "=== Direct Nginx HTTP with Host header ==="
curl -sSI --max-time 8 -H 'Host: backend.managecare.info' http://127.0.0.1/api/health || true
echo
curl -sS --max-time 8 -H 'Host: backend.managecare.info' http://127.0.0.1/api/health || true
echo

echo "=== Direct Node health ==="
curl -sSI --max-time 8 http://127.0.0.1:3000/api/health || true
echo
curl -sS --max-time 8 http://127.0.0.1:3000/api/health || true
echo

echo "=== Nginx access log latest backend hits ==="
tail -n 40 /var/log/nginx/access.log 2>/dev/null || true
echo
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-find-routing.sh && bash /tmp/managecare-find-routing.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Public routing source diagnostic failed"
}
