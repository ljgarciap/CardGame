import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/errors/api_exception.dart';

class AuthRemoteDatasource {
  final http.Client _client;

  AuthRemoteDatasource({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  Map<String, String> _authHeaders(String token) => {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      };

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      return detail
          .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
          .join('; ');
    }
    return 'Error inesperado ($statusCode)';
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final Map<String, dynamic> body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(body, response.statusCode),
    );
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String avatarId,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'avatar_id': avatarId,
      }),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> resendVerification({required String email}) async {
    final response = await _client.post(
      _uri('/api/auth/resend-verification'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email}),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    final response = await _client.post(
      _uri('/api/auth/request-password-reset'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email}),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/reset-password'),
      headers: _jsonHeaders,
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> getMe({required String token}) async {
    final response = await _client.get(
      _uri('/api/users/me'),
      headers: _authHeaders(token),
    );
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateMe({
    required String token,
    String? username,
    String? avatarId,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatarId != null) body['avatar_id'] = avatarId;

    final response = await _client.patch(
      _uri('/api/users/me'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    return _decodeOrThrow(response);
  }
}
