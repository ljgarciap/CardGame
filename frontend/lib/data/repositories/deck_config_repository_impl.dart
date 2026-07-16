import '../../core/errors/api_exception.dart';
import '../../domain/entities/deck_config.dart';
import '../../domain/repositories/deck_config_repository.dart';
import '../datasources/deck_config_remote_datasource.dart';
import '../datasources/token_storage.dart';

class DeckConfigRepositoryImpl implements DeckConfigRepository {
  final DeckConfigRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  DeckConfigRepositoryImpl({
    DeckConfigRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? DeckConfigRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return token;
  }

  @override
  Future<DeckConfigEntity> getConfig() async {
    final token = await _requireToken();
    final json = await _remote.getConfig(token: token);
    return DeckConfigEntity.fromJson(json);
  }

  @override
  Future<void> updateMaxDecksPerUser(int maxDecksPerUser) async {
    final token = await _requireToken();
    await _remote.updateConfig(token: token, maxDecksPerUser: maxDecksPerUser);
  }
}
