import 'package:business_manager/data/models/sale_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../data/repositories/industry_specific/hotel_repository.dart';
import '../services/business_reminder_service.dart';
import '../services/business_notification_manager.dart';
import '../services/hospitality_folio_service.dart';
import '../services/notification_and_email_service.dart';

// Room Models
class Room {
  final String id;
  final String number;
  final String type; // single, double, suite, deluxe
  final int capacity;
  final double pricePerNight;
  final String status; // available, occupied, maintenance, reserved
  final String? emoji;
  final List<String> amenities; // WiFi, AC, TV, Kitchenette, etc.
  final List<String> images;
  final List<Map<String, dynamic>>?
      priceIntervals; // Optional time-interval pricing
  final int floor;
  final double rating;

  Room({
    required this.id,
    required this.number,
    required this.type,
    required this.capacity,
    required this.pricePerNight,
    required this.status,
    this.emoji,
    required this.amenities,
    required this.images,
    this.priceIntervals,
    required this.floor,
    this.rating = 4.5,
  });

  Room copyWith({
    String? status,
    double? rating,
    List<Map<String, dynamic>>? priceIntervals,
  }) {
    return Room(
      id: id,
      number: number,
      type: type,
      capacity: capacity,
      pricePerNight: pricePerNight,
      status: status ?? this.status,
      emoji: emoji,
      amenities: amenities,
      images: images,
      priceIntervals: priceIntervals ?? this.priceIntervals,
      floor: floor,
      rating: rating ?? this.rating,
    );
  }
}

// Booking/Reservation Models
class Reservation {

