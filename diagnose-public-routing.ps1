param(
  [string]$HostName = "root@backend.managecare.info"
)

$ErrorActionPreference = "Stop"

$remoteScript = @'
set +e
echo '=== Local Express health ==='
curl -sS --max-time 5 http://127.0.0.1:3000/api/health
echo

echo '=== Public HTTPS health from VPS ==='
curl -skS --max-time 8 https://backend.managecare.info/api/health
echo

echo '=== Public HTTPS response headers ==='
curl -skSI --max-time 8 https://backend.managecare.info/ || true
echo
curl -skSI --max-time 8 https://backend.managecare.info/api/health || true
echo

echo '=== Listening ports ==='
ss -ltnp 2>/dev/null | grep -E ':(80|443|3000|8000|5432)\b' || true
echo

echo '=== PM2 ==='
pm2 status || true
echo

echo '=== Nginx service ==='
systemctl is-active nginx 2>/dev/null || true
nginx -t 2>&1 || true
echo

echo '=== Nginx backend.managecare.info config snippets ==='
nginx -T 2>/dev/null | grep -n -A45 -B15 'backend.managecare.info' || true
echo

echo '=== Docker containers on web ports ==='
docker ps --format 'table {{.Names}}\t{{.Ports}}' 2>/dev/null | grep -E '80|443|8000|3000|kong|supabase|traefik|caddy|nginx' || true
echo

echo '=== Cloudflared service/config presence ==='
systemctl is-active cloudflared 2>/dev/null || true
find /etc/cloudflared -maxdepth 2 -type f 2>/dev/null | sort || true
echo

echo '=== Recent backend logs ==='
pm2 logs managecare-backend --lines 20 --nostream || true
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-routing-diagnose.sh && bash /tmp/managecare-routing-diagnose.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Routing diagnostic failed"
}
