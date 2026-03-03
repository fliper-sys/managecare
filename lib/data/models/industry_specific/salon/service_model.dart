class ServiceModel {
  final String id;
  final String businessId;
  final String name;
  final Duration duration;
  final double price;
  final DateTime createdAt;

  ServiceModel({
    required this.id,
    required this.businessId,
    this.name = '',
    Duration? duration,
    this.price = 0.0,
    DateTime? createdAt,
  })  : duration = duration ?? const Duration(hours: 1),
        createdAt = createdAt ?? DateTime.now();

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String? ?? '',
        duration: json['duration'] != null
            ? Duration(seconds: json['duration'] as int)
            : null,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'duration': duration.inSeconds,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
      };
}

