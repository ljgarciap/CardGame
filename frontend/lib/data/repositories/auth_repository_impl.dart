import '../../core/errors/api_exception.dart';
import '../../domain/entities/user_account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl({
    AuthRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? AuthRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String avatarId,
  }) async {
    await _remote.register(
      email: email,
      password: password,
      username: username,
      avatarId: avatarId,
    );
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    await _remote.verifyEmail(token: token);
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _remote.resendVerification(email: email);
  }

  @override
  Future<UserAccountEntity> login({
    required String email,
    required String password,
  }) async {
    final json = await _remote.login(email: email, password: password);
    final token = json['access_token'] as String;
    await _tokenStorage.save(token);
    return getMe();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _remote.requestPasswordReset(email: email);
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _remote.resetPassword(token: token, newPassword: newPassword);
  }

  @override
  Future<UserAccountEntity> getMe() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    final json = await _remote.getMe(token: token);
    return UserAccountEntity.fromJson(json);
  }

  @override
  Future<UserAccountEntity> updateMe({String? username, String? avatarId}) async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    final json = await _remote.updateMe(
      token: token,
      username: username,
      avatarId: avatarId,
    );
    return UserAccountEntity.fromJson(json);
  }

  @override
  Future<String?> readStoredToken() => _tokenStorage.read();

  @override
  Future<void> logout() => _tokenStorage.clear();
}
