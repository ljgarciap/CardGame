import 'card.dart';

class PlayerEntity {
  final String id;
  final String name;
  final List<CardEntity> hand;
  final bool isReady;
  final int score;

  PlayerEntity({
    required this.id,
    required this.name,
    this.hand = const [],
    this.isReady = false,
    this.score = 0,
  });

  PlayerEntity copyWith({
    String? id,
    String? name,
    List<CardEntity>? hand,
    bool? isReady,
    int? score,
  }) {
    return PlayerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
      isReady: isReady ?? this.isReady,
      score: score ?? this.score,
    );
  }
}
