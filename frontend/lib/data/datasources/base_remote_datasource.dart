import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/errors/api_exception.dart';

/// Boilerplate compartido entre todos los datasources HTTP del cliente:
/// armar la URL, headers, y decodificar la respuesta o convertirla en
/// [ApiException]. Extraído después de que el mismo bloque apareciera
/// idéntico en 3 datasources (auth, packs, gacha config).
abstract class BaseRemoteDatasource {
  final http.Client client;

  BaseRemoteDatasource({http.Client? client}) : client = client ?? http.Client();

  Uri uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> get jsonHeaders => {'Content-Type': 'application/json'};

  Map<String, String> authHeaders(String token) => {
        ...jsonHeaders,
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

  Map<String, dynamic> _decodeErrorBody(http.Response response) {
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  Never _throwApiException(http.Response response) {
    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(_decodeErrorBody(response), response.statusCode),
    );
  }

  bool _isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  /// Para endpoints cuyo body de éxito es un objeto JSON (`{...}`).
  Map<String, dynamic> decodeOrThrow(http.Response response) {
    if (!_isSuccess(response)) _throwApiException(response);
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Para endpoints cuyo body de éxito es un array JSON (`[...]`) — un error
  /// FastAPI siempre es un objeto (`{"detail": ...}`) independientemente de
  /// la forma del body de éxito, por eso _throwApiException es compartido.
  List<dynamic> decodeListOrThrow(http.Response response) {
    if (!_isSuccess(response)) _throwApiException(response);
    return response.body.isEmpty ? <dynamic>[] : jsonDecode(response.body) as List<dynamic>;
  }
}
