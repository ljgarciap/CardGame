/// `targetUsername` null identifica un broadcast a toda la comunidad —
/// ahí `recipientCount` cuenta cuántos usuarios lo recibieron.
class CoinGrantEntity {
  final String id;
  final String grantedByUsername;
  final String? targetUsername;
  final int amount;
  final String? reason;
  final int? recipientCount;
  final DateTime createdAt;

  CoinGrantEntity({
    required this.id,
    required this.grantedByUsername,
    this.targetUsername,
    required this.amount,
    this.reason,
    this.recipientCount,
    required this.createdAt,
  });

  bool get isBroadcast => targetUsername == null;

  factory CoinGrantEntity.fromJson(Map<String, dynamic> json) {
    return CoinGrantEntity(
      id: json['id'] as String,
      grantedByUsername: json['granted_by_username'] as String,
      targetUsername: json['target_username'] as String?,
      amount: json['amount'] as int,
      reason: json['reason'] as String?,
      recipientCount: json['recipient_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
