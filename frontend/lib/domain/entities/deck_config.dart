/// Config paramétrica de mazos guardados (tope de mazos por usuario) —
/// editable por un superadmin vía `/api/admin/deck-config`.
class DeckConfigEntity {
  final int maxDecksPerUser;

  DeckConfigEntity({required this.maxDecksPerUser});

  factory DeckConfigEntity.fromJson(Map<String, dynamic> json) {
    return DeckConfigEntity(maxDecksPerUser: json['max_decks_per_user'] as int);
  }
}
