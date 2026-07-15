import '../entities/card.dart';
import '../entities/gacha_config.dart';

/// CRUD de la config paramétrica del gacha — solo accesible por un
/// superadmin (el backend devuelve 403 si no lo es).
abstract class GachaConfigRepository {
  Future<GachaConfigEntity> getConfig();

  Future<void> updatePackLevel({
    required int level,
    required int price,
    required int cardsPerPack,
    required CardRank? guaranteedMinRank,
  });

  Future<void> updateRankProbabilities({
    required int level,
    required String hero,
    required String demigod,
    required String minorGod,
    required String majorGod,
  });

  Future<void> updateRarityProbabilities({
    required int level,
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  });

  Future<void> updateRarityBonus({
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  });
}
