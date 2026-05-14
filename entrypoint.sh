#!/usr/bin/env bash
set -euo pipefail

VAULT_DIR="${VAULT_DIR:-/data/vault}"
APP_HOME="${OPENCODE_TELEGRAM_HOME:-/data/appHome}"
OPENCODE_DATA="${OPENCODE_DATA_DIR:-/data/opencode}"

mkdir -p "$VAULT_DIR" "$APP_HOME" "$OPENCODE_DATA"

mkdir -p /root/.local/share
if [ ! -L /root/.local/share/opencode ]; then
  rm -rf /root/.local/share/opencode
  ln -sf "$OPENCODE_DATA" /root/.local/share/opencode
fi

if [ -z "${VAULT_REPO:-}" ] || [ -z "${VAULT_GITHUB_TOKEN:-}" ]; then
  echo "[entrypoint] VAULT_REPO et VAULT_GITHUB_TOKEN sont obligatoires" >&2
  exit 1
fi

VAULT_URL="https://${VAULT_GITHUB_TOKEN}@github.com/${VAULT_REPO}.git"

if [ ! -d "$VAULT_DIR/.git" ]; then
  echo "[entrypoint] Cloning vault from $VAULT_REPO..."
  git clone "$VAULT_URL" "$VAULT_DIR"
else
  echo "[entrypoint] Pulling vault..."
  cd "$VAULT_DIR"
  git remote set-url origin "$VAULT_URL"
  git pull --rebase --autostash || echo "[entrypoint] vault pull failed, continuing"
  cd /app
fi

cd "$VAULT_DIR"
git config user.email "${GIT_AUTHOR_EMAIL:-bot@nouvellelune.co}"
git config user.name "${GIT_AUTHOR_NAME:-NL Cofounder Bot}"
cd /app

echo "[entrypoint] Starting opencode serve on port 4096 from $VAULT_DIR..."
(cd "$VAULT_DIR" && opencode serve --port 4096 --hostname 127.0.0.1) &
OPENCODE_PID=$!

echo "[entrypoint] Waiting for opencode to be ready..."
for i in $(seq 1 30); do
  if curl -fs http://127.0.0.1:4096/ >/dev/null 2>&1; then
    echo "[entrypoint] opencode is ready"
    break
  fi
  sleep 2
done

trap 'kill -TERM $OPENCODE_PID 2>/dev/null || true' EXIT INT TERM

echo "[entrypoint] Starting Telegram bot..."
exec node dist/index.js
