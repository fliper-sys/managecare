import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/services/business_reminder_service.dart';
import 'package:business_manager/services/whatsapp_service.dart';

// ==================== MODELS ====================

class SalonService {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String category; // haircut, hair-color, treatment, styling, makeup
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  SalonService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
  });

  SalonService.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        description = json['description'] ?? '',
        price = (json['price'] ?? 0).toDouble(),
        durationMinutes = json['durationMinutes'] ?? 60,
        category = json['category'] ?? 'haircut',
        imageUrl = json['imageUrl'],
        isActive = json['isActive'] ?? true,
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'durationMinutes': durationMinutes,
        'category': category,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  SalonService copyWith(
          {String? name,
          String? description,
          double? price,
          int? durationMinutes,
          String? category,
          String? imageUrl,
          bool? isActive}) =>
      SalonService(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        category: category ?? this.category,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

class SalonAppointment {
  final String id;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final String stylistId;
  final String stylistName;
  final DateTime appointmentTime;
  final int durationMinutes;
  final String status; // pending, confirmed, completed, cancelled, no-show
  final String? notes;
  final double? amountPaid;
  final String? paymentMethod;
  final double? tipAmount;
  final DateTime createdAt;

  SalonAppointment({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.stylistId,
    required this.stylistName,
    required this.appointmentTime,
    required this.durationMinutes,
    required this.status,
    this.notes,
    this.amountPaid,
    this.paymentMethod,
    this.tipAmount,
    required this.createdAt,
  });

  SalonAppointment.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        clientName = json['clientName'] ?? '',
        clientPhone = json['clientPhone'] ?? '',
        clientEmail = json['clientEmail'] ?? '',
        serviceId = json['serviceId'] ?? '',
        serviceName = json['serviceName'] ?? '',
        servicePrice = (json['servicePrice'] ?? 0).toDouble(),
        stylistId = json['stylistId'] ?? '',
        stylistName = json['stylistName'] ?? '',
        appointmentTime = parseTimestamp(json['appointmentTime']),
        durationMinutes = json['durationMinutes'] ?? 60,
        status = json['status'] ?? 'pending',
        notes = json['notes'],
        amountPaid = json['amountPaid']?.toDouble(),
        paymentMethod = json['paymentMethod'],
        tipAmount = json['tipAmount']?.toDouble(),
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientEmail': clientEmail,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'servicePrice': servicePrice,
        'stylistId': stylistId,
        'stylistName': stylistName,
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        'durationMinutes': durationMinutes,
        'status': status,
        'notes': notes,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'tipAmount': tipAmount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  SalonAppointment copyWith(
          {String? status,
          double? amountPaid,
          String? paymentMethod,
          double? tipAmount}) =>
      SalonAppointment(
        id: id,
        clientName: clientName,
        clientPhone: clientPhone,
        clientEmail: clientEmail,
        serviceId: serviceId,
        serviceName: serviceName,
        servicePrice: servicePrice,
        stylistId: stylistId,
        stylistName: stylistName,
        appointmentTime: appointmentTime,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        notes: notes,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        tipAmount: tipAmount ?? this.tipAmount,
        createdAt: createdAt,
      );
}

class Stylist {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String specialization;
  final List<String> serviceIds;
  final double? commissionPercentage;
  final double rating; // average rating from reviews
  final bool isActive;
  final DateTime createdAt;

  Stylist({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.specialization,
    required this.serviceIds,
    this.commissionPercentage,
    this.rating = 0.0,
    this.isActive = true,
    required this.createdAt,
  });

  Stylist.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        email = json['email'] ?? '',
        phone = json['phone'],
        specialization = json['specialization'] ?? 'stylist',
        serviceIds = List<String>.from(json['serviceIds'] ?? []),
        commissionPercentage = (json['commissionPercentage'] ?? 0).toDouble(),
        rating = (json['rating'] ?? 0).toDouble(),
        isActive = json['isActive'] ?? true,
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'specialization': specialization,
        'serviceIds': serviceIds,
        'commissionPercentage': commissionPercentage,
        'rating': rating,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class ProductItem {
  final String id;
  final String name;
  int quantity;
  final double price;
  final int minStock;
  final int reorderQuantity;

  ProductItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.minStock = 10,
    this.reorderQuantity = 50,
  });

  ProductItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        quantity = (json['quantity'] as num?)?.toInt() ??
            (json['qty'] as num?)?.toInt() ??
            0,
        price = (json['price'] as num?)?.toDouble() ?? 0.0,
        minStock = (json['minStock'] as num?)?.toInt() ??
            (json['minimumThreshold'] as num?)?.toInt() ??
            10,
        reorderQuantity = (json['reorderQuantity'] as num?)?.toInt() ??
            (json['reorderQuantity'] as num?)?.toInt() ??
            50;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'minStock': minStock,
        'reorderQuantity': reorderQuantity,
      };
}

