class PropertyModel {
  final String id;
  final String title;
  final String address;
  final double rent;
  final String status;

  PropertyModel(
      {required this.id,
      required this.title,
      required this.address,
      required this.rent,
      this.status = 'available'});

  factory PropertyModel.fromJson(Map<String, dynamic> json) => PropertyModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        address: json['address'] as String? ?? '',
        rent: (json['rent'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'available',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'address': address,
        'rent': rent,
        'status': status,
      };
}

