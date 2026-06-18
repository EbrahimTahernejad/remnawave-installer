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

echo "[1/3] Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
else
  echo "Docker already installed, skipping."
fi

echo "[2/3] Creating remnanode folder..."
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

echo "[3/3] Starting docker compose..."
cd /opt/remnanode
docker compose up -d --build

echo "Done."
