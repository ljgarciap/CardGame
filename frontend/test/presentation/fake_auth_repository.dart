import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/domain/entities/user_account.dart';
import 'package:card_game/domain/repositories/auth_repository.dart';

/// Doble de prueba: permite forzar éxito/fallo sin llamar al backend real.
class FakeAuthRepository implements AuthRepository {
  String? storedToken;
  UserAccountEntity? profile;
  ApiException? loginError;
  ApiException? updateError;

  FakeAuthRepository({this.storedToken, this.profile});

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String avatarId,
  }) async {}

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<UserAccountEntity> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    storedToken = 'fake-token';
    profile ??= UserAccountEntity(
      id: 'user-1',
      email: email,
      username: 'player_one',
      avatarId: 'avatar_1',
      coins: 0,
      emailVerified: true,
    );
    return profile!;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<UserAccountEntity> getMe() async {
    if (profile == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return profile!;
  }

  @override
  Future<UserAccountEntity> updateMe({String? username, String? avatarId}) async {
    if (updateError != null) throw updateError!;
    profile = UserAccountEntity(
      id: profile!.id,
      email: profile!.email,
      username: username ?? profile!.username,
      avatarId: avatarId ?? profile!.avatarId,
      coins: profile!.coins,
      emailVerified: profile!.emailVerified,
    );
    return profile!;
  }

  @override
  Future<String?> readStoredToken() async => storedToken;

  @override
  Future<void> logout() async {
    storedToken = null;
  }
}