    // Add guestId getter for compatibility with UI code
    String get guestId => id;
  final String id;
  final String roomId;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestAddress;
  final String guestNationality;
  final String guestIdType;
  final String guestIdNumber;
  final String nextOfKinName;
  final String nextOfKinPhone;
  final String nextOfKinRelationship;
  final String bookingSource;
  final String companyName;
  final String vehiclePlateNumber;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final DateTime checkIn;
  final DateTime checkOut;
  final int adults;
  final int children;
  final String status; // pending, confirmed, checked-in, checked-out, cancelled
  final double totalPrice;
  final List<String> specialRequests;
  final String paymentStatus; // unpaid, partial, paid
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.roomId,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    this.guestAddress = '',
    this.guestNationality = '',
    this.guestIdType = '',
    this.guestIdNumber = '',
    this.nextOfKinName = '',
    this.nextOfKinPhone = '',
    this.nextOfKinRelationship = '',
    this.bookingSource = 'walk-in',
    this.companyName = '',
    this.vehiclePlateNumber = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleColor = '',
    required this.checkIn,
    required this.checkOut,
    required this.adults,
    required this.children,
    required this.status,
    required this.totalPrice,
    required this.specialRequests,
    required this.paymentStatus,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Reservation copyWith({
    String? id,
    String? roomId,
    String? guestName,
    String? guestEmail,
    String? guestPhone,
    String? guestAddress,
    String? guestNationality,
    String? guestIdType,
    String? guestIdNumber,
    String? nextOfKinName,
    String? nextOfKinPhone,
    String? nextOfKinRelationship,
    String? bookingSource,
    String? companyName,
    String? vehiclePlateNumber,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    String? status,
    double? totalPrice,
    List<String>? specialRequests,
    String? paymentStatus,
    DateTime? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      guestName: guestName ?? this.guestName,
      guestEmail: guestEmail ?? this.guestEmail,
      guestPhone: guestPhone ?? this.guestPhone,
      guestAddress: guestAddress ?? this.guestAddress,
      guestNationality: guestNationality ?? this.guestNationality,
      guestIdType: guestIdType ?? this.guestIdType,
      guestIdNumber: guestIdNumber ?? this.guestIdNumber,
      nextOfKinName: nextOfKinName ?? this.nextOfKinName,
      nextOfKinPhone: nextOfKinPhone ?? this.nextOfKinPhone,
      nextOfKinRelationship:
          nextOfKinRelationship ?? this.nextOfKinRelationship,
      bookingSource: bookingSource ?? this.bookingSource,
      companyName: companyName ?? this.companyName,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      specialRequests: specialRequests ?? this.specialRequests,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get nights => checkOut.difference(checkIn).inDays;
}

// Service Orders
class ServiceOrder {
  final String id;
  final String roomId;
  final String? reservationId;
  final String serviceName; // housekeeping, laundry, food delivery, maintenance
  final String description;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String status; // pending, in-progress, completed, cancelled
  final String priority; // low, medium, high, urgent
  final double? chargeAmount;
  final String source; // hotel_service, room_service, restaurant, bar

  ServiceOrder({
    required this.id,
    required this.roomId,
    this.reservationId,
    required this.serviceName,
    required this.description,
    required this.requestedAt,
    this.completedAt,
    required this.status,
    required this.priority,
    this.chargeAmount,
    this.source = 'hotel_service',
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is fs.Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return ServiceOrder(
      id: (json['id'] ?? '').toString(),
      roomId: (json['roomId'] ?? '').toString(),
      reservationId: json['reservationId']?.toString(),
      serviceName: (json['serviceName'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      requestedAt: parseDate(json['requestedAt']) ?? DateTime.now(),
      completedAt: parseDate(json['completedAt']),
      status: (json['status'] ?? 'pending').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      chargeAmount: (json['chargeAmount'] as num?)?.toDouble(),
      source: (json['source'] ?? 'hotel_service').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'reservationId': reservationId,
      'serviceName': serviceName,
      'description': description,
      'requestedAt': requestedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status,
      'priority': priority,
      'chargeAmount': chargeAmount,
      'source': source,
    };
  }
}

class HotelProvider extends ChangeNotifier {
      // List of all sales (should be loaded from Firestore or repository)
      final List<SaleModel> _sales = [];

      List<SaleModel> get sales => _sales;
    // Returns all sales for a given roomId
    List<SaleModel> getSalesForRoom(String roomId) {
      if (_businessId == null || _businessId!.isEmpty) return [];
      // _sales should be a list of SaleModel loaded from Firestore
      return _sales.where((sale) => sale.roomId == roomId).toList();
    }

    // Returns all sales for a given guestId
    List<SaleModel> getSalesForGuest(String guestId) {
      if (_businessId == null || _businessId!.isEmpty) return [];
      return _sales.where((sale) => sale.guestId == guestId).toList();
    }
  final HotelRepository? repository;
  final BusinessNotificationManager _notificationManager =
      BusinessNotificationManager.instance;
  final NotificationAndEmailService _notificationLogger =
      NotificationAndEmailService();
  final HospitalityFolioService _folioService = HospitalityFolioService();
  String? _businessId;

  List<Room> _rooms = [];
  List<Reservation> _reservations = [];
  List<ServiceOrder> _serviceOrders = [];
  List<HospitalityFolioCharge> _folioCharges = [];
  double _occupancy = 0.0;

  HotelProvider({this.repository}) {
    // Only seed sample data for local development when no repository is provided.
    if (repository == null) {
      _initializeSampleData();
    }
  }

  /// Set business id and optionally attempt to load remote hotel data
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    _rooms = [];
    _reservations = [];
    _serviceOrders = [];
    _folioCharges = [];
    notifyListeners();
    try {
      if (repository != null) {
        await _init();
      }
    } catch (e) {
      debugPrint('[HotelProvider] Error initializing for business: $e');
    }
  }

  Future<void> _init() async {
    if (_businessId == null || _businessId!.isEmpty || repository == null)
      return;
    await loadFromRepository();
    await syncReservations();
    await _loadServiceOrders();
    await _loadFolioCharges();
  }

  // Getters
  List<Room> get rooms => _rooms;
  List<Reservation> get reservations => _reservations;
  List<ServiceOrder> get serviceOrders => _serviceOrders;
  List<HospitalityFolioCharge> get folioCharges => _folioCharges;
  double get occupancy => _occupancy;
  bool get hasRemote => repository != null;

  int get totalRooms => _rooms.length;
  int get occupiedRooms => _rooms.where((r) => r.status == 'occupied').length;
  int get availableRooms => _rooms.where((r) => r.status == 'available').length;
  int get maintenanceRooms =>
      _rooms.where((r) => r.status == 'maintenance').length;
  int get reservedRooms =>
      _reservations.where((r) => r.status == 'confirmed').length;

  List<Reservation> get checkedInReservations =>
      _reservations.where((r) => r.status == 'checked-in').toList();

  List<Reservation> get confirmedReservations =>
      _reservations.where((r) => r.status == 'confirmed').toList();

  List<Reservation> get cancelledReservations =>
      _reservations.where((r) => r.status == 'cancelled').toList();

  double get revenue => _reservations
      .where((r) => r.status == 'checked-out' || r.status == 'confirmed')
      .fold(0, (sum, r) => sum + r.totalPrice);

  Room? getRoomById(String roomId) {
    for (final room in _rooms) {
      if (room.id == roomId) return room;
    }
    return null;
  }

  List<Reservation> getReservationsForRoom(String roomId) {
    return _reservations.where((r) => r.roomId == roomId).toList();
  }

  List<Reservation> get reservationsSortedByCheckIn {
    final list = [..._reservations];
    list.sort((a, b) => a.checkIn.compareTo(b.checkIn));
    return list;
  }

  List<Map<String, dynamic>> get guestProfiles {
    final Map<String, Map<String, dynamic>> guests = {};
    for (final reservation in _reservations) {
      final key = reservation.guestEmail.trim().isNotEmpty
          ? reservation.guestEmail.trim().toLowerCase()
          : reservation.guestPhone.trim().isNotEmpty
              ? reservation.guestPhone.trim()
              : reservation.guestName.trim().toLowerCase();

      final current = guests[key];
      final room = getRoomById(reservation.roomId);
      final data = {
        'guestName': reservation.guestName,
        'guestEmail': reservation.guestEmail,
        'guestPhone': reservation.guestPhone,
        'guestAddress': reservation.guestAddress,
        'guestNationality': reservation.guestNationality,
        'guestIdType': reservation.guestIdType,
        'guestIdNumber': reservation.guestIdNumber,
        'nextOfKinName': reservation.nextOfKinName,
        'nextOfKinPhone': reservation.nextOfKinPhone,
        'nextOfKinRelationship': reservation.nextOfKinRelationship,
        'bookingSource': reservation.bookingSource,
        'companyName': reservation.companyName,
        'vehiclePlateNumber': reservation.vehiclePlateNumber,
        'reservationCount': (current?['reservationCount'] ?? 0) + 1,
        'checkedInCount': (current?['checkedInCount'] ?? 0) +
            (reservation.status == 'checked-in' ? 1 : 0),
        'totalSpend': (current?['totalSpend'] ?? 0.0) +
            getReservationBalance(reservation),
        'lastReservation': reservation,
        'roomNumber': room?.number ?? '',
      };
      guests[key] = data;
    }
    final list = guests.values.toList();
    list.sort((a, b) {
      final aRes = a['lastReservation'] as Reservation;
      final bRes = b['lastReservation'] as Reservation;
      return bRes.checkIn.compareTo(aRes.checkIn);
    });
    return list;
  }

  Map<String, int> get serviceStatusCounts {
    return {
      'pending': _serviceOrders.where((s) => s.status == 'pending').length,
      'in-progress':
          _serviceOrders.where((s) => s.status == 'in-progress').length,
      'completed': _serviceOrders.where((s) => s.status == 'completed').length,
      'cancelled': _serviceOrders.where((s) => s.status == 'cancelled').length,
    };
  }

  double estimateServiceCharge(String serviceName,
      {String priority = 'medium'}) {
    final normalized = serviceName.trim().toLowerCase();
    double base;
    switch (normalized) {
      case 'housekeeping':
        base = 5000.0;
        break;
      case 'laundry':
        base = 3500.0;
        break;
      case 'room service':
      case 'food delivery':
        base = 7000.0;
        break;
      case 'maintenance':
        base = 4000.0;
        break;
      case 'spa & wellness':
        base = 12000.0;
        break;
      default:
        base = 3000.0;
    }

    double multiplier;
    switch (priority.trim().toLowerCase()) {
      case 'urgent':
        multiplier = 1.5;
        break;
      case 'high':
        multiplier = 1.25;
        break;
      case 'low':
        multiplier = 0.9;
        break;
      default:
        multiplier = 1.0;
    }
    return base * multiplier;
  }

  List<Map<String, dynamic>> buildFolioCharges(Reservation reservation) {
    final room = getRoomById(reservation.roomId);
    final roomRate = room?.pricePerNight ?? 0.0;
    final nights = reservation.nights <= 0 ? 1 : reservation.nights;
    final charges = <Map<String, dynamic>>[
      {
        'description':
            'Room ${room?.number ?? reservation.roomId} x $nights night${nights == 1 ? '' : 's'}',
        'amount': roomRate * nights,
        'type': 'room',
      },
    ];

    final relatedServices = _serviceOrders.where((service) {
      final sameReservation = service.reservationId != null &&
          service.reservationId == reservation.id;
      final sameRoom =
          service.roomId == reservation.roomId && service.reservationId == null;
      final withinStay = !service.requestedAt.isBefore(reservation.checkIn) &&
          !service.requestedAt.isAfter(reservation.checkOut);
      return (sameReservation || sameRoom) &&
          withinStay &&
          service.status != 'cancelled';
    }).toList();

    for (final service in relatedServices) {
      final amount = service.chargeAmount ??
          estimateServiceCharge(
            service.serviceName,
            priority: service.priority,
          );
      charges.add({
        'description': '${service.serviceName} (${service.priority})',
        'amount': amount,
        'type': 'service',
      });
    }

    final reservationCharges = getFolioChargesForReservation(reservation.id);
    for (final charge in reservationCharges) {
      charges.add({
        'description': charge.description,
        'amount': charge.amount,
        'type': charge.category,
        'source': charge.source,
      });
    }

    return charges;
  }

  double getReservationBalance(Reservation reservation) {
    return buildFolioCharges(reservation).fold<double>(
      0.0,
      (sum, charge) => sum + ((charge['amount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseDynamicDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is fs.Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  bool _matchesGuestIdentity(Reservation a, Reservation b) {
    final aEmail = a.guestEmail.trim().toLowerCase();
    final bEmail = b.guestEmail.trim().toLowerCase();
    if (aEmail.isNotEmpty && bEmail.isNotEmpty) {
      return aEmail == bEmail;
    }

    final aPhone = a.guestPhone.trim();
    final bPhone = b.guestPhone.trim();
    if (aPhone.isNotEmpty && bPhone.isNotEmpty) {
      return aPhone == bPhone;
    }

    return a.guestName.trim().toLowerCase() == b.guestName.trim().toLowerCase();
  }

  String _buildGuestDocumentId(Reservation reservation) {
    final raw = reservation.guestEmail.trim().isNotEmpty
        ? reservation.guestEmail.trim().toLowerCase()
        : reservation.guestPhone.trim().isNotEmpty
            ? reservation.guestPhone.trim()
            : reservation.guestName.trim().toLowerCase();
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    return sanitized.isEmpty ? reservation.id : sanitized;
  }

  String _shortCode(String value) {
    if (value.length <= 6) return value.toUpperCase();
    return value.substring(value.length - 6).toUpperCase();
  }

  String _defaultHotelPaymentMethod(Reservation reservation) {
    if (reservation.paymentStatus == 'paid') {
      return 'hotel_billing';
    }
    if (reservation.paymentStatus == 'partial') {
      return 'deposit_pending';
    }
    return 'pay_at_checkout';
  }

  Reservation? getReservationById(String reservationId) {
    for (final reservation in _reservations) {
      if (reservation.id == reservationId) return reservation;
    }
    return null;
  }

  Reservation? getActiveReservationForRoom(String roomId) {
    final activeReservations = _reservations.where((reservation) {
      return reservation.roomId == roomId &&
          (reservation.status == 'checked-in' ||
              reservation.status == 'confirmed');
    }).toList()
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

    if (activeReservations.isEmpty) return null;
    return activeReservations.first;
  }

  List<HospitalityFolioCharge> getFolioChargesForReservation(
    String reservationId,
  ) {
    final charges = _folioCharges
        .where((charge) => charge.reservationId == reservationId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return charges;
  }

  Future<void> _syncGuestProfile(Reservation reservation) async {
    if (_businessId == null || _businessId!.isEmpty) return;

    try {
      final relatedReservations = _reservations
          .where((item) => _matchesGuestIdentity(item, reservation))
          .toList();
      final room = getRoomById(reservation.roomId);
      final totalSpend = relatedReservations.fold<double>(
        0.0,
        (sum, item) => sum + getReservationBalance(item),
      );
      final checkedInCount = relatedReservations
          .where((item) => item.status == 'checked-in')
          .length;

      await fs.FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .collection('guests')
          .doc(_buildGuestDocumentId(reservation))
          .set({
        'guestName': reservation.guestName,
        'guestEmail': reservation.guestEmail,
        'guestPhone': reservation.guestPhone,
        'guestAddress': reservation.guestAddress,
        'guestNationality': reservation.guestNationality,
        'guestIdType': reservation.guestIdType,
        'guestIdNumber': reservation.guestIdNumber,
        'nextOfKinName': reservation.nextOfKinName,
        'nextOfKinPhone': reservation.nextOfKinPhone,
        'nextOfKinRelationship': reservation.nextOfKinRelationship,
        'bookingSource': reservation.bookingSource,
        'companyName': reservation.companyName,
        'vehiclePlateNumber': reservation.vehiclePlateNumber,
        'reservationCount': relatedReservations.length,
        'checkedInCount': checkedInCount,
        'totalSpend': totalSpend,
        'activeReservationId': reservation.id,
        'currentRoomId': reservation.roomId,
        'currentRoomNumber': room?.number,
        'lastCheckIn': reservation.checkIn.toIso8601String(),
        'lastCheckOut': reservation.checkOut.toIso8601String(),
        'lastUpdatedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HotelProvider] syncGuestProfile error: $e');
    }
  }

  Map<String, dynamic> buildReservationSalePayload(
    Reservation reservation, {
    Room? room,
    String? saleId,
    String? paymentMethod,
  }) {
    final resolvedRoom = room ?? getRoomById(reservation.roomId);
    final charges = buildFolioCharges(reservation);
    final total = getReservationBalance(reservation);
    final resolvedPaymentMethod =
        paymentMethod ?? _defaultHotelPaymentMethod(reservation);
    final resolvedSaleId = saleId ?? 'hotel_${reservation.id}';
    final now = DateTime.now();

    final items = charges.map((charge) {
      final amount = ((charge['amount'] as num?)?.toDouble() ?? 0.0);
      final description = charge['description']?.toString() ?? 'Hotel charge';
      return {
        'name': description,
        'productName': description,
        'quantity': 1,
        'price': amount,
        'unitPrice': amount,
        'total': amount,
        'type': charge['type']?.toString() ?? 'charge',
      };
    }).toList();

    return {
      'id': resolvedSaleId,
      'saleId': resolvedSaleId,
      'businessId': _businessId,
      'linkedReservationId': reservation.id,
      'orderId': reservation.id,
      'bookingId': reservation.id,
      'receiptNumber': 'HOTEL-${_shortCode(reservation.id)}',
      'category': 'Hotel',
      'status':
          reservation.paymentStatus == 'paid' ? 'completed' : 'pending-payment',
      'paymentStatus': reservation.paymentStatus,
      'paymentMethod': resolvedPaymentMethod,
      'paymentMethods': [resolvedPaymentMethod],
      'items': items,
      'subtotal': total,
      'tax': 0.0,
      'discount': 0.0,
      'total': total,
      'totalAmount': total,
      'finalAmount': total,
      'timestamp': now.toIso8601String(),
      'date': now.toIso8601String(),
      'customerName': reservation.guestName,
      'customerDisplayName': reservation.guestName,
      'customerEmail': reservation.guestEmail,
      'customerPhone': reservation.guestPhone,
      'customerAddress': reservation.guestAddress,
      'numberOfPersons': reservation.adults + reservation.children,
      'roomId': reservation.roomId,
      'roomNumber': resolvedRoom?.number ?? reservation.roomId,
      'roomType': resolvedRoom?.type ?? '',
      'checkIn': reservation.checkIn.toIso8601String(),
      'checkOut': reservation.checkOut.toIso8601String(),
      'stayNights': reservation.nights,
      'bookingSource': reservation.bookingSource,
      'specialRequests': reservation.specialRequests,
      'customer': {
        'name': reservation.guestName,
        'email': reservation.guestEmail,
        'phone': reservation.guestPhone,
        'address': reservation.guestAddress,
      },
      'guestDetails': {
        'nationality': reservation.guestNationality,
        'idType': reservation.guestIdType,
        'idNumber': reservation.guestIdNumber,
        'companyName': reservation.companyName,
        'vehiclePlateNumber': reservation.vehiclePlateNumber,
      },
      'nextOfKin': {
        'name': reservation.nextOfKinName,
        'phone': reservation.nextOfKinPhone,
        'relationship': reservation.nextOfKinRelationship,
      },
    };
  }

  Future<Map<String, dynamic>> persistReservationSale(
    String reservationId, {
    String? paymentMethod,
    bool sendNotifications = true,
  }) async {
    final reservation = _reservations.firstWhere(
      (item) => item.id == reservationId,
      orElse: () => throw Exception('Reservation not found'),
    );

    final saleId = 'hotel_${reservation.id}';
    final saleMap = buildReservationSalePayload(
      reservation,
      saleId: saleId,
      paymentMethod: paymentMethod,
    );

    if (_businessId == null || _businessId!.isEmpty) {
      return saleMap;
    }

    final firestorePayload = Map<String, dynamic>.from(saleMap)
      ..['createdAt'] = fs.FieldValue.serverTimestamp()
      ..['updatedAt'] = fs.FieldValue.serverTimestamp()
      ..['timestamp'] = fs.FieldValue.serverTimestamp();

    await fs.FirebaseFirestore.instance
        .collection('businesses')
        .doc(_businessId!)
        .collection('sales')
        .doc(saleId)
        .set(firestorePayload, fs.SetOptions(merge: true));

    if (sendNotifications) {
      try {
        await _notificationManager.notifyPaymentReceived(
          businessId: _businessId!,
          customerName: reservation.guestName,
          amount: (saleMap['finalAmount'] as num?)?.toDouble() ?? 0.0,
          transactionId: saleId,
        );
        await _notificationManager.notifySaleCompleted(
          businessId: _businessId!,
          customerName: reservation.guestName,
          amount: (saleMap['finalAmount'] as num?)?.toDouble() ?? 0.0,
          paymentMethod:
              (saleMap['paymentMethod'] as String?) ?? 'hotel_billing',
        );
        await _notificationLogger.logNotificationEvent(
          businessId: _businessId!,
          type: 'hotel_payment_recorded',
          channel: 'local',
          recipient: reservation.guestName,
          success: true,
          orderId: reservation.id,
        );
      } catch (e) {
        debugPrint('[HotelProvider] hotel payment notification error: $e');
      }
    }

    return saleMap;
  }

  List<Reservation> getReservationsByStatuses(List<String> statuses) {
    return _reservations.where((r) => statuses.contains(r.status)).toList();
  }

  List<Reservation> getArrivalsForDate(DateTime date) {
    return _reservations.where((r) {
      return r.checkIn.year == date.year &&
          r.checkIn.month == date.month &&
          r.checkIn.day == date.day &&
          r.status == 'confirmed';
    }).toList();
  }

  // Initialize with sample data
  void _initializeSampleData() {
    _rooms = [
      Room(
        id: 'R1',
        number: '101',
        type: 'single',
        capacity: 1,
        pricePerNight: 80.0,
        status: 'available',
        emoji: '🏠',
        amenities: ['WiFi', 'AC', 'TV', 'Shower'],
        images: [],
        floor: 1,
        rating: 4.2,
      ),
      Room(
        id: 'R2',
        number: '102',
        type: 'double',
        capacity: 2,
        pricePerNight: 120.0,
        status: 'occupied',
        emoji: '🛏️',
        amenities: ['WiFi', 'AC', 'TV', 'Shower', 'Bathtub'],
        images: [],
        floor: 1,
        rating: 4.7,
      ),
      Room(
        id: 'R3',
        number: '103',
        type: 'suite',
        capacity: 4,
        pricePerNight: 200.0,
        status: 'available',
        emoji: '👑',
        amenities: [
          'WiFi',
          'AC',
          'TV',
          'Shower',
          'Bathtub',
          'Kitchenette',
          'Balcony'
        ],
        images: [],
        floor: 1,
        rating: 4.9,
      ),
      Room(
        id: 'R4',
        number: '201',
        type: 'double',
        capacity: 2,
        pricePerNight: 130.0,
        status: 'occupied',
        emoji: '🛏️',
        amenities: ['WiFi', 'AC', 'TV', 'Shower', 'Mountain view'],
        images: [],
        floor: 2,
        rating: 4.6,
      ),
      Room(
        id: 'R5',
        number: '202',
        type: 'deluxe',
        capacity: 2,
        pricePerNight: 180.0,
        status: 'maintenance',
        emoji: '🔧',
        amenities: ['WiFi', 'AC', 'TV', 'Shower', 'Bathtub', 'Spa tub'],
        images: [],
        floor: 2,
        rating: 4.8,
      ),
    ];

    _reservations = [
      Reservation(
        id: 'B1',
        roomId: 'R2',
        guestName: 'John Smith',
        guestEmail: 'john@example.com',
        guestPhone: '555-0101',
        guestAddress: '12 Palm Avenue',
        guestNationality: 'Nigerian',
        guestIdType: 'National ID',
        guestIdNumber: 'NIN-001',
        nextOfKinName: 'Mary Smith',
        nextOfKinPhone: '555-1101',
        nextOfKinRelationship: 'Spouse',
        bookingSource: 'walk-in',
        checkIn: DateTime.now(),
        checkOut: DateTime.now().add(const Duration(days: 2)),
        adults: 2,
        children: 0,
        status: 'checked-in',
        totalPrice: 240.0,
        specialRequests: ['Late checkout', 'Extra pillows'],
        paymentStatus: 'paid',
      ),
      Reservation(
        id: 'B2',
        roomId: 'R4',
        guestName: 'Sarah Johnson',
        guestEmail: 'sarah@example.com',
        guestPhone: '555-0102',
        guestAddress: '22 Marina Road',
        guestNationality: 'Ghanaian',
        guestIdType: 'Passport',
        guestIdNumber: 'P-7788',
        nextOfKinName: 'Daniel Johnson',
        nextOfKinPhone: '555-1102',
        nextOfKinRelationship: 'Brother',
        bookingSource: 'online',
        checkIn: DateTime.now(),
        checkOut: DateTime.now().add(const Duration(days: 3)),
        adults: 1,
        children: 1,
        status: 'checked-in',
        totalPrice: 390.0,
        specialRequests: ['Crib needed'],
        paymentStatus: 'paid',
      ),
      Reservation(
        id: 'B3',
        roomId: 'R3',
        guestName: 'Michael Brown',
        guestEmail: 'michael@example.com',
        guestPhone: '555-0103',
        guestAddress: '7 Allen Avenue',
        guestNationality: 'Kenyan',
        guestIdType: 'Driver License',
        guestIdNumber: 'DL-0092',
        nextOfKinName: 'Angela Brown',
        nextOfKinPhone: '555-1103',
        nextOfKinRelationship: 'Sister',
        bookingSource: 'corporate',
        companyName: 'Acme Travels',
        checkIn: DateTime.now().add(const Duration(days: 5)),
        checkOut: DateTime.now().add(const Duration(days: 7)),
        adults: 4,
        children: 0,
        status: 'confirmed',
        totalPrice: 400.0,
        specialRequests: [],
        paymentStatus: 'partial',
      ),
    ];

    _serviceOrders = [
      ServiceOrder(
        id: 'S1',
        roomId: 'R2',
        serviceName: 'housekeeping',
        description: 'Room cleaning and towel change',
        requestedAt: DateTime.now(),
        status: 'pending',
        priority: 'medium',
      ),
      ServiceOrder(
        id: 'S2',
        roomId: 'R4',
        serviceName: 'laundry',
        description: 'Express laundry service',
        requestedAt: DateTime.now(),
        status: 'in-progress',
        priority: 'high',
      ),
    ];

    _updateOccupancy();
  }

  void _updateOccupancy() {
    if (_rooms.isEmpty) {
      _occupancy = 0.0;
    } else {
      _occupancy = (occupiedRooms / totalRooms) * 100;
    }
  }

  // Room Management
  void updateRoomStatus(String roomId, String newStatus) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      _rooms[index] = _rooms[index].copyWith(status: newStatus);
      _updateOccupancy();
      notifyListeners();
    }
  }

  void updateRoomRating(String roomId, double rating) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      _rooms[index] = _rooms[index].copyWith(rating: rating.clamp(0, 5));
      notifyListeners();
    }
  }

  /// Create a new room and persist to repository if available
  Future<void> createRoom({
    required String number,
    required String type,
    required int capacity,
    required double pricePerNight,
    int floor = 1,
    List<String>? amenities,
    String? emoji,
    List<Map<String, dynamic>>? priceIntervals,
  }) async {
    final localId = 'R${_rooms.length + 1}';
    String id = localId;

    if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
      try {
        final res = await repository!.createRoom({
          'businessId': _businessId,
          'number': number,
          'type': type,
          'capacity': capacity,
          'pricePerNight': pricePerNight,
          'status': 'available',
          'emoji': emoji,
          'amenities': amenities ?? [],
          'images': [],
          'floor': floor,
          'priceIntervals': priceIntervals ?? [],
          'createdAt': DateTime.now().toIso8601String(),
        });
        id = res['id']?.toString() ?? id;
      } catch (e) {
        debugPrint('[HotelProvider] createRoom repository error: $e');
      }
    }

    final room = Room(
      id: id,
      number: number,
      type: type,
      capacity: capacity,
      pricePerNight: pricePerNight,
      status: 'available',
      emoji: emoji,
      amenities: amenities ?? [],
      images: [],
      priceIntervals: priceIntervals,
      floor: floor,
    );

    _rooms.add(room);
    _updateOccupancy();
    notifyListeners();
  }

  List<Room> getAvailableRoomsForDates(DateTime checkIn, DateTime checkOut) {
    return _rooms.where((room) {
      if (room.status != 'available') return false;
      final hasConflict = _reservations.any((res) {
        return res.roomId == room.id &&
            res.status != 'cancelled' &&
            res.checkOut.isAfter(checkIn) &&
            res.checkIn.isBefore(checkOut);
      });
      return !hasConflict;
    }).toList();
  }

  List<Room> filterByType(String type) {
    return _rooms.where((r) => r.type == type).toList();
  }

  List<Room> filterByCapacity(int minCapacity) {
    return _rooms.where((r) => r.capacity >= minCapacity).toList();
  }

  List<Room> sortByPrice({bool ascending = true}) {
    final sorted = [..._rooms];
    sorted.sort((a, b) => ascending
        ? a.pricePerNight.compareTo(b.pricePerNight)
        : b.pricePerNight.compareTo(a.pricePerNight));
    return sorted;
  }

  // Reservation Management
  Future<void> createReservation({
    required String roomId,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    String guestAddress = '',
    String guestNationality = '',
    String guestIdType = '',
    String guestIdNumber = '',
    String nextOfKinName = '',
    String nextOfKinPhone = '',
    String nextOfKinRelationship = '',
    String bookingSource = 'walk-in',
    String companyName = '',
    String vehiclePlateNumber = '',
    String vehicleMake = '',
    String vehicleModel = '',
    String vehicleColor = '',
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
    required List<String> specialRequests,
  }) async {
    if (checkIn.isAfter(checkOut) || checkIn.isAtSameMomentAs(checkOut)) {
      throw Exception('Check-out must be after check-in.');
    }

    final room = _rooms.firstWhere((r) => r.id == roomId,
        orElse: () => throw Exception('Selected room not found.'));

    final conflict = _reservations.any((existing) {
      if (existing.roomId != roomId || existing.status == 'cancelled')
        return false;
      return existing.checkOut.isAfter(checkIn) &&
          existing.checkIn.isBefore(checkOut);
    });

    if (conflict) {
      throw Exception('Selected room is already booked for the chosen dates.');
    }

    final nights = checkOut.difference(checkIn).inDays;
    final totalPrice = room.pricePerNight * nights;
    String reservationId = 'B${_reservations.length + 1}';

    var reservation = Reservation(
      id: reservationId,
      roomId: roomId,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      guestAddress: guestAddress,
      guestNationality: guestNationality,
      guestIdType: guestIdType,
      guestIdNumber: guestIdNumber,
      nextOfKinName: nextOfKinName,
      nextOfKinPhone: nextOfKinPhone,
      nextOfKinRelationship: nextOfKinRelationship,
      bookingSource: bookingSource,
      companyName: companyName,
      vehiclePlateNumber: vehiclePlateNumber,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      checkIn: checkIn,
      checkOut: checkOut,
      adults: adults,
      children: children,
      status: 'confirmed',
      totalPrice: totalPrice,
      specialRequests: specialRequests,
      paymentStatus: 'unpaid',
    );

    _reservations.add(reservation);

    if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
      final saved = await repository!.createBooking({
        'businessId': _businessId,
        'roomId': reservation.roomId,
        'roomNumber': room.number,
        'guestName': reservation.guestName,
        'guestEmail': reservation.guestEmail,
        'guestPhone': reservation.guestPhone,
        'guestAddress': reservation.guestAddress,
        'guestNationality': reservation.guestNationality,
        'guestIdType': reservation.guestIdType,
        'guestIdNumber': reservation.guestIdNumber,
        'nextOfKinName': reservation.nextOfKinName,
        'nextOfKinPhone': reservation.nextOfKinPhone,
        'nextOfKinRelationship': reservation.nextOfKinRelationship,
        'bookingSource': reservation.bookingSource,
        'companyName': reservation.companyName,
        'vehiclePlateNumber': reservation.vehiclePlateNumber,
        'checkIn': reservation.checkIn.toIso8601String(),
        'checkOut': reservation.checkOut.toIso8601String(),
        'adults': reservation.adults,
        'children': reservation.children,
        'status': reservation.status,
        'totalPrice': reservation.totalPrice,
        'specialRequests': reservation.specialRequests,
        'paymentStatus': reservation.paymentStatus,
        'createdAt': reservation.createdAt.toIso8601String(),
      });

      if (saved['id'] != null) {
        reservationId = saved['id'].toString();
        _reservations[_reservations.length - 1] =
            reservation.copyWith(id: reservationId);
      }
    }

    final persistedReservation = _reservations.last;
    await _syncGuestProfile(persistedReservation);

    if (_businessId != null && _businessId!.isNotEmpty) {
      try {
        await _notificationManager.notifyBookingConfirmed(
          businessId: _businessId!,
          bookingId: reservationId,
          guestName: guestName,
        );
        await _notificationLogger.logNotificationEvent(
          businessId: _businessId!,
          type: 'hotel_booking_confirmed',
          channel: 'local',
          recipient: guestName,
          success: true,
          orderId: reservationId,
        );
      } catch (e) {
        debugPrint('[HotelProvider] booking notification failed: $e');
      }
    }

    if (_businessId != null && _businessId!.isNotEmpty) {
      try {
        await BusinessReminderService.instance
            .scheduleHotelReservationReminders(
          businessId: _businessId!,
          reservationId: reservationId,
          guestName: guestName,
          roomLabel: room.number,
          checkIn: checkIn,
          checkOut: checkOut,
        );
      } catch (e) {
        debugPrint('[HotelProvider] reminder scheduling failed: $e');
      }
    }

    notifyListeners();
  }

  Future<void> updateReservationStatus(
      String reservationId, String newStatus) async {
    final index = _reservations.indexWhere((r) => r.id == reservationId);
    if (index >= 0) {
      _reservations[index] = _reservations[index].copyWith(status: newStatus);

      if (newStatus == 'checked-in') {
        updateRoomStatus(_reservations[index].roomId, 'occupied');
      } else if (newStatus == 'checked-out') {
        updateRoomStatus(_reservations[index].roomId, 'available');
      } else if (newStatus == 'cancelled') {
        updateRoomStatus(_reservations[index].roomId, 'available');
      }

      if (repository != null &&
          _businessId != null &&
          _businessId!.isNotEmpty) {
        try {
          await repository!.updateReservation(
              _businessId!, reservationId, {'status': newStatus});
        } catch (e) {
          debugPrint('[HotelProvider] updateReservationStatus error: $e');
        }
      }

      await _syncGuestProfile(_reservations[index]);

      if (newStatus == 'checked-out' &&
          _reservations[index].paymentStatus == 'paid') {
        try {
          await persistReservationSale(
            reservationId,
            sendNotifications: false,
          );
        } catch (e) {
          debugPrint(
              '[HotelProvider] persistReservationSale on checkout error: $e');
        }
      }

      notifyListeners();
    }
  }

  Future<void> cancelReservation(String reservationId, {String? reason}) async {
    await updateReservationStatus(reservationId, 'cancelled');
    if (reason != null && reason.isNotEmpty) {
      // optional reason stored in Firestore if supported
      if (repository != null &&
          _businessId != null &&
          _businessId!.isNotEmpty) {
        try {
          await repository!.updateReservation(
              _businessId!, reservationId, {'cancelReason': reason});
        } catch (e) {
          debugPrint(
              '[HotelProvider] cancelReservation reason store error: $e');
        }
      }
    }
  }

  Future<void> updatePaymentStatus(
      String reservationId, String paymentStatus) async {
    final index = _reservations.indexWhere((r) => r.id == reservationId);
    if (index >= 0) {
      _reservations[index] =
          _reservations[index].copyWith(paymentStatus: paymentStatus);

      if (repository != null &&
          _businessId != null &&
          _businessId!.isNotEmpty) {
        try {
          await repository!.updateReservation(
              _businessId!, reservationId, {'paymentStatus': paymentStatus});
        } catch (e) {
          debugPrint('[HotelProvider] updatePaymentStatus error: $e');
        }
      }

      await _syncGuestProfile(_reservations[index]);

      if (paymentStatus == 'paid') {
        try {
          await persistReservationSale(
            reservationId,
            paymentMethod: 'hotel_billing',
          );
        } catch (e) {
          debugPrint(
              '[HotelProvider] persistReservationSale on payment error: $e');
        }
      }

      notifyListeners();
    }
  }

  Future<void> addReservationCharge({
    required String reservationId,
    required String description,
    required double amount,
    String category = 'extra',
    String source = 'manual',
    String? sourceOrderId,
    String? createdById,
    String? createdByName,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_businessId == null || _businessId!.isEmpty) {
      throw Exception('Business ID is required to add a reservation charge.');
    }

    final reservation = getReservationById(reservationId);
    if (reservation == null) {
      throw Exception('Reservation not found.');
    }

    final room = getRoomById(reservation.roomId);
    final charge = await _folioService.addCharge(
      businessId: _businessId!,
      reservationId: reservation.id,
      roomId: reservation.roomId,
      roomNumber: room?.number ?? reservation.roomId,
      description: description,
      amount: amount,
      category: category,
      source: source,
      sourceOrderId: sourceOrderId,
      createdById: createdById,
      createdByName: createdByName,
      metadata: metadata,
    );

    _folioCharges = [charge, ..._folioCharges]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _syncGuestProfile(reservation);
    notifyListeners();
  }

  Future<void> extendReservationStay({
    required String reservationId,
    required DateTime newCheckOut,
    String? extensionReason,
  }) async {
    final index = _reservations
        .indexWhere((reservation) => reservation.id == reservationId);
    if (index == -1) {
      throw Exception('Reservation not found.');
    }

    final reservation = _reservations[index];
    if (!newCheckOut.isAfter(reservation.checkOut)) {
      throw Exception('New checkout must be after the current checkout date.');
    }

    final conflict = _reservations.any((existing) {
      if (existing.id == reservation.id ||
          existing.roomId != reservation.roomId ||
          existing.status == 'cancelled') {
        return false;
      }

      return existing.checkOut.isAfter(reservation.checkOut) &&
          existing.checkIn.isBefore(newCheckOut);
    });

    if (conflict) {
      throw Exception(
          'The room already has another booking within the extension window.');
    }

    final room = getRoomById(reservation.roomId);
    final updatedSpecialRequests =
        List<String>.from(reservation.specialRequests);
    if (extensionReason != null && extensionReason.trim().isNotEmpty) {
      updatedSpecialRequests.add('Stay extension: ${extensionReason.trim()}');
    }

    final nights = newCheckOut.difference(reservation.checkIn).inDays;
    final updatedReservation = reservation.copyWith(
      checkOut: newCheckOut,
      totalPrice: (room?.pricePerNight ?? 0.0) * (nights <= 0 ? 1 : nights),
      specialRequests: updatedSpecialRequests,
    );

    _reservations[index] = updatedReservation;

    if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
      await repository!.updateReservation(
        _businessId!,
        reservationId,
        {
          'checkOut': newCheckOut.toIso8601String(),
          'totalPrice': updatedReservation.totalPrice,
          'specialRequests': updatedReservation.specialRequests,
        },
      );
    }

    await _syncGuestProfile(updatedReservation);
    notifyListeners();
  }

  List<Reservation> getUpcomingCheckIns(Duration window) {
    final now = DateTime.now();
    final deadline = now.add(window);
    return _reservations.where((r) {
      return r.checkIn.isAfter(now) &&
          r.checkIn.isBefore(deadline) &&
          r.status == 'confirmed';
    }).toList();
  }

  List<Reservation> getTodayCheckOuts() {
    final today = DateTime.now();
    return _reservations.where((r) {
      return r.checkOut.year == today.year &&
          r.checkOut.month == today.month &&
          r.checkOut.day == today.day &&
          r.status == 'checked-in';
    }).toList();
  }

  // Service Management
  Future<void> createServiceOrder({
    required String roomId,
    required String serviceName,
    required String description,
    required String priority,
    String? reservationId,
    double? chargeAmount,
    String source = 'hotel_service',
  }) async {
    final order = ServiceOrder(
      id: 'service_${DateTime.now().microsecondsSinceEpoch}',
      roomId: roomId,
      reservationId: reservationId ?? getActiveReservationForRoom(roomId)?.id,
      serviceName: serviceName,
      description: description,
      requestedAt: DateTime.now(),
      status: 'pending',
      priority: priority,
      chargeAmount: chargeAmount,
      source: source,
    );

    _serviceOrders.add(order);
    if (_businessId != null && _businessId!.isNotEmpty) {
      await fs.FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .collection('hotel_service_orders')
          .doc(order.id)
          .set(order.toJson(), fs.SetOptions(merge: true));
    }
    notifyListeners();
  }

  Future<void> updateServiceOrderStatus(
    String serviceOrderId,
    String newStatus,
  ) async {
    final index = _serviceOrders.indexWhere((s) => s.id == serviceOrderId);
    if (index >= 0) {
      _serviceOrders[index] = ServiceOrder(
        id: _serviceOrders[index].id,
        roomId: _serviceOrders[index].roomId,
        reservationId: _serviceOrders[index].reservationId,
        serviceName: _serviceOrders[index].serviceName,
        description: _serviceOrders[index].description,
        requestedAt: _serviceOrders[index].requestedAt,
        completedAt: newStatus == 'completed'
            ? DateTime.now()
            : _serviceOrders[index].completedAt,
        status: newStatus,
        priority: _serviceOrders[index].priority,
        chargeAmount: _serviceOrders[index].chargeAmount,
        source: _serviceOrders[index].source,
      );
      if (_businessId != null && _businessId!.isNotEmpty) {
        await fs.FirebaseFirestore.instance
            .collection('businesses')
            .doc(_businessId!)
            .collection('hotel_service_orders')
            .doc(serviceOrderId)
            .set(
              _serviceOrders[index].toJson(),
              fs.SetOptions(merge: true),
            );
      }
      notifyListeners();
    }
  }

  List<ServiceOrder> getPendingServices(String roomId) {
    return _serviceOrders
        .where((s) => s.roomId == roomId && s.status != 'completed')
        .toList();
  }

  // Metrics
  Map<String, int> getRoomStatusDistribution() {
    return {
      'available': availableRooms,
      'occupied': occupiedRooms,
      'maintenance': maintenanceRooms,
      'reserved': _reservations.where((r) => r.status == 'confirmed').length,
    };
  }

  double getAverageRating() {
    if (_rooms.isEmpty) return 0;
    return _rooms.fold<double>(0, (sum, r) => sum + r.rating) / _rooms.length;
  }

  Future<void> loadFromRepository() async {
    if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
      // load rooms from repository and replace local rooms if available
      try {
        final docs = await repository!.fetchRooms(_businessId!);
        if (docs.isNotEmpty) {
          _rooms = docs.map((m) {
            return Room(
              id: m['id']?.toString() ?? '',
              number: m['number']?.toString() ?? '',
              type: m['type']?.toString() ?? 'single',
              capacity: (m['capacity'] is int)
                  ? m['capacity'] as int
                  : int.tryParse(m['capacity']?.toString() ?? '1') ?? 1,
              pricePerNight: (m['pricePerNight'] is num)
                  ? (m['pricePerNight'] as num).toDouble()
                  : double.tryParse(m['pricePerNight']?.toString() ?? '0') ??
                      0.0,
              status: m['status']?.toString() ?? 'available',
              emoji: m['emoji']?.toString(),
              amenities: List<String>.from(m['amenities'] ?? []),
              images: List<String>.from(m['images'] ?? []),
              priceIntervals: (m['priceIntervals'] is List)
                  ? List<Map<String, dynamic>>.from(m['priceIntervals'])
                  : null,
              floor: (m['floor'] is int)
                  ? m['floor'] as int
                  : int.tryParse(m['floor']?.toString() ?? '1') ?? 1,
            );
          }).toList();
          _updateOccupancy();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[HotelProvider] loadFromRepository error: $e');
      }
    }
  }

  Future<void> syncReservations() async {
    if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
      try {
        final docs = await repository!.fetchReservations(_businessId!);
        if (docs.isNotEmpty) {
          _reservations = docs.map((m) {
            return Reservation(
              id: m['id']?.toString() ?? '',
              roomId: m['roomId']?.toString() ?? '',
              guestName: m['guestName']?.toString() ?? '',
              guestEmail: m['guestEmail']?.toString() ?? '',
              guestPhone: m['guestPhone']?.toString() ?? '',
              guestAddress: m['guestAddress']?.toString() ?? '',
              guestNationality: m['guestNationality']?.toString() ?? '',
              guestIdType: m['guestIdType']?.toString() ?? '',
              guestIdNumber: m['guestIdNumber']?.toString() ?? '',
              nextOfKinName: m['nextOfKinName']?.toString() ?? '',
              nextOfKinPhone: m['nextOfKinPhone']?.toString() ?? '',
              nextOfKinRelationship:
                  m['nextOfKinRelationship']?.toString() ?? '',
              bookingSource: m['bookingSource']?.toString() ?? 'walk-in',
              companyName: m['companyName']?.toString() ?? '',
              vehiclePlateNumber: m['vehiclePlateNumber']?.toString() ?? '',
              checkIn: _parseDynamicDate(m['checkIn']) ?? DateTime.now(),
              checkOut: _parseDynamicDate(m['checkOut']) ?? DateTime.now(),
              adults: (m['adults'] is int)
                  ? m['adults'] as int
                  : int.tryParse(m['adults']?.toString() ?? '0') ?? 0,
              children: (m['children'] is int)
                  ? m['children'] as int
                  : int.tryParse(m['children']?.toString() ?? '0') ?? 0,
              status: m['status']?.toString() ?? 'pending',
              totalPrice: (m['totalPrice'] is num)
                  ? (m['totalPrice'] as num).toDouble()
                  : double.tryParse(m['totalPrice']?.toString() ?? '0') ?? 0.0,
              specialRequests: List<String>.from(m['specialRequests'] ?? []),
              paymentStatus: m['paymentStatus']?.toString() ?? 'unpaid',
              createdAt: _parseDynamicDate(m['createdAt']) ?? DateTime.now(),
            );
          }).toList();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[HotelProvider] syncReservations error: $e');
      }
    }
  }

  /// Get today's sales total from Firestore sales collection
  Future<double> getTodaysSalesTotal() async {
    try {
      final today = DateTime.now();

      if (_businessId != null && _businessId!.isNotEmpty) {
        final snap = await fs.FirebaseFirestore.instance
            .collection('businesses')
            .doc(_businessId!)
            .collection('sales')
            .where('category', isEqualTo: 'Hotel')
            .get();

        double total = 0.0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final createdAt =
              _parseDynamicDate(data['createdAt'] ?? data['timestamp']);
          if (createdAt != null && _sameCalendarDay(createdAt, today)) {
            total += ((data['finalAmount'] ??
                    data['totalAmount'] ??
                    data['total'] ??
                    0) as num)
                .toDouble();
          }
        }

        return total;
      }

      double total = 0.0;

      for (final reservation in _reservations) {
        final touchesToday = _sameCalendarDay(reservation.checkIn, today) ||
            _sameCalendarDay(reservation.checkOut, today);

        if (!touchesToday) continue;
        if (reservation.paymentStatus == 'paid' ||
            reservation.paymentStatus == 'partial') {
          total += reservation.totalPrice;
        }
      }

      return total;
    } catch (e) {
      debugPrint('[HotelProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }

  Future<void> _loadServiceOrders() async {
    if (_businessId == null || _businessId!.isEmpty) return;

    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .collection('hotel_service_orders')
          .get();

      _serviceOrders = snapshot.docs
          .map((doc) => ServiceOrder.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      notifyListeners();
    } catch (e) {
      debugPrint('[HotelProvider] loadServiceOrders error: $e');
    }
  }

  Future<void> _loadFolioCharges() async {
    if (_businessId == null || _businessId!.isEmpty) return;

    try {
      _folioCharges = await _folioService.fetchCharges(_businessId!);
      notifyListeners();
    } catch (e) {
      debugPrint('[HotelProvider] loadFolioCharges error: $e');
    }
  }
}
