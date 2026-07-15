import 'dart:convert';

import '../../domain/entities/card.dart';
import 'base_remote_datasource.dart';

class GachaConfigRemoteDatasource extends BaseRemoteDatasource {
  GachaConfigRemoteDatasource({super.client});

  Future<Map<String, dynamic>> getConfig({required String token}) async {
    final response = await client.get(
      uri('/api/admin/gacha-config'),
      headers: authHeaders(token),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updatePackLevel({
    required String token,
    required int level,
    required int price,
    required CardRank? guaranteedMinRank,
  }) async {
    final response = await client.put(
      uri('/api/admin/gacha-config/pack-levels/$level'),
      headers: authHeaders(token),
      body: jsonEncode({
        'price': price,
        'guaranteed_min_rank': guaranteedMinRank?.apiValue,
      }),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateRankProbabilities({
    required String token,
    required int level,
    required String hero,
    required String demigod,
    required String minorGod,
    required String majorGod,
  }) async {
    final response = await client.put(
      uri('/api/admin/gacha-config/rank-probabilities/$level'),
      headers: authHeaders(token),
      body: jsonEncode({
        'hero': hero,
        'demigod': demigod,
        'minor_god': minorGod,
        'major_god': majorGod,
      }),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateRarityProbabilities({
    required String token,
    required int level,
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    final response = await client.put(
      uri('/api/admin/gacha-config/rarity-probabilities/$level'),
      headers: authHeaders(token),
      body: jsonEncode({
        'common': common,
        'rare': rare,
        'epic': epic,
        'legendary': legendary,
      }),
    );
    return decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> updateRarityBonus({
    required String token,
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    final response = await client.put(
      uri('/api/admin/gacha-config/rarity-bonus'),
      headers: authHeaders(token),
      body: jsonEncode({
        'common': common,
        'rare': rare,
        'epic': epic,
        'legendary': legendary,
      }),
    );
    return decodeOrThrow(response);
  }
}
