class LivestockModel {
  final String id;
  final String businessId;
  final String species;
  final String tag;
  final DateTime bornAt;
  final DateTime createdAt;

  LivestockModel({
    required this.id,
    required this.businessId,
    this.species = '',
    this.tag = '',
    DateTime? bornAt,
    DateTime? createdAt,
  })  : bornAt = bornAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory LivestockModel.fromJson(Map<String, dynamic> json) => LivestockModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        species: json['species'] as String? ?? '',
        tag: json['tag'] as String? ?? '',
        bornAt: json['bornAt'] != null
            ? DateTime.parse(json['bornAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'species': species,
        'tag': tag,
        'bornAt': bornAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

