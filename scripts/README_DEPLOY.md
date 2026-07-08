# Deploying ManageCare server functions to a VPS

This document explains how to upload and run the Node `functions/server.js` Express service on your VPS.

Prerequisites (on your workstation):
- `ssh`, `scp` or `rsync` available
- `VPS_HOST`, `VPS_USER` and optional `SSH_KEY` (path to private key)

Steps

1. Upload files

Run the provided script (from repo root):

```bash
VPS_HOST=1.2.3.4 VPS_USER=ubuntu VPS_PATH=/home/ubuntu/managecare SSH_KEY=~/.ssh/id_rsa ./scripts/deploy_server_to_vps.sh
```

2. SSH into the VPS

```bash
ssh -i ~/.ssh/id_rsa ubuntu@1.2.3.4
```

3. Install Node and dependencies (on VPS)

```bash
cd /home/ubuntu/managecare/functions
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs build-essential
npm install --production
```

4. Configure environment

Create a `.env` file or export env vars for `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `JWT_SECRET`, and `PORT`.

Example `.env`:

```
DB_HOST=127.0.0.1
DB_USER=managecare
DB_PASSWORD=secret
DB_NAME=managecare_db
JWT_SECRET=some-very-secret-value
PORT=8080
```

5. Run the service

Temporary run:

```bash
node server.js
```

Run as background service (recommended):

Copy `scripts/managecare-functions.service` to `/etc/systemd/system/managecare-functions.service` and update the `WorkingDirectory` and `Environment` lines.

```bash
sudo cp scripts/managecare-functions.service /etc/systemd/system/managecare-functions.service
sudo systemctl daemon-reload
sudo systemctl enable managecare-functions
sudo systemctl start managecare-functions
sudo journalctl -u managecare-functions -f
```

6. Device configuration

Point your attendance device to the server's public IP and the configured port (e.g., `http://1.2.3.4:8080/iclock/cdata`). Ensure the server port is reachable (open firewall if necessary).

Security notes
- Use SSH keys, not passwords.
- Protect `.env` and use a firewall.
- Run Node behind a reverse proxy if exposing to the public internet.
