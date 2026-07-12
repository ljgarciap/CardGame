# Diseño técnico: Sistema de Autenticación (Architect)

Spec de referencia: `docs/specs/auth-system.md`
Estado: **Aprobado por Luis (2026-07-12)** — pasado a PM para desglose de tareas

Esta tabla `users` es la identidad real de jugador que reemplaza el
`players` mínimo que se había esbozado (y bloqueado) en
`docs/designs/gacha-engine.md`. Cuando se retome el gacha, apunta aquí.

## Componentes afectados/creados

**Backend** (todo nuevo):
- `app/models/user.py` — modelo SQLAlchemy `User`
- `app/schemas/auth.py`, `app/schemas/user.py` — Pydantic (register, login,
  reset, profile)
- `app/core/security.py` — hashing de password (passlib/bcrypt), encode/decode
  de JWT (python-jose)
- `app/core/email.py` — envío de emails vía SMTP (verificación, reset)
- `app/api/auth.py` — router: register, verify-email, resend-verification,
  login, request-password-reset, reset-password
- `app/api/users.py` — router: `GET/PATCH /api/users/me`
- `app/db/` — engine/sesión SQLAlchemy + Alembic (primera migración real
  del proyecto)

**Frontend**:
- `domain/repositories/auth_repository.dart` — interfaz
- `data/datasources/auth_remote_datasource.dart`, `data/repositories/auth_repository_impl.dart`
- `presentation/pages/`: `register_page.dart`, `login_page.dart`,
  `verify_email_pending_page.dart`, `forgot_password_page.dart`,
  `reset_password_page.dart`, `profile_page.dart`
- Provider Riverpod de sesión (JWT) + almacenamiento seguro del token

**Nuevas dependencias** (Backend Dev debe verificar versiones/compatibilidad
antes de instalar, según regla global):
- Backend: `bcrypt`, `python-jose[cryptography]`, `alembic`,
  `aiosmtplib` (o `fastapi-mail`)
- Frontend: `flutter_secure_storage` (guardar el JWT en el dispositivo)

> **Nota de implementación (2026-07-12)**: se cambió `passlib[bcrypt]` por
> `bcrypt` directo. Verificado durante la Tarea 2: passlib 1.7.4 (sin
> releases desde 2020) es incompatible con bcrypt ≥4.1 — falla al hashear
> (`ValueError: password cannot be longer than 72 bytes`, un bug conocido de
> passlib, no del password). `bcrypt` solo (mantenido, `requires_python
> >=3.8`) hace exactamente lo mismo sin la capa intermedia rota. No cambia
> el contrato de API ni el modelo de datos — es una sustitución de
> implementación, no de diseño.

## Modelo de datos

```
users
  id                              uuid pk
  email                           text unique
  password_hash                   text
  username                        text unique
  avatar_id                       text        -- preset key (ver abajo), validado en capa de app
  email_verified                  bool default false
  verification_token              text nullable
  verification_token_expires_at   timestamptz nullable
  reset_token                     text nullable
  reset_token_expires_at          timestamptz nullable
  coins                           int default 0
  created_at                      timestamptz
```

Avatares: lista fija de presets en código (`AVATAR_PRESETS = ["avatar_1", ..., "avatar_12"]`),
sin tabla propia — no hay panel de administración que la gestione en v1.

## Contrato de API

