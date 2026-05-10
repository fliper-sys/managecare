class Treatment {
  final String id;
  final String patientId;
  final String name;
  final String drugName;
  final String dosage;
  final int frequencyPerDay;
  final int durationDays;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<DateTime> administeredDates;

  Treatment({
    required this.id,
    required this.patientId,
    required this.name,
    required this.drugName,
    required this.dosage,
    required this.frequencyPerDay,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.administeredDates = const [],
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      drugName: json['drugName'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequencyPerDay: json['frequencyPerDay'] as int? ?? 1,
      durationDays: json['durationDays'] as int? ?? 1,
      startDate: DateTime.parse(json['startDate'] as String? ?? DateTime.now().toIso8601String()),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : DateTime.now().add(Duration(days: json['durationDays'] as int? ?? 1)),
      isActive: json['isActive'] as bool? ?? true,
      administeredDates: (json['administeredDates'] as List<dynamic>?)
          ?.map((e) => DateTime.parse(e as String))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'name': name,
        'drugName': drugName,
        'dosage': dosage,
        'frequencyPerDay': frequencyPerDay,
        'durationDays': durationDays,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isActive': isActive,
        'administeredDates': administeredDates.map((d) => d.toIso8601String()).toList(),
      };

  bool get isCompleted => DateTime.now().isAfter(endDate);
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}