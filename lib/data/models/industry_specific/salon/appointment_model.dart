class AppointmentModel {
  final String id;
  final String businessId;
  final String clientId;
  final String stylistId;
  final DateTime startTime;
  final Duration duration;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.businessId,
    required this.clientId,
    required this.stylistId,
    DateTime? startTime,
    Duration? duration,
    DateTime? createdAt,
  })  : startTime = startTime ?? DateTime.now(),
        duration = duration ?? const Duration(hours: 1),
        createdAt = createdAt ?? DateTime.now();

  factory AppointmentModel.fromJson(Map<String, dynamic> json) =>
      AppointmentModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        clientId: json['clientId'] as String,
        stylistId: json['stylistId'] as String,
        startTime: json['startTime'] != null
            ? DateTime.parse(json['startTime'] as String)
            : null,
        duration: json['duration'] != null
            ? Duration(seconds: json['duration'] as int)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'clientId': clientId,
        'stylistId': stylistId,
        'startTime': startTime.toIso8601String(),
        'duration': duration.inSeconds,
        'createdAt': createdAt.toIso8601String(),
      };
}

