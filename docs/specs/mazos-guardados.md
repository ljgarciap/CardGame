# Spec: Mazos Guardados

**Date**: 2026-07-16 (spec retroactiva — la feature ya está implementada,
revisada por Senior Reviewer y aprobada; ver "Nota" abajo)
**Requested by**: Luis
**Status**: Done
**Project**: CardGame

## Nota sobre esta spec
Esta feature se implementó por pedido directo de Luis, saltando el flujo
normal Analyst → Architect → PM (ver `docs/memory.md`, sección "2026-07-16
(continuación 4) — Mazos guardados"). Esta spec se escribe retroactivamente
para dejar "mazos guardados" documentado con el mismo criterio que
auth-system, game-gacha-engine y realtime-match — no cambia nada del
comportamiento ya implementado, solo lo registra.

## Problem
El spec original de partidas en tiempo real (`docs/specs/realtime-match.md`
→ `docs/designs/realtime-match.md`) dejó explícitamente fuera de alcance
"deck presets guardados / múltiples mazos por jugador": el jugador elegía
sus 10 cartas de forma ad-hoc antes de cada partida, sin ninguna
persistencia. Esto significaba rearmar el mismo mazo a mano cada vez que
se quería jugar — fricción real para cualquier jugador con más de una
estrategia o que juega más de una vez seguida.

## Solution summary
El jugador puede crear, nombrar, editar y borrar múltiples mazos guardados
(cada uno con exactamente 10 cartas de su colección). El flujo de
multijugador pasa a entrar primero a "Mis Mazos" (hub), desde donde se
juega directo con un mazo ya guardado, en vez de armar la selección cada
vez. El protocolo de WebSocket de la partida no cambia: sigue recibiendo
la misma lista de `player_card_id`, ahora tomada de un mazo guardado en
vez de una selección ad-hoc.

## Users and roles
- **Cualquier jugador autenticado**: crea/lista/edita/borra únicamente sus
  propios mazos. Un mazo de otro usuario nunca es visible ni editable
  (404 al intentarlo, no 403 — no se revela que el mazo existe).
- **Superadmin**: además puede ajustar el tope de mazos guardados por
  usuario (`/api/admin/deck-config`, pantalla "ADMIN: CONFIG DE MAZOS" en
  el perfil) — es un umbral de negocio, no una constante de código (regla
  global de `CLAUDE.md`).

## Acceptance criteria
- [x] Un mazo tiene exactamente 10 cartas distintas, todas de la colección
      propia del jugador (`player_cards.user_id` = el usuario autenticado).
- [x] Crear un mazo sin escribir nombre lo autogenera (`"Mazo dd/mm
      hh:mm"`) — guardar es indispensable para poder jugar, pero nunca se
      bloquea al jugador pidiéndole que piense un nombre primero.
- [x] Listar mazos devuelve solo los del usuario autenticado, con sus 10
      cartas cada uno.
- [x] Editar un mazo permite renombrarlo y reemplazar sus 10 cartas
      (mismas reglas de validación que crear).
- [x] Borrar un mazo propio lo elimina junto con sus filas de
      `deck_cards` (`ondelete=CASCADE`).
- [x] Ningún endpoint de mazos es accesible sin autenticación (401).
- [x] Operar sobre un mazo de otro usuario (ver/editar/borrar) devuelve
      404, nunca 403 ni datos del mazo ajeno.
- [x] Hay un tope de mazos guardados por usuario, configurable por un
      superadmin sin deploy (`deck_config.max_decks_per_user`, default
      20) — al alcanzarlo, crear un mazo nuevo devuelve 400 con el
      número vigente en el mensaje.
- [x] El tope se sostiene incluso con requests concurrentes del mismo
      usuario (lock de fila sobre `User`, no solo un chequeo de
      lectura-luego-escritura) — verificado con un test de 5 threads
      reales contra un tope de 1.
- [x] Encolar una partida en tiempo real desde "Mis Mazos" usa la lista de
      cartas del mazo elegido, sin ningún cambio al protocolo WebSocket
      existente.

## Edge cases and error scenarios
- **Cantidad de cartas ≠ 10, o con IDs duplicados** → 400
  ("El mazo debe tener exactamente 10 cartas distintas").
- **Alguna carta no existe o no es del jugador** → 400 ("Alguna carta del
  mazo no existe o no te pertenece") — no distingue cuál para no filtrar
  información de otros usuarios.
- **Tope de mazos alcanzado** → 400 con el número vigente en el mensaje.
- **Requests concurrentes cerca del tope** → como mucho una crea el mazo
  extra; el resto recibe 400 (lock de fila, no race condition).
- **Nombre vacío al guardar** → autogenerado, nunca bloquea el guardado.
- **Editar/borrar un mazo ajeno** → 404.
- **Fila de configuración (`deck_config`) inexistente** (ambiente sin
  migraciones corridas, ej. tests) → se autocrea con el default (20) la
  primera vez que hace falta, sin devolver 500.
- **Endpoint admin sin ser superadmin** → 403.
- **Endpoint admin con `max_decks_per_user` ≤ 0** → 422 (validación de
  Pydantic, `Field(gt=0)`).

## Out of scope
- **"Jugar sin guardar" / mazo efímero**: evaluado explícitamente (3
  opciones presentadas a Luis: auto-nombrado, ruta paralela sin persistir,
  slot temporal reciclable) — se descartó a favor del auto-nombrado, que
  resuelve la fricción sin agregar un concepto nuevo de "mazo temporal".
- **Compartir mazos entre jugadores, mazos predefinidos por el juego,
  import/export de mazos**: no pedido, no implementado.
- **Cualquier cambio al protocolo WebSocket de partida**: sigue recibiendo
  la misma lista de `player_card_id` que antes de esta feature.
- **Paginación real de `GET /api/cards/mine`**: hallazgo ya documentado
  por separado (límite defensivo de 500, no paginación) — no es parte de
  esta feature, solo una dependencia que ya existía.

## Open questions
Ninguna bloqueante — la feature está implementada, revisada (Senior
Reviewer, 🟢) y verificada end-to-end. Dos decisiones de negocio que sí
requirieron a Luis durante la implementación ya están resueltas y
documentadas en `docs/memory.md`:
- `max_decks_per_user` es umbral de negocio (no defensivo) → tabla
  paramétrica + admin.
- UX de guardado → auto-nombrado, no forzar ni revertir a un flujo sin
  guardar.

## References
- Spec/diseño previo que deja esto fuera de alcance:
  `docs/specs/realtime-match.md`, `docs/designs/realtime-match.md`.
- Revisión senior de esta feature: `docs/reviews/mazos-guardados.md`
  (veredicto final 🟢).
- Historial de decisiones: `docs/memory.md`, secciones "2026-07-16
  (continuación 4) — Mazos guardados" y "(continuación 5) — Resolución de
  los 10 hallazgos de mazos guardados".
- Código: `backend/app/api/decks.py`, `backend/app/models/deck.py`,
  `backend/app/services/deck_config.py`,
  `frontend/lib/presentation/pages/my_decks_page.dart`,
  `frontend/lib/presentation/pages/deck_builder_page.dart`,
  `frontend/lib/presentation/pages/deck_config_admin_page.dart`.
