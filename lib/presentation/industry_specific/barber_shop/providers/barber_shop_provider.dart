import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/services/business_reminder_service.dart';
import 'package:business_manager/services/whatsapp_service.dart';
import 'dart:convert';
import '../../../../data/local/database_helper.dart';

// ==================== MODELS ====================

class BarberShopService {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String category; // haircut, beard, shaving, coloring, styling
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  BarberShopService({
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

  BarberShopService.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        description = json['description'] ?? '',
        price = (json['price'] ?? 0).toDouble(),
        durationMinutes = json['durationMinutes'] ?? 30,
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

  BarberShopService copyWith({
    String? name,
    String? description,
    double? price,
    int? durationMinutes,
    String? category,
    String? imageUrl,
    bool? isActive,
  }) =>
      BarberShopService(
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

class BarberShopAppointment {
  final String id;
  final String clientName;
  final String clientPhone;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final String barberId;
  final String barberName;
  final DateTime appointmentTime;
  final int durationMinutes;
  final String status; // pending, confirmed, completed, cancelled
  final String? notes;
  final double? amountPaid;
  final String? paymentMethod;
  final DateTime createdAt;

  BarberShopAppointment({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.barberId,
    required this.barberName,
    required this.appointmentTime,
    required this.durationMinutes,
    required this.status,
    this.notes,
    this.amountPaid,
    this.paymentMethod,
    required this.createdAt,
  });

  BarberShopAppointment.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        clientName = json['clientName'] ?? '',
        clientPhone = json['clientPhone'] ?? '',
        serviceId = json['serviceId'] ?? '',
        serviceName = json['serviceName'] ?? '',
        servicePrice = (json['servicePrice'] ?? 0).toDouble(),
        barberId = json['barberId'] ?? '',
        barberName = json['barberName'] ?? '',
        appointmentTime = parseTimestamp(json['appointmentTime']).toLocal(),
        durationMinutes = json['durationMinutes'] ?? 30,
        status = json['status'] ?? 'pending',
        notes = json['notes'],
        amountPaid = json['amountPaid']?.toDouble(),
        paymentMethod = json['paymentMethod'],
        createdAt = (json['createdAt'] == null)
            ? DateTime.now().toLocal()
            : parseTimestamp(json['createdAt']).toLocal();

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'servicePrice': servicePrice,
        'barberId': barberId,
        'barberName': barberName,
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        'durationMinutes': durationMinutes,
        'status': status,
        'notes': notes,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  BarberShopAppointment copyWith({
    String? status,
    double? amountPaid,
    String? paymentMethod,
  }) =>
      BarberShopAppointment(
        id: id,
        clientName: clientName,
        clientPhone: clientPhone,
        serviceId: serviceId,
        serviceName: serviceName,
        servicePrice: servicePrice,
        barberId: barberId,
        barberName: barberName,
        appointmentTime: appointmentTime,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        notes: notes,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        createdAt: createdAt,
      );
}

class Barber {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String specialization; // general, senior, master
  final List<String> serviceIds;
  final double? commissionPercentage;
  final bool isActive;
  final DateTime createdAt;

  Barber({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.specialization,
    required this.serviceIds,
    this.commissionPercentage,
    this.isActive = true,
    required this.createdAt,
  });

  Barber.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        email = json['email'] ?? '',
        phone = json['phone'],
        specialization = json['specialization'] ?? 'general',
        serviceIds = List<String>.from(json['serviceIds'] ?? []),
        commissionPercentage = (json['commissionPercentage'] ?? 0).toDouble(),
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
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class BarberShopSale {
  final String id;
  final String appointmentId;
  final String clientName;
  final List<Map<String, dynamic>> services;
  final double subtotal;
  final double tax;
  final double total;
  final List<Map<String, dynamic>>? payments;
  final String paymentMethod;
  final String barberId;
  final String barberName;
  final DateTime saleDate;

  BarberShopSale({
    required this.id,
    required this.appointmentId,
    required this.clientName,
    required this.services,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.payments,
    required this.paymentMethod,
    required this.barberId,
    required this.barberName,
    required this.saleDate,
  });

  BarberShopSale.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        appointmentId = json['appointmentId'] ?? '',
        clientName = json['clientName'] ?? '',
        services = List<Map<String, dynamic>>.from(json['services'] ?? []),
        subtotal = (json['subtotal'] ?? 0).toDouble(),
        tax = (json['tax'] ?? 0).toDouble(),
        total = (json['total'] ?? 0).toDouble(),
        payments = (json['payments'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        paymentMethod = json['paymentMethod'] ?? (json['payments'] != null && (json['payments'] as List).isNotEmpty ? (json['payments'][0]['method'] ?? 'cash') : 'cash'),
        barberId = json['barberId'] ?? '',
        barberName = json['barberName'] ?? '',
        saleDate = parseTimestamp(json['saleDate']).toLocal();

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointmentId': appointmentId,
        'clientName': clientName,
        'services': services,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'payments': payments,
        'paymentMethod': paymentMethod,
        'barberId': barberId,
        'barberName': barberName,
        'saleDate': Timestamp.fromDate(saleDate),
      };
}

// ==================== PROVIDER ====================

class BarberShopProvider extends ChangeNotifier {
  final FirebaseFirestore? _firestore;
  String? _businessId;

  BarberShopProvider({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;

  List<BarberShopService> _services = [];
  List<BarberShopAppointment> _appointments = [];
  List<Barber> _barbers = [];
  List<BarberShopSale> _sales = [];
  String? _errorMessage;

  // Getters
  List<BarberShopService> get services => _services;
  List<BarberShopAppointment> get appointments => _appointments;
  List<Barber> get barbers => _barbers;
  List<BarberShopSale> get sales => _sales;
  String? get errorMessage => _errorMessage;
  bool get hasBusinessContext => _businessId != null && _businessId!.isNotEmpty;

  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    // Load relevant data for this business context
    loadServices();
    loadBarbers();
    loadAppointments();
    loadSales();
    notifyListeners();
  }

  // ==================== SERVICES ====================

  Future<void> loadServices() async {
    if (!hasBusinessContext) {
      _services = [];
      notifyListeners();
      return;
    }
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .where('category', whereIn: [
        'haircut',
        'beard',
        'shaving',
        'coloring',
        'styling'
      ]).get();

      _services = snapshot.docs
          .map((doc) => BarberShopService.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addService(BarberShopService service) async {
    try {
      if (_businessId == null || _businessId!.isEmpty) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }

      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .doc(service.id)
          .set(service.toJson());

      // Refresh authoritative state from Firestore to avoid transient UI mismatches
      await loadServices();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateService(BarberShopService service) async {
    try {
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('services')
          .doc(service.id)
          .update(service.toJson());

      final index = _services.indexWhere((s) => s.id == service.id);
      if (index >= 0) {
        _services[index] = service;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      await _fs
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
    if (!hasBusinessContext) {
      _appointments = [];
      notifyListeners();
      return;
    }
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .orderBy('appointmentTime', descending: true)
          .get();

      _appointments = snapshot.docs
          .map((doc) => BarberShopAppointment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createAppointment(BarberShopAppointment appointment) async {
    if (_businessId == null || _businessId!.isEmpty) {
      _errorMessage = 'No business selected';
      notifyListeners();
      return false;
    }

    try {
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointment.id)
          .set(appointment.toJson());

      // Refresh authoritative list from server to avoid timezone/order mismatches
      await loadAppointments();

      // Schedule a fuller reminder set for operational follow-up.
      try {
        await _scheduleAppointmentReminders(appointment);
      } catch (_) {}
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _scheduleAppointmentReminders(BarberShopAppointment appointment) async {
    if (_businessId == null) return;
    await BusinessReminderService.instance.scheduleBarberBookingReminders(
      businessId: _businessId!,
      appointmentId: appointment.id,
      clientName: appointment.clientName,
      serviceName: appointment.serviceName,
      barberName: appointment.barberName,
      appointmentTime: appointment.appointmentTime,
    );
  }

  /// Build and return per-customer messages for pending barber bookings.
  List<Map<String, String>> buildPendingBookingMessages() {
    final now = DateTime.now();
    final targets = <Map<String, String>>[];
    for (final a in _appointments) {
      if ((a.status == 'pending' || a.status == 'confirmed') && a.appointmentTime.isAfter(now)) {
        final when = a.appointmentTime.toLocal().toString().split('.').first;
        final msg = 'Hello ${a.clientName}, reminder: your appointment for ${a.serviceName} with ${a.barberName} is on $when. Reply to confirm or contact us to reschedule.';
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
    final uniquePhones = phones.toSet().toList();
    final sample = targets.firstWhere((t) => t['phone'] == uniquePhones.first)['message'] ?? '';
    final svc = WhatsAppService();
    return await svc.sendTextToNumbers(businessId: _businessId!, toNumbers: uniquePhones, message: sample);
  }

  String buildDailyCompletedBookingsReport({DateTime? date}) {
    final d = date ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    final end = start.add(Duration(days: 1));
    final completed = _appointments.where((a) => a.status == 'completed' && a.appointmentTime.isAfter(start) && a.appointmentTime.isBefore(end)).toList();
    final lines = <String>[];
    for (var i = 0; i < completed.length; i++) {
      final a = completed[i];
      final when = a.appointmentTime.toLocal().toString().split('.').first;
      lines.add(
        '${i + 1}. ${a.clientName} - ${a.serviceName} - ${a.barberName} - $when - NGN ${(a.amountPaid ?? 0).toStringAsFixed(2)}',
      );
    }
    final header = 'Completed bookings for ${start.toLocal().toIso8601String().split('T').first}: ${completed.length}';
    return [header, ...lines].join('\n');
  }

  Future<bool> sendDailyCompletedBookingsReportViaWhatsApp({required String businessOwnerNumber, DateTime? date}) async {
    if (_businessId == null) return false;
    final report = buildDailyCompletedBookingsReport(date: date);
    final svc = WhatsAppService();
    return await svc.sendTextToNumbers(businessId: _businessId!, toNumbers: [businessOwnerNumber], message: report);
  }

  /// Send the daily completed bookings report to configured business owner(s).
  Future<bool> sendDailyCompletedBookingsReportToOwners({DateTime? date}) async {
    if (_businessId == null) return false;
    final report = buildDailyCompletedBookingsReport(date: date);
    final svc = WhatsAppService();
    return await svc.sendTextToOwners(businessId: _businessId!, message: report);
  }

  Future<void> updateAppointmentStatus(
      String appointmentId, String newStatus) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': newStatus});

      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index >= 0) {
        _appointments[index] = _appointments[index].copyWith(status: newStatus);
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> completeAppointment(
      String appointmentId, double amountPaid, String paymentMethod, {List<Map<String, dynamic>>? payments}) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'completed',
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
      });

      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index >= 0) {
        _appointments[index] = _appointments[index].copyWith(
          status: 'completed',
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
        );
      }
      // create a sale record for the completed appointment so payments and reports can use it
      try {
        final appt = _appointments.firstWhere((a) => a.id == appointmentId);
        final calculatedTotal = (payments != null && payments.isNotEmpty)
            ? payments.fold<double>(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0))
            : amountPaid;

        final sale = BarberShopSale(
          id: appointmentId + '-sale',
          appointmentId: appointmentId,
          clientName: appt.clientName,
          services: [
            {
              'serviceId': appt.serviceId,
              'serviceName': appt.serviceName,
              'price': appt.servicePrice,
            }
          ],
          subtotal: appt.servicePrice,
          tax: 0.0,
          total: calculatedTotal,
          payments: payments,
          paymentMethod: paymentMethod,
          barberId: appt.barberId,
          barberName: appt.barberName,
          saleDate: DateTime.now(),
        );

        await recordSale(sale);
      } catch (_) {
        // best-effort: don't fail the appointment completion if sale creation fails
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== BARBERS ====================

  Future<void> loadBarbers() async {
    if (!hasBusinessContext) {
      _barbers = [];
      notifyListeners();
      return;
    }
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('barbers')
          .where('isActive', isEqualTo: true)
          .get();

      // Start with explicit barber entries
      final map = <String, Barber>{};
      for (final doc in snapshot.docs) {
        final b = Barber.fromJson({...doc.data(), 'id': doc.id});
        map[b.id] = b;
      }

      // Also include workers who have 'barber' as a role (workers collection)
      try {
        final workersSnap = await _fs
          .collection('workers')
          .where('businessId', isEqualTo: _businessId)
          .where('isActive', isEqualTo: true)
          .get();

        for (final w in workersSnap.docs) {
          final data = w.data();
          final id = data['id'] ?? w.id;
          if (map.containsKey(id)) continue; // prefer explicit barber document

          // detect role flexibly: support 'roles' (list) and 'role' (string)
          final roles = <String>[];
          if (data['roles'] is List) roles.addAll(List<String>.from(data['roles']).map((r) => r.toString().toLowerCase()));
          if (data['role'] is String) roles.add((data['role'] as String).toLowerCase());
          if (!roles.any((r) => ['barber', 'hairstylist', 'stylist'].contains(r))) continue;

          final barber = Barber(
            id: id,
            name: data['fullName'] ?? data['name'] ?? '',
            email: data['email'] ?? '',
            phone: data['phoneNumber'] ?? data['phone'],
            specialization: (data['specialization'] ?? 'general'),
            serviceIds: List<String>.from(data['serviceIds'] ?? []),
            commissionPercentage: (data['commissionPercentage'] ?? 0).toDouble(),
            isActive: data['isActive'] ?? true,
            createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
          );
          map[id] = barber;
        }
      } catch (e) {
        // Log but don't fail the load
        print('[BarberShop] Failed to merge workers into barbers: $e');
      }

      _barbers = map.values.toList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addBarber(Barber barber) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('barbers')
          .doc(barber.id)
          .set(barber.toJson());

      // Refresh authoritative list to include any server-side transforms
      await loadBarbers();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateBarber(Barber barber) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('barbers')
          .doc(barber.id)
          .set(barber.toJson(), SetOptions(merge: true));

      final index = _barbers.indexWhere((b) => b.id == barber.id);
      if (index >= 0) {
        _barbers[index] = barber;
      } else {
        _barbers.add(barber);
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteBarber(String barberId) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('barbers')
          .doc(barberId)
          .set({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      _barbers.removeWhere((b) => b.id == barberId);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== SALES ====================

  Future<void> loadSales() async {
    if (!hasBusinessContext) {
      _sales = [];
      notifyListeners();
      return;
    }
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .orderBy('saleDate', descending: true)
          .get();

      _sales = snapshot.docs
          .map((doc) => BarberShopSale.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Merge local DB sales for offline records that may not be in Firestore yet
      try {
        DatabaseHelper? db;
        try {
          db = DatabaseHelper.instance;
        } catch (_) {
          db = null;
        }

        if (db != null) {
          final rows = await db.query('sales', where: 'businessId = ?', whereArgs: [_businessId], orderBy: 'createdAt DESC');
          for (final r in rows) {
            final id = r['id'] as String;
            if (_sales.any((s) => s.id == id)) continue;

            // build services from sale_items
            final items = await db.query('sale_items', where: 'saleId = ?', whereArgs: [id]);
            final services = items.map((it) => {
              'serviceId': it['productId'],
              'serviceName': it['productName'],
              'price': (it['unitPrice'] as num).toDouble()
            }).toList();

            final notesRaw = r['notes'] as String?;
            Map<String, dynamic> notes = {};
            try {
              if (notesRaw != null) notes = Map<String, dynamic>.from(jsonDecode(notesRaw));
            } catch (_) {}

            final payments = (notes['payments'] is List) ? List<Map<String, dynamic>>.from(notes['payments']) : null;
            final barberId = notes['barberId'] as String? ?? '';

            final sale = BarberShopSale(
              id: id,
              appointmentId: '',
              clientName: r['customerId'] ?? '',
              services: services,
              subtotal: (r['finalAmount'] as num?)?.toDouble() ?? (services.fold<double>(0.0, (s, e) => s + ((e['price'] ?? 0) as num).toDouble())),
              tax: (r['taxAmount'] as num?)?.toDouble() ?? 0.0,
              total: (r['finalAmount'] as num?)?.toDouble() ?? (r['totalAmount'] as num?)?.toDouble() ?? 0.0,
              payments: payments,
              paymentMethod: r['paymentMethod'] as String? ?? 'unknown',
              barberId: barberId,
              barberName: '',
              saleDate: DateTime.tryParse(r['createdAt'] as String? ?? '') ?? DateTime.now(),
            );

            _sales.insert(0, sale);
          }
        }
      } catch (_) {}

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> recordSale(BarberShopSale sale) async {
    try {
      if (!hasBusinessContext) {
        _errorMessage = 'No business selected';
        notifyListeners();
        return;
      }
      final data = {
        ...sale.toJson(),
        'businessId': _businessId,
        'status': 'completed',
        'customerName': sale.clientName,
        'category': 'Barber Shop',
        'industry': 'barber_shop',
        'totalAmount': sale.total,
        'finalAmount': sale.total,
        'createdAt': Timestamp.fromDate(sale.saleDate),
      };

      await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .doc(sale.id)
          .set(data);

      // Also write top-level mirror for easier lookup by id (best-effort)
      try {
        await _fs.collection('sales').doc(sale.id).set({...data, 'businessId': _businessId});
      } catch (_) {}

      _sales.insert(0, sale);

      // persist locally as synced record
      try {
        DatabaseHelper? db;
        try {
          db = DatabaseHelper.instance;
        } catch (_) {
          db = null;
        }

        if (db != null) {
          final local = {
            'id': sale.id,
            'businessId': _businessId,
            'customerId': null,
            'totalAmount': sale.total,
            'discountAmount': 0.0,
            'taxAmount': sale.tax,
            'finalAmount': sale.total,
            'paymentMethod': sale.paymentMethod,
            'status': 'completed',
            'notes': jsonEncode({'barberId': sale.barberId, 'payments': sale.payments}),
            'createdBy': '',
            'createdAt': sale.saleDate.toIso8601String(),
            'syncStatus': 'synced',
          };
          try {
            await db.insert('sales', local);
          } catch (_) {}

          // insert sale items for services
          for (final sv in sale.services) {
            final itemId = '${sale.id}-${sv['serviceId']}';
            final itemData = {
              'id': itemId,
              'saleId': sale.id,
              'productId': sv['serviceId'],
              'productName': sv['serviceName'],
              'quantity': 1,
              'unitPrice': sv['price'],
              'discount': 0.0,
              'total': sv['price'],
            };
            try {
              await db.insert('sale_items', itemData);
            } catch (_) {}
          }
        }
      } catch (_) {}

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      // On failure, write local pending record for later sync
      try {
        DatabaseHelper? db;
        try {
          db = DatabaseHelper.instance;
        } catch (_) {
          db = null;
        }

        if (db != null) {
          final local = {
            'id': sale.id,
            'businessId': _businessId,
            'customerId': null,
            'totalAmount': sale.total,
            'discountAmount': 0.0,
            'taxAmount': sale.tax,
            'finalAmount': sale.total,
            'paymentMethod': sale.paymentMethod,
            'status': 'completed',
            'notes': jsonEncode({'barberId': sale.barberId, 'payments': sale.payments}),
            'createdBy': '',
            'createdAt': sale.saleDate.toIso8601String(),
            'syncStatus': 'pending',
          };
          try {
            await db.insert('sales', local);
          } catch (_) {}

          for (final sv in sale.services) {
            final itemId = '${sale.id}-${sv['serviceId']}';
            final itemData = {
              'id': itemId,
              'saleId': sale.id,
              'productId': sv['serviceId'],
              'productName': sv['serviceName'],
              'quantity': 1,
              'unitPrice': sv['price'],
              'discount': 0.0,
              'total': sv['price'],
            };
            try {
              await db.insert('sale_items', itemData);
            } catch (_) {}
          }

          try {
            await db.addToSyncQueue(entityType: 'sale', entityId: sale.id, action: 'create', data: {...sale.toJson(), 'id': sale.id});
          } catch (_) {}
        }
      } catch (_) {}

      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Get sales by payment method within date range
  Future<List<BarberShopSale>> getSalesByPaymentMethod(String method, DateTime start, DateTime end) async {
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('paymentMethod', isEqualTo: method)
          .where('saleDate', isGreaterThanOrEqualTo: start)
          .where('saleDate', isLessThanOrEqualTo: end)
          .get();

      return snapshot.docs.map((d) => BarberShopSale.fromJson(d.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sales grouped by barber (simple list) for reporting
  Future<List<BarberShopSale>> getSalesByBarber(String barberId, DateTime start, DateTime end) async {
    try {
      final snapshot = await _fs
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('barberId', isEqualTo: barberId)
          .where('saleDate', isGreaterThanOrEqualTo: start)
          .where('saleDate', isLessThanOrEqualTo: end)
          .get();

      return snapshot.docs.map((d) => BarberShopSale.fromJson(d.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== UTILITIES ====================

  List<BarberShopAppointment> getUpcomingAppointments() {
    return _appointments
        .where((a) =>
            a.status != 'cancelled' &&
            a.appointmentTime.isAfter(DateTime.now()))
        .toList();
  }

  List<BarberShopAppointment> getTodayAppointments() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _appointments.where((a) {
      final t = a.appointmentTime.toLocal();
      final inRange = (t.isAtSameMomentAs(start) || (t.isAfter(start) && t.isBefore(end)));
      return inRange && a.status != 'cancelled';
    }).toList();
  }

  double getTodayRevenue() {
    return _sales.where((s) {
      final now = DateTime.now();
      return s.saleDate.day == now.day &&
          s.saleDate.month == now.month &&
          s.saleDate.year == now.year;
    }).fold(0, (sum, sale) => sum + sale.total);
  }

  double getMonthlyRevenue() {
    final now = DateTime.now();
    return _sales
        .where(
            (s) => s.saleDate.month == now.month && s.saleDate.year == now.year)
        .fold(0, (sum, sale) => sum + sale.total);
  }

  int getTotalAppointments() => _appointments.length;

  int getCompletedAppointments() =>
      _appointments.where((a) => a.status == 'completed').length;

  double getAverageServicePrice() {
    if (_services.isEmpty) return 0;
    return _services.fold(0.0, (sum, s) => sum + s.price) / _services.length;
  }

  /// Test helper to set appointments list directly (used by unit tests)
  @visibleForTesting
  void setAppointmentsForTesting(List<BarberShopAppointment> appts) {
    _appointments = appts;
    notifyListeners();
  }

  /// Commission helpers
  double getBarberCommissionTotal(String barberId) {
    try {
      final barber = _barbers.firstWhere((b) => b.id == barberId);
      final pct = barber.commissionPercentage ?? 0.0;
      if (pct <= 0.0) return 0.0;
      final total = _sales
          .where((s) => s.barberId == barberId)
          .fold(0.0, (sum, sale) {
            final saleBase = sale.payments != null && sale.payments!.isNotEmpty
                ? sale.payments!.fold<double>(
                    0.0,
                    (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0),
                  )
                : sale.total;
            return sum + (saleBase * (pct / 100.0));
          });
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  double getTotalCommissionOwed() {
    double total = 0.0;
    for (final b in _barbers) {
      total += getBarberCommissionTotal(b.id);
    }
    return total;
  }

  int getBarberCompletedAppointmentsCount(String barberId) {
    return _appointments
        .where((a) => a.barberId == barberId && a.status == 'completed')
        .length;
  }

  double getBarberRevenueTotal(String barberId) {
    return _sales
        .where((s) => s.barberId == barberId)
        .fold(0.0, (sum, sale) => sum + sale.total);
  }
}

extension BarberCopyWith on Barber {
  Barber copyWith({
    String? name,
    String? email,
    String? phone,
    String? specialization,
    List<String>? serviceIds,
    double? commissionPercentage,
    bool? isActive,
  }) =>
      Barber(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        specialization: specialization ?? this.specialization,
        serviceIds: serviceIds ?? this.serviceIds,
        commissionPercentage: commissionPercentage ?? this.commissionPercentage,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

/// Get today's sales total from Firestore sales collection
extension BarberShopProviderSales on BarberShopProvider {
  Future<double> getTodaysSalesTotal() async {
    try {
      if (_businessId == null || _businessId!.isEmpty) return 0.0;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      double sumSales(QuerySnapshot<Map<String, dynamic>> snapshot) {
        var totalSales = 0.0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if ((data['status'] as String?)?.toLowerCase() != 'completed') continue;
          final amount =
              (data['finalAmount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ??
              (data['total'] as num?)?.toDouble() ??
              0.0;
          totalSales += amount;
        }
        return totalSales;
      }

      try {
        final snapshot = await _fs
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .where('status', isEqualTo: 'completed')
            .get();

        final totalSales = sumSales(snapshot);
        debugPrint("[BarberShopProvider] Today's sales total: NGN $totalSales");
        return totalSales;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('requires an index') || msg.contains('FAILED_PRECONDITION')) {
          try {
            debugPrint("[BarberShopProvider] Composite index required; falling back to createdAt/date-only query for today's sales");
            final fallback = await _fs
                .collection('businesses')
                .doc(_businessId)
                .collection('sales')
                .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                .get();

            final totalSales = sumSales(fallback);
            debugPrint("[BarberShopProvider] Today's sales total (fallback): NGN $totalSales");
            return totalSales;
          } catch (e2) {
            debugPrint("[BarberShopProvider] Fallback date-only query failed: $e2");
            return 0.0;
          }
        }

        debugPrint("[BarberShopProvider] Error fetching today's sales: $e");
        return 0.0;
      }
    } catch (e) {
      debugPrint("[BarberShopProvider] Error fetching today's sales: $e");
      return 0.0;
    }
  }
}


