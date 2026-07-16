import '../entities/deck_config.dart';

/// CRUD de la config paramétrica de mazos guardados — solo accesible por un
/// superadmin (el backend devuelve 403 si no lo es).
abstract class DeckConfigRepository {
  Future<DeckConfigEntity> getConfig();

  Future<void> updateMaxDecksPerUser(int maxDecksPerUser);
}
