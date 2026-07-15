import '../../core/errors/api_exception.dart';
import '../../domain/entities/pack.dart';
import '../../domain/repositories/pack_repository.dart';
import '../datasources/pack_remote_datasource.dart';
import '../datasources/token_storage.dart';

class PackRepositoryImpl implements PackRepository {
  final PackRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  PackRepositoryImpl({
    PackRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? PackRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  @override
  Future<PackOpenResultEntity> openPack({required int level}) async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    final json = await _remote.openPack(token: token, level: level);
    return PackOpenResultEntity.fromJson(json);
  }
}
