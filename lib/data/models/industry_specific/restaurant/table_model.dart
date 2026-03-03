class TableModel {
  final String id;
  final String name;
  final int seats;
  final String status;

  TableModel(
      {required this.id,
      required this.name,
      required this.seats,
      this.status = 'available'});

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        seats: json['seats'] as int? ?? 0,
        status: json['status'] as String? ?? 'available',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seats': seats,
        'status': status,
      };
}

