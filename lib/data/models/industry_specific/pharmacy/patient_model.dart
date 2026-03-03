class PatientModel {
  final String id;
  final String name;
  final String phone;
  final DateTime dateOfBirth;

  PatientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateOfBirth,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dateOfBirth: DateTime.parse(
          json['dateOfBirth'] as String? ?? DateTime(1970).toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'dateOfBirth': dateOfBirth.toIso8601String(),
      };
}

