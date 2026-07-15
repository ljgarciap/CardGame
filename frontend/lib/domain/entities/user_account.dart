class UserAccountEntity {
  final String id;
  final String email;
  final String username;
  final String avatarId;
  final int coins;
  final bool emailVerified;
  final bool isSuperadmin;

  UserAccountEntity({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarId,
    required this.coins,
    required this.emailVerified,
    required this.isSuperadmin,
  });

  factory UserAccountEntity.fromJson(Map<String, dynamic> json) {
    return UserAccountEntity(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      avatarId: json['avatar_id'] as String,
      coins: json['coins'] as int,
      emailVerified: json['email_verified'] as bool,
      isSuperadmin: json['is_superadmin'] as bool,
    );
  }
}
