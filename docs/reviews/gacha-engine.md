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

**Actualización 2026-07-15 — todo cerrado.** Los 4 blockers están
arreglados (ver sección al final) y aprobados por QA. De los 6 hallazgos
🟡: 5 arreglados/documentados, 1 (`guaranteed_min_rank`) cerrado como "no es
un bug" por decisión explícita de Luis. El hallazgo cosmético de QA
(mensajes de error con `repr` de Python) está arreglado. `CARDS_PER_PACK`
(hallazgo de conventions) se movió a la tabla paramétrica por decisión de
Luis — ver sección final.

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

5. ~~**TOCTOU en el precio**~~ **— arreglado 2026-07-15.** Ver sección
   "Fix del TOCTOU de precio" al final de este documento.
6. ~~**`KeyError` no manejado si falta una combinación**~~ **— arreglado
   2026-07-15.** `_get_archetype`/`_get_rarity_bonus` ahora lanzan
   `IncompleteGachaConfigError` (mensaje claro, sin exponer detalle interno
   al cliente) en vez de un `KeyError` crudo; `packs.py` la captura y
   devuelve 500 con un mensaje limpio. Tests: 2 unitarios (la excepción se
   lanza con el dato correcto) + 1 de integración (`monkeypatch` de
   `generate_pack`, verifica el 500 limpio end-to-end sin depender de la
   aleatoriedad del RNG para forzar la combinación faltante).
7. ~~**`guaranteed_min_rank` editable sin cruzar validación**~~ **— cerrado
   2026-07-15, decisión de Luis: no es un bug.** La garantía mínima es un
   mecanismo de pity, no una propiedad derivada de la tabla de
   probabilidades — que un nivel barato garantice un rango con probabilidad
   natural baja es una decisión de balance válida, no una inconsistencia
   técnica. Agregar un umbral de validación acá requeriría inventar otro
   valor de negocio hardcodeado (exactamente lo que esta feature existe
   para evitar); si se quiere una regla real, es una decisión del Game
   Expert, no de este código. Documentado en
   `docs/designs/gacha-engine.md` (sección nueva) y con comentarios en
   `gacha_service.py`/`gacha_config.py`.
8. ~~**Duplicación en los 3 handlers PUT**~~ **— arreglado 2026-07-15.**
   Extraídos `_payload_to_values`/`_values_by_name`/`_upsert` (el patrón
   "load-or-create" queda en un solo lugar) y `_group_by_level` para el GET
   dump. Refactor puro, sin cambio de comportamiento — verificado con la
   suite completa (87 passed + 1 skip, sin tocar ningún test).
9. ~~**El gotcha de ENUMs de Postgres + Alembic no quedó
   institucionalizado**~~ **— cerrado 2026-07-15.** Nueva sección "Backend
   Conventions" en `docs/architecture.md` con el checklist de los 4 gotchas
   reales encontrados en esta feature (reusar un ENUM existente sin
   `create_type=False`, no dropear el tipo en el downgrade, verificar
   siempre contra Postgres real y no solo `Base.metadata.create_all`, y
   `server_default` faltante en un `ADD COLUMN NOT NULL`), con ejemplos de
   código copiables. Documentación pura, sin cambio de código.
10. ~~**`CARDS_PER_PACK = 5` sigue hardcodeado**~~ **— arreglado
    2026-07-15c.** Movido a `gacha_pack_levels.cards_per_pack` (por nivel,
    no global, mismo criterio que `price`). `PUT pack-levels/{level}` ahora
    requiere `cards_per_pack` en el body (valida `> 0`) — **breaking change
    de contrato**, el frontend (`GachaConfigRemoteDatasource`,
    `GachaConfigRepositoryImpl`, `GachaConfigAdminPage`, y el fake de tests)
    se actualizó en el mismo cambio; se detectó el break probándolo en vivo
    contra el backend real (curl sin el campo nuevo → 422) antes de tocar
    Flutter, no después. Migración con `server_default='5'` verificada
    contra una fila existente + ciclo upgrade→downgrade→upgrade. Suite:
    90 passed + 1 skip (backend), 10/10 (frontend).

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

---

## Fix del TOCTOU de precio (2026-07-15, post-QA)

`backend/app/api/packs.py::open_pack` ahora toma `SELECT ... FOR UPDATE`
sobre la fila de `gacha_pack_levels` correspondiente al nivel, **antes** de
leer `price` y **antes** de lockear la fila del usuario. Orden de locks
documentado en el código (`pack_level` primero, `user` después) para evitar
deadlocks si en el futuro se agregan más locks a esta transacción.

No se tocó `gacha_config.py` (el lado admin): un `UPDATE` de SQLAlchemy ya
toma el lock de fila necesario de forma atómica al ejecutarse, así que el
lado de escritura ya era seguro — el hueco estaba solo en el lado de lectura
de `packs.py`, que guardaba el precio en una variable de Python sin lock
antes de usarlo.

**Verificado con un lock real, no un test sintético**: un script separado
mantuvo `SELECT ... FOR UPDATE` sobre `gacha_pack_levels level=1` durante 12
segundos (conexión de Postgres distinta a la del servidor); un
`POST /api/packs/open` disparado mientras el lock estaba tomado tardó
**11.96 segundos** en responder (200, precio correcto cobrado) — bloqueado
hasta que el lock se liberó. Suite completa sigue en 84 tests pasan + 1 skip,
sin regresiones.
