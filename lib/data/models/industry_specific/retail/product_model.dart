class ProductModel {
  final String id;
  final String name;
  final String sku;
  final double price;
  final double cost;
  final int stock;
  final String emoji;

  ProductModel(
      {required this.id,
      required this.name,
      required this.sku,
      required this.price,
      this.cost = 0.0,
      required this.stock,
      this.emoji = '📦'});

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
        stock: json['stock'] as int? ?? 0,
        emoji: json['emoji'] as String? ?? '📦',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'price': price,
        'cost': cost,
        'stock': stock,
        'emoji': emoji,
      };
}

