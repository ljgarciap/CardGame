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
7. Arranca `uvicorn app.main:app --reload --port 8001` en foreground
   (Ctrl+C para detener; también baja el proceso pero no los
   contenedores — usar `docker compose down` aparte si hace falta).

Al terminar, backend en `http://localhost:8001` (docs en `/docs`),
Mailhog UI en `http://localhost:8025`.

Para el frontend, en otra terminal:

```bash
cd frontend
flutter run -d chrome     # o -d macos
```

El default de `ApiConfig.baseUrl` (`frontend/lib/core/api_config.dart`)
ya es `http://localhost:8001`, no hace falta `--dart-define` salvo que
se quiera apuntar a otro host (ej. `10.0.2.2` para emulador Android).
**Si cambiás ese default, hacé `flutter run` de nuevo (no alcanza con
hot reload) — el valor se compila al arrancar.**

## Nota sobre puertos (importante en esta máquina)

Este workspace corre varios proyectos (GuepardAI, ZIA, Factoring) en
simultáneo, y algunos ya ocupan los puertos default de este proyecto:
Postgres (5432) → `infra-postgres-1`, Redis (6379) → `zia_redis`, y
**8000 → `factoring_backend_web`** (nginx de Factoring, publicado en
`0.0.0.0:8000`). Este último es el más traicionero: como uvicorn corre
en el host (no en Docker) escuchando en `127.0.0.1:8000` mientras el
proxy de Docker escucha en `*:8000`, ambos "funcionan" a la vez y
`localhost:8000` resuelve a uno u otro de forma intermitente — un
`curl /docs` puede dar 200 en los dos, pero un POST real puede caer en
el backend equivocado (404 de Laravel en vez de la respuesta de
FastAPI). Por eso el backend de CardGame usa **8001**, no 8000, tanto
en `dev-up.sh` como en el default de `ApiConfig.baseUrl`. **Nunca tocar
los contenedores de otros proyectos**, son de trabajo activo de Luis.

`docker-compose.override.yml` (no versionado, está en `.gitignore`)
remapea CardGame a `5433` (db), `6380` (redis) y `8001` (backend, para
cuando corra en Docker) usando la sintaxis `ports: !override` de
Compose (reemplaza la lista en vez de mergearla — el merge default de
Compose concatena arrays, lo que generaba conflicto igual con el puerto
base). Si esos puertos también llegaran a estar ocupados en el futuro,
ajustar ese archivo — `dev-up.sh` no depende de valores fijos para
db/redis, siempre lee el puerto real con
`docker compose port <servicio> <puerto-interno>` (el puerto del
backend sí está fijo, vía `BACKEND_PORT` al principio del script,
porque uvicorn corre en el host, no a través de Compose).

Si esta máquina no tuviera estos conflictos (ej. clon limpio en otra
compu), `docker-compose.override.yml` puede no existir — pero
`BACKEND_PORT=8001` y el default de `ApiConfig.baseUrl` seguirían
apuntando a 8001 igual, no hace falta tocar nada para que funcione.

## Verificar que quedó arriba

```bash
curl -s -w "\nHTTP %{http_code}\n" http://localhost:8001/docs
# 200 = ok. Pero no te quedes solo con /docs (ver troubleshooting abajo)
# — probá un POST real (ej. /api/auth/register) para confirmar que no
# estás pegándole al backend equivocado de otro proyecto.
```

## Troubleshooting

**"Internal Server Error" / `relation "users" does not exist` en el
log del backend, pero `alembic upgrade head` no aplica nada nuevo**:
corriste la suite de `pytest` contra esta misma base después del último
`dev-up.sh`. El fixture `_setup_db` de `tests/conftest.py` hace
`Base.metadata.drop_all` al terminar cada test — borra las tablas de la
app pero no `alembic_version`, así que Alembic cree que ya está al día
y no las recrea. Arreglo:

```bash
docker exec cardgame-db-1 psql -U user -d card_game -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
cd backend && source .venv/bin/activate
alembic upgrade head
python -m app.db.seed && python -m app.db.seed_gacha_config && python -m app.db.seed_deck_config
```

Si vas a correr `pytest` y después vas a seguir probando la app a mano
en la misma sesión, planeá re-seedear después — son cosas que no
conviven sobre la misma base.

## Limpieza

```bash
docker compose down          # baja db/redis/mailhog (mantiene el volumen)
docker compose down -v       # además borra el volumen de datos
```
