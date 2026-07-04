#!/usr/bin/env bash
set -euo pipefail

# Render expone PORT; local/Docker usan 10000 por defecto.
PORT="${PORT:-10000}"
WORKERS="${GUNICORN_WORKERS:-2}"
# Cálculo masivo multi-empresa puede tardar muchos minutos (SSE abierto).
TIMEOUT="${GUNICORN_TIMEOUT:-1800}"
GRACEFUL="${GUNICORN_GRACEFUL_TIMEOUT:-120}"

exec gunicorn \
  --bind "0.0.0.0:${PORT}" \
  --workers "${WORKERS}" \
  --timeout "${TIMEOUT}" \
  --graceful-timeout "${GRACEFUL}" \
  --keep-alive 5 \
  app:app
