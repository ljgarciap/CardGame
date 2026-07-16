# Revisión: Fix de los 10 hallazgos de mazos guardados (Senior Reviewer)

Commit revisado: `1bdb5af` — fix(decks): resolver los 10 hallazgos de la
revisión senior de mazos guardados.
Contexto: ronda de fixes sobre los 10 hallazgos abiertos en
793abf4/e0ec81e (ver `docs/memory.md`, sección "2026-07-16 (continuación
4/5)"), con dos decisiones de negocio de Luis antes de implementar (tope
de mazos = umbral de negocio → tabla paramétrica; UX de guardado →
auto-nombrado en vez de forzar/revertir).

**Veredicto original: 🟡 Aprobado con un hallazgo nuevo a corregir antes de
QA, uno más para backlog.** Los 10 hallazgos originales están genuinamente
resueltos y verificados (159 tests backend + 1 skip, `flutter analyze` sin
errores nuevos, `flutter test` 34/34, E2E real en browser). Revisión
completa de los 26 archivos del diff (no solo el diff en sí) encontró 2
hallazgos nuevos que el trabajo original no cubrió.

**Actualización — ambos cerrados.** Ver "Fixes aplicados" al final.
Verificado con la suite completa (159 passed + 1 skip, sin regresiones),
`flutter analyze`/`flutter test` sin cambios (0 errores nuevos, 34/34), y
un chequeo dirigido en vivo de cada fix (ver sección final). **Veredicto
final: 🟢 Listo para QA.**

---

## 🔴 Blocker

### 1. El mensaje de éxito en `DeckConfigAdminPage` nunca se muestra
`frontend/lib/presentation/pages/deck_config_admin_page.dart:82-96`
(`_MaxDecksSectionState._save`)

`_save()` llama a `await widget.onReloaded()`, que es `_reload()` del
padre (`_DeckConfigAdminPageState`). Ese `_reload()` hace
`setState(_loadConfig)` — reemplaza `_configFuture` por uno nuevo, lo que
hace que `AsyncFutureView`/`FutureBuilder` vuelva a `connectionState:
waiting` y desmonte todo el subárbol que `builder` devolvía, incluyendo
`_MaxDecksSection` (y su State). Para cuando `await widget.onReloaded()`
retorna y el código llega a `if (!mounted) return; setState(() =>
_successMessage = ...)`, el widget **ya está disposed** — el `mounted`
guard hace su trabajo (no crashea), pero como efecto colateral el mensaje
de éxito es código muerto: nunca se ve en pantalla.

Esto es justo lo que se observó en la verificación E2E (screenshot tras
guardar sin ningún mensaje de éxito ni error) — en su momento se atribuyó
a timing, pero es un bug reproducible al 100%, no una demora.

**Comparar con el patrón ya usado en `gacha_config_admin_page.dart`**:
`_LevelConfigSectionState._save()` nunca dispara un reload de la página
completa — solo actualiza su propio `_successMessage`/`_errorMessage`
locales, porque ya tiene el valor nuevo (lo acaba de mandar). No hay
necesidad real de re-fetch: el servidor va a devolver exactamente el valor
que se acaba de guardar.

**Fix sugerido**: sacar el parámetro `onReloaded` de `_MaxDecksSection`
por completo (no hace falta re-consultar el server para saber el valor que
uno mismo acaba de guardar) y mostrar `_successMessage` localmente, igual
que la sección de gacha.

---

## 🟡 Hallazgo no bloqueante (real pero de ventana muy angosta)

### 2. `get_or_create_deck_config` puede liberar el lock de `create_deck` antes de tiempo
`backend/app/services/deck_config.py:11-22` + `backend/app/api/decks.py:117-124`

`create_deck` toma `SELECT ... FOR UPDATE` sobre la fila de `User` para
serializar creaciones concurrentes del mismo usuario contra el tope — ese
es el fix del hallazgo original de TOCTOU. Pero inmediatamente después
llama a `get_or_create_deck_config(db)`, que si la fila `deck_config`
todavía no existe, hace `db.add(...)` + **`db.commit()`** + `db.refresh()`
— ese `commit()` cierra la transacción que sostenía el lock de `User`,
liberándolo *antes* de llegar al chequeo del tope y al `INSERT` del mazo.
Reabre, en esa ventana puntual, la misma race condition que este fix
existe para cerrar.

