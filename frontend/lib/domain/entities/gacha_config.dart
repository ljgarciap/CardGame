import 'card.dart';

/// Config paramétrica del gacha (precio, garantía, probabilidades, bono de
/// rareza) — editable por un superadmin vía `/api/admin/gacha-config`, no
/// vive hardcodeada en el cliente ni en el servidor.
///
/// Las probabilidades/bono se guardan como `String` (no `double`): el
/// backend los serializa como texto decimal (Pydantic `Decimal`) y así
/// evitamos perder precisión en el round-trip GET -> editar -> PUT.
class GachaPackLevelConfig {
  final int level;
  final int price;
  final int cardsPerPack;
  final CardRank? guaranteedMinRank;

  GachaPackLevelConfig({
    required this.level,
    required this.price,
    required this.cardsPerPack,
    required this.guaranteedMinRank,
  });

  factory GachaPackLevelConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['guaranteed_min_rank'] as String?;
    return GachaPackLevelConfig(
      level: json['level'] as int,
      price: json['price'] as int,
      cardsPerPack: json['cards_per_pack'] as int,
      guaranteedMinRank: raw == null ? null : CardRankApi.fromApiValue(raw),
    );
  }
}

class GachaRankProbabilitiesConfig {
  final int level;
  final String hero;
  final String demigod;
  final String minorGod;
  final String majorGod;

  GachaRankProbabilitiesConfig({
    required this.level,
    required this.hero,
    required this.demigod,
    required this.minorGod,
    required this.majorGod,
  });

  factory GachaRankProbabilitiesConfig.fromJson(Map<String, dynamic> json) {
    return GachaRankProbabilitiesConfig(
      level: json['level'] as int,
      hero: json['hero'] as String,
      demigod: json['demigod'] as String,
      minorGod: json['minor_god'] as String,
      majorGod: json['major_god'] as String,
    );
  }
}

class GachaRarityProbabilitiesConfig {
  final int level;
  final String common;
  final String rare;
  final String epic;
  final String legendary;

  GachaRarityProbabilitiesConfig({
    required this.level,
    required this.common,
    required this.rare,
    required this.epic,
    required this.legendary,
  });

  factory GachaRarityProbabilitiesConfig.fromJson(Map<String, dynamic> json) {
    return GachaRarityProbabilitiesConfig(
      level: json['level'] as int,
      common: json['common'] as String,
      rare: json['rare'] as String,
      epic: json['epic'] as String,
      legendary: json['legendary'] as String,
    );
  }
}

class GachaRarityBonusConfig {
  final String common;
  final String rare;
  final String epic;
  final String legendary;

  GachaRarityBonusConfig({
    required this.common,
    required this.rare,
    required this.epic,
    required this.legendary,
  });

  factory GachaRarityBonusConfig.fromJson(Map<String, dynamic> json) {
    return GachaRarityBonusConfig(
      common: json['common'] as String,
      rare: json['rare'] as String,
      epic: json['epic'] as String,
      legendary: json['legendary'] as String,
    );
  }
}

class GachaConfigEntity {
  final List<GachaPackLevelConfig> packLevels;
  final List<GachaRankProbabilitiesConfig> rankProbabilities;
  final List<GachaRarityProbabilitiesConfig> rarityProbabilities;
  final GachaRarityBonusConfig rarityBonus;

  GachaConfigEntity({
    required this.packLevels,
    required this.rankProbabilities,
    required this.rarityProbabilities,
    required this.rarityBonus,
  });

  factory GachaConfigEntity.fromJson(Map<String, dynamic> json) {
    return GachaConfigEntity(
      packLevels: (json['pack_levels'] as List)
          .map((e) => GachaPackLevelConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      rankProbabilities: (json['rank_probabilities'] as List)
          .map((e) => GachaRankProbabilitiesConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      rarityProbabilities: (json['rarity_probabilities'] as List)
          .map((e) => GachaRarityProbabilitiesConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      rarityBonus: GachaRarityBonusConfig.fromJson(
        json['rarity_bonus'] as Map<String, dynamic>,
      ),
    );
  }
}