// ==================== PROVIDER ====================

class SalonProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  String? _businessId;

  SalonProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  bool get _hasBusinessId => _businessId != null && _businessId!.isNotEmpty;

  bool _ensureBusinessId() {
    if (_hasBusinessId) return true;
    _errorMessage = 'No business selected';
    notifyListeners();
    return false;
  }

  List<SalonService> _services = [];
  List<SalonAppointment> _appointments = [];
  List<Stylist> _stylists = [];
  List<ProductItem> _products = [];
  String? _errorMessage;

  List<SalonService> get services => _services;
  List<SalonAppointment> get appointments => _appointments;
  List<Stylist> get stylists => _stylists;
  List<ProductItem> get products => _products;
  String? get errorMessage => _errorMessage;

  void setBusinessId(String businessId) {
    // If the business id hasn't changed, do nothing
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    // Load data for the newly selected business
    // Fire-and-forget; provider methods will set error messages and notify listeners
    loadServices();
    loadStylists();
    loadAppointments();
    loadProducts();
  }

  // ==================== SERVICES ====================

  Future<void> loadServices() async {
    if (!_ensureBusinessId()) return;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .get();
      _services = snapshot.docs
          .map((doc) => SalonService.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (_services.isEmpty) {
        final fallbackSnapshot = await _firestore
            .collection('salon_services')
            .where('businessId', isEqualTo: _businessId)
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          _services = fallbackSnapshot.docs
              .map(
                  (doc) => SalonService.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        }
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addService(SalonService service) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .doc(service.id)
          .set(service.toJson());
      // Refresh from backend to ensure state matches server (avoids transient UI disappearance)
      await loadServices();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateService(SalonService service) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .doc(service.id)
          .update(service.toJson());
      final index = _services.indexWhere((s) => s.id == service.id);
      if (index >= 0) _services[index] = service;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .doc(serviceId)
          .delete();
      _services.removeWhere((s) => s.id == serviceId);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== APPOINTMENTS ====================

  Future<void> loadAppointments() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .orderBy('appointmentTime', descending: true)
          .get();
      _appointments = snapshot.docs
          .map((doc) => SalonAppointment.fromJson(doc.data()))
          .toList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> createAppointment(SalonAppointment appointment) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointment.id)
          .set(appointment.toJson());
      _appointments.insert(0, appointment);
      // Schedule a fuller reminder set for operational follow-up.
      try {
        await _scheduleAppointmentReminders(appointment);
      } catch (_) {}
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _scheduleAppointmentReminders(
      SalonAppointment appointment) async {
    if (_businessId == null) return;
    await BusinessReminderService.instance.scheduleSalonBookingReminders(
      businessId: _businessId!,
      appointmentId: appointment.id,
      clientName: appointment.clientName,
      serviceName: appointment.serviceName,
      stylistName: appointment.stylistName,
      appointmentTime: appointment.appointmentTime,
    );
  }

  /// Build per-customer messages for pending bookings that can be sent via
  /// WhatsApp Cloud API (requires whatsapp credentials on the business doc).
  List<Map<String, String>> buildPendingBookingMessages() {
    final now = DateTime.now();
    final targets = <Map<String, String>>[];
    for (final a in _appointments) {
      if ((a.status == 'pending' || a.status == 'confirmed') &&
          a.appointmentTime.isAfter(now)) {
        final when = a.appointmentTime.toLocal().toString().split('.').first;
        final msg =
            'Hello ${a.clientName}, this is a reminder of your upcoming appointment for ${a.serviceName} on $when at our salon. Reply to confirm or contact us to reschedule.';
        if (a.clientPhone.trim().isNotEmpty) {
          targets.add({'phone': a.clientPhone.trim(), 'message': msg});
        }
      }
    }
    return targets;
  }

  Future<bool> sendWhatsAppToPendingBookings() async {
    if (_businessId == null) return false;
    final targets = buildPendingBookingMessages();
    final phones = targets.map((t) => t['phone']!).toList();
    if (phones.isEmpty) return false;
    // Send an identical message to all recipients; for per-recipient text use loop
    final uniquePhones = phones.toSet().toList();
    final sample = targets
            .firstWhere((t) => t['phone'] == uniquePhones.first)['message'] ??
        '';
    final svc = WhatsAppService();
    return await svc.sendTextToNumbers(
        businessId: _businessId!, toNumbers: uniquePhones, message: sample);
  }

  /// Builds a readable daily completed bookings report for [date] (defaults to today).
  String buildDailyCompletedBookingsReport({DateTime? date}) {
    final d = date ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    final end = start.add(Duration(days: 1));
    final completed = _appointments
        .where((a) =>
            a.status == 'completed' &&
            a.appointmentTime.isAfter(start) &&
            a.appointmentTime.isBefore(end))
        .toList();
    final lines = <String>[];
    for (var i = 0; i < completed.length; i) {
      final a = completed[i];
      final when = a.appointmentTime.toLocal().toString().split('.').first;
      lines.add(
          '${i + 1}. ${a.clientName} - ${a.serviceName} - ${a.stylistName} - $when - NGN ${(a.amountPaid ?? 0).toString()}');
    }
    final header =
        'Completed bookings for ${start.toLocal().toIso8601String().split('T').first}: ${completed.length}';
    return [header, ...lines].join('\n');
  }

  Future<bool> sendDailyCompletedBookingsReportViaWhatsApp(
      {required String businessOwnerNumber, DateTime? date}) async {
    if (_businessId == null) return false;
    final report = buildDailyCompletedBookingsReport(date: date);
    final svc = WhatsAppService();
    return await svc.sendTextToNumbers(
        businessId: _businessId!,
        toNumbers: [businessOwnerNumber],
        message: report);
  }

  /// Send the daily completed bookings report to configured business owner(s).
  Future<bool> sendDailyCompletedBookingsReportToOwners(
      {DateTime? date}) async {
    if (_businessId == null) return false;
    final report = buildDailyCompletedBookingsReport(date: date);
    final svc = WhatsAppService();
    return await svc.sendTextToOwners(
        businessId: _businessId!, message: report);
  }

  Future<void> updateAppointmentStatus(
      String appointmentId, String newStatus) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': newStatus});
      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index >= 0)
        _appointments[index] = _appointments[index].copyWith(status: newStatus);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> completeAppointment(String appointmentId, double amountPaid,
      String paymentMethod, double? tipAmount) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'completed',
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'tipAmount': tipAmount
      });
      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index >= 0)
        _appointments[index] = _appointments[index].copyWith(
            status: 'completed',
            amountPaid: amountPaid,
            paymentMethod: paymentMethod,
            tipAmount: tipAmount);
      // Also create a sales record for reporting and commission calculations
      try {
        final appt = _appointments.firstWhere((a) => a.id == appointmentId);
        final saleId = appointmentId + '-sale';
        final data = {
          'id': saleId,
          'saleId': saleId,
          'businessId': _businessId,
          'appointmentId': appointmentId,
          'clientName': appt.clientName,
          'services': [
            {
              'serviceId': appt.serviceId,
              'serviceName': appt.serviceName,
              'price': appt.servicePrice,
            }
          ],
          'subtotal': appt.servicePrice,
          'tax': 0.0,
          'total': amountPaid,
          'totalAmount': amountPaid,
          'finalAmount': amountPaid,
          'status': 'completed',
          'payments': null,
          'paymentMethod': paymentMethod,
          'paymentBreakdown': [
            {
              'method': paymentMethod,
              'amount': amountPaid,
            }
          ],
          'stylistId': appt.stylistId,
          'stylistName': appt.stylistName,
          'category': 'Salon',
          'saleDate': DateTime.now(),
        };

        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .doc(saleId)
            .set({...data, 'createdAt': FieldValue.serverTimestamp()});

        // Best-effort top-level mirror
        try {
          await _firestore
              .collection('sales')
              .doc(saleId)
              .set({...data, 'businessId': _businessId});
        } catch (_) {}
      } catch (_) {}
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== STYLISTS ====================

  Future<void> loadStylists() async {
    if (!_ensureBusinessId()) return;

    try {
      // Load explicit stylist documents in business collection first
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stylists')
          .where('isActive', isEqualTo: true)
          .get();

      final map = <String, Stylist>{};
      for (final doc in snapshot.docs) {
        final s = Stylist.fromJson(doc.data());
        map[s.id] = s;
      }

      // Also include workers who have 'stylist' as a role in top-level workers collection
      try {
        final workersSnap = await _firestore
            .collection('workers')
            .where('businessId', isEqualTo: _businessId)
            .where('isActive', isEqualTo: true)
            .get();

        for (final w in workersSnap.docs) {
          final data = w.data();
          final id = data['id'] ?? w.id;
          if (map.containsKey(id)) continue; // prefer explicit stylist document

          // Handle both 'roles' (array) and 'role' (string) fields robustly
          final rolesRaw = data['roles'];
          final List<String> roles = rolesRaw is List
              ? List<String>.from(
                  rolesRaw.map((r) => r.toString().toLowerCase()))
              : (data['role'] != null
                  ? [data['role'].toString().toLowerCase()]
                  : []);

          final isStylist = roles
              .any((r) => ['stylist', 'hairstylist', 'barber'].contains(r));
          if (!isStylist) continue;

          final stylist = Stylist(
            id: id,
            name: data['fullName'] ?? data['name'] ?? '',
            email: data['email'] ?? '',
            phone: data['phoneNumber'] ?? data['phone'],
            specialization: data['specialization'] ?? 'stylist',
            serviceIds: List<String>.from(data['serviceIds'] ?? []),
            commissionPercentage:
                (data['commissionPercentage'] ?? 0).toDouble(),
            rating: (data['rating'] ?? 0).toDouble(),
            isActive: data['isActive'] ?? true,
            createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                DateTime.now(),
          );

          map[id] = stylist;
        }
      } catch (e) {
        debugPrint('[SalonProvider] Failed to merge workers as stylists: $e');
      }

      _stylists = map.values.toList();

      if (_stylists.isEmpty) {
        final fallbackSnapshot = await _firestore
            .collection('salon_staff')
            .where('businessId', isEqualTo: _businessId)
            .where('role', isEqualTo: 'stylist')
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          _stylists = fallbackSnapshot.docs.map((doc) {
            final data = doc.data();
            return Stylist(
              id: doc.id,
              name: data['fullName'] ?? data['name'] ?? '',
              email: data['email'] ?? '',
              phone: data['phoneNumber'] ?? data['phone'],
              specialization: data['specialization'] ?? 'stylist',
              serviceIds: List<String>.from(data['serviceIds'] ?? []),
              commissionPercentage:
                  (data['commissionPercentage'] ?? 0).toDouble(),
              rating: (data['rating'] ?? 0).toDouble(),
              isActive: data['isActive'] ?? true,
              createdAt:
                  DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
            );
          }).toList();
        }
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addStylist(Stylist stylist) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stylists')
          .doc(stylist.id)
          .set(stylist.toJson());
      _stylists.add(stylist);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateStylist(Stylist stylist) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stylists')
          .doc(stylist.id)
          .update(stylist.toJson());
      final index = _stylists.indexWhere((s) => s.id == stylist.id);
      if (index != -1) {
        _stylists[index] = stylist;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .get();
      _products = snapshot.docs
          .map((d) => ProductItem.fromJson({'id': d.id, ...d.data()}))
          .toList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addProduct(ProductItem product) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(product.id)
          .set(product.toJson());
      _products.add(product);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateProduct(ProductItem product) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(product.id)
          .update(product.toJson());
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx >= 0) _products[idx] = product;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId)
          .delete();
      _products.removeWhere((p) => p.id == productId);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== INVENTORY / PRODUCTS ====================

  Future<void> adjustProductQuantity(String productId, int delta) async {
    try {
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx == -1) throw Exception('Product not found');
      final p = _products[idx];
      p.quantity += delta;
      if (p.quantity < 0) p.quantity = 0;
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId)
          .update({'quantity': p.quantity});
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Testing helper: replace products directly (visible for tests)
  @visibleForTesting
  void setProductsForTesting(List<ProductItem> products) {
    _products = products;
    notifyListeners();
  }

  @visibleForTesting
  void setStylistsForTesting(List<Stylist> stylists) {
    _stylists = stylists;
    notifyListeners();
  }

  @visibleForTesting
  void setAppointmentsForTesting(List<SalonAppointment> appointments) {
    _appointments = appointments;
    notifyListeners();
  }

  /// Adjusts product quantity locally (no network). Visible for tests.
  @visibleForTesting
  void adjustProductQuantityLocal(String productId, int delta) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) throw Exception('Product not found');
    final p = _products[idx];
    p.quantity += delta;
    if (p.quantity < 0) p.quantity = 0;
    notifyListeners();
  }

  // ==================== UTILITIES ====================

  List<SalonAppointment> getUpcomingAppointments() => _appointments
      .where((a) =>
          a.status != 'cancelled' && a.appointmentTime.isAfter(DateTime.now()))
      .toList();

  List<SalonAppointment> getTodayAppointments() {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.appointmentTime.day == now.day &&
            a.appointmentTime.month == now.month &&
            a.appointmentTime.year == now.year &&
            a.status != 'cancelled')
        .toList();
  }

  double getTodayRevenue() {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.appointmentTime.day == now.day &&
            a.appointmentTime.month == now.month &&
            a.appointmentTime.year == now.year &&
            a.status == 'completed')
        .fold(0, (sum, a) => sum + (a.amountPaid ?? 0));
  }

  double getMonthlyRevenue() {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.appointmentTime.month == now.month &&
            a.appointmentTime.year == now.year &&
            a.status == 'completed')
        .fold(0, (sum, a) => sum + (a.amountPaid ?? 0));
  }

  int getTotalAppointments() => _appointments.length;

  int getCompletedAppointments() =>
      _appointments.where((a) => a.status == 'completed').length;

  double getAverageServicePrice() {
    if (_services.isEmpty) return 0;
    return _services.fold(0.0, (sum, s) => sum + s.price) / _services.length;
  }

  double getTotalTips() => _appointments
      .where((a) => a.status == 'completed')
      .fold(0, (sum, a) => sum + (a.tipAmount ?? 0));

  /// Calculate total commission owed to a stylist based on completed appointments
  double getStylistCommissionTotal(String stylistId) {
    final stylist = _stylists.firstWhere((s) => s.id == stylistId,
        orElse: () => Stylist(
              id: stylistId,
              name: 'Unknown',
              email: '',
              phone: null,
              specialization: 'stylist',
              serviceIds: [],
              commissionPercentage: 0.0,
              isActive: false,
              createdAt: DateTime.now(),
            ));

    final completed = _appointments
        .where((a) => a.stylistId == stylistId && a.status == 'completed');

    return SalonProvider.computeStylistCommission(stylist, completed);
  }

  double getStylistCommissionTotalForPeriod(
      String stylistId, DateTime start, DateTime end) {
    final stylist = _stylists.firstWhere((s) => s.id == stylistId,
        orElse: () => Stylist(
              id: stylistId,
              name: 'Unknown',
              email: '',
              phone: null,
              specialization: 'stylist',
              serviceIds: [],
              commissionPercentage: 0.0,
              isActive: false,
              createdAt: DateTime.now(),
            ));

    final completed = _appointments.where((a) =>
        a.stylistId == stylistId &&
        a.status == 'completed' &&
        !a.appointmentTime.isBefore(start) &&
        !a.appointmentTime.isAfter(end));

    return SalonProvider.computeStylistCommission(stylist, completed);
  }

  Map<String, double> getCommissionsByStylistForPeriod(
      DateTime start, DateTime end) {
    final Map<String, double> result = {};
    for (final s in _stylists) {
      result[s.id] = getStylistCommissionTotalForPeriod(s.id, start, end);
    }
    return result;
  }

  List<SalonAppointment> getAppointmentsForStylistInPeriod(
      String stylistId, DateTime start, DateTime end) {
    return _appointments
        .where((a) =>
            a.stylistId == stylistId &&
            !a.appointmentTime.isBefore(start) &&
            !a.appointmentTime.isAfter(end))
        .toList();
  }

  /// Pure helper useful for unit tests: computes commission owed based on stylist commission percentage and completed appointments
  static double computeStylistCommission(
      Stylist stylist, Iterable<SalonAppointment> appointments) {
    final pct = stylist.commissionPercentage ?? 0.0;
    return appointments.fold(
        0.0, (sum, a) => sum + (a.servicePrice) * (pct / 100.0));
  }

  /// Reset all provider state - called during logout to clear business data
  void reset() {
    _services.clear();
    _appointments.clear();
    _stylists.clear();
    _products.clear();
    _errorMessage = null;
    print('[SalonProvider] State cleared for next business');
    notifyListeners();
  }
}

