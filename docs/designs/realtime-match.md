# Diseño técnico: Partida en Tiempo Real (Architect)

Spec de referencia: `docs/specs/realtime-match.md`
Estado: Aprobado por Luis (2026-07-15) — listo para PM. Revisión sobre el
borrador original: el estado de partida vive en Redis (no en memoria de un
solo proceso), para soportar múltiples workers/procesos de backend sin
perder correctitud — pedido explícito de Luis.

Backend: **implementado y verificado** (2026-07-15) — las 7 tareas de la
tabla de estimación están completas, con tests contra Postgres/Redis reales
(no mocks) y una verificación end-to-end adicional con 2 procesos backend
independientes (contenedores separados) compartiendo el mismo Redis, jugando
una partida completa hasta la victoria. Dos bugs de concurrencia real
encontrados y corregidos en el camino — ver "Redis async client" y "Testing
WebSocket disconnect handling" en `docs/architecture.md`.

Frontend: **implementado y verificado** (2026-07-16) — deck builder,
matchmaking y tablero de partida completos, conectados al backend real.
Verificado end-to-end en un browser real con dos usuarios jugando una
partida completa hasta la victoria. Detalle en `docs/memory.md`.

## Decisiones de arquitectura

### Estado de partida: Redis, no Postgres, no memoria de un solo proceso
Consistente con `CardGame/CLAUDE.md`: "WebSockets para todo estado de
partida en vivo; REST para marketplace/colección/perfil" — sigue sin
tocarse Postgres por cada acción de juego. Pero un objeto Python en memoria
del proceso (el diseño original) solo funciona si hay un único worker de
Uvicorn; con más de un proceso/worker, dos jugadores de la misma partida
pueden terminar con sus conexiones WebSocket en procesos distintos, que no
comparten memoria — el jugador en el worker B nunca se enteraría de la
jugada que hizo su rival en el worker A.

**Redis resuelve las 3 piezas que necesitan estar compartidas entre
procesos**:
1. **Estado de la partida** (`match:{id}` → JSON del `Match` completo) —
   cualquier worker puede leerlo/escribirlo.
2. **Lock distribuido por partida** (`redis.asyncio.lock.Lock`, SET NX PX
   por debajo) — serializa dos acciones concurrentes sobre la misma
   partida así vengan de workers distintos, evita read-modify-write races.
3. **Cola de matchmaking** (`Redis LIST` + un script Lua chico para
   emparejar de forma atómica — ver abajo) y **Pub/Sub** para que el
   worker que procesó una acción le avise al worker que tiene la conexión
   del rival.

Añade `redis` como servicio nuevo a `docker-compose.yml` (mismo patrón que
ya usa GuepardAI en el workspace — no es tecnología nueva para el equipo) +
`redis` (con soporte asyncio) a `requirements.txt`.

**Todavía no hay historial de partidas**: al terminar una partida, se borra
la key de Redis — nada se persiste a Postgres (ranking/replays siguen
fuera de alcance, spec `docs/specs/realtime-match.md`). Si Redis se cae,
las partidas en curso se pierden — mejor que "si un solo proceso de
backend se reinicia" del diseño anterior, pero sigue siendo una
dependencia con estado; aceptado para esta iteración.

### Cómo se enteran los workers unos de otros: Pub/Sub por partida
Cuando la conexión de un jugador entra a una partida (`match_found`), el
worker que tiene esa conexión se **suscribe** (asyncio, `redis.asyncio`)
al canal `match:{id}:events`. Cuando CUALQUIER worker procesa una acción
válida para esa partida:
1. Toma el lock distribuido de la partida.
2. Lee el estado actual desde Redis.
3. Aplica la acción con `match_engine.py` (lógica pura, sin I/O).
4. Guarda el nuevo estado en Redis.
5. Suelta el lock.
6. **Publica** el estado canónico completo (server-side, sin recortar por
   jugador) al canal `match:{id}:events`.

Todo worker suscripto a ese canal (incluido el que publicó, por
simplicidad — no hay caso especial "es mi propia conexión") recibe el
estado canónico y, para cada conexión local que tenga en esa partida,
computa la vista scoped-por-jugador (tu mano completa, solo la cantidad de
la mano rival, etc. — misma función usada tanto para la respuesta directa
de tu propia acción como para el broadcast al rival) y la manda por su
WebSocket local.

Esto es el patrón estándar para escalar WebSockets horizontalmente (mismo
principio que el adapter de Redis de Socket.IO o el channel layer de Redis
de Django Channels) — no es algo inventado ad hoc para este proyecto.

