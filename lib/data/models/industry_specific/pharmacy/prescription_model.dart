class PrescriptionModel {
  final String id;
  final String patientId;
  final List<String> drugIds;
  final List<Map<String, dynamic>> items;
  final DateTime issuedAt;
  final String prescriber;
  final String? prescriberName;
  final String? patientName;
  final String status;
  final String? notes;
  final String? attachmentReference;
  final bool attachmentRequired;
  final DateTime? patientDateOfBirth;

  PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.drugIds,
    this.items = const [],
    required this.issuedAt,
    required this.prescriber,
    this.prescriberName,
    this.patientName,
    this.status = 'pending',
    this.notes,
    this.attachmentReference,
    this.attachmentRequired = false,
    this.patientDateOfBirth,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawItems = (json['items'] as List<dynamic>?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final resolvedDrugIds =
        (json['drugIds'] as List<dynamic>?)?.cast<String>() ??
            rawItems
                .map((item) => item['drugId']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

    return PrescriptionModel(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      drugIds: resolvedDrugIds,
      items: rawItems.isNotEmpty
          ? rawItems
          : resolvedDrugIds
              .map((id) => <String, dynamic>{'drugId': id, 'qty': 1})
              .toList(),
      issuedAt: DateTime.parse(
          json['issuedAt'] as String? ?? DateTime.now().toIso8601String()),
      prescriber: json['prescriber'] as String? ?? '',
      prescriberName: (json['prescriberName'] as String?) ??
          (json['prescriber_name'] as String?),
      patientName: json['patientName'] as String?,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      attachmentReference: json['attachmentReference'] as String?,
      attachmentRequired: json['attachmentRequired'] == true,
      patientDateOfBirth: parseNullableDate(json['patientDateOfBirth']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'drugIds': drugIds,
        'items': items,
        'issuedAt': issuedAt.toIso8601String(),
        'prescriber': prescriber,
        if (prescriberName != null) 'prescriberName': prescriberName,
        if (patientName != null) 'patientName': patientName,
        'status': status,
        if (notes != null) 'notes': notes,
        if (attachmentReference != null)
          'attachmentReference': attachmentReference,
        'attachmentRequired': attachmentRequired,
        if (patientDateOfBirth != null)
          'patientDateOfBirth': patientDateOfBirth!.toIso8601String(),
      };
}