```
POST /api/auth/register        { email, password, username, avatar_id }
  -> 201, envía email de verificación. NO devuelve JWT (aún no verificado).
  -> 409 si email o username ya existen (mensaje genérico, sin filtrar cuál)

GET  /api/auth/verify-email?token=...
  -> 200 marca email_verified=true, invalida el token
  -> 400 si el token no existe, expiró, o ya fue usado

POST /api/auth/resend-verification   { email }
  -> 200 siempre (mismo mensaje exista o no el email, evita enumeración)

POST /api/auth/login           { email, password }
  -> 200 { access_token, token_type: "bearer" } si password correcto y email_verified
  -> 403 "verifica tu email" si password correcto pero no verificado
  -> 401 "email o contraseña incorrectos" en cualquier otro caso de fallo

POST /api/auth/request-password-reset   { email }
  -> 200 siempre (mismo mensaje exista o no el email)

POST /api/auth/reset-password   { token, new_password }
  -> 200 cambia password_hash, invalida el token
  -> 400 si el token no existe, expiró o ya fue usado

GET  /api/users/me              (requiere JWT)
  -> 200 { id, email, username, avatar_id, coins, email_verified }

PATCH /api/users/me             (requiere JWT) { username?, avatar_id? }
  -> 200 perfil actualizado
  -> 409 si el username ya está tomado
```

## Decisiones técnicas (Architect)

**JWT — access token único, sin refresh token.**
Expiración larga (7 días), firmado HS256 con secret en variable de entorno.
Se elige no implementar refresh tokens en esta iteración: la spec pedía
"cuenta completa" en términos de perfil (verificación, reset, username,
avatar), no necesariamente una arquitectura de sesión compleja. Si en el
futuro se requiere revocación inmediata de sesión, se revisita.

**Verificación y reset por token simple en la fila del usuario**, no una
tabla aparte — un usuario no tiene más de un token de verificación o de
reset válido a la vez (generar uno nuevo invalida el anterior por
sobreescritura). Suficiente para el volumen actual del proyecto.

**Rate limiting**: no es criterio de aceptación de esta iteración (fuera de
alcance en la spec), pero se recomienda un límite básico por IP en
`/auth/login`, `/auth/register` y `/auth/*-password-reset` (ej. `slowapi`)
como mitigación de bajo costo. Se anota como tarea opcional para PM, no
bloqueante.

## Prerrequisito externo (no soy yo quien lo decide)
**Credenciales SMTP reales** (proveedor tipo Mailgun/Brevo, o SMTP propio en
el VPS) — hoy no existe nada configurado. Sin esto, el flujo de
verificación/reset no se puede probar end-to-end. Backend Dev puede
implementar contra un SMTP de desarrollo (ej. Mailhog local en
docker-compose) mientras se define el proveedor real de producción.

## Riesgos
| Riesgo | Mitigación |
|---|---|
| Sin refresh token, sesión expira a los 7 días | Aceptado por diseño; UX debe manejar "sesión expirada" con re-login simple |
| Sin rate limiting en login/registro | Riesgo de bruteforce/spam; recomendado `slowapi` como tarea de bajo esfuerzo, no bloqueante |
| SMTP de producción no definido todavía | Desarrollo puede avanzar con Mailhog local; no bloquea implementación, sí bloquea pruebas end-to-end reales |
| Password hash débil si se elige mal el algoritmo | Usar `passlib` con bcrypt (o argon2), nunca hash propio |

## Estimación (para PM)
| Tarea | Agente | Depende de | Estimado |
|---|---|---|---|
| Modelo `User` + migración Alembic | Backend Dev | — | 2h |
| `core/security.py` (hash + JWT) | Backend Dev | modelo | 2h |
| `core/email.py` + Mailhog en docker-compose (dev) | Backend Dev | — | 2h |
| Endpoints register/verify/resend | Backend Dev | security + email | 3h |
| Endpoints login/reset-password | Backend Dev | security + email | 2h |
| Endpoints `/users/me` (GET/PATCH) | Backend Dev | modelo + JWT | 1h |
| Tests (registro, verificación, login, reset, duplicados) | Backend Dev | endpoints | 3h |
| Pantallas Flutter: registro, login, verify-pending | Frontend Dev | contrato de API | 4h |
| Pantallas Flutter: forgot/reset password, perfil | Frontend Dev | contrato de API | 3h |
| Provider de sesión + `flutter_secure_storage` | Frontend Dev | contrato de API | 2h |

Backend y Frontend pueden avanzar en paralelo una vez fijado el contrato de
API de arriba (Frontend puede mockear respuestas).
