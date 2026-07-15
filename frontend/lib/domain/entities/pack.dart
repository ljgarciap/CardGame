import 'card.dart';

/// Resultado de abrir un sobre — el backend es la única fuente de verdad
/// (server-authoritative), el cliente solo anima estas cartas.
class PackOpenResultEntity {
  final List<TCGCardEntity> cards;
  final int remainingCoins;

  PackOpenResultEntity({required this.cards, required this.remainingCoins});

  factory PackOpenResultEntity.fromJson(Map<String, dynamic> json) {
    return PackOpenResultEntity(
      cards: (json['cards'] as List)
          .map((c) => TCGCardEntity.fromJson(c as Map<String, dynamic>))
          .toList(),
      remainingCoins: json['remaining_coins'] as int,
    );
  }
}
