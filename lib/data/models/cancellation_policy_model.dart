class CancellationPolicy {
  final String id;
  final double depositPercent; // 0-100
  final bool nonRefundable;
  final int freeCancelWindowHours; // hours before check-in to cancel for free
  final String? notes;

  CancellationPolicy({
    required this.id,
    required this.depositPercent,
    required this.nonRefundable,
    required this.freeCancelWindowHours,
    this.notes,
  });

  factory CancellationPolicy.fromMap(String id, Map<String, dynamic>? data) {
    data ??= {};
    return CancellationPolicy(
      id: id,
      depositPercent: (data['depositPercent'] ?? 0.0).toDouble(),
      nonRefundable: data['nonRefundable'] ?? false,
      freeCancelWindowHours: (data['freeCancelWindowHours'] ?? 0) as int,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'depositPercent': depositPercent,
      'nonRefundable': nonRefundable,
      'freeCancelWindowHours': freeCancelWindowHours,
      'notes': notes,
    };
  }
}
