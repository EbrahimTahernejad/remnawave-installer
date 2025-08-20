#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
blue() { printf "\033[34m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }

prompt_default() {
  local prompt="$1" default="$2" reply
  read -r -p "$(bold "$prompt") [${default}]: " reply
  echo "${reply:-$default}"
}

is_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

bold "RemnaNode installer"

# ── Inputs ──
APP_PORT="$(prompt_default "App port" "8000")"
while ! is_port "$APP_PORT"; do
  red "Invalid port"
  APP_PORT="$(prompt_default "App port" "8000")"
done

SSL_CERT="$(prompt_default "SSL_CERT string value" "letsencrypt")"

# ── Docker install ──
if ! command -v docker >/dev/null 2>&1; then
  blue "Installing Docker…"
  sudo curl -fsSL https://get.docker.com | sh
fi

if ! docker compose version >/dev/null 2>&1; then
  red "docker compose v2 not found"
  exit 1
fi

# ── Setup dirs ──
sudo mkdir -p /opt/remnanode /opt/remnawave/ssl
sudo chown -R "$(id -u)":"$(id -g)" /opt/remnanode
cd /opt/remnanode

# ── Write .env ──
cat > .env <<EOF
APP_PORT=$APP_PORT
SSL_CERT=$SSL_CERT
EOF
green "Wrote .env"

# ── Write docker-compose.yml ──
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

# ── Start ──
blue "Starting container…"
docker compose up -d
docker compose logs -f