**Verificado empíricamente y matizado**: escribí un test descartable (no
committeado) con 25 threads concurrentes creando mazos para un usuario
nuevo, **sin** sembrar `deck_config` de antemano (a diferencia del test de
concurrencia que sí quedó en el repo, que siembra la fila primero y por
eso no ejercita este camino). Corrido 6 veces, siempre dieron exactamente
20 mazos creados (el tope), nunca más. Razón: la ventana vulnerable
requiere que un segundo request alcance a re-disputar el lock de `User`
*entre* el `commit()` interno de `get_or_create_deck_config` y el
`commit()` final del primer request — y el primer request típicamente
termina su propio tramo restante (contar, validar, insertar, commit) más
rápido de lo que Postgres tarda en despachar al siguiente esperador de la
cola de locks. Además esta fila es un singleton global (`id=1`, no por
usuario): una vez creada por el primer `create_deck` de todo el sistema,
nunca vuelve a faltar — la ventana existe una sola vez en la vida del
deployment (o en cada corrida de tests, que arman el schema con
`create_all` sin migraciones).

Por eso queda como 🟡 y no 🔴: es un defecto de diseño real (un helper
compartido no debería hacer un `commit()` a mitad de la transacción de
otro caller sin que ese caller lo sepa) pero de explotabilidad práctica
muy baja dado el singleton + la brevedad de la ventana. Igual conviene
arreglarlo porque es barato y es exactamente la clase de bug que esta
ronda se propuso eliminar.

**Fix sugerido**: `get_or_create_deck_config` no debería commitear por su
cuenta — cambiar `db.commit()` por `db.flush()` (alcanza para que la fila
sea visible y tenga su default aplicado dentro de la misma transacción) y
dejar que cada caller (el admin endpoint, `create_deck`) haga su propio
commit al final, como ya hacen ambos de todas formas.

---

## Lo que sí está bien

- Los 10 hallazgos originales genuinamente resueltos: tabla paramétrica +
  admin para el tope, auto-nombrado (con el efecto colateral bueno de
  también resolver el rebuild-por-tecla), N+1, queries redundantes, DELETE
  no-op, `mounted` checks, `owned_card_out()` compartido, `AsyncFutureView`
  compartido (adoptado también por la pantalla nueva, no solo por las 4
  originales).
- Migración inserta la fila default en el `upgrade()` mismo — el tope
  nunca queda "sin configurar" en un ambiente real que corra migraciones
  (a diferencia de gacha, que depende de un seed manual).
- Test de regresión de concurrencia real (5 threads, `with_for_update`)
  para el hallazgo original — sólido en su alcance, solo no cubre el caso
  límite del hallazgo 2 de esta revisión.
- Verificación end-to-end real en browser (no solo tests): mazo creado sin
  nombre → auto-nombrado visible en "Mis Mazos"; tope cambiado desde el
  admin → confirmado persistido vía API.
- Base de dev reseteada a estado limpio después de verificar — buena
  disciplina dado que los contenedores de dev son compartidos.

## Próximo paso
Arreglar el blocker 1 (sacar `onReloaded` de `_MaxDecksSection`) antes de
dar esta ronda por cerrada. El hallazgo 2 puede resolverse en el mismo
paso (es un cambio de una línea) o quedar documentado como backlog — a
decisión de Luis dado lo angosto de la ventana.

---

## Fixes aplicados

- **#1 (mensaje de éxito muerto)**: `deck_config_admin_page.dart` —
  `_MaxDecksSection` ya no recibe `onReloaded`; `_save()` ya no dispara el
  reload del padre, solo setea `_successMessage` local (mismo patrón que
  `GachaConfigAdminPage`). **Verificado en vivo** (Playwright, no solo
  lectura de código): cambié el tope a 12 desde el admin y el mensaje
  "Tope de mazos actualizado." apareció en pantalla — antes de este fix,
  nunca se veía.
- **#2 (lock liberado antes de tiempo)**: `get_or_create_deck_config`
  cambió su `db.commit()` interno por `db.flush()` — ya no cierra la
  transacción del caller ni le libera ningún lock que tenga tomado. Como
  `get_deck_config` (GET del admin) no tenía ningún otro commit propio, se
  le agregó uno explícito después de llamar al helper, para que la fila
  default siga persistiendo entre requests (antes lo hacía por el commit
  interno que se acaba de sacar). `update_deck_config` (PUT) y
  `create_deck` ya comiteaban por su cuenta al final, así que no
  necesitaron cambios. **Verificado en vivo**: borré la fila `deck_config`
  a mano, hice un GET (auto-creó y devolvió el default 20), confirmé la
  fila en Postgres, e hice un segundo GET en una request nueva que la vio
  persistida (no la volvió a crear) — exactamente el comportamiento que el
  fix buscaba preservar sin el commit interno.

Suite backend: 159 passed + 1 skip (sin cambios respecto a la ronda
anterior, ningún test nuevo hizo falta — ambos fixes son de
comportamiento, no de contrato). `flutter analyze`: 0 errores nuevos.
`flutter test`: 34/34.
