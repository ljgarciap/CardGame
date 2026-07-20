/// Un ataque resuelto por el servidor — llega como su propio mensaje WS
/// (`attack_event`), antes del `state_update` que ya refleja el resultado.
/// Sin esto, el cliente tendría que inferir "quién le pegó a quién"
/// comparando snapshots (frágil: con varios ataques del bot en el mismo
/// turno, comparar solo el antes/después no dice el orden ni distingue
/// cada golpe individual — ver docs/memory.md 2026-07-20).
class AttackEventEntity {
  final String attackingPlayerId;
  final String attackerId;
  final String attackerName;

  /// "face" o el `playerCardId` de la carta objetivo.
  final String target;
  final String? targetName;
  final int damage;
  final bool targetDefeated;

  const AttackEventEntity({
    required this.attackingPlayerId,
    required this.attackerId,
    required this.attackerName,
    required this.target,
    this.targetName,
    required this.damage,
    required this.targetDefeated,
  });

  bool get isFaceAttack => target == 'face';

  factory AttackEventEntity.fromJson(Map<String, dynamic> json) {
    final rawTarget = json['target'];
    return AttackEventEntity(
      attackingPlayerId: json['attacking_player_id'] as String,
      attackerId: json['attacker_id'] as String,
      attackerName: json['attacker_name'] as String,
      target: rawTarget is String ? rawTarget : (rawTarget as Map<String, dynamic>)['card_id'] as String,
      targetName: json['target_name'] as String?,
      damage: json['damage'] as int,
      targetDefeated: json['target_defeated'] as bool,
    );
  }
}
