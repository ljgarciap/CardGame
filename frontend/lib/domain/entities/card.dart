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

  /// El backend usa rank en snake_case (`minor_god`, `major_god`) — no
  /// coincide con los nombres camelCase del enum Dart, hace falta mapear.
  static CardRank _rankFromJson(String value) {
    switch (value) {
      case 'hero':
        return CardRank.hero;
      case 'demigod':
        return CardRank.demigod;
      case 'minor_god':
        return CardRank.minorGod;
      case 'major_god':
        return CardRank.majorGod;
      default:
        throw ArgumentError('rank desconocido: $value');
    }
  }

  factory TCGCardEntity.fromJson(Map<String, dynamic> json) {
    return TCGCardEntity(
      id: json['archetype_id'] as String,
      name: json['name'] as String,
      faction: CardFaction.values.byName(json['faction'] as String),
      rarity: CardRarity.values.byName(json['rarity'] as String),
      rank: _rankFromJson(json['rank'] as String),
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      description: '',
    );
  }
}
