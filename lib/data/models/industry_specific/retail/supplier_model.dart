class SupplierModel {
  final String id;
  final String businessId;
  final String name;
  final String contactPhone;
  final String email;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactPhone = '',
    this.email = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        contactPhone: json['contactPhone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'contactPhone': contactPhone,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };
}

