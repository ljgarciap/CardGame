import 'card.dart';

class PackLevel {
  final int level; // 1 to 5
  final Map<CardRank, double> rankProbabilities;
  final Map<CardRarity, double> rarityProbabilities;
  final CardRank? guaranteedRank;

  PackLevel({
    required this.level,
    required this.rankProbabilities,
    required this.rarityProbabilities,
    this.guaranteedRank,
  });

  factory PackLevel.level1() {
    return PackLevel(
      level: 1,
      rankProbabilities: {
        CardRank.hero: 0.80,
        CardRank.demigod: 0.15,
        CardRank.minorGod: 0.04,
        CardRank.majorGod: 0.01,
      },
      rarityProbabilities: {
        CardRarity.common: 0.90,
        CardRarity.rare: 0.08,
        CardRarity.epic: 0.015,
        CardRarity.legendary: 0.005,
      },
    );
  }

  factory PackLevel.level5() {
    return PackLevel(
      level: 5,
      rankProbabilities: {
        CardRank.hero: 0.10,
        CardRank.demigod: 0.20,
        CardRank.minorGod: 0.40,
        CardRank.majorGod: 0.30,
      },
      rarityProbabilities: {
        CardRarity.common: 0.40,
        CardRarity.rare: 0.30,
        CardRarity.epic: 0.20,
        CardRarity.legendary: 0.10,
      },
      guaranteedRank: CardRank.majorGod,
    );
  }
}

class CardPackEntity {
  final String id;
  final String name;
  final PackLevel level;
  final int cardCount;

  CardPackEntity({
    required this.id,
    required this.name,
    required this.level,
    this.cardCount = 5,
  });
}
