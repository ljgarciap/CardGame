import '../entities/owned_card.dart';

abstract class CollectionRepository {
  /// La colección completa del jugador autenticado — la usa el deck
  /// builder de partidas en tiempo real para elegir las 10 cartas del mazo.
  ///
  /// Lanza [ApiException] con status 401 (no autenticado).
  Future<List<OwnedCardEntity>> getMyCards();
}
