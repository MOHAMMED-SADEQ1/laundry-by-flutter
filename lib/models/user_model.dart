class UserModel {
  final int? userId;
  final String username;
  final String passwordHash;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    this.userId,
    required this.username,
    required this.passwordHash,
    this.role = 'cashier',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      role: map['role'] ?? 'cashier',
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isCashier => role == 'cashier';
}