extension StylistCopyWith on Stylist {
  Stylist copyWith({
    String? name,
    String? email,
    String? phone,
    String? specialization,
    List<String>? serviceIds,
    double? commissionPercentage,
    double? rating,
    bool? isActive,
  }) =>
      Stylist(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        specialization: specialization ?? this.specialization,
        serviceIds: serviceIds ?? this.serviceIds,
        commissionPercentage: commissionPercentage ?? this.commissionPercentage,
        rating: rating ?? this.rating,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

/// Get today's sales total from Firestore sales collection
extension SalonProviderSales on SalonProvider {
  Future<double> getTodaysSalesTotal() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      try {
        final snapshot = await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .where('createdAt', isLessThanOrEqualTo: endOfDay)
            .where('status', isEqualTo: 'completed')
            .get();

        double totalSales = 0.0;
        for (final doc in snapshot.docs) {
          final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
          totalSales += amount;
        }

        debugPrint('[SalonProvider] Today\'s sales total: NGN $totalSales');
        return totalSales;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('requires an index') ||
            msg.contains('FAILED_PRECONDITION')) {
          try {
            debugPrint(
                '[SalonProvider] Composite index required; falling back to date-only query for today\'s sales');
            final fallback = await _firestore
                .collection('businesses')
                .doc(_businessId)
                .collection('sales')
                .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
                .where('createdAt', isLessThanOrEqualTo: endOfDay)
                .get();

            double totalSales = 0.0;
            for (final doc in fallback.docs) {
              if ((doc['status'] as String?)?.toLowerCase() != 'completed')
                continue;
              final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
              totalSales += amount;
            }

            debugPrint(
                '[SalonProvider] Today\'s sales total (fallback): NGN $totalSales');
            return totalSales;
          } catch (e2) {
            debugPrint('[SalonProvider] Fallback date-only query failed: $e2');
            return 0.0;
          }
        }

        debugPrint('[SalonProvider] Error fetching today\'s sales: $e');
        return 0.0;
      }
    } catch (e) {
      debugPrint('[SalonProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}
