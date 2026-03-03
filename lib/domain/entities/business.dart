/// Business entity
class Business {
  final String id;
  final String name;
  final String type;
  final String ownerId;
  final String? description;
  final String? logoUrl;
  final String currency;
  final DateTime createdAt;
  final bool isActive;

  Business({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    this.description,
    this.logoUrl,
    required this.currency,
    required this.createdAt,
    required this.isActive,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Business &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

