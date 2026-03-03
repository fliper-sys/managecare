/// User entity
class User {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String role;
  final String businessId;
  final DateTime createdAt;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.role,
    required this.businessId,
    required this.createdAt,
    required this.isActive,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? role,
    String? businessId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}

