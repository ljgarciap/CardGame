# Memory Log - Card Game

## 2026-04-24
- **Project Started**: Initialization of the card game project.
- **Frontend Choice**: Flutter (Multiplatform).
- **Backend Selection**: Python (FastAPI) selected for real-time concurrency.
- **Database Selection**: PostgreSQL selected for persistence.
- **Infrastructure**: VPS selected for deployment.
- **Initial Files**: Created `memory.md` and `architecture.md`.
- **Project Reorganization**: Moved to a monorepo structure (`frontend/`, `backend/`, `docs/`).
- **TCG & Gacha System**: Defined logic for Factions, Rarity (Common-Legendary), and Ranks (Hero-Major God).
- **Pack Probabilities**: Implemented a level-based pack system (Level 1-5) with probability tables for ranks and rarities.
- **Domain Entities**: Updated `CardEntity` and created `CardPackEntity` in `frontend/`.
- **Marketplace UI**: Created `MarketplacePage` with a grid of packs, prices, and level-based styling.
- **Pack Opening System**: Implemented `PackOpeningPage` with floating animations, dramatic opening sequence, and card reveal logic.
- **Git Repository**: Initialized Git monorepo with a comprehensive global `.gitignore`.

## 2026-07-12
- **Equipo de agentes**: configurado para el proyecto (Analyst, Architect, PM, UX/UI, Game Expert, Backend Dev, Frontend Dev, Senior Reviewer) — ver `CLAUDE.md`.
- **Motor de gacha**: spec de diseño de juego (`docs/specs/game-gacha-engine.md`) y diseño técnico (`docs/designs/gacha-engine.md`) completos, pero **bloqueados** — requieren autenticación real primero (decisión de Luis).
- **Sistema de autenticación**: priorizado como siguiente feature. Spec (`docs/specs/auth-system.md`) y diseño técnico (`docs/designs/auth-system.md`) aprobados: email+password, JWT sin refresh token, verificación de email obligatoria, reset de password, perfil con username único y avatar de presets.
- **Backend — Tarea 1 (modelo `User` + migración Alembic)**: implementada. `app/core/config.py`, `app/db/base.py`, `app/db/session.py`, `app/models/user.py`, Alembic inicializado y configurado contra `Base.metadata`. Migración `create_users_table` generada y verificada (upgrade → downgrade → upgrade) contra Postgres real.
- **Backend — Tarea 2 (hash de password + JWT)**: implementada en `app/core/security.py`. Cambio de diseño menor: `passlib[bcrypt]` reemplazado por `bcrypt` directo (passlib 1.7.4 es incompatible con bcrypt ≥4.1 — verificado, ver nota en `docs/designs/auth-system.md`). JWT vía `python-jose`, HS256, 7 días, sin refresh token. 8 tests unitarios pasando (`backend/tests/test_security.py`).
- **Backend — Tarea 3 (email + Mailhog)**: `app/core/email.py` (`send_email` vía `aiosmtplib`). Agregado servicio `mailhog` a `docker-compose.yml` (SMTP dev en :1025, UI en :8025) y variables `JWT_SECRET_KEY`/`SMTP_*` al servicio `backend`. Verificado end-to-end contra un Mailhog real (correo recibido con To/Subject/Body correctos). Test automatizado en `backend/tests/test_email.py` (se salta si no hay SMTP disponible, pasa cuando sí lo hay).
- **Backend — Tarea 4 (endpoints register/verify/resend)**: `app/api/auth.py` + `app/schemas/auth.py` + `app/core/constants.py` (avatares preset). Router montado en `main.py`. 10 tests de integración en `backend/tests/test_auth.py` contra Postgres real (duplicados de email/username, password corto, avatar inválido, verificación con token válido/inválido/expirado, resend con mensaje genérico y sin reenviar a usuarios ya verificados) — todos pasando.
- **Backend — Tarea 5 (login/reset-password)**: `POST /api/auth/login`, `POST /api/auth/request-password-reset`, `POST /api/auth/reset-password` en `app/api/auth.py`. 9 tests en `backend/tests/test_login_and_reset.py`: login correcto emite JWT válido, no verificado → 403, credenciales incorrectas y email inexistente → mismo 401/mensaje, reset con token válido cambia el password (login con el nuevo funciona, con el viejo falla), token de reset se invalida tras un solo uso, token inválido/expirado → 400. Suite completa: 27 pasan + 1 skip (Mailhog no corriendo, esperado).
- **Backend — Tarea 6 (`/users/me` GET/PATCH)**: `app/api/deps.py` (`get_current_user`, JWT vía `HTTPBearer`, reutilizable por futuros endpoints autenticados), `app/api/users.py`, `app/schemas/user.py`. Refactor: validaciones de username/avatar/password extraídas a `app/schemas/validators.py` (antes duplicadas entre register y reset). 7 tests en `backend/tests/test_users.py`. Con esto, las Tareas 1-6 del sistema de auth (diseño en `docs/designs/auth-system.md`) están implementadas del lado backend — 34 tests pasan + 1 skip (Mailhog). La Tarea 7 del diseño ("tests" como tarea separada) queda cubierta por los tests ya escritos junto a cada tarea, no hace falta repetirla.
- **Frontend — Tareas 8-10 (registro/login/reset/perfil + sesión)**: capa completa Flutter para el sistema de auth. `domain/entities/user_account.dart`, `domain/repositories/auth_repository.dart`, `data/datasources/auth_remote_datasource.dart` + `token_storage.dart` (flutter_secure_storage), `data/repositories/auth_repository_impl.dart`, `presentation/providers/auth_provider.dart` (Riverpod `Notifier`, restaura sesión al abrir la app). Pantallas: `register_page.dart`, `login_page.dart`, `verify_email_pending_page.dart`, `forgot_password_page.dart`, `reset_password_page.dart` (token editable manualmente — deep link queda pendiente), `profile_page.dart`. `main.dart` ahora envuelve la app en `ProviderScope` y usa un `AuthGate` que decide login vs. menú principal según la sesión persistida. Nuevas dependencias: `http`, `flutter_secure_storage`.
  - Verificado con 5 widget tests (`test/presentation/auth_flow_test.dart`, repositorio falso) y contra el **backend real construido con Docker** (no solo el host): levanté `docker compose build backend` + stack completo en puertos temporales, corrí la migración dentro del contenedor y probé el flujo real register → verify-email (token extraído de Mailhog) → login → GET/PATCH `/users/me`. Todo correcto. `docker-compose.yml` quedó restaurado a sus puertos originales tras la prueba.
  - Limpieza de paso: eliminé `frontend/test/widget_test.dart` (test de plantilla del contador de Flutter, roto desde antes de este trabajo — referenciaba una clase `MyApp` inexistente).
  - **Limpieza de código muerto** (a pedido de Luis, tras verificar que nada lo usaba): eliminé `frontend/lib/domain/entities/deck.dart`, `player.dart` y `game_state.dart`. `deck.dart`/`player.dart` no compilaban (referenciaban `CardEntity`/`CardSuit`/`CardValue`, tipos inexistentes — el modelo real es `TCGCardEntity`/`CardRarity`/`CardRank` en `card.dart`); `game_state.dart` era su único consumidor y tampoco lo importaba nadie más (verificado con `grep` en `lib/` y `test/` antes de borrar). `flutter analyze` pasó de 9 errores a 0; los 5 widget tests de auth siguen pasando.

