class ClientModel {
  final String id;
  final String businessId;
  final String name;
  final String phone;
  final String email;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.businessId,
    this.name = '',
    this.phone = '',
    this.email = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'phone': phone,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };
}

