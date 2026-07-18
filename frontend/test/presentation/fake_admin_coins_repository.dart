import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/domain/entities/coin_grant.dart';
import 'package:card_game/domain/repositories/admin_coins_repository.dart';

/// Doble de prueba: permite forzar éxito/fallo sin llamar al backend real.
class FakeAdminCoinsRepository implements AdminCoinsRepository {
  List<CoinGrantEntity> history;
  ApiException? grantError;
  ApiException? broadcastError;
  ApiException? historyError;
  int nextBalance = 100;
  int nextRecipientCount = 5;

  final List<String> calls = [];

  FakeAdminCoinsRepository({List<CoinGrantEntity>? history}) : history = history ?? [];

  @override
  Future<int> grant({
    required String userIdentifier,
    required int amount,
    String? reason,
  }) async {
    calls.add('grant($userIdentifier, $amount)');
    if (grantError != null) throw grantError!;
    return nextBalance;
  }

  @override
  Future<int> broadcast({required int amount, String? reason}) async {
    calls.add('broadcast($amount)');
    if (broadcastError != null) throw broadcastError!;
    return nextRecipientCount;
  }

  @override
  Future<List<CoinGrantEntity>> getHistory() async {
    calls.add('getHistory()');
    if (historyError != null) throw historyError!;
    return history;
  }
}
