class PrescriptionModel {
  final String id;
  final String patientId;
  final List<String> drugIds;
  final DateTime issuedAt;
  final String prescriber;
  final String? prescriberName;

  PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.drugIds,
    required this.issuedAt,
    required this.prescriber,
    this.prescriberName,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      drugIds: (json['drugIds'] as List<dynamic>?)?.cast<String>() ?? [],
      issuedAt: DateTime.parse(
          json['issuedAt'] as String? ?? DateTime.now().toIso8601String()),
      prescriber: json['prescriber'] as String? ?? '',
      prescriberName: (json['prescriberName'] as String?) ?? (json['prescriber_name'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'drugIds': drugIds,
        'issuedAt': issuedAt.toIso8601String(),
        'prescriber': prescriber,
        if (prescriberName != null) 'prescriberName': prescriberName,
      };
}

