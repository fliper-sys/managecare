#!/usr/bin/env bash
set -euo pipefail

# Deploy the functions folder (including server.js) to a VPS via rsync/scp.
# Usage (example):
# VPS_HOST=1.2.3.4 VPS_USER=ubuntu VPS_PATH=/home/ubuntu/managecare SSH_KEY=~/.ssh/id_rsa ./scripts/deploy_server_to_vps.sh

echo "Deploy script starting..."

if [ -z "${VPS_HOST:-}" ] || [ -z "${VPS_USER:-}" ]; then
  echo "Please set VPS_HOST and VPS_USER environment variables." >&2
  echo "Example: VPS_HOST=1.2.3.4 VPS_USER=ubuntu VPS_PATH=/home/ubuntu/managecare ./scripts/deploy_server_to_vps.sh" >&2
  exit 2
fi

VPS_PATH=${VPS_PATH:-/home/$VPS_USER/managecare}
SSH_KEY_OPT=()
if [ -n "${SSH_KEY:-}" ]; then
  SSH_KEY_OPT=("-e" "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no")
fi

echo "Target: ${VPS_USER}@${VPS_HOST}:${VPS_PATH}"

if command -v rsync >/dev/null 2>&1; then
  echo "Using rsync to copy functions/ -> ${VPS_USER}@${VPS_HOST}:${VPS_PATH}/functions/"
  rsync -avz ${SSH_KEY:+-e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no"} --delete ./functions/ ${VPS_USER}@${VPS_HOST}:${VPS_PATH}/functions/
else
  echo "rsync not found, falling back to scp (may be slower)."
  mkdir -p /tmp/mc_deploy
  tar -czf /tmp/mc_deploy/functions.tar.gz -C . functions
  if [ -n "${SSH_KEY:-}" ]; then
    scp -i "${SSH_KEY}" /tmp/mc_deploy/functions.tar.gz "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/functions.tar.gz"
  else
    scp /tmp/mc_deploy/functions.tar.gz "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/functions.tar.gz"
  fi
  echo "Uploaded tarball to remote. SSH into the server and extract: tar -xzf ${VPS_PATH}/functions.tar.gz -C ${VPS_PATH}"
fi

echo "Upload complete. Next steps (on VPS):"
echo "  cd ${VPS_PATH}/functions"
echo "  npm install --production"
echo "  # Option A: run with node"
echo "  node server.js &"
echo "  # Option B (recommended): create a systemd unit and start it (see scripts/managecare-functions.service)"

echo "Done."
