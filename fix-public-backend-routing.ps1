param(
  [string]$HostName = "root@backend.managecare.info"
)

$ErrorActionPreference = "Stop"

$remoteScript = @'
set -e

SITE=/etc/nginx/sites-enabled/backend.managecare.info
BACKUP="/root/backend.managecare.info.nginx.$(date +%Y%m%d-%H%M%S).bak"

echo "=== Backup current nginx site ==="
cp "$SITE" "$BACKUP"
echo "backup: $BACKUP"

echo "=== Write backend proxy config ==="
cat > "$SITE" <<'NGINX'
server {
    listen 80;
    server_name backend.managecare.info;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name backend.managecare.info;

    ssl_certificate /etc/letsencrypt/live/backend.managecare.info/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/backend.managecare.info/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 50m;

    location /admin-api/ {
        rewrite ^/admin-api/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /socket.io/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
    }
}
NGINX

echo "=== Validate and reload nginx ==="
nginx -t
systemctl reload nginx

echo "=== Verify public health ==="
curl -skSI --max-time 8 https://backend.managecare.info/api/health
echo
curl -skS --max-time 8 https://backend.managecare.info/api/health
echo

echo "=== Verify public signup ==="
TEST_EMAIL="public-routing-check-$(date +%s)@example.com"
curl -skS -X POST https://backend.managecare.info/auth/v1/signup \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"Test1234!\",\"data\":{\"full_name\":\"Public Routing Check\"}}"
echo
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
ssh $HostName "echo $encoded | base64 -d > /tmp/managecare-fix-routing.sh && bash /tmp/managecare-fix-routing.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Public backend routing fix failed"
}
