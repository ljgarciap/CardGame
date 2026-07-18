#!/usr/bin/env bash
# Levanta el ambiente local completo de CardGame: db + redis + mailhog
# (Docker), migraciones, seeds y el backend con reload.
#
# Los puertos de host de db/redis pueden estar tomados por otros proyectos
# del workspace (ver docker-compose.override.yml, no versionado) — este
# script no asume 5432/6379 fijos, lee el puerto real publicado por Compose.
#
# Uso: ./scripts/dev-up.sh
set -euo pipefail

# 8000 está tomado en esta máquina por factoring_backend_web (nginx del
# proyecto Factoring, publicado en 0.0.0.0:8000) — colisiona con uvicorn
# en localhost:8000 de forma intermitente (según a qué proceso resuelva
# "localhost" en cada request). Ver docs/memory.md 2026-07-18.
BACKEND_PORT="${BACKEND_PORT:-8001}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Levantando db, redis y mailhog..."
docker compose up -d db redis mailhog

echo "==> Esperando a que Postgres acepte conexiones..."
until docker compose exec -T db pg_isready -U user -d card_game >/dev/null 2>&1; do
  sleep 1
done

DB_PORT="$(docker compose port db 5432 | cut -d: -f2)"
REDIS_PORT="$(docker compose port redis 6379 | cut -d: -f2)"

BACKEND_DIR="$ROOT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"

cat > "$ENV_FILE" <<EOF
DATABASE_URL=postgresql://user:password@localhost:${DB_PORT}/card_game
JWT_SECRET_KEY=dev-secret-change-in-production
SMTP_HOST=localhost
SMTP_PORT=1025
SMTP_FROM=noreply@cardgame.local
REDIS_URL=redis://localhost:${REDIS_PORT}/0
EOF
echo "==> backend/.env generado (db:${DB_PORT} redis:${REDIS_PORT})"

if [ ! -d "$BACKEND_DIR/.venv" ]; then
  echo "==> Creando .venv del backend..."
  python3 -m venv "$BACKEND_DIR/.venv"
fi

# shellcheck disable=SC1091
source "$BACKEND_DIR/.venv/bin/activate"
pip install -q -r "$BACKEND_DIR/requirements.txt"

cd "$BACKEND_DIR"
echo "==> Aplicando migraciones..."
alembic upgrade head

echo "==> Corriendo seeds (idempotentes)..."
python -m app.db.seed
python -m app.db.seed_gacha_config
python -m app.db.seed_deck_config

echo "==> Mailhog UI: http://localhost:8025"
echo "==> Backend arrancando en http://localhost:${BACKEND_PORT} (Ctrl+C para detener)"
echo "==> Frontend (otra terminal): cd frontend && flutter run -d chrome"
exec uvicorn app.main:app --reload --port "$BACKEND_PORT"
