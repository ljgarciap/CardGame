import 'card.dart';

/// Una carta dentro de una partida en curso — en la mano o en el tablero.
/// Los campos de "en juego" (`currentDefense`/`summoningSick`/
/// `hasAttackedThisTurn`) son null para cartas en la mano: el servidor solo
/// los manda para cartas en un tablero (ver `_card_view` en
/// `match_engine.py` y docs/designs/realtime-match.md).
class CardInPlayEntity {
  final String playerCardId;
  final String name;
  final CardFaction faction;
  final CardRank rank;
  final CardRarity rarity;
  final int attack;
  final int maxDefense;
  final int? currentDefense;
  final bool? summoningSick;
  final bool? hasAttackedThisTurn;

  CardInPlayEntity({
    required this.playerCardId,
    required this.name,
    required this.faction,
    required this.rank,
    required this.rarity,
    required this.attack,
    required this.maxDefense,
    this.currentDefense,
    this.summoningSick,
    this.hasAttackedThisTurn,
  });

  bool get isInPlay => currentDefense != null;

  factory CardInPlayEntity.fromJson(Map<String, dynamic> json) {
    return CardInPlayEntity(
      playerCardId: json['player_card_id'] as String,
      name: json['name'] as String,
      faction: CardFaction.values.byName(json['faction'] as String),
      rarity: CardRarity.values.byName(json['rarity'] as String),
      rank: CardRankApi.fromApiValue(json['rank'] as String),
      attack: json['attack'] as int,
      maxDefense: json['max_defense'] as int,
      currentDefense: json['current_defense'] as int?,
      summoningSick: json['summoning_sick'] as bool?,
      hasAttackedThisTurn: json['has_attacked_this_turn'] as bool?,
    );
  }
}

/// Vista scoped de una partida en curso desde la perspectiva de ESTE
/// jugador (`state_update.state` del protocolo) — tu mano completa, solo
/// la cantidad de la mano rival, nunca el orden de ningún mazo.
class MatchStateEntity {
  final bool yourTurn;
  final int yourLife;
  final int opponentLife;
  final List<CardInPlayEntity> yourHand;
  final List<CardInPlayEntity> yourBoard;
  final List<CardInPlayEntity> opponentBoard;
  final int opponentHandCount;
  final int yourDeckCount;
  final int opponentDeckCount;

  MatchStateEntity({
    required this.yourTurn,
    required this.yourLife,
    required this.opponentLife,
    required this.yourHand,
    required this.yourBoard,
    required this.opponentBoard,
    required this.opponentHandCount,
    required this.yourDeckCount,
    required this.opponentDeckCount,
  });

  factory MatchStateEntity.fromJson(Map<String, dynamic> json) {
    List<CardInPlayEntity> cards(String key) => (json[key] as List)
        .map((c) => CardInPlayEntity.fromJson(c as Map<String, dynamic>))
        .toList();

    return MatchStateEntity(
      yourTurn: json['your_turn'] as bool,
      yourLife: json['your_life'] as int,
      opponentLife: json['opponent_life'] as int,
      yourHand: cards('your_hand'),
      yourBoard: cards('your_board'),
      opponentBoard: cards('opponent_board'),
      opponentHandCount: json['opponent_hand_count'] as int,
      yourDeckCount: json['your_deck_count'] as int,
      opponentDeckCount: json['opponent_deck_count'] as int,
    );
  }
}
