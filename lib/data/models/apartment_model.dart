class Apartment {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String address;
  final List<String> photos;
  final List<String> amenities;
  final String? defaultCancellationPolicyId;
  final DateTime? createdAt;

  Apartment({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.address,
    this.photos = const [],
    this.amenities = const [],
    this.defaultCancellationPolicyId,
    this.createdAt,
  });

  Apartment copyWith({
    String? id,
    String? title,
    String? description,
    String? ownerId,
    String? address,
    List<String>? photos,
    List<String>? amenities,
    String? defaultCancellationPolicyId,
    DateTime? createdAt,
  }) {
    return Apartment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      address: address ?? this.address,
      photos: photos ?? this.photos,
      amenities: amenities ?? this.amenities,
      defaultCancellationPolicyId:
          defaultCancellationPolicyId ?? this.defaultCancellationPolicyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Apartment.fromMap(Map<String, dynamic> data, {String? id}) {
    return Apartment(
      id: id ?? data['id']?.toString() ?? '',
      title: data['title'] ?? data['name'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? data['owner_id'] ?? '',
      address: data['address'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      defaultCancellationPolicyId:
          data['defaultCancellationPolicyId'] ?? data['default_cancellation_policy_id'],
      createdAt: _dateOrNull(data['createdAt'] ?? data['created_at']),
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'address': address,
      'photos': photos,
      'amenities': amenities,
      'defaultCancellationPolicyId': defaultCancellationPolicyId,
    };
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
