# Revisión: Motor de Gacha + Config Paramétrica (Senior Reviewer)

Spec: `docs/specs/game-gacha-engine.md`
Diseño: `docs/designs/gacha-engine.md`
Alcance revisado: Tareas 1-11 (Backend: modelos, `gacha_service.py`, endpoint
`POST /api/packs/open`, tests, `is_superadmin`, config paramétrica +
CRUD `/api/admin/gacha-config`, tests) + Tareas 5-6 (Frontend: datasource,
repository, wire de `PackOpeningPage`).

**Veredicto original: 🔴 Devuelto.** Revisión con 8 agentes en paralelo (3
ángulos de correctness + reuse + simplificación + eficiencia + altitude +
conventions) sobre el diff completo, seguida de un pase de verificación
adversarial (1-voto) sobre cada candidato de bug objetivo. 4 bugs quedaron
**CONFIRMED**, 6 hallazgos más quedaron **PLAUSIBLE** (reales pero de menor
severidad/probabilidad, o de arquitectura/proceso).

**Actualización — los 4 blockers están arreglados** (ver sección al final).
Los 6 hallazgos 🟡 quedan en backlog, no bloquean QA.

---

## 🔴 Blockers (deben arreglarse antes de QA)

### 1. `price` sin validar en el CRUD admin → mint de coins
`backend/app/api/admin/gacha_config.py:94` (`update_pack_level`) +
`backend/app/schemas/gacha_config.py:18` (`PackLevelUpdateRequest.price: int`)

Sin ninguna validación de que `price` sea positivo. `packs.py:35-42` solo
chequea `coins < price` antes de restar — con `price` negativo o cero, un
superadmin puede dar sobres gratis o, peor, **sumar coins** a cada apertura.
Ningún `CheckConstraint` en la migración tampoco lo cubre.

**Fix**: validar `price > 0` en el handler (mismo patrón que
`_validate_probability_sum`, 400 si falla) — o `Field(gt=0)` en el schema.

### 2. Suma de probabilidades válida no implica valores no-negativos
`backend/app/api/admin/gacha_config.py:48` (`_validate_probability_sum`)

Solo verifica que la suma dé ~1.0. Un payload como
`hero=-0.20, demigod=0.40, minor_god=0.40, major_god=0.40` pasa (suma=1.00).
**Verificado empíricamente**: `random.choices()` con un peso negativo no
lanza error — devuelve selecciones silenciosamente corrompidas (0 picks de
`hero` en 20,000 pruebas del verificador). Esto rompe la distribución del
gacha sin ningún error visible.

**Fix**: `_validate_probability_sum` debe rechazar (400) cualquier valor
individual `< 0`, además de la suma.

### 3. `rarity-bonus` sin ninguna validación
`backend/app/api/admin/gacha_config.py:156` (`update_rarity_bonus`)

A diferencia de los otros dos PUT, este no valida absolutamente nada. Un
bono negativo (ej. `rare = -2.0`) produce `attack`/`defense` negativos que
se persisten en `player_cards` y se devuelven al cliente — sin
`CheckConstraint` en el modelo ni chequeo en el handler.

**Fix**: como mínimo, rechazar bonos negativos (400).

### 4. Frontend: excepción no-`ApiException` deja el botón bloqueado para siempre
`frontend/lib/presentation/pages/pack_opening_page.dart:35`

`_openPack()` solo captura `on ApiException`. Un error de red, un body no-JSON,
o un valor de `rank` no reconocido (`TCGCardEntity._rankFromJson`) se propaga
sin capturar: `_isLoading` queda en `true` para siempre y el botón "OPEN PACK"
(`onPressed: _isLoading ? null : _openPack`) se deshabilita permanentemente,
sin mensaje de error, sin forma de reintentar sin salir de la pantalla.

**Fix**: agregar un `catch (e)` genérico además de `on ApiException`, que
resetee `_isLoading` y muestre un mensaje de error genérico.

---

## 🟡 Hallazgos no bloqueantes (PLAUSIBLE — recomendado atender pronto, no obligatorio para QA)

