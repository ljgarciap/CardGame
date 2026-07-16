import 'dart:convert';

import 'base_remote_datasource.dart';

class DeckRemoteDatasource extends BaseRemoteDatasource {
  DeckRemoteDatasource({super.client});

  Future<List<dynamic>> getDecks({required String token}) async {
    final response = await client.get(uri('/api/decks'), headers: authHeaders(token));
    return decodeListOrThrow(response);
  }

  Future<Map<String, dynamic>> createDeck({
    required String token,
    required String name,
    required List<String> playerCardIds,
  }) async {
    final response = await client.post(
      uri('/api/decks'),
      headers: authHeaders(token),
      body: jsonEncode({'name': name, 'player_card_ids': playerCardIds}),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateDeck({
    required String token,
    required String deckId,
    required String name,
    required List<String> playerCardIds,
  }) async {
    final response = await client.put(
      uri('/api/decks/$deckId'),
      headers: authHeaders(token),
      body: jsonEncode({'name': name, 'player_card_ids': playerCardIds}),
    );
    return decodeOrThrow(response);
  }

  Future<void> deleteDeck({required String token, required String deckId}) async {
    final response = await client.delete(uri('/api/decks/$deckId'), headers: authHeaders(token));
    decodeOrThrow(response);
  }
}
