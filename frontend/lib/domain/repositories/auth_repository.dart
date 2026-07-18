import '../entities/user_account.dart';

abstract class AuthRepository {
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String avatarId,
  });

  Future<void> verifyEmail({required String token});

  Future<void> resendVerification({required String email});

  /// Inicia sesión y persiste el token. Devuelve el perfil del jugador.
  Future<UserAccountEntity> login({
    required String email,
    required String password,
  });

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<UserAccountEntity> getMe();

  Future<UserAccountEntity> updateMe({String? username, String? avatarId});

  /// Token persistido, o null si no hay sesión iniciada.
  Future<String?> readStoredToken();

  Future<void> logout();
}
