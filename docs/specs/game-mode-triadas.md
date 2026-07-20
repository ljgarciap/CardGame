# Spec de juego: Modo Tríadas (Game Expert)

Estado: **Diseño aprobado por Luis (2026-07-20), pendiente de implementación.**
Origen: brainstorm iterativo con Luis, ver `docs/memory.md` 2026-07-19 (4) y
2026-07-20 para el historial completo de cómo se llegó a este modelo
(incluye dos versiones descartadas antes de converger acá).

## Qué es

Un **modo de juego nuevo**, alternativo al modo clásico ya existente (el
que recién se corrigió de balance — tablero de hasta `MAX_BOARD_SIZE`
criaturas, mazo de `DECK_SIZE`). **No lo reemplaza.** El jugador elige con
cuál jugar. El modo clásico no se toca por esta spec.

Identidad: en vez de un tablero ancho de criaturas intercambiables, cada
jugador controla **un solo Personaje activo a la vez**, potenciado por
Equipo y Magia — un duelo de héroe-equipado, no un ejército abstracto.
Encaja con el tema del juego ("jugás un dios/héroe a la vez").

## Campo

3 **zonas fijas y distintas** por jugador — no 3 copias iguales de un
mismo slot:

| Zona | Contenido | Obligatoria |
|---|---|---|
| Personaje | 1 carta de tipo Personaje | No, pero ver regla de guardián abajo |
| Equipo | 1 carta de tipo Equipo | No |
| Magia | 1 carta de tipo Magia | No |

### Regla de guardián (la pieza central del diseño)

Mientras haya un Personaje en la zona de Personaje, **el rival tiene que
atacarlo a él — no puede saltarlo e ir directo a la vida del jugador**.
Sin Personaje en campo, la vida queda expuesta a ataque directo.

Esto no es solo lore: resuelve un hueco real que tiene el motor de combate
clásico hoy (`match_engine.py`, `attack()`) — el atacante siempre puede
elegir ir a la cara sin importar qué tenga el rival en el tablero, así que
ahí nunca hay incentivo real para "bloquear" con nada. Acá sí lo hay: el
Personaje es un bloqueador obligatorio mientras esté vivo.

## Cómo se arma una tríada

- El Personaje se juega solo, como cualquier carta — cuenta como **tu
  jugada del turno** (mismo límite de "una carta por turno" que ya existe
  en el modo clásico).
- Equipo y Magia se juegan **como acción aparte**, no consumen tu jugada
  del turno — podés jugar el Personaje Y equiparlo en el mismo turno, o
  ir armando la tríada en turnos separados (jugás el Personaje ahora, le
  sumás Equipo/Magia cuando te convenga o te toquen).
- Solo pelea el Personaje. Combate: `(ataque base del Personaje + bono
  plano de Equipo) × multiplicador de Magia`. Equipo y Magia nunca son
  objetivo de ataque por sí solos ni atacan por su cuenta — modifican al
  Personaje.

### Reequipar

Podés reemplazar el Equipo o la Magia de un Personaje vivo en cualquier
momento. **La carta vieja se pierde (va al descarte)** — no vuelve a la
mano, no se recicla. Reequipar es una decisión con costo real, no un
intercambio gratis.

### Muerte del Personaje

Cuando el Personaje muere, **se limpia la zona entera** — el Equipo/Magia
que tenía puestos se pierden con él, no sobreviven para el próximo
Personaje. Un Personaje nuevo siempre entra pelado; no hay forma de
pre-cargarle Equipo/Magia antes de que esté en campo (la zona de
Equipo/Magia depende de que haya un Personaje activo al que modificar).

Esto le da peso real a perder tu Personaje: no perdés una carta, perdés
toda la inversión de la tríada completa. El jugador puede jugar un
Personaje nuevo en su siguiente turno (sujeto al límite de una carta por
turno) y seguir la partida — no es sudden-death.

## Origen de las cartas

Los tres tipos salen del **mismo sistema de gacha** que ya existe, no un
catálogo aparte:

- **Personaje**: los arquetipos ya existentes (`card_archetypes`) — cada
  uno debería poder tener uno de los tres tipos como atributo, elegido
  según su lore (ej. un dios conocido por un arma legendaria propia →
  Equipo; un dios de trucos/hechizos → Magia; un guerrero puro →
  Personaje). Coherente con el trabajo de autenticidad cultural ya hecho
  (Muisca, "El Tejido") — el tipo no es arbitrario, sale de la mitología
  real de cada personaje. Pendiente: pasada de asignación de tipo por
  arquetipo, a cargo del Game Expert antes de implementar.
- **Equipo y Magia**: arquetipos **nuevos**, dedicados — reusan
  exactamente la misma arquitectura rango + rareza que ya existe para
  Personaje (`Rank`, `Rarity`, `rank_base_stats`, bono de rareza), no un
  sistema nuevo. Un Equipo/Magia de rango alto y rareza alta es más
  fuerte que uno de rango bajo, igual que hoy con los Personajes.

Pendiente de definir en una pasada de balance dedicada (mismo criterio que
ya se usó para `rank_base_stats`, ver `docs/specs/game-gacha-engine.md`):
los valores concretos de bono plano de Equipo y multiplicador de Magia por
rango/rareza. Ambos deberían vivir en tablas paramétricas ajustables sin
deploy (regla global del workspace), no hardcodeados — mismo patrón que
`combat_balance_config`/`rank_base_stats`.

## Fuera de alcance de esta spec, pendiente de otra pasada

- Valores numéricos concretos de bono de Equipo / multiplicador de Magia.
- Asignación de tipo (Personaje/Equipo/Magia) a cada arquetipo existente.
- Diseño de los arquetipos nuevos de Equipo/Magia (nombres, lore,
  distribución por facción/rango).
- `STARTING_LIFE` de este modo — la dinámica de combate es completamente
  distinta al modo clásico (un solo Personaje activo, no hasta 5
  criaturas), así que el valor que ya se tuneó para el modo clásico no
  necesariamente sirve acá. Requiere su propia pasada de balance una vez
  que haya un prototipo jugable.
- Mazo de 30 cartas — confirmado por Luis, pero falta definir reglas de
  composición (¿mínimo/máximo de cada tipo?).
- Diseño técnico (Architect): cómo cambia `MatchPlayerState`/`CardInPlay`
  para soportar zonas tipadas en vez de una lista plana de `board`, nuevas
  acciones WebSocket (equipar/reemplazar), y cómo convive esto con el
  modo clásico en el mismo protocolo sin duplicar todo el motor.
- Diseño de UX/UI: cómo se ve el campo de 3 zonas, cómo se arma/reequipa
  una tríada desde la interfaz, cómo se comunica la fórmula de combate
  resultante al jugador.
