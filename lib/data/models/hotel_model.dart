class HotelModel {
  final String id;
  final String businessId;
  final String name;
  final int totalRooms;
  final List<String> roomTypes; // e.g., single, double, suite
  final DateTime createdAt;

  HotelModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.totalRooms = 0,
    this.roomTypes = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HotelModel.fromJson(Map<String, dynamic> json) => HotelModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        totalRooms: json['totalRooms'] as int? ?? 0,
        roomTypes: (json['roomTypes'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'totalRooms': totalRooms,
        'roomTypes': roomTypes,
        'createdAt': createdAt.toIso8601String(),
      };
}

