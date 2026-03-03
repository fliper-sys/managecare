class JobCardModel {
  final String id;
  final String serviceOrderId;
  final String technicianId;
  final List<String> tasks;
  final DateTime createdAt;

  JobCardModel({
    required this.id,
    required this.serviceOrderId,
    this.technicianId = '',
    this.tasks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory JobCardModel.fromJson(Map<String, dynamic> json) => JobCardModel(
        id: json['id'] as String,
        serviceOrderId: json['serviceOrderId'] as String,
        technicianId: json['technicianId'] as String? ?? '',
        tasks: (json['tasks'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceOrderId': serviceOrderId,
        'technicianId': technicianId,
        'tasks': tasks,
        'createdAt': createdAt.toIso8601String(),
      };
}

