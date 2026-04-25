enum CardRarity {
  common,
  rare,
  epic,
  legendary,
}

enum CardRank {
  hero,
  demigod,
  minorGod,
  majorGod,
}

enum CardFaction {
  greek,
  norse,
  egyptian,
  aztec,
  oriental,
}

class TCGCardEntity {
  final String id;
  final String name;
  final CardFaction faction;
  final CardRarity rarity;
  final CardRank rank;
  final int attack;
  final int defense;
  final String description;
  final String? imageUrl;

  TCGCardEntity({
    required this.id,
    required this.name,
    required this.faction,
    required this.rarity,
    required this.rank,
    required this.attack,
    required this.defense,
    required this.description,
    this.imageUrl,
  });
}
