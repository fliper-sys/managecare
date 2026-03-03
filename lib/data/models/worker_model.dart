class WorkerModel {
  final String id;
  final String name;
  final String role; // primary role for backward compatibility
  final List<String> roles; // allow multiple roles
  final List<String> serviceIds; // services the worker can perform
  final String email;

  WorkerModel(
      {required this.id,
      required this.name,
      required this.role,
      this.roles = const [],
      this.serviceIds = const [],
      this.email = ''});

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    final roles = <String>[];
    if (json['roles'] is List) {
      roles.addAll(List<String>.from(json['roles']));
    } else if (json['role'] is String && (json['role'] as String).isNotEmpty) {
      roles.add(json['role'] as String);
    }

    return WorkerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? (roles.isNotEmpty ? roles.first : ''),
      roles: roles,
      serviceIds: List<String>.from(json['serviceIds'] ?? []),
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'roles': roles,
        'serviceIds': serviceIds,
        'email': email,
      };
}

