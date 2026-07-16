# Spec de juego: Partida en Tiempo Real (Game Expert)

Estado: **Done** — implementado y revisado (2 rondas de Senior Reviewer:
4 bugs de concurrencia + hallazgos medios/bajos, ver `docs/memory.md`).
(Aprobado por Luis 2026-07-15 — listo para diseño técnico del Architect.)

## Decisiones de alcance (aprobadas)
- **Sin sistema de recursos**: no hay maná/energía. Se juega 1 carta por
  turno, limitada por espacio en el tablero (no por costo) — no hace falta
  agregar un campo `cost` a `CardArchetype`.
- **Deck building manual**: antes de cada partida, el jugador elige 10
  cartas de su colección (`player_cards`) para formar su mazo.
- **Combate con targeting, sin bloqueo**: el atacante elige el objetivo de
  cada ataque (la vida del rival, o una carta específica del tablero
  rival) — la carta atacada no tiene ninguna reacción/decisión propia, por
  eso sigue sin ser "bloqueo". `defense` es la vida de cada carta en juego.

## Regla completa propuesta

### Mazo y setup
- Mazo: exactamente **10 cartas**, elegidas por el jugador de su colección
  (`player_cards` propias — puede repetir el mismo arquetipo si tiene varias
  copias de distintas aperturas).
- Life total inicial: **20** por jugador.
- Tablero: máximo **5 cartas** en juego por jugador.
- Mano inicial: **3 cartas**, mazo mezclado al azar server-side.
- 1v1 únicamente en esta iteración (sin espectadores, sin free-for-all).

### Estructura de turno (alternado)
1. **Draw**: robar 1 carta. El jugador que empieza la partida **no roba en
   su primer turno** (evita ventaja de salida, convención estándar de TCG).
   Si el mazo está vacío y toca robar → esa persona pierde (fatiga).
2. **Main**: jugar como máximo **1 carta** de la mano a un slot vacío del
   tablero (si hay espacio). La carta recién jugada tiene "mareo de
   invocación" — no puede atacar en el turno en que se juega (evita jugar
   5 cartas y ganar de un saque; convención estándar, no agrega
   complejidad real de implementación).
3. **Combate**: cada carta del tablero que no tenga mareo de invocación y no
   haya atacado este turno ataca una vez, eligiendo objetivo:
   - **Vida del rival**: resta `attack` al life total del rival.
   - **Una carta específica del tablero rival**: resta `attack` al
     `defense` restante de esa carta. Cada carta en juego trackea su
     `defense` actual (arranca en el valor completo de la carta al entrar
     al tablero, no se cura entre turnos). Si llega a 0, la carta es
     destruida y sale del tablero — no vuelve a la mano ni al mazo.
   - No hay bloqueo: la carta/jugador atacado no tiene ninguna
     reacción — el targeting es 100% decisión del atacante.
4. **End**: pasa el turno.

### Condición de victoria
- Life total del rival llega a 0 → ganás.
- Rival tiene que robar con el mazo vacío → pierde (fatiga).
- Rival se desconecta/abandona → ganás por default.

### `defense` como vida de la carta (decisión final)
`defense` deja de ser un stat decorativo en combate: cada carta jugada al
tablero tiene su propio "HP" (= su `defense`), independiente del life total
del jugador. Atacar una carta rival hasta llevarla a 0 la destruye — es la
forma principal de remover amenazas del rival sin arriesgar tu propio life
total. Esto reemplaza la simplificación original de "solo se puede pegarle
a la cara" que se había considerado y luego se descartó.

### Fuera de alcance de esta iteración (a futuro, requiere decisión de Luis)
- Sistema de recompensas por ganar (coins, cartas) — es una decisión de
  economía/monetización, no de este spec.
- Ranking/ELO, temporadas competitivas.
- Espectadores, replays.
- Deck presets guardados / múltiples mazos por jugador.
- Cualquier mecánica de carta más allá de "atacar" (habilidades especiales,
  efectos por facción, sinergias) — hoy todas las cartas son funcionalmente
  idénticas salvo `attack`/`rank`/`rarity`/`faction` (`faction` tampoco tiene
  ningún efecto de combate en esta iteración, es solo identidad temática).

## Criterios de aceptación (para QA)
- No se puede jugar una carta si el tablero ya tiene 5 cartas.
- No se puede jugar más de 1 carta por turno.
- Una carta recién jugada no puede atacar en el mismo turno.
- El jugador que empieza no roba en su turno 1.
- Robar con el mazo vacío causa derrota inmediata por fatiga.
- El life total nunca baja de 0 en la respuesta del servidor (se clampea).
- El `defense` restante de una carta nunca baja de 0; al llegar a 0 la carta
  se destruye y desaparece del tablero de ambos jugadores en la misma
  actualización de estado.
- Atacar solo puede apuntar a la vida del rival o a una carta que esté
  actualmente en el tablero rival — no a cartas ya destruidas ni a cartas
  propias.
- Una carta con `defense` restante dañado de un turno anterior no se cura
  entre turnos.
- Un jugador no puede actuar fuera de su turno (todas las acciones fuera de
  turno se rechazan).
- Desconexión de un jugador resuelve la partida a favor del otro.

## Handoff
Pasa al Architect para el diseño técnico (protocolo de WebSocket, arquitectura
del motor de partida en el servidor, matchmaking).
