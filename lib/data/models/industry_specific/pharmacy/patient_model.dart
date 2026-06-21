class PatientModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? dateOfBirth;
  final String? allergies;
  final String? bloodType;
  final String? additionalNotes;

  PatientModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.dateOfBirth,
    this.allergies,
    this.bloodType,
    this.additionalNotes,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      allergies: json['allergies'] as String?,
      bloodType: json['bloodType'] as String?,
      additionalNotes: json['additionalNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (allergies != null) 'allergies': allergies,
        if (bloodType != null) 'bloodType': bloodType,
        if (additionalNotes != null) 'additionalNotes': additionalNotes,
      };

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}

