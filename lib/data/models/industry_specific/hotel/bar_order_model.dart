class BarOrderModel {
  final String id;
  final String businessId;
  final String? tabId;
  final String? tableId;
  final String? roomId;
  final String? guestId;
  final String attachmentType;
  final String? attachmentLabel;
  final List<Map<String, dynamic>> items;
  final double total;
  final DateTime createdAt;

  BarOrderModel({
    required this.id,
    required this.businessId,
    this.tabId,
    this.tableId,
    this.roomId,
    this.guestId,
    this.attachmentType = 'tab',
    this.attachmentLabel,
    this.items = const [],
    this.total = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BarOrderModel.fromJson(Map<String, dynamic> json) => BarOrderModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        tabId: json['tabId'] as String?,
        tableId: json['tableId'] as String?,
        roomId: json['roomId'] as String?,
        guestId: json['guestId'] as String?,
        attachmentType: json['attachmentType'] as String? ??
            ((json['roomId'] as String?)?.isNotEmpty == true ? 'room' : 'tab'),
        attachmentLabel: json['attachmentLabel'] as String?,
        items:
            (json['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [],
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'tabId': tabId,
        'tableId': tableId,
        if (roomId != null) 'roomId': roomId,
        if (guestId != null) 'guestId': guestId,
        'attachmentType': attachmentType,
        if (attachmentLabel != null) 'attachmentLabel': attachmentLabel,
        'items': items,
        'total': total,
        'createdAt': createdAt.toIso8601String(),
      };
}

