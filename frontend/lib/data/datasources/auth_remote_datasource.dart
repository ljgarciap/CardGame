import 'dart:convert';

import 'base_remote_datasource.dart';

class AuthRemoteDatasource extends BaseRemoteDatasource {
  AuthRemoteDatasource({super.client});

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String avatarId,
  }) async {
    final response = await client.post(
      uri('/api/auth/register'),
      headers: jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'avatar_id': avatarId,
      }),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> resendVerification({required String email}) async {
    final response = await client.post(
      uri('/api/auth/resend-verification'),
      headers: jsonHeaders,
      body: jsonEncode({'email': email}),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      uri('/api/auth/login'),
      headers: jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    final response = await client.post(
      uri('/api/auth/request-password-reset'),
      headers: jsonHeaders,
      body: jsonEncode({'email': email}),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await client.post(
      uri('/api/auth/reset-password'),
      headers: jsonHeaders,
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> getMe({required String token}) async {
    final response = await client.get(
      uri('/api/users/me'),
      headers: authHeaders(token),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateMe({
    required String token,
    String? username,
    String? avatarId,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatarId != null) body['avatar_id'] = avatarId;

    final response = await client.patch(
      uri('/api/users/me'),
      headers: authHeaders(token),
      body: jsonEncode(body),
    );
    return decodeOrThrow(response);
  }
}
