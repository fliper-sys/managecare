import 'managecare_api_client.dart';

class HospitalityFolioCharge {
  final String id;
  final String businessId;
  final String reservationId;
  final String roomId;
  final String roomNumber;
  final String description;
  final String category;
  final double amount;
  final String source;
  final String? sourceOrderId;
  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const HospitalityFolioCharge({
    required this.id,
    required this.businessId,
    required this.reservationId,
    required this.roomId,
    required this.roomNumber,
    required this.description,
    required this.category,
    required this.amount,
    required this.source,
    this.sourceOrderId,
    this.createdById,
    this.createdByName,
    required this.createdAt,
    this.metadata = const {},
  });

  factory HospitalityFolioCharge.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return HospitalityFolioCharge(
      id: (json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      reservationId: (json['reservationId'] ?? '').toString(),
      roomId: (json['roomId'] ?? '').toString(),
      roomNumber: (json['roomNumber'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'extra').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      source: (json['source'] ?? 'manual').toString(),
      sourceOrderId: json['sourceOrderId']?.toString(),
      createdById: json['createdById']?.toString(),
      createdByName: json['createdByName']?.toString(),
      createdAt: createdAt,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'reservationId': reservationId,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'description': description,
      'category': category,
      'amount': amount,
      'source': source,
      'sourceOrderId': sourceOrderId,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class HospitalityFolioService {
  HospitalityFolioService({ManagecareApiClient? api}) : _api = api ?? ManagecareApiClient.instance;

  final ManagecareApiClient _api;

  Map<String, dynamic> _rowToJson(Map<String, dynamic> row) => {
        'id': row['id'],
        'businessId': row['business_id'],
        'reservationId': row['reservation_id'],
        'roomId': row['room_id'],
        'roomNumber': row['room_number'],
        'description': row['description'],
        'category': row['category'],
        'amount': row['amount'],
        'source': row['source'],
        'sourceOrderId': row['source_order_id'],
        'createdById': row['created_by_id'],
        'createdByName': row['created_by_name'],
        'createdAt': row['created_at'],
        'metadata': row['metadata'],
      };

  Future<List<HospitalityFolioCharge>> fetchCharges(String businessId) async {
    if (businessId.isEmpty) return const [];

    final response = await _api.get('/api/hotel/$businessId/folio-charges');
    final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    final charges = rows.map((r) => HospitalityFolioCharge.fromJson(_rowToJson(r))).toList();
    charges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return charges;
  }

  Future<HospitalityFolioCharge> addCharge({
    required String businessId,
    required String reservationId,
    required String roomId,
    required String roomNumber,
    required String description,
    required double amount,
    String category = 'extra',
    String source = 'manual',
    String? sourceOrderId,
    String? createdById,
    String? createdByName,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await _api.post('/api/hotel/$businessId/folio-charges', body: {
      'reservation_id': reservationId,
      'room_id': roomId,
      'room_number': roomNumber,
      'description': description,
      'amount': amount,
      'category': category,
      'source': source,
      'source_order_id': sourceOrderId,
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'metadata': metadata,
    });
    return HospitalityFolioCharge.fromJson(_rowToJson(Map<String, dynamic>.from(response as Map)));
  }
}
