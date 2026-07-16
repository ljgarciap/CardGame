import '../../core/errors/api_exception.dart';
import '../../domain/repositories/match_repository.dart';
import '../datasources/match_websocket_client.dart';
import '../datasources/token_storage.dart';

class MatchRepositoryImpl implements MatchRepository {
  final MatchWebSocketClient _client;
  final TokenStorage _tokenStorage;

  MatchRepositoryImpl({
    MatchWebSocketClient? client,
    TokenStorage? tokenStorage,
  })  : _client = client ?? MatchWebSocketClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  @override
  Future<Stream<Map<String, dynamic>>> connect() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return _client.connect(token);
  }

  @override
  void queue(List<String> deck) => _client.send({'action': 'queue', 'deck': deck});

  @override
  void leaveQueue() => _client.send({'action': 'leave_queue'});

  @override
  void playCard(String playerCardId) =>
      _client.send({'action': 'play_card', 'player_card_id': playerCardId});

  @override
  void attackFace(String attackerId) =>
      _client.send({'action': 'attack', 'attacker_id': attackerId, 'target': 'face'});

  @override
  void attackCard({required String attackerId, required String targetCardId}) => _client.send({
        'action': 'attack',
        'attacker_id': attackerId,
        'target': {'card_id': targetCardId},
      });

  @override
  void endTurn() => _client.send({'action': 'end_turn'});

  @override
  void forfeit() => _client.send({'action': 'forfeit'});

  @override
  Future<void> disconnect() => _client.close();

  @override
  int? get lastCloseCode => _client.closeCode;
}
