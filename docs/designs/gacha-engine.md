# Diseño técnico: Motor de Gacha (Architect)

Spec de referencia: `docs/specs/game-gacha-engine.md`
Estado: **Tareas 1-4 (Backend, modelo de cartas + servicio + endpoint +
tests) implementadas con tablas de probabilidad hardcodeadas en
`gacha_service.py`. Revisión 2026-07-15b: esas tablas se mueven a DB
parametrizable** — la regla global agregada hoy en `../CLAUDE.md`
("Hardcodear umbrales/márgenes/porcentajes/divisores de negocio... — todo
valor de ese tipo va en una tabla paramétrica configurable, con CRUD y vista
de administración") aplica directo a `RANK_PROBABILITIES`,
`RARITY_PROBABILITIES`, `RARITY_BONUS` y `PACK_PRICE_PER_LEVEL`. Ver sección
"Configuración paramétrica" más abajo para el rediseño; el resto de este
documento (modelo de cartas, endpoint, transacción) no cambia.

El diseño original (2026-07-12) quedaba bloqueado porque no existía
autenticación real; el sistema de auth ya está implementado
(`app/models/user.py`, JWT vía `get_current_user`), así que la "Decisión
pendiente para Luis" de esa versión queda resuelta: se usa el `User`
autenticado, no un `player_id` anónimo. Ver historial de la decisión en
`docs/memory.md` (2026-07-12) y en el diff de este archivo.

## Componentes afectados/creados

**Backend** (`backend/app/` ya tiene el sistema de auth completo; esto es
la primera feature que se apoya en él):
- `app/models/` — `CardArchetype`, `PlayerCard` (SQLAlchemy). **No se crea
  tabla `players`** — el diseño anterior la proponía como stand-in de cuenta
  de jugador sin login; ya no hace falta, `User` (con su `coins`) cumple ese
  rol.
- `app/schemas/` — Pydantic: `PackOpenRequest`, `PackOpenResponse`, `CardOut`
- `app/services/gacha_service.py` — RNG ponderado + selección de arquetipo + cálculo de stats
- `app/api/packs.py` — router con `POST /api/packs/open`, protegido con
  `Depends(get_current_user)` (mismo patrón que `app/api/users.py`)
- `app/db/` — migración Alembic para `card_archetypes` + `player_cards`, seed de los 20 arquetipos

**Frontend** (primer uso real de estas carpetas, hoy vacías):
- `data/datasources/pack_remote_datasource.dart` — llamada HTTP autenticada al backend (reutiliza el token guardado por `token_storage.dart`, mismo patrón que `auth_remote_datasource.dart`)
- `data/repositories/pack_repository_impl.dart`
- `presentation/pages/pack_opening_page.dart` — reemplazar `_generateRandomCard()` local por la llamada al repositorio; el resultado ya viene resuelto del servidor, el cliente solo anima

## Modelo de datos

Nota 2026-07-19: `base_attack`/`base_defense` se sacaron de `card_archetypes`
(eran idénticos para toda carta del mismo rango) y pasaron a
`rank_base_stats`, una tabla paramétrica ajustable sin deploy — ver
`app/models/combat_balance.py` y `docs/specs/game-gacha-engine.md`. El
diagrama de abajo queda como registro del diseño original, no como schema
vigente. `faction` tampoco incluye ya `muisca` (agregada después, ver
`docs/memory.md`).

```
card_archetypes
  id            uuid pk
  name          text
  faction       enum(greek, norse, egyptian, aztec, oriental)
  rank          enum(hero, demigod, minor_god, major_god)
  description   text

player_cards
  id            uuid pk
  user_id       uuid fk -> users.id       -- antes player_id -> players.id
  archetype_id  uuid fk -> card_archetypes.id
  rarity        enum(common, rare, epic, legendary)
  attack        int   -- ya calculado con el bono de rareza, no se recalcula en lectura
  defense       int
  obtained_at   timestamptz
```

`users.coins` (ya existe, migración `create_users_table`) es el saldo que se
descuenta al abrir un sobre — no se agrega columna nueva.

## Contrato de API

```
GET /api/packs/levels
Headers: Authorization: Bearer <jwt>        -- cualquier usuario autenticado, no solo superadmin

200 OK:
[
  { "level": 1, "price": 1000, "cards_per_pack": 5, "guaranteed_min_rank": null },
  { "level": 3, "price": 3000, "cards_per_pack": 5, "guaranteed_min_rank": "demigod" },
  // ... x5
]

401 Unauthorized -> falta o expiró el JWT
```
Agregado 2026-07-15d: el Marketplace mostraba packs con precio hardcodeado
en el cliente (`nivel * 1000`), calculado a mano y potencialmente
desincronizado del precio real configurable por el admin CRUD. Este
endpoint reusa `PackLevelOut` (mismo schema que ya devuelve
`GET /api/admin/gacha-config`, sin el resto del dump) — no hay nada sensible
en precio/cantidad de cartas, y el spec de juego exige explícitamente que
las probabilidades de gacha nunca se oculten al jugador, así que no hace
falta un endpoint separado "público" vs "admin" con distinto nivel de
detalle, solo distinto scope (todo el dump vs. solo pack_levels).

POST /api/packs/open
Headers: Authorization: Bearer <jwt>        -- igual que /api/users/me
Body:    { "level": 1 }   // 1-5, sin player_id: el usuario sale del token

200 OK:
{
  "cards": [
    { "archetype_id": "...", "name": "Achilles, the Unyielding",
      "faction": "greek", "rank": "hero", "rarity": "rare",
      "attack": 33, "defense": 33 }
    // x5
  ],
  "remaining_coins": 4000
}

400 Bad Request      -> level fuera de 1-5
401 Unauthorized     -> falta o expiró el JWT (mismo comportamiento que endpoints de /api/users)
402 Payment Required -> coins insuficientes (precio = gacha_pack_levels.price del nivel, configurable — ya no es literalmente level*1000 desde la revisión 2026-07-15b)
```

REST, no WebSocket — abrir un sobre no es una interacción en tiempo real
entre jugadores, es una operación puntual request/response.

## Algoritmo del servicio (`gacha_service.py`)

Por cada una de las 5 cartas del pack:
1. `rank = weighted_choice(RANK_PROBABILITIES[level])`
2. `rarity = weighted_choice(RARITY_PROBABILITIES[level])`
3. `faction = uniform_choice(FACTIONS)` — **asunción**: la spec del Game
   Expert no define probabilidad por facción, así que se mantiene uniforme
   (igual que el comportamiento actual del cliente). Si se quiere sesgar
   por facción, es un ajuste futuro de la spec, no de este diseño.
4. `archetype = lookup(faction, rank)` en `card_archetypes`
5. `attack, defense = round(archetype.base_* * (1 + RARITY_BONUS[rarity]))`

Después de generar las 5 cartas: si el nivel tiene garantía mínima de rango
(niveles 3-5) y ninguna de las 5 la cumple, se fuerza el rango de la última
carta generada al mínimo garantizado y se recalculan sus stats.

RNG: `random.SystemRandom` (no determinístico, no seedeable por el cliente).

## Configuración paramétrica (revisión 2026-07-15b)

`RANK_PROBABILITIES`, `RARITY_PROBABILITIES`, `RARITY_BONUS` y
`PACK_PRICE_PER_LEVEL` dejan de ser diccionarios en `gacha_service.py` y
pasan a vivir en tablas — son exactamente los "umbrales/porcentajes de
negocio" que la regla global prohíbe hardcodear. `GUARANTEED_MIN_RANK`
también se parametriza (va junto al precio, es config por nivel).

**Alcance de esta revisión** (decisión de Luis 2026-07-15): solo backend —
tablas + CRUD protegido. La pantalla de administración en Flutter queda
como tarea separada de Frontend Dev, no bloquea que el motor de gacha esté
funcional hoy (el seed deja la config con los mismos valores que ya estaban
hardcodeados, así que el comportamiento no cambia).

### Superadmin
No existe ningún concepto de rol/admin todavía en el proyecto. Se agrega el
mínimo viable: `users.is_superadmin: bool` (default `false`, migración
nueva) y una dependencia `get_current_superadmin` en `app/api/deps.py` que
envuelve `get_current_user` y devuelve 403 si el flag es falso. No se crea
tabla de roles — un solo flag boolean alcanza para el único caso de uso de
hoy; si en el futuro aparecen más niveles de permiso, es un rediseño
separado, no algo a anticipar ahora.

### Modelo de datos nuevo
```
users
  is_superadmin   boolean not null default false   -- columna nueva

gacha_pack_levels
  level                 int pk                        -- 1-5
  price                 int
  cards_per_pack        int                           -- agregado 2026-07-15c, antes CARDS_PER_PACK hardcodeado
  guaranteed_min_rank   enum(hero, demigod, minor_god, major_god) nullable

gacha_rank_probabilities
  level         int fk -> gacha_pack_levels.level
  rank          enum(hero, demigod, minor_god, major_god)
  probability   numeric(6,5)
  pk (level, rank)

gacha_rarity_probabilities
  level         int fk -> gacha_pack_levels.level
  rarity        enum(common, rare, epic, legendary)
  probability   numeric(6,5)
  pk (level, rarity)

gacha_rarity_bonus
  rarity   enum(common, rare, epic, legendary) pk
  bonus    numeric(6,5)
```
Seed: mismos 20+20+5+4 valores que hoy están en `gacha_service.py`
(`docs/specs/game-gacha-engine.md`), ahora como filas.

### Contrato CRUD (`app/api/admin/gacha_config.py`)
Todos los endpoints requieren `Depends(get_current_superadmin)` → 403 si no
es superadmin, 401 si no hay JWT válido (igual que el resto de la API).

```
GET  /api/admin/gacha-config
  -> dump completo: pack_levels, rank_probabilities, rarity_probabilities, rarity_bonus
     (GachaConfigAdminPage en Flutter consume este único endpoint para poblarse)

PUT  /api/admin/gacha-config/pack-levels/{level}
  Body: { "price": int, "cards_per_pack": int, "guaranteed_min_rank": "demigod" | null }
  400 si price <= 0 o cards_per_pack <= 0

PUT  /api/admin/gacha-config/rank-probabilities/{level}
  Body: { "hero": float, "demigod": float, "minor_god": float, "major_god": float }
  400 si la suma no da 1.0 ± 0.0001

PUT  /api/admin/gacha-config/rarity-probabilities/{level}
  Body: { "common": float, "rare": float, "epic": float, "legendary": float }
  400 si la suma no da 1.0 ± 0.0001

PUT  /api/admin/gacha-config/rarity-bonus
  Body: { "common": float, "rare": float, "epic": float, "legendary": float }
  -- global, no es por nivel
```
`level` fuera de 1-5 en cualquiera de estos → 404 (no existe esa fila).

### Cambio en `gacha_service.py`
`generate_pack(db, level)` deja de leer los `dict` de módulo y consulta las
tablas de arriba al inicio de cada llamada (una apertura de pack es una
acción deliberada del usuario, no hot-path — no hace falta cachear entre
requests para esta iteración). `MIN_LEVEL`/`MAX_LEVEL` como constantes de
rango válido (1-5) sí se quedan en código: no son un valor de negocio
ajustable, son la cardinalidad fija del catálogo de niveles definida por el
Game Expert.

### `CARDS_PER_PACK` movido a la tabla paramétrica (2026-07-15c)
Hallazgo de conventions del Senior Reviewer: `CARDS_PER_PACK = 5` seguía
hardcodeado en `gacha_service.py` después de que el resto de los valores de
negocio de esta misma feature (precio, probabilidades, bono) se movieran a
DB — a diferencia de `MIN_LEVEL`/`MAX_LEVEL`, no tenía una justificación
explícita de por qué era una excepción. Decisión de Luis: moverlo.

`gacha_pack_levels` gana la columna `cards_per_pack` (por nivel, no global —
mismo criterio que `price`: nada impide que a futuro un nivel premium
entregue más cartas por sobre). `generate_pack` lee `pack_level.cards_per_pack`
en vez de la constante de módulo. CRUD: `PUT pack-levels/{level}` ahora
requiere `cards_per_pack` en el body (valida `> 0`, mismo patrón que
`price`) — **breaking change en el contrato**, el frontend (datasource,
repository, `GachaConfigAdminPage`) se actualizó en el mismo cambio.

### `guaranteed_min_rank` y `rank_probabilities`: independientes a propósito
Nota agregada 2026-07-15 tras una revisión de Senior Reviewer que marcó como
hallazgo (🟡, no bloqueante) que el CRUD admin permite editar
`guaranteed_min_rank` de un nivel sin cruzar validación contra la tabla
`rank_probabilities` de ese mismo nivel — por ejemplo, nada impide
configurar un nivel barato con probabilidad baja de rango alto pero con
garantía de rango alto igual.

Decisión (Luis, 2026-07-15): esto **no se valida en código**. La garantía
mínima es un mecanismo de pity, no una propiedad estadística derivada de la
tabla de probabilidades — que un nivel tenga probabilidad natural baja de
un rango y aun así garantice ese rango es una decisión de balance de juego
legítima ("nunca te vas con las manos vacías, aunque la suerte natural sea
mala"), no una inconsistencia técnica. Agregar una validación bloqueante acá
requeriría inventar un umbral de "cuán baja es demasiado baja", que sería
exactamente el tipo de valor de negocio hardcodeado que esta feature existe
para evitar. Si en el futuro se quiere una regla real sobre esta interacción
(ej. "la garantía no puede pedir un rango con probabilidad natural menor a
X%"), eso es una decisión del Game Expert — la spec de juego, no este
diseño técnico, debe definir el umbral.

## Transacción y concurrencia
Todo en una sola transacción DB:
1. `SELECT ... FOR UPDATE` sobre la fila de `users` del usuario autenticado
   (evita doble gasto por requests concurrentes del mismo usuario)
2. Verificar `coins >= price`; si no, rollback y devolver 402
3. Descontar `coins`, generar las 5 cartas, insertar en `player_cards`
4. Commit

No se necesita idempotency key: cada request es una apertura nueva y
legítima; no hay un efecto externo (pago con gateway) que deduplicar.

## Riesgos
| Riesgo | Mitigación |
|---|---|
| Doble gasto por requests concurrentes | `SELECT FOR UPDATE` dentro de la transacción |
| Drift entre tablas de probabilidad del cliente (`pack.dart`) y el servidor | El cliente deja de tener su propia tabla — solo el backend conoce las probabilidades tras este cambio |
| Superadmin edita probabilidades que no suman 1.0 (packs con distribución rota) | Validación en cada PUT antes de commit (suma ± 0.0001), 400 si no cumple |
| Query extra a 4 tablas en cada apertura de pack (antes eran dicts en memoria) | Aceptado para esta iteración — abrir un pack no es hot-path; revisar si el perfil de uso cambia |

El riesgo de `player_id` spoofable de la versión anterior del diseño queda
cerrado: el usuario se identifica por JWT (`get_current_user`), igual que en
`/api/users/me`, no por un id enviado en el body.

## Estimación (para PM)
| Tarea | Agente | Depende de | Estimado |
|---|---|---|---|
| ~~Modelos (`CardArchetype`, `PlayerCard`) + migración + seed de 20 arquetipos~~ | Backend Dev | — | ✅ hecho |
| ~~`gacha_service.py` (RNG ponderado + garantía)~~ | Backend Dev | modelos | ✅ hecho |
| ~~Endpoint `POST /api/packs/open` + schemas~~ | Backend Dev | servicio | ✅ hecho |
| ~~Tests estadísticos de distribución (pytest)~~ | Backend Dev | endpoint | ✅ hecho |
| `is_superadmin` en `User` + migración + `get_current_superadmin` | Backend Dev | — | 1h |
| Modelos config (`gacha_pack_levels`, `gacha_rank_probabilities`, `gacha_rarity_probabilities`, `gacha_rarity_bonus`) + migración + seed con los valores actuales | Backend Dev | — | 2h |
| CRUD `app/api/admin/gacha_config.py` (GET dump + 4 PUT, validación de suma=1.0) | Backend Dev | modelos config + superadmin | 2h |
| Refactor `gacha_service.py` para leer de DB en vez de los `dict` | Backend Dev | modelos config | 1h |
| Tests de la config paramétrica (CRUD + validación de suma + 403 sin superadmin) | Backend Dev | CRUD | 1.5h |
| Datasource + repository Flutter (llamada autenticada) | Frontend Dev | contrato de `/api/packs/open` (ya fijo, no cambia) | 2h |
| Wire `PackOpeningPage` al repositorio, quitar RNG local | Frontend Dev | datasource | 1h |
| *(fuera de esta iteración, a pedido de Luis)* Pantalla Flutter de administración de config de gacha | Frontend Dev | CRUD | — backlog separado |

Frontend (Tareas de `pack_opening_page`) puede seguir en paralelo sin
esperar la config paramétrica — el contrato de `POST /api/packs/open` no
cambia, solo cambia de dónde lee sus números el backend.
