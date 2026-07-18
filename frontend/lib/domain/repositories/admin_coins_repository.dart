import '../entities/coin_grant.dart';

/// Otorgamiento de coins por un superadmin — individual (premio a un
/// jugador puntual, por email o username) o broadcast (evento para toda la
/// comunidad). Solo accesible por un superadmin (el backend devuelve 403
/// si no lo es).
abstract class AdminCoinsRepository {
  /// Devuelve el saldo resultante del usuario otorgado.
  Future<int> grant({
    required String userIdentifier,
    required int amount,
    String? reason,
  });

  /// Devuelve la cantidad de usuarios que recibieron el otorgamiento.
  Future<int> broadcast({required int amount, String? reason});

  Future<List<CoinGrantEntity>> getHistory();
}
