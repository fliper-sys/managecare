class BookingModel {
  final String id;
  final String businessId;
  final String roomId;
  final String guestId;
  final DateTime checkIn;
  final DateTime checkOut;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.businessId,
    required this.roomId,
    required this.guestId,
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? createdAt,
  })  : checkIn = checkIn ?? DateTime.now(),
        checkOut = checkOut ?? DateTime.now().add(const Duration(days: 1)),
        createdAt = createdAt ?? DateTime.now();

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        roomId: json['roomId'] as String,
        guestId: json['guestId'] as String,
        checkIn: json['checkIn'] != null
            ? DateTime.parse(json['checkIn'] as String)
            : null,
        checkOut: json['checkOut'] != null
            ? DateTime.parse(json['checkOut'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'roomId': roomId,
        'guestId': guestId,
        'checkIn': checkIn.toIso8601String(),
        'checkOut': checkOut.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

