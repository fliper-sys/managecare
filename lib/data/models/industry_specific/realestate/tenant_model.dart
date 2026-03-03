class TenantModel {
  final String id;
  final String name;
  final String contact;

  TenantModel({required this.id, required this.name, required this.contact});

  factory TenantModel.fromJson(Map<String, dynamic> json) => TenantModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        contact: json['contact'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'contact': contact};
}

