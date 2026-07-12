import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_account.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final UserAccountEntity? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(UserAccountEntity user)
      : this(status: AuthStatus.authenticated, user: user);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    final token = await _repository.readStoredToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final user = await _repository.getMe();
      state = AuthState.authenticated(user);
    } catch (_) {
      await _repository.logout();
      state = const AuthState.unauthenticated();
    }
  }

  /// Lanza [ApiException] en caso de error — la pantalla decide cómo mostrarlo.
  Future<void> login({required String email, required String password}) async {
    final user = await _repository.login(email: email, password: password);
    state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.unauthenticated();
  }

  /// Lanza [ApiException] en caso de error (ej. username ya en uso).
  Future<void> updateProfile({String? username, String? avatarId}) async {
    final user = await _repository.updateMe(username: username, avatarId: avatarId);
    state = AuthState.authenticated(user);
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getMe();
      state = AuthState.authenticated(user);
    } catch (_) {
      await logout();
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
