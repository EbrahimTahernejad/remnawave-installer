#!/usr/bin/env bash
set -euo pipefail

# ---- check root ----
if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh"
  exit 1
fi

# ---- input secret ----
read -rp "input: SECRET_KEY: " SECRET_KEY

# ---- input node port (default 2222) ----
read -rp "input: NODE_PORT [2222]: " NODE_PORT
NODE_PORT="${NODE_PORT:-2222}"

# validate it's a number in the valid port range
if ! [[ "$NODE_PORT" =~ ^[0-9]+$ ]] || (( NODE_PORT < 1 || NODE_PORT > 65535 )); then
  echo "Invalid NODE_PORT: '$NODE_PORT' (must be 1-65535)"
  exit 1
fi

echo "[1/7] Updating Ubuntu APT sources..."

SRC_FILE="/etc/apt/sources.list.d/ubuntu.sources"
BACKUP_FILE="/etc/apt/sources.list.d/ubuntu.sources.bak"

cp "$SRC_FILE" "$BACKUP_FILE"

# replace all URIs lines safely
sed -i 's|^URIs:.*|URIs: http://mirror.arvancloud.ir/ubuntu|g' "$SRC_FILE"

echo "[2/7] Adding hosts entry..."
if ! grep -q "mirror.arvancloud.ir" /etc/hosts; then
  echo "185.143.233.235 mirror.arvancloud.ir" >> /etc/hosts
fi

echo "[3/7] Installing docker deb packages..."
dpkg -i ./*.deb || true

echo "[4/7] Fixing dependencies..."
apt -f install -y

echo "[5/7] Loading docker image..."
docker load -i remnanode.tar

echo "[6/7] Creating remnanode folder..."
mkdir -p /opt/remnanode

# ---- YAML safe escaping (important) ----
ESCAPED_SECRET_KEY=$(printf "%s" "$SECRET_KEY" | sed "s/'/''/g")

cat > /opt/remnanode/docker-compose.yml <<EOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:2.7.0
    network_mode: host
    restart: always
    cap_add:
      - NET_ADMIN
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    volumes:
      - '/opt/remnawave/ssl:/var/lib/remnawave/configs/xray/ssl'
    environment:
      - NODE_PORT=${NODE_PORT}
      - SECRET_KEY='${ESCAPED_SECRET_KEY}'
EOF

echo "[7/7] Starting docker compose..."
cd /opt/remnanode
docker compose up -d --build

echo "Done."
