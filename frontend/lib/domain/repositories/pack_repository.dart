import '../entities/gacha_config.dart';
import '../entities/pack.dart';

abstract class PackRepository {
  /// Niveles de sobre disponibles (precio, cartas por sobre, garantía) tal
  /// como están configurados hoy en el servidor — el Marketplace lo usa en
  /// vez de datos hardcodeados en el cliente, que podrían desincronizarse
  /// del admin CRUD.
  Future<List<GachaPackLevelConfig>> getPackLevels();

  /// Abre un sobre del nivel dado. El resultado (cartas + saldo restante)
  /// viene resuelto del servidor — server-authoritative.
  ///
  /// Lanza [ApiException] con status 401 (no autenticado), 400 (nivel
  /// inválido) o 402 (saldo insuficiente).
  Future<PackOpenResultEntity> openPack({required int level});
}
