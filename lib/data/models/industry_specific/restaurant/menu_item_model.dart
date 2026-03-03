class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> modifiers;

  MenuItemModel(
      {required this.id,
      required this.name,
      this.description = '',
      required this.price,
      this.modifiers = const []});

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        modifiers: (json['modifiers'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'modifiers': modifiers,
      };
}

