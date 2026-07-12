# Diseño técnico: Motor de Gacha (Architect)

Spec de referencia: `docs/specs/game-gacha-engine.md`
Estado: **bloqueado** — Luis decidió (2026-07-12) priorizar un sistema de
autenticación real antes de tocar monedas/inventario. El diseño de abajo
queda como referencia válida; se retoma (y se revisa el modelo `players`
mínimo, que asume no-auth) una vez exista auth.

## Componentes afectados/creados

**Backend** (todo nuevo — `backend/app/` solo tiene el boilerplate de FastAPI hoy):
- `app/models/` — `CardArchetype`, `Player`, `PlayerCard` (SQLAlchemy)
- `app/schemas/` — Pydantic: `PackOpenRequest`, `PackOpenResponse`, `CardOut`
- `app/services/gacha_service.py` — RNG ponderado + selección de arquetipo + cálculo de stats
- `app/api/packs.py` — router con `POST /api/packs/open`
- `app/db/` — engine/sesión SQLAlchemy + migración inicial + seed de los 20 arquetipos

**Frontend** (primer uso real de estas carpetas, hoy vacías):
- `data/datasources/pack_remote_datasource.dart` — llamada HTTP al backend
- `data/repositories/pack_repository_impl.dart`
- `presentation/pages/pack_opening_page.dart` — reemplazar `_generateRandomCard()` local por la llamada al repositorio; el resultado ya viene resuelto del servidor, el cliente solo anima

## Modelo de datos

```
card_archetypes
  id            uuid pk
  name          text
  faction       enum(greek, norse, egyptian, aztec, oriental)
  rank          enum(hero, demigod, minor_god, major_god)
  base_attack   int
  base_defense  int
  description   text

players            -- mínimo viable, ver "Decisión pendiente" abajo
  id       uuid pk
  name     text
  coins    int

player_cards
  id            uuid pk
  player_id     uuid fk -> players.id
  archetype_id  uuid fk -> card_archetypes.id
  rarity        enum(common, rare, epic, legendary)
  attack        int   -- ya calculado con el bono de rareza, no se recalcula en lectura
  defense       int
  obtained_at   timestamptz
```

## Contrato de API

```
POST /api/packs/open
Body:    { "player_id": "uuid", "level": 1 }   // 1-5

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

400 Bad Request   -> level fuera de 1-5
402 Payment Required -> coins insuficientes (precio = level * 1000)
404 Not Found      -> player_id no existe
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

## Transacción y concurrencia
Todo en una sola transacción DB:
1. `SELECT ... FOR UPDATE` sobre la fila del player (evita doble gasto por
   requests concurrentes del mismo jugador)
2. Verificar `coins >= price`; si no, rollback y devolver 402
3. Descontar `coins`, generar las 5 cartas, insertar en `player_cards`
4. Commit

No se necesita idempotency key: cada request es una apertura nueva y
legítima; no hay un efecto externo (pago con gateway) que deduplicar.

## Decisión pendiente para Luis
**No existe todavía ningún sistema de autenticación/cuentas de jugador en
el backend** (`player.dart` en Flutter es solo estado de partida en curso,
no una cuenta persistente). Server-authoritative para el gacha requiere
igual saber "de quién" se descuentan monedas.

Propongo para esta iteración: una tabla `players` mínima (id, name, coins)
sin login real — el cliente manda un `player_id` fijo/local (ej. generado y
guardado en el dispositivo la primera vez que se abre la app). **Esto es un
hueco de seguridad conocido y aceptado**: un cliente malicioso podría enviar
el `player_id` de otro jugador. Es aceptable para esta iteración porque no
hay sistema de auth en ningún otro lado del proyecto todavía — pero quiero
que sea una decisión tuya, no algo que yo asuma en silencio.

Alternativa: bloquear esta feature hasta tener autenticación real. Más
lento, pero cierra el hueco desde el diseño.

## Riesgos
| Riesgo | Mitigación |
|---|---|
| `player_id` spoofable (sin auth) | Aceptado para esta iteración, ver decisión arriba — revisar cuando exista auth |
| Doble gasto por requests concurrentes | `SELECT FOR UPDATE` dentro de la transacción |
| Drift entre tablas de probabilidad del cliente (`pack.dart`) y el servidor | El cliente deja de tener su propia tabla — solo el backend conoce las probabilidades tras este cambio |

## Estimación (para PM)
| Tarea | Agente | Depende de | Estimado |
|---|---|---|---|
| Modelos + migración + seed de 20 arquetipos | Backend Dev | — | 2h |
| `gacha_service.py` (RNG ponderado + garantía) | Backend Dev | modelos | 2h |
| Endpoint `POST /api/packs/open` + schemas | Backend Dev | servicio | 1h |
| Tests estadísticos de distribución (pytest) | Backend Dev | endpoint | 2h |
| Datasource + repository Flutter | Frontend Dev | contrato de API (no requiere backend corriendo, puede mockear) | 2h |
| Wire `PackOpeningPage` al repositorio, quitar RNG local | Frontend Dev | datasource | 1h |

Backend y Frontend pueden avanzar en paralelo una vez el contrato de API
(arriba) esté fijo — Frontend puede mockear la respuesta mientras Backend
implementa.