### Matchmaking: cola en Redis + emparejamiento atómico
`LPUSH match_queue <json: {user_id, username, deck}>` al encolar. El
emparejamiento (¿hay 2 o más en la cola? sacar los primeros 2) tiene que
ser atómico entre procesos — un `LLEN` + `RPOP` en pasos separados tiene
race condition si dos workers lo hacen a la vez. Se resuelve con un script
Lua chico (`EVAL`, Redis ejecuta scripts de forma atómica):
```lua
local len = redis.call('LLEN', KEYS[1])
if len >= 2 then
  local p1 = redis.call('RPOP', KEYS[1])
  local p2 = redis.call('RPOP', KEYS[1])
  return {p1, p2}
end
return nil
```
Cualquier worker que encola a un jugador nuevo intenta este script
inmediatamente después — si hay 2+ en cola, empareja y crea la partida en
ese momento (no hace falta un proceso "matchmaker" separado corriendo en
loop).

### Deck: no hay tabla `decks`
Sin cambios respecto al diseño original: elegir 10 cartas antes de la
partida, no un mazo guardado para reusar (fuera de alcance en el spec). La
lista de `player_card_id` viaja en el mensaje de `queue` y termina como
parte del JSON de la partida en Redis — no hay tabla nueva en Postgres.

### Auth del WebSocket: JWT por query param
Sin cambios: `wss://.../ws/match?token=<jwt>` — los WebSocket de browser no
mandan headers custom en el handshake. Mismo JWT que `/api/auth/login`,
validado con la misma lógica que `get_current_user`, adaptada para cerrar
la conexión con un código de error en vez de lanzar `HTTPException`.

### Un solo WebSocket para matchmaking + partida
Sin cambios: conectás una vez a `/ws/match?token=...`, mandás `queue`, y la
misma conexión sigue usándose para toda la partida.

### Desconexión = derrota inmediata, sin reconexión
Sin cambios — tal como pide el spec. El worker que detecta la desconexión
(su propio `WebSocketDisconnect`) toma el lock de la partida, marca
`is_over=true` con el rival como ganador, guarda en Redis, publica
`match_over` al canal, y el otro worker (con la conexión del rival) lo
recibe y se lo manda.

### Broadcast: sincronía de estado completo, no diffs incrementales
Sin cambios en la forma del mensaje — ahora el "estado completo" es
literalmente lo que vive en Redis, no un objeto en memoria. Mismo
razonamiento: tableros de máximo 5 cartas + mazos de 10 son payloads
chicos, sin problema de performance en esta escala.

## Modelo de estado (Pydantic, serializado a JSON en Redis)

Se modela con Pydantic (no dataclasses) porque necesita
serializar/deserializar limpio a JSON para Redis — mismo patrón que ya usa
el resto del backend para schemas.

```python
class CardInPlay(BaseModel):
    player_card_id: UUID
    name: str
    faction: Faction
    rank: Rank
    rarity: Rarity
    attack: int
    max_defense: int
    current_defense: int       # arranca en max_defense, no se cura entre turnos
    summoning_sick: bool = True
    has_attacked_this_turn: bool = False

class MatchPlayerState(BaseModel):
    user_id: UUID
    username: str
    life: int = 20
    deck: list[CardInPlay]      # mezclado server-side al iniciar, orden = orden de robo
    hand: list[CardInPlay]
    board: list[CardInPlay]     # máx 5
    drew_first_turn: bool = False

class Match(BaseModel):
    id: UUID
    players: dict[UUID, MatchPlayerState]   # exactamente 2
    turn_order: list[UUID]
    current_turn_index: int
    is_over: bool = False
    winner_user_id: UUID | None = None
    reason: str | None = None   # "life_zero" | "fatigue" | "forfeit" | "disconnect"
```

`connection`/`WebSocket` **no** vive en este modelo — no es serializable ni
tiene sentido compartirlo entre procesos. Cada worker mantiene su propio
`dict[UUID, WebSocket]` local (qué conexiones tiene ESTE proceso), separado
del estado de la partida en Redis.

## Protocolo de WebSocket (`/ws/match?token=<jwt>`)
Sin cambios respecto al diseño original — el protocolo cliente↔servidor es
el mismo, lo que cambió es cómo se propaga internamente entre workers.

### Cliente → Servidor
```
{"action": "queue", "deck": ["<player_card_id>", ...]}   // exactamente 10, todas propias
{"action": "leave_queue"}
{"action": "play_card", "player_card_id": "..."}
{"action": "attack", "attacker_id": "...", "target": "face"}
{"action": "attack", "attacker_id": "...", "target": {"card_id": "..."}}
{"action": "end_turn"}
{"action": "forfeit"}
```

### Servidor → Cliente
```
{"type": "queued"}
{"type": "match_found", "match_id": "...", "opponent_username": "...", "your_turn": bool}
{"type": "state_update", "state": { ... ver forma abajo ... }}
{"type": "match_over", "winner_user_id": "..." | null, "reason": "life_zero" | "fatigue" | "forfeit" | "disconnect"}
{"type": "error", "detail": "..."}
```

