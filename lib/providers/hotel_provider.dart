import 'package:flutter/foundation.dart';
import '../data/repositories/industry_specific/hotel_repository.dart';

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
  final List<Map<String, dynamic>>? priceIntervals; // Optional time-interval pricing
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
  final String id;
  final String roomId;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final DateTime checkIn;
  final DateTime checkOut;
  final int adults;
  final int children;
  final String status; // pending, confirmed, checked-in, checked-out, cancelled
  final double totalPrice;
  final List<String> specialRequests;
  final String paymentStatus; // unpaid, partial, paid

  Reservation({
    required this.id,
    required this.roomId,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.checkIn,
    required this.checkOut,
    required this.adults,
    required this.children,
    required this.status,
    required this.totalPrice,
    required this.specialRequests,
    required this.paymentStatus,
  });

  int get nights => checkOut.difference(checkIn).inDays;
}

// Service Orders
class ServiceOrder {
  final String id;
  final String roomId;
  final String serviceName; // housekeeping, laundry, food delivery, maintenance
  final String description;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String status; // pending, in-progress, completed, cancelled
  final String priority; // low, medium, high, urgent

  ServiceOrder({
    required this.id,
    required this.roomId,
    required this.serviceName,
    required this.description,
    required this.requestedAt,
    this.completedAt,
    required this.status,
    required this.priority,
  });
}

class HotelProvider extends ChangeNotifier {
  final HotelRepository? repository;
  String? _businessId;

  List<Room> _rooms = [];
  List<Reservation> _reservations = [];
  List<ServiceOrder> _serviceOrders = [];
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
    if (_businessId == null || _businessId!.isEmpty || repository == null) return;
    await loadFromRepository();
    await syncReservations();
  }

  // Getters
  List<Room> get rooms => _rooms;
  List<Reservation> get reservations => _reservations;
  List<ServiceOrder> get serviceOrders => _serviceOrders;
  double get occupancy => _occupancy;
  bool get hasRemote => repository != null;

  int get totalRooms => _rooms.length;
  int get occupiedRooms => _rooms.where((r) => r.status == 'occupied').length;
  int get availableRooms => _rooms.where((r) => r.status == 'available').length;
  int get maintenanceRooms =>
      _rooms.where((r) => r.status == 'maintenance').length;

  double get revenue => _reservations
      .where((r) => r.status == 'checked-out' || r.status == 'confirmed')
      .fold(0, (sum, r) => sum + r.totalPrice);

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
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
    required List<String> specialRequests,
  }) async {
    final room = _rooms.firstWhere((r) => r.id == roomId);
    final nights = checkOut.difference(checkIn).inDays;
    final totalPrice = room.pricePerNight * nights;

    final reservation = Reservation(
      id: 'B${_reservations.length + 1}',
      roomId: roomId,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
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

    if (repository != null) {
      // Persist as a simple map using repository API
      await repository!.createBooking({
        'businessId': _businessId ?? '',
        'roomId': reservation.roomId,
        'guestName': reservation.guestName,
        'guestEmail': reservation.guestEmail,
        'guestPhone': reservation.guestPhone,
        'checkIn': reservation.checkIn.toIso8601String(),
        'checkOut': reservation.checkOut.toIso8601String(),
        'adults': reservation.adults,
        'children': reservation.children,
        'status': reservation.status,
        'totalPrice': reservation.totalPrice,
        'specialRequests': reservation.specialRequests,
        'paymentStatus': reservation.paymentStatus,
      });
    }

    notifyListeners();
  }

  void updateReservationStatus(String reservationId, String newStatus) {
    final index = _reservations.indexWhere((r) => r.id == reservationId);
    if (index >= 0) {
      _reservations[index] = Reservation(
        id: _reservations[index].id,
        roomId: _reservations[index].roomId,
        guestName: _reservations[index].guestName,
        guestEmail: _reservations[index].guestEmail,
        guestPhone: _reservations[index].guestPhone,
        checkIn: _reservations[index].checkIn,
        checkOut: _reservations[index].checkOut,
        adults: _reservations[index].adults,
        children: _reservations[index].children,
        status: newStatus,
        totalPrice: _reservations[index].totalPrice,
        specialRequests: _reservations[index].specialRequests,
        paymentStatus: _reservations[index].paymentStatus,
      );

      if (newStatus == 'checked-in') {
        updateRoomStatus(_reservations[index].roomId, 'occupied');
      } else if (newStatus == 'checked-out') {
        updateRoomStatus(_reservations[index].roomId, 'available');
      }

      notifyListeners();
    }
  }

  void updatePaymentStatus(String reservationId, String paymentStatus) {
    final index = _reservations.indexWhere((r) => r.id == reservationId);
    if (index >= 0) {
      _reservations[index] = Reservation(
        id: _reservations[index].id,
        roomId: _reservations[index].roomId,
        guestName: _reservations[index].guestName,
        guestEmail: _reservations[index].guestEmail,
        guestPhone: _reservations[index].guestPhone,
        checkIn: _reservations[index].checkIn,
        checkOut: _reservations[index].checkOut,
        adults: _reservations[index].adults,
        children: _reservations[index].children,
        status: _reservations[index].status,
        totalPrice: _reservations[index].totalPrice,
        specialRequests: _reservations[index].specialRequests,
        paymentStatus: paymentStatus,
      );
      notifyListeners();
    }
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
  void createServiceOrder({
    required String roomId,
    required String serviceName,
    required String description,
    required String priority,
  }) {
    final order = ServiceOrder(
      id: 'S${_serviceOrders.length + 1}',
      roomId: roomId,
      serviceName: serviceName,
      description: description,
      requestedAt: DateTime.now(),
      status: 'pending',
      priority: priority,
    );

    _serviceOrders.add(order);
    notifyListeners();
  }

  void updateServiceOrderStatus(String serviceOrderId, String newStatus) {
    final index = _serviceOrders.indexWhere((s) => s.id == serviceOrderId);
    if (index >= 0) {
      _serviceOrders[index] = ServiceOrder(
        id: _serviceOrders[index].id,
        roomId: _serviceOrders[index].roomId,
        serviceName: _serviceOrders[index].serviceName,
        description: _serviceOrders[index].description,
        requestedAt: _serviceOrders[index].requestedAt,
        completedAt: newStatus == 'completed'
            ? DateTime.now()
            : _serviceOrders[index].completedAt,
        status: newStatus,
        priority: _serviceOrders[index].priority,
      );
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
              checkIn: DateTime.tryParse(m['checkIn']?.toString() ?? '') ??
                  DateTime.now(),
              checkOut: DateTime.tryParse(m['checkOut']?.toString() ?? '') ??
                  DateTime.now(),
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
      // Get business ID from some provider or context
      // For now, return 0 as placeholder - this needs to be integrated with business context
      return 0.0;
    } catch (e) {
      debugPrint('[HotelProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}

