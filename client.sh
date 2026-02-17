#!/usr/bin/env bash
set -euo pipefail

bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
blue()   { printf "\033[34m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }

is_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }

bold "RemnaNode installer"

# ── Inputs ──
read -r -p "$(bold 'App port') [8000]: " APP_PORT
APP_PORT="${APP_PORT:-8000}"
while ! is_port "$APP_PORT"; do
  red "Invalid port (1–65535)."
  read -r -p "App port [8000]: " APP_PORT
  APP_PORT="${APP_PORT:-8000}"
done

read -r -p "$(bold 'SSL_CERT string (required): ')" SSL_CERT
SSL_CERT="${SSL_CERT:-}"
if [[ -z "$SSL_CERT" ]]; then
  red "SSL_CERT is required. Aborting."
  exit 1
fi

# ── Sanitize SSL_CERT ──
# Remove leading/trailing whitespace
SSL_CERT="$(echo "$SSL_CERT" | xargs)"
# Strip SSL_CERT= prefix if present
SSL_CERT="${SSL_CERT#SSL_CERT=}"
SSL_CERT="${SSL_CERT#SSL_CERT:=}"
# Strip surrounding quotes (single or double)
SSL_CERT="${SSL_CERT%\"}"
SSL_CERT="${SSL_CERT#\"}"
SSL_CERT="${SSL_CERT%\'}"
SSL_CERT="${SSL_CERT#\'}"

if [[ -z "$SSL_CERT" ]]; then
  red "SSL_CERT became empty after sanitization. Aborting."
  exit 1
fi

# ── Docker install ──
if ! command -v docker >/dev/null 2>&1; then
  blue "Installing Docker…"
  sudo curl -fsSL https://get.docker.com | sh
  green "Docker installed."
else
  green "Docker is already installed."
fi

if ! docker compose version >/dev/null 2>&1; then
  red "docker compose v2 not found. Install Docker Compose plugin and re-run."
  exit 1
fi

# ── Setup ──
sudo mkdir -p /opt/remnanode /opt/remnawave/ssl
sudo chown -R "$(id -u)":"$(id -g)" /opt/remnanode
cd /opt/remnanode

# ── .env ──
cat > .env <<EOF
NODE_PORT=$APP_PORT
SECRET_KEY=$SSL_CERT
EOF
green "Wrote .env (SSL_CERT=$SSL_CERT)"

# ── docker-compose.yml ──
cat > docker-compose.yml <<'YAML'
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    restart: always
    network_mode: host
    volumes:
      - '/opt/remnawave/ssl:/var/lib/remnawave/configs/xray/ssl'
    env_file:
      - .env
YAML
green "Wrote docker-compose.yml"

# ── Run ──
blue "Starting container…"
docker compose up -d
green "Container started."
yellow "Tailing logs (Ctrl+C to stop; container keeps running):"
docker compose logs -f
