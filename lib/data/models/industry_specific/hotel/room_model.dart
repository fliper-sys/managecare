class RoomModel {
  final String id;
  final String businessId;
  final String roomNumber;
  final String type;
  final int capacity;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.businessId,
    this.roomNumber = '',
    this.type = '',
    this.capacity = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        roomNumber: json['roomNumber'] as String? ?? '',
        type: json['type'] as String? ?? '',
        capacity: json['capacity'] as int? ?? 1,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'roomNumber': roomNumber,
        'type': type,
        'capacity': capacity,
        'createdAt': createdAt.toIso8601String(),
      };
}

