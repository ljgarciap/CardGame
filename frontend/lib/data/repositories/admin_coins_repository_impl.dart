import '../../core/errors/api_exception.dart';
import '../../domain/entities/coin_grant.dart';
import '../../domain/repositories/admin_coins_repository.dart';
import '../datasources/admin_coins_remote_datasource.dart';
import '../datasources/token_storage.dart';

class AdminCoinsRepositoryImpl implements AdminCoinsRepository {
  final AdminCoinsRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  AdminCoinsRepositoryImpl({
    AdminCoinsRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? AdminCoinsRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return token;
  }

  @override
  Future<int> grant({
    required String userIdentifier,
    required int amount,
    String? reason,
  }) async {
    final token = await _requireToken();
    final json = await _remote.grant(
      token: token,
      userIdentifier: userIdentifier,
      amount: amount,
      reason: reason,
    );
    return json['target_coins'] as int;
  }

  @override
  Future<int> broadcast({required int amount, String? reason}) async {
    final token = await _requireToken();
    final json = await _remote.broadcast(token: token, amount: amount, reason: reason);
    return json['recipient_count'] as int;
  }

  @override
  Future<List<CoinGrantEntity>> getHistory() async {
    final token = await _requireToken();
    final json = await _remote.getHistory(token: token);
    return json
        .map((e) => CoinGrantEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
