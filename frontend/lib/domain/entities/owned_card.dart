import 'card.dart';

/// Una carta que el jugador realmente posee (`player_cards` en el backend),
/// distinta de [TCGCardEntity] que solo describe el arquetipo. La usa el
/// deck builder para elegir las 10 cartas del mazo — necesita el
/// `playerCardId` de la instancia poseída, no solo el `archetypeId`.
class OwnedCardEntity {
  final String playerCardId;
  final String archetypeId;
  final String name;
  final CardFaction faction;
  final CardRank rank;
  final CardRarity rarity;
  final int attack;
  final int defense;

  OwnedCardEntity({
    required this.playerCardId,
    required this.archetypeId,
    required this.name,
    required this.faction,
    required this.rank,
    required this.rarity,
    required this.attack,
    required this.defense,
  });

  factory OwnedCardEntity.fromJson(Map<String, dynamic> json) {
    return OwnedCardEntity(
      playerCardId: json['player_card_id'] as String,
      archetypeId: json['archetype_id'] as String,
      name: json['name'] as String,
      faction: CardFaction.values.byName(json['faction'] as String),
      rarity: CardRarity.values.byName(json['rarity'] as String),
      rank: CardRankApi.fromApiValue(json['rank'] as String),
      attack: json['attack'] as int,
      defense: json['defense'] as int,
    );
  }
}
