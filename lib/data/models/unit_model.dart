class Unit {
  final String id;
  final String name; // e.g., Unit 101
  final int capacity;
  final double pricePerNight;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final List<String> photos;
  final bool active;

  Unit({
    required this.id,
    required this.name,
    required this.capacity,
    required this.pricePerNight,
    this.availableFrom,
    this.availableTo,
    this.photos = const [],
    this.active = true,
  });

  factory Unit.fromMap(Map<String, dynamic> data, {String? id}) {
    return Unit(
      id: id ?? data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      capacity: _readInt(data['capacity'], fallback: 1),
      pricePerNight: _readDouble(data['pricePerNight'] ?? data['price_per_night']),
      availableFrom: _dateOrNull(data['availableFrom'] ?? data['available_from']),
      availableTo: _dateOrNull(data['availableTo'] ?? data['available_to']),
      photos: List<String>.from(data['photos'] ?? []),
      active: data['active'] ?? true,
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'name': name,
      'capacity': capacity,
      'pricePerNight': pricePerNight,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableTo': availableTo?.toIso8601String(),
      'photos': photos,
      'active': active,
    };
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }
}
