import '../entities/saved_deck.dart';

abstract class DeckRepository {
  /// Lanza [ApiException] 401 si no hay sesión.
  Future<List<SavedDeckEntity>> getDecks();

  /// Lanza [ApiException] 400 si el mazo no tiene exactamente 10 cartas
  /// propias distintas, o si ya se llegó al máximo de mazos guardados.
  Future<SavedDeckEntity> createDeck({required String name, required List<String> playerCardIds});

  /// Lanza [ApiException] 404 si el mazo no existe o no es del usuario, 400
  /// con la misma validación que [createDeck].
  Future<SavedDeckEntity> updateDeck({
    required String deckId,
    required String name,
    required List<String> playerCardIds,
  });

  /// Lanza [ApiException] 404 si el mazo no existe o no es del usuario.
  Future<void> deleteDeck(String deckId);
}
