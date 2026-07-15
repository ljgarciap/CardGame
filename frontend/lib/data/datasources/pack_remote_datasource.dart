import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/errors/api_exception.dart';

class PackRemoteDatasource {
  final http.Client _client;

  PackRemoteDatasource({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
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

  Future<Map<String, dynamic>> openPack({required String token, required int level}) async {
    final response = await _client.post(
      _uri('/api/packs/open'),
      headers: _authHeaders(token),
      body: jsonEncode({'level': level}),
    );
    return _decodeOrThrow(response);
  }
}
