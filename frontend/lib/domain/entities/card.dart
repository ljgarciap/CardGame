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

/// El backend usa rank en snake_case (`minor_god`, `major_god`) — no
/// coincide con los nombres camelCase del enum Dart, hace falta mapear en
/// ambas direcciones (parsear la respuesta del servidor y serializar el
/// body de un PUT admin).
extension CardRankApi on CardRank {
  String get apiValue {
    switch (this) {
      case CardRank.hero:
        return 'hero';
      case CardRank.demigod:
        return 'demigod';
      case CardRank.minorGod:
        return 'minor_god';
      case CardRank.majorGod:
        return 'major_god';
    }
  }

  static CardRank fromApiValue(String value) {
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
}

/// Label legible para mostrar en UI — separado de [CardRankApi.apiValue]
/// porque `rank.name.toUpperCase()` en un enum Dart camelCase (`minorGod`)
/// da "MINORGOD" sin espacio, no "MINOR GOD".
extension CardRankDisplay on CardRank {
  String get displayLabel {
    switch (this) {
      case CardRank.hero:
        return 'HERO';
      case CardRank.demigod:
        return 'DEMIGOD';
      case CardRank.minorGod:
        return 'MINOR GOD';
      case CardRank.majorGod:
        return 'MAJOR GOD';
    }
  }
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

  factory TCGCardEntity.fromJson(Map<String, dynamic> json) {
    return TCGCardEntity(
      id: json['archetype_id'] as String,
      name: json['name'] as String,
      faction: CardFaction.values.byName(json['faction'] as String),
      rarity: CardRarity.values.byName(json['rarity'] as String),
      rank: CardRankApi.fromApiValue(json['rank'] as String),
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      description: '',
    );
  }
}
