import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// En Flutter Web, `flutter_secure_storage` cifra con la Web Crypto API del
/// navegador (`crypto.subtle`), que solo existe en contextos seguros (HTTPS
/// o `http://localhost`). Servido por HTTP plano sobre una IP (como este VPS
/// de prueba, sin TLS todavía), `crypto.subtle` no existe y el write()
/// tira una excepción no capturada -- el login parece "no hacer nada".
/// En Web usamos SharedPreferences (sin cifrar) en su lugar; en el resto de
/// plataformas se mantiene el cifrado real del SO vía FlutterSecureStorage.
class TokenStorage {
  static const _tokenKey = 'auth_access_token';

  final FlutterSecureStorage? _secureStorage;

  TokenStorage({FlutterSecureStorage? storage})
      : _secureStorage = kIsWeb ? null : (storage ?? const FlutterSecureStorage());

  Future<void> save(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return;
    }
    await _secureStorage!.write(key: _tokenKey, value: token);
  }

  Future<String?> read() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return _secureStorage!.read(key: _tokenKey);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      return;
    }
    await _secureStorage!.delete(key: _tokenKey);
  }
}
