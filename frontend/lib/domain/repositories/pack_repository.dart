import '../entities/pack.dart';

abstract class PackRepository {
  /// Abre un sobre del nivel dado. El resultado (cartas + saldo restante)
  /// viene resuelto del servidor — server-authoritative.
  ///
  /// Lanza [ApiException] con status 401 (no autenticado), 400 (nivel
  /// inválido) o 402 (saldo insuficiente).
  Future<PackOpenResultEntity> openPack({required int level});
}