`state_update.state` (vista scoped, distinta por jugador — computada por
el worker que tiene la conexión local, a partir del estado canónico):
```json
{
  "your_turn": true,
  "your_life": 17,
  "opponent_life": 20,
  "your_hand": [ { "player_card_id", "name", "faction", "rank", "rarity", "attack", "max_defense" } ],
  "your_board": [ { "player_card_id", "name", ..., "current_defense", "summoning_sick", "has_attacked_this_turn" } ],
  "opponent_board": [ /* mismo shape que your_board, visible para todos */ ],
  "opponent_hand_count": 4,
  "your_deck_count": 6,
  "opponent_deck_count": 5
}
```

### Validaciones server-side (server-authoritative, mismo principio que el gacha)
- Toda acción de gameplay valida `current_turn_index` == este jugador →
  si no, `error` sin aplicar nada.
- `play_card`: la carta debe estar en la mano de este jugador, tablero con
  espacio (<5), y no haber jugado ya una carta este turno.
- `attack`: la carta atacante debe estar en el tablero de este jugador, sin
  `summoning_sick`, sin haber atacado ya este turno; el target (si es una
  carta) debe existir en el tablero rival en este momento.
- `queue`: el deck debe tener exactamente 10 `player_card_id` que existan y
  sean propiedad de este usuario (validado contra `player_cards` en
  Postgres al momento de encolar — única vez que esta feature toca la DB
  relacional).

## Endpoints REST nuevos
Ninguno — todo el flujo de matchmaking + partida vive en el WebSocket.

## Componentes nuevos (backend)
- `app/services/match_engine.py` — lógica pura de reglas (aplica
  play_card/attack/end_turn/fatiga a un `Match` de Pydantic, sin I/O,
  100% testeable sin Redis ni WebSocket real — igual que `gacha_service.py`).
- `app/services/match_store.py` — leer/guardar `Match` en Redis + el
  context manager del lock distribuido por partida.
- `app/services/matchmaking.py` — cola en Redis + el script Lua de
  emparejamiento atómico.
- `app/services/match_pubsub.py` — publicar/suscribirse al canal
  `match:{id}:events` de un match.
- `app/api/match_ws.py` — el endpoint `/ws/match`: auth por query param,
  traduce mensajes JSON ↔ llamadas a los servicios de arriba, mantiene el
  `dict[UUID, WebSocket]` local de este proceso, corre la tarea asyncio que
  lee la suscripción Pub/Sub y reenvía a las conexiones locales.

## Componentes nuevos (frontend) — fuera de esta ronda de diseño
El botón "MULTIPLAYER" en `main_menu_page.dart` ya existe como placeholder
(`onPressed: () {}`). El diseño de las pantallas (deck builder, sala de
espera, tablero de partida) se hace como una segunda etapa después de que
el motor de backend esté implementado y verificado — mismo orden que se usó
para el motor de gacha (backend primero, frontend después).

## Riesgos
| Riesgo | Mitigación / aceptado |
|---|---|
| Redis se cae → todas las partidas en curso se pierden | Aceptado para esta iteración (sin persistencia a Postgres) — mejor que "un solo proceso backend se reinicia" del diseño anterior, pero sigue siendo una dependencia con estado |
| Race condition al emparejar 2 jugadores desde workers distintos | Script Lua atómico para el pop de la cola |
| Race condition al aplicar 2 acciones concurrentes sobre la misma partida desde workers distintos | Lock distribuido por partida (Redis SET NX PX) antes de todo read-modify-write |
| Un worker se cae mientras tiene una suscripción Pub/Sub activa | La conexión WebSocket de ese jugador también se cae con el worker → dispara la regla de "desconexión = derrota" del otro lado, comportamiento consistente aunque no elegante |
| Desconexión breve de red = derrota | Aceptado, tal como pide el spec |
| Cliente deshonesto manda acciones inválidas | Todo validado server-side, mismo principio que el gacha — el cliente solo anima lo que el servidor confirma |

## Estimación (para PM)
| Tarea | Agente | Depende de |
|---|---|---|
| `docker-compose.yml` + `requirements.txt`: servicio Redis, cliente `redis` asyncio | Backend Dev | — |
| `match_engine.py` (reglas puras: play_card, attack, end_turn, fatiga, victoria) + tests | Backend Dev | — |
| `match_store.py` (Redis: leer/guardar `Match`, lock distribuido) + tests contra Redis real | Backend Dev | Redis en compose |
| `matchmaking.py` (cola Redis + script Lua de emparejamiento atómico) + tests contra Redis real | Backend Dev | Redis en compose |
| `match_pubsub.py` (publish/subscribe por partida) + tests contra Redis real | Backend Dev | Redis en compose |
| `app/api/match_ws.py` (WebSocket completo, integra todo lo anterior) + tests de integración | Backend Dev | todo lo anterior |
| Verificación end-to-end con **2+ workers de Uvicorn reales** (o 2 contenedores backend) compartiendo el mismo Redis, y clientes WebSocket en cada uno | Backend Dev | endpoint completo |

Frontend (deck builder + pantallas de partida) se desglosa en una ronda de
PM separada, después de que el backend esté revisado.
