/// Deep link de reset-password: `cardgame://reset-password?token=...`.
///
/// Custom URL scheme, no Universal/App Link verificado — `cardgame.local`
/// (el dominio que manda el email de reset, ver `backend/app/api/auth.py`)
/// no es un dominio real que podamos hostear, así que no hay forma de
/// publicar `apple-app-site-association`/`assetlinks.json` para verificar un
/// link HTTPS. Un custom scheme funciona sin esa infraestructura.
String? extractResetPasswordToken(Uri uri) {
  if (uri.scheme != 'cardgame' || uri.host != 'reset-password') return null;
  final token = uri.queryParameters['token'];
  return (token == null || token.isEmpty) ? null : token;
}

/// Deep link de verificación de email: `cardgame://verify-email?token=...`.
/// Mismo scheme y mismo motivo que [extractResetPasswordToken].
String? extractVerifyEmailToken(Uri uri) {
  if (uri.scheme != 'cardgame' || uri.host != 'verify-email') return null;
  final token = uri.queryParameters['token'];
  return (token == null || token.isEmpty) ? null : token;
}
