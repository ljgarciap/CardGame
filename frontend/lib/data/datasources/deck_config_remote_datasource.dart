import 'dart:convert';

import 'base_remote_datasource.dart';

class DeckConfigRemoteDatasource extends BaseRemoteDatasource {
  DeckConfigRemoteDatasource({super.client});

  Future<Map<String, dynamic>> getConfig({required String token}) async {
    final response = await client.get(
      uri('/api/admin/deck-config'),
      headers: authHeaders(token),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateConfig({
    required String token,
    required int maxDecksPerUser,
  }) async {
    final response = await client.put(
      uri('/api/admin/deck-config'),
      headers: authHeaders(token),
      body: jsonEncode({'max_decks_per_user': maxDecksPerUser}),
    );
    return decodeOrThrow(response);
  }
}
