class StoreModel {
  final String id;
  final String businessId;
  final String name;
  final String location;
  final String phone;
  final DateTime createdAt;

  StoreModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.location = '',
    this.phone = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        location: json['location'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'location': location,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
      };
}

