import 'dart:convert';

import 'base_remote_datasource.dart';

class AdminCoinsRemoteDatasource extends BaseRemoteDatasource {
  AdminCoinsRemoteDatasource({super.client});

  Future<Map<String, dynamic>> grant({
    required String token,
    required String userIdentifier,
    required int amount,
    String? reason,
  }) async {
    final response = await client.post(
      uri('/api/admin/coins/grant'),
      headers: authHeaders(token),
      body: jsonEncode({
        'user_identifier': userIdentifier,
        'amount': amount,
        'reason': reason,
      }),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> broadcast({
    required String token,
    required int amount,
    String? reason,
  }) async {
    final response = await client.post(
      uri('/api/admin/coins/broadcast'),
      headers: authHeaders(token),
      body: jsonEncode({'amount': amount, 'reason': reason}),
    );
    return decodeOrThrow(response);
  }

  Future<List<dynamic>> getHistory({required String token}) async {
    final response = await client.get(
      uri('/api/admin/coins/history'),
      headers: authHeaders(token),
    );
    return decodeListOrThrow(response);
  }
}
