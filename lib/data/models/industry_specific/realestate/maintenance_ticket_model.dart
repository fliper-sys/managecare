class MaintenanceTicketModel {
  final String id;
  final String propertyId;
  final String description;
  final String status;
  final DateTime createdAt;

  MaintenanceTicketModel(
      {required this.id,
      required this.propertyId,
      required this.description,
      this.status = 'open',
      required this.createdAt});

  factory MaintenanceTicketModel.fromJson(Map<String, dynamic> json) =>
      MaintenanceTicketModel(
        id: json['id'] as String? ?? '',
        propertyId: json['propertyId'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'description': description,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}

