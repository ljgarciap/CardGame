---
name: run
description: Levanta el ambiente local completo de CardGame (Postgres, Redis, Mailhog, backend FastAPI y guía para el frontend Flutter) para poder probar cambios. Usar cuando Luis pide "probar lo que va", "levantar el ambiente", "correr esto en local" o similar dentro del proyecto CardGame.
---

# Levantar CardGame en local

## Camino rápido (recomendado)

Desde la raíz del repo `CardGame/`:

```bash
./scripts/dev-up.sh
```

Este script:
1. Levanta `db`, `redis` y `mailhog` vía `docker compose up -d`.
2. Espera a que Postgres acepte conexiones (`pg_isready`).
3. Lee los puertos de host reales que Compose publicó (no asume
   5432/6379 fijos — ver nota de puertos abajo) y regenera
   `backend/.env` con esos valores.
4. Crea `backend/.venv` si no existe e instala `requirements.txt`.
5. Corre `alembic upgrade head`.
6. Corre los tres seeds (`app.db.seed`, `app.db.seed_gacha_config`,
   `app.db.seed_deck_config`) — los tres son idempotentes, se pueden
   correr las veces que haga falta sin duplicar datos.
7. Arranca `uvicorn app.main:app --reload --port 8000` en foreground
   (Ctrl+C para detener; también baja el proceso pero no los
   contenedores — usar `docker compose down` aparte si hace falta).

Al terminar, backend en `http://localhost:8000` (docs en `/docs`),
Mailhog UI en `http://localhost:8025`.

Para el frontend, en otra terminal:

```bash
cd frontend
flutter run -d chrome     # o -d macos
```

El default de `ApiConfig.baseUrl` (`frontend/lib/core/api_config.dart`)
ya es `http://localhost:8000`, no hace falta `--dart-define` salvo que
se quiera apuntar a otro host (ej. `10.0.2.2` para emulador Android).

## Nota sobre puertos (importante en esta máquina)

Este workspace corre varios proyectos (GuepardAI, ZIA, Factoring) en
simultáneo, y algunos ya ocupan los puertos default de Postgres
(5432) y Redis (6379) — `infra-postgres-1` y `zia_redis`
respectivamente, vistos en `docker ps`. **Nunca tocar esos
contenedores**, son de otros proyectos activos.

`docker-compose.override.yml` (no versionado, está en `.gitignore`)
remapea CardGame a `5433` (db) y `6380` (redis) usando la sintaxis
`ports: !override` de Compose (reemplaza la lista en vez de
mergearla — el merge default de Compose concatena arrays, lo que
generaba conflicto igual con el puerto base). Si esos puertos también
llegaran a estar ocupados en el futuro, ajustar ese archivo — el
script `dev-up.sh` no depende de valores fijos, siempre lee el puerto
real con `docker compose port <servicio> <puerto-interno>`.

Si esta máquina no tuviera esos conflictos (ej. clon limpio en otra
compu), `docker-compose.override.yml` puede no existir y todo
funciona igual contra los puertos default — el script se adapta solo.

## Verificar que quedó arriba

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/docs
# 200 = ok
```

## Limpieza

```bash
docker compose down          # baja db/redis/mailhog (mantiene el volumen)
docker compose down -v       # además borra el volumen de datos
```
