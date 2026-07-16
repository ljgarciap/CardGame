# Spec: Sistema de Autenticación

**Date**: 2026-07-12
**Requested by**: Luis
**Status**: Done
**Project**: CardGame

## Problem
El proyecto no tiene ninguna identidad de jugador persistente en el backend
(`player.dart` en Flutter es solo estado de una partida en curso, no una
cuenta). Esto bloqueó directamente el diseño del Motor de Gacha (`docs/designs/gacha-engine.md`,
bloqueado 2026-07-12): no se puede tener una billetera de monedas ni un
inventario de cartas sin saber de quién son. Se resuelve ahora porque es
prerrequisito de toda mecánica de progresión/economía del juego.

## Solution summary
Registro e inicio de sesión con email + contraseña, sesión vía JWT.
Verificación de email obligatoria antes de poder usar la cuenta.
Recuperación de contraseña por email con link de un solo uso. Perfil con
username único y avatar seleccionable de un set de presets (sin upload de
imágenes en esta iteración). Envío de emails vía SMTP genérico.

## Users and roles
Un único rol por ahora: **Jugador**. No hay rol de administrador ni
moderación en esta iteración.

## Acceptance criteria
- [x] Registro con email + password válidos crea la cuenta con
      `email_verified = false` y envía un email con link de verificación
- [x] Un jugador con `email_verified = false` **no puede iniciar sesión**:
      recibe un error explícito indicando que debe verificar su email, con
      opción de reenviar el correo de verificación
- [x] Click en el link de verificación (válido, no expirado, no usado)
      marca `email_verified = true` y permite iniciar sesión
- [x] Login con email + password correctos y email verificado devuelve un
      JWT válido
- [x] Login con credenciales incorrectas devuelve un error genérico
      ("email o contraseña incorrectos") sin revelar si el email existe
      en el sistema
- [x] Solicitar recuperación de contraseña envía un email con link de un
      solo uso y expiración (ej. 1 hora) — incluye deep link de app móvil
      (custom URL scheme, agregado 2026-07-15) además del link web
- [x] Completar el reset con un link válido cambia la contraseña y el link
      queda invalidado para siempre (no reutilizable)
- [x] Username es único — el registro/edición de perfil rechaza duplicados
      con un error claro (constraint `unique=True` en `users.username` +
      validación a nivel API)
- [x] Avatar se elige de un set de presets fijo (no hay upload de archivo)
- [x] Las contraseñas se almacenan hasheadas (bcrypt) — nunca en texto
      plano, ni siquiera en logs
- [x] Password mínimo 8 caracteres (política mínima; ajustable después)

## Edge cases and error scenarios
- Registro con un email ya existente → error claro, sin filtrar si la
  colisión es por email o por otro campo
- Username duplicado en registro o edición de perfil → error claro
- Token de verificación o de reset expirado, o ya usado → error claro +
  opción de solicitar uno nuevo
- Envío de email falla (proveedor SMTP caído) → la cuenta no debe quedar
  en un estado inconsistente (ej. registrada pero sin ninguna forma de
  verificar); ofrecer reintento de envío
- JWT expirado → el cliente debe re-autenticarse (ver pregunta abierta
  sobre refresh token)
- Múltiples solicitudes de reset de password seguidas → los links previos
  quedan invalidados al generarse uno nuevo (evita acumulación de tokens
  válidos)

## Out of scope
- Login social (Google/Apple) — evaluado y descartado para esta iteración
- Upload de imagen de avatar — solo presets
- Roles de administrador o moderación
- 2FA
- Recuperación de cuenta por username (solo por email)
- Rate limiting / protección anti-bruteforce detallada (se anota como
  riesgo para que el Architect lo considere, pero no es un criterio de
  aceptación de esta iteración)

## Open questions (resueltas durante la implementación)
- **JWT único vs. access+refresh** → se implementó **JWT de acceso único
  con expiración de 7 días** (`ACCESS_TOKEN_EXPIRE_DAYS = 7` en
  `backend/app/core/security.py`), sin refresh token — prioriza simplicidad
  de implementación sobre la UX de expiración silenciosa. Si en el futuro
  se necesita revocar sesiones sin esperar la expiración (ej. "cerrar
  sesión en todos los dispositivos"), esto requiere rediseño (hoy no hay
  ninguna lista de tokens revocados).
- **Credenciales SMTP** → en desarrollo se usa **Mailhog** (contenedor
  local, `docker-compose.yml`), que no envía correos reales — captura todo
  en una UI de inspección (`localhost:8025`). **No hay todavía una cuenta
  transaccional real para producción** (Mailgun/Brevo/etc.) — pendiente
  cuando el proyecto tenga un ambiente de producción real; es decisión de
  AWS Architect/DevOps, no bloquea el desarrollo actual.

## References
- Bloqueante que originó esta spec: `docs/designs/gacha-engine.md`
  (motor de gacha, bloqueado hasta tener auth)
- Backend actual: `backend/app/main.py` (solo boilerplate FastAPI, sin
  modelos ni rutas todavía)
- Sin código de perfil/cuenta existente en frontend (`player.dart` es
  estado de partida, no aplica)
