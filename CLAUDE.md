# CardGame — proyecto

Juego de cartas coleccionables (TCG) multiplataforma con sistema de gacha
(sobres por nivel, facciones, rarezas y rangos) y partidas en tiempo real.

El equipo de agentes, el flujo de trabajo y las reglas globales viven en
`../CLAUDE.md` (raíz del workspace Softclass). Este archivo solo documenta
lo específico de este proyecto.

---

## Stack

- **Frontend**: Flutter (Android, iOS, Web) — Riverpod, `flutter_animate`, `google_fonts`
- **Backend**: Python FastAPI — SQLAlchemy, Pydantic, WebSockets nativo
- **Base de datos**: PostgreSQL 15
- **Comunicación**: WebSockets para todo estado de partida en vivo; REST para
  marketplace/colección/perfil
- **Infraestructura**: Docker Compose (`db` + `backend`), destino VPS

Detalle completo en `docs/architecture.md`.

---

## Dominio del juego

- **Facciones**: agrupan cartas con identidad temática/mecánica propia
- **Rareza**: Common → Legendary
- **Rango**: Hero → Major God
- **Sobres (packs)**: niveles 1-5, cada uno con tabla de probabilidad propia
  de rareza/rango
- Historial de decisiones de diseño en `docs/memory.md` — actualizar tras
  cualquier cambio arquitectónico o de balance, según la regla global

---

## Equipo asignado a este proyecto

Este proyecto usa el siguiente subconjunto del equipo de agentes
(`../.claude/agents/`):

- **Analyst** — clarifica requerimientos
- **Architect** — diseño técnico, daily con Luis
- **PM** — desglose y asignación de tareas
- **UX/UI Designer** — spec visual/UX (ver sección CardGame en `ux-ui.md`)
- **Game Expert** — mecánicas, balance, gacha y economía (ver `game-expert.md`);
  interviene entre el Analyst y el Architect cuando la tarea toca reglas de
  juego, probabilidades o monetización
- **Backend Dev** — implementación FastAPI (ver sección CardGame en `backend-dev.md`)
- **Frontend Dev** — implementación Flutter (ver sección CardGame en `frontend-dev.md`)
- **Senior Reviewer** — aprobación de código antes de cerrar cualquier tarea

Roles no activados todavía en este proyecto (QA, DevOps, Cybersecurity, AI
Architect, etc.) se incorporan cuando el proyecto lo requiera, siguiendo el
flujo general del workspace.

---

## Reglas específicas del proyecto

- El motor de gacha (tablas de probabilidad) es sensible al balance del juego:
  ningún cambio se implementa sin spec previa del Game Expert
- Cualquier cambio al protocolo de mensajes WebSocket es decisión del
  Architect, no solo de implementación
- No hay design system formal todavía — el tema de facto (Material 3,
  dark-only, seed color `0xFF673AB7`, fuente Outfit) vive en
  `frontend/lib/main.dart`; ver detalle en la sección CardGame de `ux-ui.md`