## 2026-07-15
- **Motor de gacha — desbloqueado**: revisé `docs/designs/gacha-engine.md` ahora que el sistema de auth está completo. La "decisión pendiente para Luis" de la versión 2026-07-12 (tabla `players` mínima con `player_id` spoofable, sin login) queda resuelta: se elimina esa tabla y `player_cards.user_id` referencia directamente a `users.id`; la identidad del jugador sale del JWT (`Depends(get_current_user)`, mismo patrón que `/api/users/me`), no de un id enviado en el body. `users.coins` (ya existe desde la Tarea 1 de auth) es el saldo a descontar, no se agrega columna nueva. Endpoint `POST /api/packs/open` protegido con Bearer token. Diseño queda **listo para PM** — sin bloqueos pendientes.
- **PM**: diseño desglosado en 6 tareas (4 Backend, 2 Frontend), sin DevOps/Tech Writer (no activados en este proyecto). Backend secuencial (modelos → servicio → endpoint → tests), Frontend puede arrancar en paralelo mockeando el contrato.
- **Backend — Tarea 1 (modelos + migración + seed)**: `app/models/enums.py` (`Faction`/`Rank`/`Rarity`), `app/models/card_archetype.py`, `app/models/player_card.py`, `app/db/seed.py` (seed idempotente de los 20 arquetipos). Migración `351803a2ed78_create_gacha_tables.py` generada con autogenerate y corregida a mano: el `downgrade()` auto-generado no eliminaba los tipos ENUM de Postgres (`faction`, `rank`, `rarity`) — un `drop_table` no los limpia, y eso rompía un `upgrade` posterior con `type already exists`. Se agregó `sa.Enum(...).drop(op.get_bind(), checkfirst=True)` explícito para cada tipo. Verificado upgrade→downgrade→upgrade contra Postgres real.
- **Backend — Tarea 2 (`gacha_service.py`)**: RNG ponderado (`random.SystemRandom`), tablas de rango/rareza por nivel, escalera de garantía (niveles 3-5). Verificado con smoke test estadístico (500 aperturas/nivel) contra Postgres real: distribuciones consistentes, garantía se cumple 100% en niveles 3-5.
- **Backend — Tarea 3 (`POST /api/packs/open`)**: `app/schemas/pack.py` + `app/api/packs.py`, protegido con `Depends(get_current_user)`, transacción con `SELECT...FOR UPDATE` sobre la fila del usuario. Router montado en `main.py`. Verificado 200/400/401/402 contra Postgres real, incluyendo que un 402 no tiene efectos secundarios (ni coins ni cartas).
- **Backend — Tarea 4 (tests estadísticos)**: `tests/test_gacha_service.py` (distribución de rango/rareza sobre 10,000 cartas/nivel, garantía mínima, fórmula de stats) y `tests/test_packs.py` (integración del endpoint). **Bug real encontrado y corregido**: `round()` de Python usa banker's rounding (redondeo half-to-even) — `round(30 * 1.35)` da 40, pero la tabla oficial del spec (`docs/specs/game-gacha-engine.md`) exige 41 para Hero+Legendary (redondeo half-up). Se reemplazó `round()` nativo por un helper con `decimal.ROUND_HALF_UP` en `gacha_service._calculate_stats`, verificado contra los 20 valores de la tabla del spec. Suite completa: 66 tests pasan + 1 skip (Mailhog).
- **Arquitecto — revisión 2026-07-15b**: `../CLAUDE.md` (workspace) sumó una regla global reforzada en Binax: ningún umbral/margen/porcentaje/divisor de negocio va hardcodeado en código, siempre en tabla paramétrica con CRUD + vista de admin. Aplica directo a `RANK_PROBABILITIES`, `RARITY_PROBABILITIES`, `RARITY_BONUS` y `PACK_PRICE_PER_LEVEL` de `gacha_service.py` (Tareas 1-4, ya implementadas con esos valores hardcodeados). Se frenó Frontend (Tareas 5-6 de PM) y se rediseñó: nuevas tablas `gacha_pack_levels`/`gacha_rank_probabilities`/`gacha_rarity_probabilities`/`gacha_rarity_bonus`, CRUD en `/api/admin/gacha-config` protegido por un flag nuevo `users.is_superadmin` (no existía ningún concepto de admin en el proyecto). Decisión de Luis: esta iteración es solo backend (tablas + CRUD); la pantalla Flutter de administración queda como tarea separada de Frontend Dev, no bloquea el motor de gacha. Diseño actualizado en `docs/designs/gacha-engine.md`, PM desglosó 5 tareas nuevas de Backend Dev (#7-#11).
- **Backend — Tarea 8 (modelos config paramétrica + migración + seed)**: `app/models/gacha_config.py` (`GachaPackLevel`, `GachaRankProbability`, `GachaRarityProbability`, `GachaRarityBonus`) + `app/db/seed_gacha_config.py` (mismos valores que estaban hardcodeados). **Segundo bug de migración con ENUMs de Postgres encontrado y corregido** (mismo patrón que la Tarea 1, distinta causa): estas tablas nuevas reutilizan los tipos `rank`/`rarity` ya creados por la migración de `card_archetypes`; el autogenerate de Alembic emite `sa.Enum(..., name='rank')` sin `create_type=False`, lo que intenta un `CREATE TYPE` duplicado y rompe con `DuplicateObject` en un upgrade limpio (no hace falta downgrade previo para disparar esto, a diferencia del bug de la Tarea 1). Fix: `postgresql.ENUM(..., name=..., create_type=False)` para toda columna que reutilice un tipo ENUM ya creado en una migración anterior. Verificado upgrade→downgrade→upgrade y seed contra Postgres real (cada nivel suma exactamente 1.0 en rank/rarity probabilities).
- **Nota de proceso**: a partir de la Tarea 8, dejo un Postgres+backend de Docker corriendo persistente (`cardgame_pg_dev`/`cardgame_dev_net`) para verificar todas las tareas de esta feature, en vez de crear/destruir el ciclo completo (red+contenedor+build) en cada tarea — a pedido de Luis, por la fricción de tantos permission prompts de Docker seguidos.
- **Backend — Tarea 9 (refactor `gacha_service.py` a DB)**: `generate_pack` ya no usa los `dict` de módulo, consulta `gacha_pack_levels`/`gacha_rank_probabilities`/`gacha_rarity_probabilities`/`gacha_rarity_bonus` en cada llamada. `get_pack_price` ahora recibe `db`. **Tercer bug real encontrado y corregido**: `random.choices()` (usado en `weighted_choice`) rompe con `TypeError: unsupported operand type(s) for +: 'decimal.Decimal' and 'float'` si los `weights` son `Decimal` — internamente hace `cum_weights[-1] + 0.0`. Antes no aparecía porque las probabilidades eran `float` hardcodeado; ahora que vienen de columnas `Numeric` (Decimal), hay que convertir a `float` explícitamente en `weighted_choice`. Detectado por la suite completa (16 tests fallando), no por inspección manual. Verificado con la suite corrida dos veces: 68 passed + 1 skip.
- **Backend — Tarea 10 (CRUD `/api/admin/gacha-config`)**: `app/schemas/gacha_config.py` + `app/api/admin/gacha_config.py`. `GET` (dump completo) + 3 `PUT` (pack-levels/{level}, rank-probabilities/{level}, rarity-probabilities/{level}, rarity-bonus), todos con `Depends(get_current_superadmin)` a nivel de router. Validación de suma de probabilidades (400, tolerancia ±0.0001) hecha a mano en el handler, no con un `field_validator` de Pydantic — así devuelve 400 como pide el diseño en vez del 422 que daría una validación de Pydantic (mismo criterio que ya usa `packs.py` para el chequeo de `level`). Verificado con smoke test manual contra Postgres real: 401/403/200/400/404, y que `gacha_service.get_pack_price` ve el cambio de precio inmediatamente después de un `PUT` (sin caché). **Nota operativa**: el fixture `_setup_db` de `conftest.py` hace `drop_all` después de cada test, así que correr un script manual (no pytest) contra el Postgres persistente después de una corrida de la suite requiere resetear el schema (`DROP SCHEMA public CASCADE` + `alembic upgrade head`) antes — si no, las tablas no existen aunque `alembic_version` diga que sí.
- **Backend — Tarea 11 (tests de config paramétrica)**: `tests/test_gacha_config_admin.py` — 11 tests (401/403/200 en GET, 200/403/404 en PUT pack-levels, 200/400 en PUT rank-probabilities y rarity-probabilities por suma inválida, PUT rarity-bonus, y que `gacha_service.get_pack_price` refleja un cambio de precio sin caché). Con esto, las Tareas 7-11 de la revisión de config paramétrica (`docs/designs/gacha-engine.md`) quedan completas del lado Backend. Suite completa: **79 tests pasan + 1 skip** (Mailhog). En total durante esta feature se encontraron y corrigieron 5 bugs reales antes de llegar a Senior Reviewer: redondeo half-up vs banker's rounding, dos gotchas de ENUMs de Postgres en Alembic (downgrade no limpia tipos; autogenerate no pone `create_type=False` al reusar un tipo), falta de `server_default` en un `ADD COLUMN NOT NULL`, y `random.choices()` incompatible con pesos `Decimal`.
- **Frontend — Tareas 5-6 (datasource/repository de packs + wire de `PackOpeningPage`)**: `data/datasources/pack_remote_datasource.dart` (mismo patrón que `auth_remote_datasource.dart`), `data/repositories/pack_repository_impl.dart` (reutiliza `TokenStorage`), `domain/repositories/pack_repository.dart`, `presentation/providers/pack_provider.dart`. `card.dart` ganó `TCGCardEntity.fromJson` — el backend manda `rank` en snake_case (`minor_god`, `major_god`), no coincide con los nombres camelCase del enum Dart (`minorGod`, `majorGod`), hace falta un mapeo explícito (`faction`/`rarity` sí matchean 1:1). `pack.dart` ganó `PackOpenResultEntity`. `pack_opening_page.dart` reescrita a `ConsumerStatefulWidget`: `_generateRandomCard()` local eliminado, ahora llama a `packRepositoryProvider`, muestra loading y el mensaje de `ApiException` (402/400/401) en vez de romper, y dispara `authNotifierProvider.refreshProfile()` (sin bloquear la animación) para que `ProfilePage` refleje el nuevo saldo de coins.
  - **Verificación**: `flutter analyze` (0 errores, solo infos preexistentes de `withOpacity` deprecado) y `flutter test` (5/5 widget tests de auth siguen pasando). No había `chromium-cli` ni Playwright instalados en este entorno para manejar un browser headless y ver la UI renderizada — en su lugar corrí la cadena real de datos (`PackRemoteDatasource` + `PackOpenResultEntity.fromJson`/`TCGCardEntity.fromJson`, el mismo código que usa la página) contra el backend real vía `dart run --define=API_BASE_URL=...`: 200 con 5 cartas parseadas correctamente (incluyendo el mapeo de rank), 400 nivel inválido, 401 token inválido, 402 saldo insuficiente — los cuatro casos que la página maneja. **Pendiente**: nadie vio la animación/UI renderizada en un browser real; si se consigue `chromium-cli`/Playwright en este entorno más adelante, vale la pena una pasada visual antes de dar la feature por 100% verificada de cara al usuario.
- **Senior Reviewer — revisión 2026-07-15b**: revisión con 8 agentes en paralelo (correctness x3, reuse, simplificación, eficiencia, altitude, conventions) sobre el diff completo (Tareas 1-11 backend + 5-6 frontend), más un pase de verificación adversarial sobre cada candidato de bug. **Veredicto: devuelto, 4 blockers 🔴** — reporte completo en `docs/reviews/gacha-engine.md`. Resumen: (1) `PUT pack-levels/{level}` acepta `price` negativo/cero sin validar → mint de coins vía `packs.py`; (2) `_validate_probability_sum` solo chequea que la suma dé 1.0, no que cada valor sea no-negativo → un valor negativo compensado corrompe `random.choices()` silenciosamente (verificado empíricamente: 0 picks de un rank en 20,000 pruebas); (3) `PUT rarity-bonus` no valida absolutamente nada → bono negativo produce `attack`/`defense` negativos persistidos; (4) frontend `_openPack()` solo captura `ApiException`, cualquier otra excepción deja el botón "OPEN PACK" deshabilitado para siempre sin mensaje de error. 6 hallazgos más quedaron como 🟡 backlog no bloqueante (TOCTOU de precio, `KeyError` no defendido si falta una combinación de config, `guaranteed_min_rank` sin cruzar validación contra las probabilidades del mismo nivel, duplicación entre los 3 handlers PUT del CRUD admin, gotcha de ENUMs de Postgres+Alembic no institucionalizado — ya se repitió dos veces en esta misma feature —, y `CARDS_PER_PACK` hardcodeado sin justificación explícita). Tareas de fix creadas (#12-#15) para Backend Dev/Frontend Dev.
- **Fixes de los 4 blockers (#12-#15)**: `_validate_non_negative` nuevo en `gacha_config.py`, reusado por `_validate_probability_sum` (fix #2) y por `update_rarity_bonus` (fix #3, antes sin ninguna validación); `update_pack_level` rechaza `price <= 0` (fix #1). Frontend: `_openPack()` ganó un `catch (_)` genérico después del `on ApiException` (fix #4). 4 tests nuevos cubriendo cada caso (incluyendo el caso "suma da 1.0 pero un valor es negativo", que era exactamente el hueco que dejaba pasar el bug). Suite backend: **83 tests pasan + 1 skip**. `flutter analyze` 0 errores, `flutter test` 5/5.

- **QA — 2026-07-15**: `docs/qa/gacha-engine-2026-07-15.md`. Validación en vivo contra el backend real corriendo (`curl`, no solo `TestClient`/pytest): los 5 criterios de aceptación del spec pasan, los 4 blockers del Senior Reviewer confirmados arreglados en vivo, 3 controles positivos confirman que la validación nueva no rompió los casos válidos. Hallazgo cosmético nuevo (no bloqueante): los mensajes 400 de validación de negatividad devuelven la `repr` de Python del enum en el JSON en vez de un mensaje limpio. **Veredicto: ✅ Aprobado.**
- **Commit**: motor de gacha + config paramétrica (34 archivos, backend + frontend) commiteado como un solo commit `feat(gacha): ...` — mismo criterio que el commit único de auth.
- **Frontend — pantalla de admin de GachaConfig** (backlog que había quedado explícitamente diferido el 2026-07-15b): `GachaConfigAdminPage`, gateada en `ProfilePage` detrás de `user.isSuperadmin`. Requirió un cambio chico de backend primero: `UserProfileResponse` (`/api/users/me`) no exponía `is_superadmin`, así que el cliente no tenía forma de saber si mostrar la entrada — se agregó el campo + test. Capa de datos: `GachaConfigRemoteDatasource`/`GachaConfigRepositoryImpl`/provider, mismo patrón que auth/packs. **Refactor oportunista**: al ser el 3er datasource con la misma duplicación de `_decodeOrThrow`/`_extractErrorMessage`/headers (byte a byte igual en los 3), se extrajo `BaseRemoteDatasource` compartido y se migraron los 3 datasources existentes — regla de tres, no una decisión prematura. También se extrajo `CardRankApi` (extension con `apiValue`/`fromApiValue`) desde el mapeo privado que antes solo vivía en `TCGCardEntity`, porque ahora hace falta en ambas direcciones (parsear Y serializar) en dos lugares. Las probabilidades/bono de la pantalla se manejan como `String` (no `double`) para no perder precisión en el round-trip con los campos `Decimal` del backend.
  - **Verificación**: capa de datos verificada en vivo contra el backend real (mismo patrón `dart run --define=...` que la feature anterior) — dump parseado correctamente, serialización de `CardRank` enum->string en el PUT, validación de negatividad reflejada. La pantalla en sí (`GachaConfigAdminPage`) se verificó con **widget tests nuevos** (`test/presentation/gacha_config_admin_test.dart`, 5 tests con un `FakeGachaConfigRepository` — mismo patrón que `fake_auth_repository.dart`) ya que seguía sin haber browser disponible: carga y muestra los 5 niveles + bono, error 403 al cargar con botón reintentar, guardar un nivel dispara los 3 PUT en orden y muestra éxito, error 400 del servidor se muestra inline, guardar el bono llama al repositorio. Gotcha de testing (no de la app): `ExpansionTile` expandido queda fuera del viewport default de 800x600 del test — hace falta `tester.ensureVisible()` antes de tapear el botón de guardar, si no `tester.tap()` falla con "no hit testable". Suite completa: **10/10 tests frontend pasan**, `flutter analyze` 0 errores.

Los 6 hallazgos 🟡 de `docs/reviews/gacha-engine.md` quedan en backlog, no bloquean.

## 2026-07-15 (continuación)
- **Fix del TOCTOU de precio** (hallazgo #5 del backlog, `docs/reviews/gacha-engine.md`): `packs.py::open_pack` ahora toma `SELECT...FOR UPDATE` sobre `gacha_pack_levels` antes de leer el precio y antes de lockear al usuario (orden documentado en el código para evitar deadlocks futuros). No hizo falta tocar el CRUD admin — un `UPDATE` de SQLAlchemy ya lockea la fila atómicamente al ejecutarse, el hueco estaba solo del lado de lectura. **Verificado con un lock real** (no un test sintético): un script separado mantuvo el lock 12s, un `POST /api/packs/open` disparado durante ese lock tardó 11.96s en responder — bloqueado hasta que se liberó. Suite completa: 84 passed + 1 skip, sin regresiones. Quedan 5 hallazgos 🟡 en el backlog.
- Ambos commits de la feature (motor de gacha + pantalla de admin) pusheados a `origin/master` (`fc1e286`), más el fix del TOCTOU (`b4ef671`).
- **Fix del `KeyError` no defendido** (hallazgo #6 del backlog): `gacha_service.py` gana `IncompleteGachaConfigError` + `_get_archetype`/`_get_rarity_bonus` (lookups con mensaje claro en vez de subscript directo). `packs.py` la captura y devuelve 500 limpio ("Error de configuración del gacha. Contactá a soporte.") sin exponer qué combinación falta. Tests deterministas (no dependen del RNG): 2 unitarios de las funciones de lookup + 1 de integración con `monkeypatch` sobre `generate_pack`. Suite completa: 87 passed + 1 skip.
- **Fix de la duplicación del CRUD admin** (hallazgo #8): extraídos `_payload_to_values`/`_values_by_name`/`_upsert` (el patrón "load-or-create" repetido en los 3 PUT queda en un solo lugar) y `_group_by_level` para el GET dump. Refactor puro, sin cambio de comportamiento — verificado con la suite completa sin tocar ningún test (87 passed + 1 skip, mismo resultado que antes del refactor). - **`guaranteed_min_rank` sin cruzar validación (hallazgo #7) — cerrado como "no es un bug"**, decisión de Luis: la garantía mínima es un mecanismo de pity, no una propiedad derivada de la tabla de probabilidades; validar esa interacción requeriría inventar otro umbral de negocio hardcodeado (lo que esta feature existe para evitar). Si se quiere una regla real, es decisión del Game Expert. Documentado con una sección nueva en `docs/designs/gacha-engine.md` + comentarios en `gacha_service.py`/`gacha_config.py`. Suite sin cambios de comportamiento: 87 passed + 1 skip.

- **Convención de ENUMs de Postgres+Alembic institucionalizada (hallazgo #9)**: nueva sección "Backend Conventions" en `docs/architecture.md` con el checklist completo de los 4 gotchas reales de esta feature (reusar ENUM sin `create_type=False`, no dropear el tipo en downgrade, verificar siempre contra Postgres real, `server_default` faltante en `ADD COLUMN NOT NULL`), con snippets de código copiables. Documentación pura.

**Con esto, los 6 hallazgos 🟡 de la revisión de Senior Reviewer quedan cerrados** (5 arreglados, 1 cerrado como "no es un bug" por decisión de Luis). Quedan sueltos: el hallazgo cosmético de QA (mensajes de error con `repr` de Python) y la decisión sobre `CARDS_PER_PACK` hardcodeado — ninguno de los dos tenía consenso todavía sobre si vale la pena tocarlo.

## 2026-07-15 (continuación 2)
- **Fix del hallazgo cosmético de QA**: `_validate_non_negative` (`app/api/admin/gacha_config.py`) armaba el mensaje 400 dejando que el f-string usara `repr()` del dict (`"{<Rank.hero: 'hero'>: Decimal('-0.2')}"`). Ahora arma el texto con `k.value`/`str(v)` — mensaje legible (`"hero: -0.2"`). Test nuevo que fija el formato. Suite: 87 passed + 1 skip. `docs/qa/gacha-engine-2026-07-15.md` actualizado. Con esto, de todo lo encontrado en la revisión de esta feature solo queda pendiente de decisión `CARDS_PER_PACK` hardcodeado.

## 2026-07-15 (continuación 3)
- **`CARDS_PER_PACK` movido a la tabla paramétrica** (decisión de Luis): `gacha_pack_levels` gana `cards_per_pack` (por nivel, no global). `generate_pack` lee `pack_level.cards_per_pack` en vez de la constante. Migración con `server_default='5'` (siguiendo el checklist de `docs/architecture.md`), verificada con una fila existente insertada a mano + ciclo upgrade→downgrade→upgrade. CRUD: `PUT pack-levels/{level}` ahora exige `cards_per_pack` en el body (valida `>0`).
  - **Breaking change de contrato detectado y arreglado en el mismo cambio**: probé el body viejo (sin `cards_per_pack`) contra el backend real → 422 `"Field required"`, confirmando que rompía la pantalla de admin de Flutter ya construida. Actualicé `GachaPackLevelConfig`, `GachaConfigRemoteDatasource.updatePackLevel`, `GachaConfigRepository`/`RepositoryImpl`, `GachaConfigAdminPage` (nuevo campo "Cartas por sobre") y el fake de tests — todo en el mismo commit, no quedó roto entre pasos.
  - Suite: **90 passed + 1 skip** (backend, +3 tests nuevos), **10/10** (frontend). `flutter analyze` 0 errores.
  - Con esto, **no queda nada pendiente** de la revisión de Senior Reviewer/QA de esta feature.

## 2026-07-15 (continuación 4) — Marketplace desconectado de la config real
Detectado al preguntar "qué queda faltando": `marketplace_page.dart` seguía mostrando 3 packs hardcodeados en el cliente (precio calculado a mano como `nivel*1000`), sin leer nunca `gacha_pack_levels` — si un admin cambiaba el precio vía el CRUD, el jugador seguía viendo el precio viejo.

- **Backend**: `GET /api/packs/levels` nuevo en `packs.py` — cualquier usuario autenticado (no solo superadmin), reusa el schema `PackLevelOut` que ya existía para el admin dump. No hay nada sensible en precio/cantidad de cartas, y el spec de juego exige que las probabilidades de gacha nunca se oculten al jugador. Test: 401 sin token, 200 con los 5 niveles reales del seed.
- **Frontend**: `PackRepository` gana `getPackLevels()` (reusa `GachaPackLevelConfig`, ya existía para la pantalla de admin — sin duplicar entidad). `BaseRemoteDatasource` gana `decodeListOrThrow` (el endpoint devuelve un array JSON, no un objeto — la primera vez que un datasource necesita eso). `MarketplacePage` reescrita a `ConsumerStatefulWidget`, fetch real con loading/error/reintentar.
- **Limpieza de código muerto**: `PackLevel`/`CardPackEntity` en `pack.dart` eran mock data de la era pre-motor-de-gacha-server-authoritative (tablas de probabilidad hardcodeadas en el cliente que ya no se usaban desde que `PackOpeningPage` se conectó al backend real, semanas atrás). Confirmé que `PackOpeningPage` solo leía `pack.level.level` de todo `CardPackEntity` — lo simplifiqué a `required int level` y borré las dos clases muertas.
- **Gotcha de testing nuevo**: `pumpAndSettle()` cuelga con timeout en pantallas con animaciones `repeat(reverse: true)` (el shimmer del ícono de sobre) — nunca "settlea" porque la animación no termina nunca. Fix: pump acotado (`pump()` + `pump(Duration)`) en vez de `pumpAndSettle()` para estas pantallas.
- Verificado en vivo contra el backend real (`dart run`, mismo patrón de siempre): los 5 niveles parsean correctamente con los valores reales del seed. Suite: **92 passed + 1 skip** (backend), **13/13** (frontend, incluye `marketplace_page_test.dart` nuevo con fake repository).

## 2026-07-15 (continuación 5) — Deep link de reset-password
Último loose-end de la lista de "qué queda faltando": el token de reset-password se seguía pegando a mano desde que se implementó auth (2026-07-12).

- **Decisión**: custom URL scheme (`cardgame://reset-password?token=...`), no Universal/App Link HTTPS — `cardgame.local` (el dominio que ya usaba el email) no es un dominio real, no hay dónde hostear `apple-app-site-association`/`assetlinks.json` para verificarlo. Un custom scheme no necesita esa infraestructura.
- **Backend**: `_send_password_reset_email` en `auth.py` arma el link nuevo. Sin cambios de tests (ninguno aseraba el formato de URL).
- **Frontend**: dependencia nueva `app_links: ^6.4.1`. `main.dart` (convertido a `ConsumerStatefulWidget`, gana `navigatorKey`) escucha cold-start (`getInitialLink()`) y links en caliente (`uriLinkStream`), parsea con `core/deep_link.dart::extractResetPasswordToken` (función pura, 5 tests unitarios sin necesidad de dispositivo) y navega a `ResetPasswordPage` pre-rellenada. iOS (`Info.plist` `CFBundleURLTypes`) y Android (`AndroidManifest.xml` intent-filter) registran el scheme. El campo de token manual sigue como fallback, sin tocar.
- **Verificado**: email real contra un Mailhog temporal — el body contiene `cardgame://reset-password?token=...` con el formato correcto. Suite: 92 passed + 1 skip (backend), 18/18 (frontend, +5 tests de `deep_link_test.dart`).
- **Límite explícito**: no hay simulador/dispositivo en este entorno — no se pudo confirmar que el OS efectivamente abre la app al tocar el link (el ruteo nativo real de iOS/Android). Recomendado probarlo en un dispositivo/simulador antes de darlo por 100% cerrado.

## 2026-07-15 (continuación 6) — Arranca Real-time Server (Partida en Tiempo Real)
Primera feature nueva de gameplay real (no gacha/auth). No existía spec de reglas de juego en ningún lado — pasó por Analyst→Game Expert→Architect antes de tocar código, como pide el flujo del equipo para cambios de protocolo WebSocket.

- **Spec de juego** (`docs/specs/realtime-match.md`, Game Expert, aprobada por Luis): mazo de 10 cartas elegidas manualmente de la colección, sin maná/energía (1 carta por turno, límite de tablero=5), combate con targeting (vida del rival o una carta específica — `defense` es la vida de cada carta en juego, se destruye al llegar a 0). Vida inicial 20. Fuera de alcance: recompensas por ganar, ranking, replays, mazos guardados, habilidades de carta.
- **Diseño técnico** (`docs/designs/realtime-match.md`, Architect): primera versión asumía un solo worker de Uvicorn con estado en memoria de proceso — **Luis pidió explícitamente abordar múltiples procesos para la concurrencia**, así que se rediseñó con **Redis** como store compartido (estado de partida serializado como JSON Pydantic, lock distribuido por partida, cola de matchmaking con script Lua atómico para emparejar sin race conditions entre workers) + **Pub/Sub** por partida para que el worker que procesa una acción le avise al worker que tiene la conexión del rival (patrón estándar de escalado horizontal de WebSockets, mismo principio que el adapter de Redis de Socket.IO). Sin persistencia a Postgres del estado de partida en sí (solo se lee `player_cards` una vez, al encolar, para validar que el deck es del jugador). `docker-compose.yml` gana un servicio `redis` nuevo — mismo stack que ya usa GuepardAI en el workspace.
- Backend primero, frontend (deck builder + pantallas de partida) queda para una ronda de PM separada después. El botón "MULTIPLAYER" en `main_menu_page.dart` ya existe como placeholder.
- **Backend — Tarea 22 (`match_engine.py`)**: reglas puras (play_card/attack/end_turn/fatiga/victoria) sobre modelos Pydantic (`Match`, `MatchPlayerState`, `CardInPlay`), sin I/O. 21 tests cubriendo cada criterio de aceptación del spec, corridos 3 veces por la aleatoriedad (orden de turno, mezclado de mazo) — sin flakiness.
- **Backend — Tarea 23 (`match_store.py`)**: guardar/leer `Match` en Redis (JSON) + lock distribuido por partida. Bug de config de tests encontrado: el cliente Redis singleton se rompía entre tests porque pytest-asyncio crea un event loop nuevo por test por default ("Event loop is closed") — fix con `pytest.ini` (`asyncio_default_fixture_loop_scope/test_loop_scope = session`), no un cambio de código de producción.
- **Backend — Tarea 24 (`matchmaking.py`)**: cola FIFO en Redis + script Lua atómico para emparejar sin race conditions entre workers. **Bug real y serio encontrado en `app/db/redis.py`**: el cliente Redis se creaba a nivel de módulo (import time) — en Python 3.9, `asyncio.Lock()` (que usa el connection pool internamente) se ata al event loop "actual" en el momento en que se construye; como el import pasa ANTES de que Uvicorn cree el loop real, el lock quedaba atado a un loop equivocado. Andaba perfecto con una operación a la vez y rompía con concurrencia real (`RuntimeError: ... attached to a different loop`) — exactamente el escenario que esta feature necesita manejar bien. Encontrado por un test que dispara 30 `try_pair()` concurrentes (`asyncio.gather`), no por inspección de código. Fix: singleton lazy (`get_redis_client()`), el cliente se crea en el primer uso real, ya adentro del loop que corre la app. Verificado: el mismo test de 30 llamadas concurrentes ahora pasa, corrido 5 veces sin flakiness; también confirma que el matchmaking nunca empareja al mismo jugador dos veces ni pierde a nadie bajo concurrencia real contra Redis.
- Suite completa: 123 passed + 1 skip.

## 2026-07-15 (continuación 7) — Real-time Server completo + revisión Senior Reviewer
- **Backend — Tarea 25 (`match_pubsub.py`) y Tarea 26 (`app/api/match_ws.py`)**: pub/sub por partida y por usuario (dos canales — el de usuario existe porque el worker que empareja a dos jugadores puede no ser el mismo que tiene la conexión WebSocket de ninguno de los dos), y el endpoint `/ws/match` que integra match_engine + match_store + matchmaking + pub/sub: auth por JWT (query param, no header — el WebSocket del browser no puede setear headers custom en el handshake), validación de mazo, cola/emparejamiento, acciones de partida, desconexión. **Segundo bug de la misma familia que el de la Tarea 24** encontrado al verificar con TestClient real: el singleton lazy de Redis rompía igual si se lo pedía desde un loop DISTINTO al que lo construyó (no solo "antes de que exista el loop real") — pasa con cualquier test que abre un event loop nuevo por conexión, y en producción con cualquier proceso de vida larga que recree su loop. Fix: el singleton ahora es loop-aware, se reconstruye si cambia el loop que lo pide.
- **Tarea 27**: verificación end-to-end con 2 contenedores backend independientes (procesos reales separados, no workers de un mismo Uvicorn) compartiendo el mismo Postgres/Redis — partida completa jugada hasta la victoria vía websockets reales (no TestClient), ambos procesos de acuerdo en el ganador.
- **Revisión Senior Reviewer** (skill `/code-review`, 8 ángulos + verificación, sobre el commit del endpoint): 10 hallazgos confirmados. Corregidos en dos tandas (decisión de Luis: primero los 4 de alta severidad + push, después los 6 restantes):
  - **Alta severidad**: (1) `leave_queue` no era atómico (LRANGE+LREM en dos viajes) y podía perder la carrera contra el `RPOP` atómico de `try_pair`, emparejando a un jugador que se estaba desconectando y dejando al rival esperando una jugada que nunca llega — fix: `leave_queue` también es un script Lua atómico ahora (usa `cjson.decode` para buscar por `user_id` dentro del script). (2) La misma clase de carrera cancelación-vs-limpieza-async que se había corregido solo en el test de desconexión seguía viva en el propio endpoint (`forward_task.cancel()` sin esperar antes de que `_resolve_disconnect` hiciera su propio I/O) — fix: se espera la cancelación antes de limpiar. (3) Sin guard contra re-encolar estando ya en partida — fix: `_handle_queue` rechaza con `MatchRuleViolation` si el user ya tiene un `match_id` local. (4) Un mensaje de cliente no-JSON o JSON-no-objeto tiraba la conexión entera — fix: se atrapa y responde error, la conexión sigue viva. De paso se agregó el ack `{"type":"queued"}` que el protocolo documentado prometía y el servidor nunca mandaba.
  - **Media/baja**: fuga de conexiones Redis al reconstruir el cliente entre loops (`get_redis_client()` ahora es `async def`, cierra el cliente viejo con `aclose()` antes de reemplazarlo — obligó a actualizar todos los callers a `await`); llamadas síncronas a la DB bloqueando el event loop entero del worker (auth y resolución de mazo ahora corren en threadpool vía `run_in_threadpool`, con sesión de vida corta abierta y cerrada en el mismo hilo); sesión de DB inyectada por toda la conexión WebSocket aunque solo se usaba dos veces — se sacó `Depends(get_db)` del route, cada operación abre su propia sesión corta; gap de cobertura de tests (los unitarios de pub/sub solo ejercitaban el combinador viejo `listen()`/`listen_for_user()`, no el patrón de dos pasos `subscribe()`+`consume()` que usa producción — tests nuevos que cubren ese patrón); duplicación de la lógica de auth entre `match_ws._authenticate` y `deps.get_current_user` — extraído `deps.resolve_user_by_token()` compartido por los dos.
- Verificado con la suite completa (137 passed + 1 skip, 3 corridas sin flakiness) y dos rondas más de la verificación end-to-end de 2 procesos tras cada tanda de fixes.

## 2026-07-16 — Frontend del Real-time Server

Ronda de PM separada, como estaba planeado. 10 tareas (#28-#37): un endpoint
backend nuevo + 9 piezas de frontend.

- **Backend — `GET /api/cards/mine`**: no existía ningún endpoint que
  expusiera la colección completa de un usuario (solo se podía ABRIR sobres,
  nunca LISTAR lo que ya se tiene) — el deck builder lo necesitaba para
  elegir las 10 cartas del mazo. Mismo patrón que `GET /api/packs/levels`.
- **`MatchWebSocketClient`**: primer uso real de WebSocket en la app
  (`web_socket_channel` pasa de dependencia transitiva a directa). Sin
  lógica de reconexión a propósito — el spec de juego define desconexión =
  derrota inmediata.
- **`CollectionRepository`/`OwnedCardEntity`**: primera vez que el frontend
  expone la colección del jugador — no existía ni la entidad ni el
  repositorio antes de esta ronda.
- **`GameCardWidget`**: extraído del `_TCGCardWidget` que vivía duplicado
  dentro de `pack_opening_page.dart` — ahora lo reusan esa pantalla, el
  deck builder y el tablero de partida.
- **`MatchNotifier`** (Riverpod, mismo patrón que `AuthNotifier`): modela
  el ciclo completo `queue→queued→match_found→state_update→match_over`
  como estado reactivo. Se le escribieron 11 tests unitarios con un
  repositorio fake — **encontraron un bug real** antes de tocar un
  browser: `ref.read()` no se puede llamar dentro de un callback de
  `onDispose` (Riverpod lo prohíbe explícitamente), y el primer borrador
  del notifier lo hacía para desconectar el WebSocket al destruirse. Fix:
  capturar la referencia al repositorio ANTES de registrar el callback.
- **DeckBuilderPage / MatchmakingPage / MatchPage**: selección de 10
  cartas, pantalla de "buscando partida", y el tablero completo (mano,
  tablero propio/rival, targeting de ataque cara-o-carta, terminar turno,
  rendirse, diálogo de resultado ¡VICTORIA!/DERROTA).
- **Verificación end-to-end real**: sin `chromium-cli` disponible en este
  entorno, se armó un driver Playwright a mano (Node) contra un build real
  de Flutter Web servido localmente + el backend real. Gotcha encontrado:
  Flutter Web renderiza sobre `<canvas>` (CanvasKit) — no hay `<input>`/
  texto real en el DOM, así que los selectores típicos de Playwright
  (`fill`, `text=`) no sirven; hubo que interactuar por coordenadas de
  mouse leídas de capturas de pantalla sucesivas. Con eso: dos usuarios
  reales (`ui_alice`/`ui_bob`, 10 cartas cada uno) hicieron login, armaron
  mazo, encolaron, matchmaking los emparejó, jugaron una carta, pasaron
  turno, atacaron a la cara, y el diálogo de resultado apareció correcto
  en los dos lados (`¡VICTORIA! / por vida a cero` en un lado, `DERROTA /
  por vida a cero` en el otro) — con tráfico WebSocket real de punta a
  punta, no mockeado.
- `flutter analyze`: 0 errores nuevos (solo los `withOpacity` deprecados
  que ya existían en el resto del proyecto). `flutter test`: 29 passed (18
  preexistentes + 11 del `MatchNotifier`).
- Con esto, el "qué falta" del real-time match queda: Senior Review del
  frontend (el backend ya lo tuvo, ver entrada anterior) y push.

## 2026-07-16 (continuación 2) — Senior Review del frontend

Mismo proceso que el backend (`/code-review`, 8 ángulos + verificación) sobre
los 3 commits del frontend. 10 hallazgos confirmados, decisión de Luis:
corregir los 10 antes de pushear.

- **El más grave**: `GameCardWidget` en `deck_builder_page.dart` se llamaba
  sin pasar `width:`, así que caía en su default de 250px — en la grilla de
  2 columnas de un celular real (~160-190px de ancho de celda) cada carta
  desbordaba. La verificación end-to-end de la entrada anterior corrió en un
  browser desktop de 1280px, lo bastante ancho para que esto nunca se viera.
  Fix: `LayoutBuilder` calcula el ancho real de la celda y se lo pasa al
  widget. **Reverificado con Playwright en un viewport de 390px (iPhone)**:
  las cartas ahora entran perfectas en la grilla.
- Una excepción al parsear un mensaje del servidor en `_handleMessage` no la
  agarraba `onError` de la suscripción (Dart no rutea excepciones sync de
  `onData` a `onError`) — dejaba la UI colgada sin ningún error visible. Fix:
  try/catch alrededor del switch, cae a `fatalError` con mensaje.
  Test nuevo que manda un `state` con forma inválida y confirma la
  transición.
- La carta atacante seleccionada no se limpiaba al terminar turno ni se
  gateaba por `yourTurn` — quedaba "armada" contra el rival en el turno de
  él. Fix: gate por `yourTurn` + que la carta siga en el tablero, y limpieza
  explícita al tocar "Terminar turno".
- `MatchWebSocketClient.connect()` pisaba la conexión anterior sin cerrarla
  (fuga en doble-conexión) y `close()` corría una carrera real con un
  re-encolado rápido (podía anular la referencia a la conexión NUEVA). Fix:
  cerrar la vieja antes de reemplazar, y en `close()` solo limpiar la
  referencia si sigue siendo la misma instancia que se estaba cerrando
  (`identical`).
- Dos errores idénticos consecutivos del servidor no volvían a mostrar el
  SnackBar (el listener comparaba por igualdad de texto). Fix: `errorNonce`
  nuevo en `MatchUiState`, se incrementa en cada mensaje `error` sin importar
  el texto — el listener compara por nonce, no por contenido.
- `rank.name.toUpperCase()` en un enum Dart camelCase (`minorGod`) da
  "MINORGOD" sin espacio. Fix: `CardRankDisplay.displayLabel` nuevo en
  `card.dart`, separado de `CardRankApi` (que es para serialización, no
  display).
- `leaveQueue()` estaba completamente implementado de punta a punta pero
  nunca se llamaba — "Cancelar" en matchmaking siempre desconectaba del todo
  en vez de solo salir de la cola. Fix: `leaveAndReset()` manda `leaveQueue()`
  primero si la fase es `connecting`/`queued`.
- Tocar una carta con mareo de invocación o que ya atacó no daba ningún
  feedback — parecía que la app no respondía. Fix: SnackBar explicando el
  motivo; se agregó un parámetro `disabled` a `GameCardWidget` separado de
  `summoningSick` (mismo atenuado visual, sin el ícono de luna que sería
  semánticamente incorrecto para "ya atacó").
- Un token vencido/inválido se veía como "conexión perdida" genérico en vez
  de avisar que había que volver a iniciar sesión. Fix: `closeCode` nuevo
  expuesto de punta a punta (`WebSocketChannel.closeCode` → 
  `MatchWebSocketClient` → `MatchRepository.lastCloseCode`) — si el cierre
  fue código 4401 (rechazo de JWT del backend), mensaje específico de sesión
  vencida.
- `GET /api/cards/mine` sin límite — la apertura de sobres no tiene tope más
  que el saldo, así que la colección puede crecer sin cota. Fix defensivo:
  `.limit(500)` (no es paginación real — el deck builder necesita ver toda
  la colección para elegir 10 cartas — solo evita un response verdaderamente
  ilimitado; si algún usuario real llega a este techo, hace falta paginación
  de verdad, no subir el número).
- Verificado: `flutter analyze` (0 errores nuevos), `flutter test` (34
  passed, 5 nuevos), suite backend completa (140 passed + 1 skip), y una
  segunda vuelta de la verificación end-to-end con Playwright — esta vez
  agregando específicamente un viewport de celular real para confirmar el
  fix del desborde.

## 2026-07-16 (continuación 4) — Mazos guardados

"Mazos guardados" estaba explícitamente fuera de alcance en el spec
original del real-time match ("no hay tabla `decks`") — Luis pidió
agregarlo como ronda de PM separada, con alcance "múltiples mazos con
nombre" (no solo recordar el último usado). 7 tareas (#38-44).

- **Tablas nuevas**: `decks` (id, user_id, name, timestamps) + `deck_cards`
  (deck_id, player_card_id, position, FK con `ondelete=CASCADE`) —
  normalizado, no JSON. El protocolo WebSocket de partida no cambió: `queue`
  sigue recibiendo la misma lista de `player_card_id`, ahora tomada de un
  mazo guardado en vez de una selección ad-hoc.
- **Refactor proactivo**: la consulta PlayerCard+CardArchetype+ownership ya
  estaba duplicada 2 veces (`cards.py`, `match_ws.py`) desde la revisión
  anterior — esta feature hubiera agregado una tercera copia en los
  endpoints de mazos, así que se extrajo a `app/services/card_ownership.py`
  antes de escribir el CRUD nuevo, y los tres call sites la comparten ahora.
- **CRUD `/api/decks`**: exactamente 10 cartas propias distintas (mismo
  criterio de validación que ya usaba `match_ws.py` al encolar), ownership
  check en update/delete (404 si el mazo no es del usuario, no 403 — no se
  revela que el mazo existe), tope defensivo de 20 mazos por usuario (no es
  un valor de negocio ajustable, mismo criterio que `DECK_SIZE`).
- **Frontend**: `MyDecksPage` nueva es ahora el hub del flujo multijugador
  (el botón MULTIPLAYER del menú entra acá, no directo al builder) —
  Jugar/Editar/Eliminar por mazo, botón Nuevo mazo. `DeckBuilderPage` deja
  de armar-y-encolar directo: ahora pide nombre y Guardar persiste el mazo
  (crea o actualiza según si viene con `deckId`), sin una ruta paralela de
  "jugar sin guardar" — un solo flujo coherente en vez de dos.
- **Verificado end-to-end en browser real** (mismo approach Playwright por
  coordenadas que las rondas anteriores, dado que Flutter Web no expone
  `<input>`/texto real en el DOM): crear mazo con nombre + 10 cartas → 201,
  aparece en la lista → editar (cambiar nombre) → 200, se actualiza →
  eliminar → 204, la lista vuelve a estar vacía. Confirmado con logs reales
  de `REQ`/`RES` de red, no solo capturas de pantalla.
- Suite backend completa: 152 passed + 1 skip (12 tests nuevos de
  `test_decks.py`). `flutter analyze`: 0 errores nuevos. `flutter test`: 34
  passed (sin tests nuevos de widget para `MyDecksPage`/`DeckBuilderPage`
  editado — cubierto por la verificación end-to-end en browser real en su
  lugar, dado el tiempo ya invertido en esta ronda).
- **Senior Review (793abf4/e0ec81e) — 10 hallazgos, push aprobado sin
  corregir (decisión explícita de Luis: "push ya, arreglar después")**.
  Quedan pendientes como deuda técnica documentada, no perdida:
  - Race condition (TOCTOU) real en el tope de 20 mazos: `create_deck`
    hace `SELECT count(*)` y luego `INSERT` sin lock — dos requests
    concurrentes pueden dejar a un usuario con 21+ mazos.
  - N+1 en `list_decks` (1 query de mazos + 1 query de cartas por mazo).
  - `_validate_deck_cards` carga las cartas propias solo para contar,
    las descarta, y `_deck_out` las vuelve a consultar segundos después.
  - `_replace_deck_cards` ejecuta un `DELETE` garantizado no-op en
    `create_deck` (el `deck.id` es un UUID recién generado).
  - `MyDecksPage._createNew/_edit/_delete` no chequean `mounted` tras
    un `await` (Navigator.push / showDialog), a diferencia del resto
    del código (login/register/profile/gacha-config sí lo hacen).
  - `_MAX_DECKS_PER_USER = 20` hardcodeado — posible choque con la regla
    global de CLAUDE.md (umbrales de negocio en tabla paramétrica, no en
    código), aunque el comentario del código lo justifica como tope
    defensivo, no de negocio — pendiente de confirmación explícita de Luis.
  - La remoción de "jugar sin guardar" (ver arriba) fue una decisión de
    UX tomada durante la implementación, documentada pero no escalada
    formalmente como decisión de negocio antes de aplicarla — pendiente
    de confirmación retroactiva de Luis.
  - `OwnedCardOut` se construye por separado y de forma idéntica en
    `decks.py` y `cards.py` (no se extrajo junto con `load_owned_cards`).
  - El boilerplate de `FutureBuilder` (loading/error/reintentar) está
    duplicado ahora en 4 páginas (`MyDecksPage`, `marketplace_page.dart`,
    `deck_builder_page.dart`, `gacha_config_admin_page.dart`).
  - El campo de nombre en `DeckBuilderPage` usa
    `onChanged: (_) => setState(() {})`, recontruyendo toda la página
    (incluido el grid de cartas) en cada tecla, cuando solo el estado
    del botón Guardar necesita reaccionar al nombre.

## 2026-07-16 (continuación 5) — Resolución de los 10 hallazgos de mazos guardados

Daily con Analyst/Architect/PM: Luis pidió avanzar con los 10 hallazgos
pendientes de la revisión senior de 793abf4/e0ec81e. Dos quedaban atados a
decisiones de negocio explícitas de Luis antes de tocar código:

- **`_MAX_DECKS_PER_USER=20`: SÍ es umbral de negocio** (no defensivo como
  decía el comentario original) — va a tabla paramétrica con CRUD +
  vista de admin, mismo criterio que `gacha_config` (regla global de
  CLAUDE.md). Nueva tabla `deck_config` (fila única id=1), sembrada por la
  migración misma (no depende de un seed manual para no quedar "sin
  configurar" en ningún ambiente real) — `seed_deck_config.py` existe solo
  para tests, que arman el schema con `create_all` sin migraciones.
  `GET/PUT /api/admin/deck-config` protegido por `get_current_superadmin`,
  pantalla Flutter `DeckConfigAdminPage` gateada en `ProfilePage` igual que
  la de gacha.
- **UX de "jugar sin guardar"**: ni ratificar el flujo 100% forzado ni
  revertir a la ruta paralela de antes — Luis pidió una alternativa a
  mitad de camino. Se presentaron 3 opciones (auto-nombrado, ruta paralela
  sin persistir, slot temporal reciclable); eligió **auto-nombrado**:
  `DeckBuilderPage._save()` genera `"Mazo dd/mm hh:mm"` si el campo de
  nombre queda vacío, sin modal ni paso extra — sigue gastando 1 de los
  N mazos del tope (no es un slot gratis), pero nunca bloquea con un
  "poné un nombre" delante del botón Guardar. Efecto colateral bueno: al
  sacar el requisito de nombre no vacío de `_canSave`, se pudo borrar
  también el `onChanged: (_) => setState(() {})` que causaba el rebuild de
  toda la página por tecla (hallazgo #10) — un solo cambio resolvió los dos.

Resto de hallazgos, con su fix:

- **Race condition (TOCTOU) real**: `create_deck` ahora lockea la fila del
  `User` con `with_for_update()` antes de contar+insertar, serializando
  creaciones concurrentes del mismo usuario. Test de regresión con 5
  threads reales contra el tope (`max_decks_per_user=1` vía DB): antes del
  fix hubiera dejado pasar más de un 201; con el fix, exactamente uno.
- **N+1 en `list_decks`**: una sola query con `deck_id.in_(...)` agrupada
  en memoria por `deck_id`, en vez de una query de cartas por mazo.
- **Queries redundantes**: `_validate_deck_cards` ahora devuelve las filas
  ya cargadas (`dict[player_card_id, (PlayerCard, CardArchetype)]`) y
  `create_deck`/`update_deck` las reusan para armar la respuesta — ya no
  se vuelve a consultar en `_deck_out` lo que se acababa de cargar para
  validar.
- **`DELETE` no-op en `create_deck`**: se separó `_insert_deck_cards`
  (solo INSERT, usado por `create_deck`) de `_replace_deck_cards`
  (DELETE+INSERT, usado por `update_deck`, que si necesita borrar lo
  previo).
- **`MyDecksPage` sin `mounted`**: chequeo agregado en `_createNew`,
  `_edit` (tras el `await Navigator...push`) y en `_delete` (tras el
  `await showDialog` y tras el `await deleteDeck`).
- **`OwnedCardOut` duplicado**: `owned_card_out()` nuevo en
  `card_ownership.py`, reusado por `cards.py` y `decks.py`.
- **`FutureBuilder` boilerplate x4**: `AsyncFutureView<T>` nuevo en
  `presentation/widgets/`, adoptado por `MyDecksPage`, `DeckBuilderPage`,
  `MarketplacePage`, `GachaConfigAdminPage` y la `DeckConfigAdminPage`
  nueva (5 pantallas, no 4 — la nueva pantalla de admin nació ya usándolo).

**Verificado**: suite backend completa contra Postgres real vía contenedor
Python 3.9 en la red `cardgame_dev_net` (los contenedores de dev no
publican puerto a host, así que se corrió un contenedor efímero conectado
a esa red en vez de tocar la configuración de los contenedores existentes)
— 159 passed + 1 skip (152 previos + 7 nuevos: 1 de concurrencia + 6 del
admin de `deck_config`). `flutter analyze`: 0 errores nuevos (30 infos
preexistentes de `withOpacity`, sin relación). `flutter test`: 34 passed,
sin regresiones. Verificación end-to-end en browser real (Playwright por
coordenadas, mismo approach que rondas anteriores): usuario de prueba
creado directo en Postgres (email verificado, superadmin, 12 cartas de 3
facciones) contra un backend corrido en un contenedor con el puerto
publicado — creó un mazo de 10 cartas sin escribir nombre → apareció en
"Mis Mazos" como "Mazo 16/07 13:45"; en el admin de mazos cambió el tope
de 20 a 15 y se confirmó persistido vía API. Después de verificar, se
reseteó la base de dev a su estado limpio (schema + seeds base, sin el
usuario de prueba) — nota operativa ya documentada en la ronda de gacha
sigue aplicando: el fixture `_setup_db` hace `drop_all` después de cada
test, así que correr algo manual contra el Postgres persistente después de
una corrida de pytest requiere `DROP SCHEMA public CASCADE` +
`alembic upgrade head` antes.

**Revisión senior post-fix (commit `1bdb5af`)**: 2 hallazgos nuevos, no
cubiertos por el trabajo original — reporte completo en
`docs/reviews/mazos-guardados.md`. `get_or_create_deck_config` comiteaba
internamente, lo que podía liberarle a `create_deck` el lock de `User`
antes de tiempo y reabrir el TOCTOU (ventana angosta, no reproducida
empíricamente en 6 corridas con hasta 25 threads, pero defecto de diseño
real). `DeckConfigAdminPage` disparaba un reload del padre al guardar, que
desmontaba el widget antes de mostrar "Tope de mazos actualizado." — el
mensaje de éxito era código muerto. Ambos corregidos (commit `80e5e44`) y
verificados en vivo, no solo por inspección de código. Spec retroactiva
agregada en `docs/specs/mazos-guardados.md` (commit `c4dce89`).

**Cierre — 2026-07-16: Luis aprobó la feature completa.** Mazos guardados
queda cerrado: implementación (793abf4/e0ec81e) → 10 hallazgos originales
resueltos (1bdb5af) → revisión senior con 2 hallazgos más, corregidos
(80e5e44) → spec retroactiva (c4dce89) → aprobación final de Luis. QA
formal no aplica (rol no activado todavía en CardGame).

## 2026-07-17
- **Ambiente local de desarrollo**: `scripts/dev-up.sh` levanta el stack
  completo (`docker compose up -d db redis mailhog`, espera a Postgres,
  regenera `backend/.env` leyendo el puerto de host real que publicó
  Compose, migraciones, seeds idempotentes, `uvicorn --reload`). Necesario
  porque los puertos default (5432/6379) ya están tomados en esta máquina
  por otros proyectos del workspace (`infra-postgres-1`, `zia_redis`) —
  `docker-compose.override.yml` (no versionado, en `.gitignore`) remapea
  a 5433/6380 con `ports: !override` (el merge default de Compose concatena
  arrays en vez de reemplazar, así que sin `!override` el conflicto de
  puerto seguía apareciendo). Documentado como skill de proyecto en
  `.claude/skills/run/SKILL.md`.
- **CI activado** (`.github/workflows/ci.yml`): Postgres+Redis como
  servicios, Python 3.9 igual que `backend/Dockerfile`, `python -m pytest`
  [no `pytest` a secas, falla el import de `app`], Flutter stable con
  `analyze --no-fatal-infos` [hay ~30 avisos info preexistentes de
  `withOpacity` deprecated, deuda ya existente, no bloquean]. Verificado
  localmente en las mismas condiciones antes de commitear: 160 tests de
  backend y 34 de frontend pasando. Es solo testing en runners de GitHub,
  no depliega a ningún servidor — el CD real (deploy al VPS) queda
  pendiente aparte, para cuando exista esa infraestructura.
- **CI — primer run real reveló deuda de versión**: el primer push a
  GitHub Actions falló en frontend (backend pasó limpio). Causa: el canal
  `stable` de `subosito/flutter-action` bajó Flutter 3.44.6, cuyo SDK de
  Dart marca `IconData` como `final class` — rompe la compilación de
  `font_awesome_flutter` 10.x (pin actual `^10.9.1`, resuelve a 10.12.0),
  que extiende esa clase. En local (Flutter 3.32.8, ~1 año desactualizado)
  no se veía porque esa versión de Flutter no tiene el cambio. El fix de
  fondo es `font_awesome_flutter` 11.0.0, pero es un breaking change real
  (`Icon`→`FaIcon`, `find.byIcon(...)` pasa a requerir `.data`) que toca
  varios archivos — no se hizo de paso arreglando el CI. Solución
  temporal: `ci.yml` pinea `flutter-version: "3.32.8"` (la misma que se
  usa en desarrollo local) en vez de `channel: stable`. **Pendiente**:
  actualizar Flutter local + migrar a `font_awesome_flutter` 11.0.0 en
  una tarea separada, y recién ahí destrabar `channel: stable` en CI.

## 2026-07-18
- **Bug real: registro no funcionaba probando en local**. Causa raíz:
  puerto 8000 también ocupado por `factoring_backend_web` (nginx del
  proyecto Factoring, publicado en `0.0.0.0:8000`) — coexistiendo con
  `uvicorn` del host en `127.0.0.1:8000`, `localhost:8000` resolvía a
  uno u otro de forma intermitente (un `GET /docs` daba 200 contra
  cualquiera de los dos, pero el `POST /api/auth/register` real caía en
  el Laravel de Factoring → 404). Se movió el backend de CardGame a
  **8001**: `scripts/dev-up.sh` (`BACKEND_PORT=8001`),
  `docker-compose.override.yml` (backend `8001:8000`, para cuando corra
  en Docker) y el default de `frontend/lib/core/api_config.dart`
  (`http://localhost:8001`). Documentado en
  `.claude/skills/run/SKILL.md`.
- **Segundo bug, mismo intento de probar**: con el puerto ya corregido,
  el registro daba 500 — `relation "users" does not exist`. La corrida
  de `pytest` de la sesión anterior (validando la CI en local) dejó la
  base sin tablas: el fixture `_setup_db` de `tests/conftest.py` hace
  `Base.metadata.drop_all` al terminar cada test contra la misma base de
  desarrollo, y no toca `alembic_version` — así que un `alembic upgrade
  head` posterior no detecta nada pendiente y no las recrea. Arreglo:
  `DROP SCHEMA public CASCADE` + `alembic upgrade head` + reseed.
  Troubleshooting documentado en `.claude/skills/run/SKILL.md` — correr
  `pytest` y probar la app a mano en la misma sesión no conviven sobre
  la misma base sin resembrar entre medio.
- **Bug real: el link de verificación de email no llevaba a ningún
  lado**. Causa raíz: `_send_verification_email` (`backend/app/api/auth.py`)
  armaba el link como `https://cardgame.local/verify-email?token=...` —
  el mismo problema que ya se había encontrado y resuelto para
  reset-password (`docs/designs/auth-system.md`, "Deep link de
  reset-password", 2026-07-15e: `cardgame.local` no es un dominio real,
  no hay forma de hostear `apple-app-site-association`/`assetlinks.json`
  para un Universal/App Link HTTPS), pero ese fix nunca se aplicó a
  verify-email. Se corrigió aplicando el mismo patrón ya aprobado:
  - Backend: link ahora `cardgame://verify-email?token=...`.
  - Frontend: `core/deep_link.dart` suma `extractVerifyEmailToken`
    (mismo patrón que `extractResetPasswordToken`, con tests). `main.dart`
    lo escucha y navega a `VerifyEmailPendingPage(token: ...)`.
  - **`VerifyEmailPendingPage` ahora tiene un campo de token editable +
    botón "Verificar"** (antes solo tenía "reenviar" y "ya verifiqué, ir
    a login", sin forma de completar la verificación desde la UI). Es la
    única forma real de probar este flujo en web
    (`flutter run -d chrome`): un custom URL scheme no dispara nada al
    abrir el link desde un cliente de correo dentro de un tab de Chrome.
    Nueva capa de datos: `AuthRemoteDatasource.verifyEmail`,
    `AuthRepository.verifyEmail` (+ impl + fake de tests).
  - Verificado end-to-end contra Mailhog real: registro → token
    extraído del email → verify-email 200 → login 200 con JWT.
  - **Nota al pasar, no bloqueante**: el body del email llega con
    `Content-Transfer-Encoding: quoted-printable` (vía `aiosmtplib`,
    por el acento en "Hacé") — la API REST de Mailhog (`/api/v2/...`,
    `/api/v1/...`) devuelve el body *sin decodificar* (con `=3D` y
    saltos de línea `=` de soft-wrap), pero la UI web de Mailhog
    decodifica MIME del lado del cliente para mostrarlo, así que copiar
    el token desde ahí a mano da el valor limpio — confirmado
    decodificando el quoted-printable a mano, no se pudo confirmar
    visualmente en la UI real (extensión de Chrome no conectada en esta
    sesión). Si algún día se ve un token roto al copiarlo de Mailhog,
    empezar por acá.

- **Superadmin convertido a mano**: `luis@luis.co` (username `squall`,
  registrado por Luis vía la UI) fue promovido a superadmin directo en la
  base (`UPDATE users SET is_superadmin = true`) — no hay endpoint para
  auto-otorgarse el flag, es la única vía hoy. Se perdió después en una
  corrida de `pytest` (mismo gotcha del `drop_all` de arriba) y Luis tuvo
  que volver a registrarse.
- **4 features nuevas a pedido de Luis, todas implementadas y probadas
  end-to-end contra Mailhog/Postgres reales** (174 tests backend + 49
  frontend, ambos en verde):
  1. **Multirol (UI-only)**: `AuthState.viewAsPlayer` en
     `auth_provider.dart` — toggle "VER COMO JUGADOR"/"VOLVER A MODO
     ADMIN" en `ProfilePage`, visible solo si `isSuperadmin`. No toca el
     backend ni el JWT: `is_superadmin` sigue siendo el permiso real, el
     toggle solo oculta la navegación admin para que un superadmin pueda
     navegar la app como jugador. Se resetea a `false` en cada
     login/restauración de sesión (no persiste).
  2. **Otorgar coins** (`app/api/admin/coins.py`, superadmin-only):
     `POST /grant` (por email o username, premio individual) y
     `POST /broadcast` (a todos los usuarios, evento — `UPDATE` en bloque,
     no trae filas a Python). Ambos validan `amount > 0` (422 si no) y
     quedan auditados en la tabla nueva `coin_grants`
     (`granted_by_id`, `target_user_id` nullable = broadcast,
     `recipient_count` solo se completa en broadcasts) — decisión de
     Luis: sí quería historial. `GET /history` lista los últimos 200.
     Frontend: `AdminCoinsPage` — el broadcast pide confirmación en un
     diálogo antes de ejecutar (irreversible, afecta a todos).
  3. **Cambiar contraseña logueado**: `POST /api/auth/change-password`
     (requiere `current_password`, valida contra el hash real, 400 si no
     matchea) — distinto del flujo de reset por email que ya existía
     (`reset-password`, sin sesión, con token). `ChangePasswordPage`
     nueva, accesible para cualquier usuario desde `ProfilePage`.
  4. **Seed de superadmin** (`app/db/seed_superadmin.py`, idempotente,
     wireado en `scripts/dev-up.sh`): `lujogarpin78@gmail.com` /
     `lionheartsq` / password `12345678` — genérica a propósito, **nunca
     correr este seed contra un ambiente real**, es la única forma de
     tener un primer superadmin sin editar la base a mano (no hay
     endpoint para auto-otorgarse el flag). Username `lionheartsq` chocaba
     con un usuario de prueba viejo sin verificar (`test@example.com`) —
     se borró antes de correr el seed (decisión de Luis).
  - Migración `3ad75176b9c6_create_coin_grants_table.py`. Nota de
    higiene: `app/models/deck_config.py` **no** está importado en
    `alembic/env.py` (gap preexistente, no introducido acá) — si algún
    día se corre `alembic revision --autogenerate`, Alembic no lo va a
    ver en `target_metadata` y puede proponer un `DROP TABLE
    deck_config`. Se agregó el import de `coin_grant` sí, para que este
    modelo no caiga en el mismo agujero.
  - **Bug real atrapado por la CI, no por mí en local**: `coins.py` usó
    sintaxis `str | None` (PEP 604) en la firma de `_grant_out` — válida
    desde Python 3.10, pero `backend/Dockerfile`/la CI corren 3.9. El
    `.venv` local es 3.14 (ver nota de deuda de versión más abajo de
    todos modos), así que ahí no rompía; recién se vio en el primer push
    real a GitHub Actions (`TypeError: unsupported operand type(s) for
    |`). Corregido a `Optional[str]` (`typing`), consistente con el
    resto del código (`Optional[...]`, no `X | None`, en todo el
    proyecto — mismo patrón que ya evitó este problema en
    `app/schemas/coin_grant.py`). Mismo tipo de gotcha que el pin de
    Flutter en CI de más arriba: el toolchain local (Python 3.14,
    Flutter 3.32.8) es más nuevo que el target real de producción/CI —
    tenerlo en cuenta antes de asumir que "pasa en local" alcanza.
