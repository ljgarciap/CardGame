import '../../core/errors/api_exception.dart';
import '../../domain/entities/saved_deck.dart';
import '../../domain/repositories/deck_repository.dart';
import '../datasources/deck_remote_datasource.dart';
import '../datasources/token_storage.dart';

class DeckRepositoryImpl implements DeckRepository {
  final DeckRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  DeckRepositoryImpl({
    DeckRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? DeckRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return token;
  }

  @override
  Future<List<SavedDeckEntity>> getDecks() async {
    final token = await _requireToken();
    final json = await _remote.getDecks(token: token);
    return json.map((e) => SavedDeckEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SavedDeckEntity> createDeck({required String name, required List<String> playerCardIds}) async {
    final token = await _requireToken();
    final json = await _remote.createDeck(token: token, name: name, playerCardIds: playerCardIds);
    return SavedDeckEntity.fromJson(json);
  }

  @override
  Future<SavedDeckEntity> updateDeck({
    required String deckId,
    required String name,
    required List<String> playerCardIds,
  }) async {
    final token = await _requireToken();
    final json = await _remote.updateDeck(
      token: token,
      deckId: deckId,
      name: name,
      playerCardIds: playerCardIds,
    );
    return SavedDeckEntity.fromJson(json);
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    final token = await _requireToken();
    await _remote.deleteDeck(token: token, deckId: deckId);
  }
}
