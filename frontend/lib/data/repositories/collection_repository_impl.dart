import '../../core/errors/api_exception.dart';
import '../../domain/entities/owned_card.dart';
import '../../domain/repositories/collection_repository.dart';
import '../datasources/collection_remote_datasource.dart';
import '../datasources/token_storage.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  final CollectionRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  CollectionRepositoryImpl({
    CollectionRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? CollectionRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return token;
  }

  @override
  Future<List<OwnedCardEntity>> getMyCards() async {
    final token = await _requireToken();
    final json = await _remote.getMyCards(token: token);
    return json.map((e) => OwnedCardEntity.fromJson(e as Map<String, dynamic>)).toList();
  }
}