5. **TOCTOU en el precio** (`backend/app/api/packs.py:27`) — el precio se lee
   antes de tomar el lock `SELECT...FOR UPDATE` sobre el usuario, y nada lo
   re-valida contra un cambio de precio concurrente del admin antes del
   commit. Baja frecuencia, pero contradice el objetivo explícito de esta
   feature ("precio ajustable sin deploy, servidor como única fuente de
   verdad"). (Un claim relacionado de "query duplicada" fue refutado: el
   identity map de SQLAlchemy sirve la segunda lectura desde cache dentro de
   la misma sesión, no es un round-trip extra a la DB — solo una llamada
   redundante.)
6. **`KeyError` no manejado si falta una combinación en `card_archetypes`/
   `gacha_rarity_bonus`** (`backend/app/services/gacha_service.py:126,100`) —
   hoy no es alcanzable vía API (los seeds cubren el 100% de las
   combinaciones y no hay forma de dejar una fila parcial), pero el día que
   se agregue un valor nuevo a `Faction`/`Rank`/`Rarity` sin actualizar el
   seed correspondiente, esto va a tirar un 500 crudo en vez de un error
   claro.
7. **`guaranteed_min_rank` editable sin cruzar validación contra las
   probabilidades de ese mismo nivel** (`gacha_config.py:94`) — un admin
   puede configurar una garantía inconsistente con la tabla de probabilidad
   del nivel, sin que nada lo avise.
8. **Duplicación en los 3 handlers PUT** de `gacha_config.py` — mismo patrón
   de "dict de payload + loop de upsert" repetido 3 veces; agregar un 5to
   valor de Rank/Rarity requiere editar 3 lugares a mano.
9. **El gotcha de ENUMs de Postgres + Alembic no quedó institucionalizado** —
   son comentarios inline en 2 archivos de migración + una entrada en
   `memory.md`, ya se repitió dos veces en esta misma feature y no hay nada
   que evite una tercera.
10. **`CARDS_PER_PACK = 5` sigue hardcodeado** — a diferencia de
    `MIN_LEVEL`/`MAX_LEVEL` (que tienen comentario justificando la excepción),
    esto controla directamente cuánto valor recibe el jugador por compra, la
    misma categoría económica que ya se parametrizó en esta misma tarea. Es
    una decisión de alcance defendible, pero debería ser explícita (comentario
    o mover a la tabla), no un olvido silencioso.

---

## Lo que sí está bien
- Arquitectura del endpoint (`SELECT FOR UPDATE`, transacción atómica,
  identidad vía JWT) alineada con el diseño del Architect.
- 79 tests backend + 5 tests frontend pasan; el equipo encontró y corrigió 5
  bugs reales *antes* de esta revisión (redondeo half-up, dos gotchas de
  ENUM, `server_default` faltante, `random.choices` con `Decimal`) — buena
  señal de que el proceso de verificación contra Postgres real está
  funcionando, no que el código estaba descuidado.
- El endpoint público (`/api/packs/open`) en sí está bien defendido — los
  blockers 1-3 están todos del lado del CRUD *admin*, no del lado del
  jugador.

## Próximo paso
Devolver a Backend Dev (blockers 1-3) y Frontend Dev (blocker 4). Los 6
hallazgos 🟡 quedan como backlog — no bloquean QA pero conviene no
perderlos de vista, especialmente el TOCTOU de precio y la falta de
convención documentada para ENUMs de Postgres (ya causó el mismo bug dos
veces).

---

## Fixes aplicados (2026-07-15)

- **#1 (price)**: `update_pack_level` rechaza `price <= 0` con 400.
- **#2 (probabilidades negativas)**: nuevo helper `_validate_non_negative`,
  invocado desde `_validate_probability_sum` — el caso "suma da 1.0 pero un
  valor es negativo" ahora se rechaza.
- **#3 (rarity-bonus sin validar)**: `update_rarity_bonus` ahora llama a
  `_validate_non_negative` también.
- **#4 (frontend botón bloqueado)**: `_openPack()` ganó un `catch (_)`
  genérico después del `on ApiException`, resetea `_isLoading` y muestra un
  mensaje de error.

4 tests nuevos (uno por blocker, incluyendo específicamente el caso
"suma=1.0 con un valor negativo" que era el hueco real). Suite backend:
**83 tests pasan + 1 skip**. `flutter analyze` 0 errores, `flutter test`
5/5. **Veredicto actualizado: 🟢 Listo para QA.**
