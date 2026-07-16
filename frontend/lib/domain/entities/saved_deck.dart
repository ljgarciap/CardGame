import 'owned_card.dart';

/// Un mazo guardado por el jugador (nombre + 10 cartas), persistido en el
/// backend — distinto de la selección ad-hoc que hacía el deck builder
/// antes de esta ronda.
class SavedDeckEntity {
  final String id;
  final String name;
  final List<OwnedCardEntity> cards;

  SavedDeckEntity({
    required this.id,
    required this.name,
    required this.cards,
  });

  factory SavedDeckEntity.fromJson(Map<String, dynamic> json) {
    return SavedDeckEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      cards: (json['cards'] as List)
          .map((c) => OwnedCardEntity.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
