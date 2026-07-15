import 'dart:convert';

import 'base_remote_datasource.dart';

class PackRemoteDatasource extends BaseRemoteDatasource {
  PackRemoteDatasource({super.client});

  Future<Map<String, dynamic>> openPack({required String token, required int level}) async {
    final response = await client.post(
      uri('/api/packs/open'),
      headers: authHeaders(token),
      body: jsonEncode({'level': level}),
    );
    return decodeOrThrow(response);
  }
}
