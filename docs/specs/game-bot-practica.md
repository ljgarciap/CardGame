# Spec de juego: Bot de práctica "Eco" (Game Expert)

Estado: **Aprobado por Luis (2026-07-19) e implementado** — verificado con
tests automatizados (backend) y una partida real contra el backend en vivo.

## Problema y objetivo

El motor de partidas en tiempo real (`match_engine.py`, `matchmaking.py`,
`match_ws.py`) ya estaba completo, pero el matchmaking es estrictamente
PvP: necesita dos jugadores reales en la cola a la vez
(`_TRY_PAIR_SCRIPT` de `matchmaking.py` exige `LLEN >= 2`), sin timeout ni
fallback. Un jugador solo (o probando la app en desarrollo) se queda
esperando para siempre. Este documento define un oponente de práctica que
resuelve eso sin tocar el matchmaking real.

## Punto de entrada

Botón explícito **"PRACTICAR CONTRA BOT"** en `MyDecksPage`, al lado del
botón de matchmaking real. Arranca la partida al toque, sin cola.

Descartado para esta iteración: que el matchmaking caiga a un bot después
de un timeout esperando rival real. Es mejor UX a futuro, pero agrega
manejo de temporizador que no hacía falta para resolver el problema
inmediato — se puede sumar después sin romper este diseño.

## Identidad del bot

- `BOT_USER_ID`: UUID fijo (`app/services/bot.py`), no una fila real de
  `users` — `Match`/`MatchPlayerState` viven en Redis como modelos
  Pydantic (`match_store.py`), sin FK que romper.
- Nombre: **"Eco"** — atado al lore ya aprobado (`docs/specs/game-lore-tejido.md`,
  Los Nacidos del Eco: mitos modernos sin cultura propia). Encaja
  temáticamente como el "no-jugador" de práctica.

## Mazo del bot

`DECK_SIZE` (10) arquetipos elegidos al azar de `card_archetypes` en el
momento de arrancar la partida, rareza `common` (stats base, sin bono de
rareza). Se arma fresco en cada partida contra el catálogo real — no hay
mazo fijo/curado para mantener sincronizado con el roster de facciones a
medida que crece (mismo tipo de mantenimiento que ya falló una vez con el
enum `CardFaction` del frontend al agregar Muisca; acá se evita del todo
consultando el catálogo real en vez de duplicar una lista).

## Comportamiento (v1 — reglas fijas, sin IA real)

Una sola pasada por turno, ejecutada sincrónicamente en el servidor
(`run_bot_turn`), llamando exactamente las mismas funciones puras de
`match_engine.py` que valida cualquier jugada humana:

1. **Jugar**: si tiene lugar en el tablero y cartas en mano, juega la de
   mayor ataque.
2. **Atacar**: para cada carta que puede atacar (no mareada, no atacó
   este turno) —
   - Si hay alguna carta rival que puede matar de un golpe (su ataque ≥
     la defensa actual del objetivo), ataca la más fuerte de esas
     (prioriza sacar la amenaza más grande, no cualquier trade).
   - Si no hay ningún trade favorable, ataca directo a la cara.
3. **Terminar turno**.

Sin niveles de dificultad en esta iteración — un solo comportamiento. Se
ajusta después si hace falta de verdad (no antes, para no diseñar sobre
una necesidad hipotética).

## Ejecución del turno (detalle técnico para el Architect/Backend Dev)

- `POST` equivalente: acción WebSocket nueva `start_bot_match` (mismo
  protocolo que `queue`, mismo mensaje `match_found` vía `user_notify`) —
  el resto del cliente (`MatchPage`, `_forward_events`) no necesita saber
  que el rival es un bot.
- Si el orden de turno al azar (`start_match` lo baraja igual que en una
  partida real) le toca arrancar al bot, `run_bot_turn` corre antes de
  guardar el estado inicial y notificar `match_found` — el humano nunca
  ve un estado a mitad de jugar del bot, solo el resultado.
- Después de cada `end_turn` humano, si el nuevo jugador activo es el
  bot, `run_bot_turn` corre en el mismo bloque (mismo lock de
  `match_store`, mismo `save_match`/`publish_match_update`) — no hace
  falta un mecanismo de difusión aparte.

## Balance

Actualizado 2026-07-19 — la nota original de esta sección quedó
desactualizada. `STARTING_LIFE` (20) contra ataque base 30-108 hacía que
cualquier carta matara de un solo golpe: eso SÍ era un bug real (encontrado
jugando contra este bot en el VPS), no una regla de diseño, y ya se
corrigió — ver `docs/memory.md` 2026-07-19 y `docs/specs/game-gacha-engine.md`.
Balance actual vive en `combat_balance_config`/`rank_base_stats`
(ajustable sin deploy vía `/api/admin/combat-balance`), no hardcodeado.
Con los valores por default ninguna carta mata de un solo golpe.

## Verificación

- `tests/test_bot.py`: mazo del bot (tamaño, cartas distintas, rareza),
  `is_bot_turn`, heurística de `run_bot_turn` (juega la carta correcta,
  ataca a la cara sin objetivos, prioriza un trade favorable, ataca a la
  cara si no hay trade posible, no hace nada fuera de su turno, no rompe
  en el turno 0 sin mano) + 2 tests de integración vía WebSocket real
  (`start_bot_match` deja al humano con el turno, `end_turn` contra el
  bot vuelve al humano o termina la partida — ambos desenlaces válidos
  por la nota de balance de arriba).
- Partida real contra el backend en vivo (no solo tests): `match_found`
  con `opponent_username: "Eco"`, el bot jugó y atacó solo tras el
  `end_turn` del humano, partida terminada por `life_zero` con
  `winner_user_id` del bot.

## Fuera de alcance a propósito

Dificultad ajustable, fallback por timeout desde matchmaking real,
cualquier personalidad/diálogo del bot.
