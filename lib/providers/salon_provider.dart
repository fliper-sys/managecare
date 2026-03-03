import 'package:flutter/foundation.dart';

class Appointment {
  final String id;
  final String serviceId;
  final String staffId;
  final String customerId;
  DateTime start;
  DateTime end;
  String status; // scheduled, checked-in, completed, cancelled
  double price;
  String notes;

  Appointment({
    required this.id,
    required this.serviceId,
    required this.staffId,
    required this.customerId,
    required this.start,
    required this.end,
    this.status = 'scheduled',
    required this.price,
    this.notes = '',
  });
}

class StaffMember {
  final String id;
  final String name;
  final String role;
  double commissionRate; // percent (e.g., 10.0)
  double rating;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.commissionRate = 0.0,
    this.rating = 0.0,
  });
}

class ServiceItem {
  final String id;
  final String name;
  final Duration duration;
  final double price;
  final String description;

  ServiceItem({
    required this.id,
    required this.name,
    required this.duration,
    required this.price,
    this.description = '',
  });
}

class ProductItem {
  final String id;
  final String name;
  int quantity;
  final double price;

  ProductItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  int loyaltyPoints;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.loyaltyPoints = 0,
  });
}

class Review {
  final String id;
  final String customerId;
  final String staffId;
  final int rating; // 1-5
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.customerId,
    required this.staffId,
    required this.rating,
    this.comment = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SalonProvider extends ChangeNotifier {
  String? _businessId;
  // In-memory stores (sample data)
  final List<StaffMember> staff = [];
  final List<ServiceItem> services = [];
  final List<ProductItem> products = [];
  final List<Customer> customers = [];
  final List<Appointment> appointments = [];
  final List<Review> reviews = [];

  SalonProvider() {
    _initSampleData();
  }

  /// Set business id for salon provider (no-op for sample-only provider)
  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    notifyListeners();
  }

  void _initSampleData() {
    staff.addAll([
      StaffMember(
          id: 's1',
          name: 'Alice',
          role: 'Stylist',
          commissionRate: 12.0,
          rating: 4.6),
      StaffMember(
          id: 's2',
          name: 'Ben',
          role: 'Barber',
          commissionRate: 10.0,
          rating: 4.4),
      StaffMember(
          id: 's3',
          name: 'Clara',
          role: 'Therapist',
          commissionRate: 15.0,
          rating: 4.8),
    ]);

    services.addAll([
      ServiceItem(
          id: 'svc1',
          name: 'Haircut',
          duration: const Duration(minutes: 45),
          price: 25.0),
      ServiceItem(
          id: 'svc2',
          name: 'Beard Trim',
          duration: const Duration(minutes: 20),
          price: 12.0),
      ServiceItem(
          id: 'svc3',
          name: 'Massage',
          duration: const Duration(minutes: 60),
          price: 60.0),
    ]);

    products.addAll([
      ProductItem(id: 'p1', name: 'Shampoo', quantity: 20, price: 8.0),
      ProductItem(id: 'p2', name: 'Conditioner', quantity: 12, price: 9.0),
    ]);

    customers.addAll([
      Customer(
          id: 'c1',
          name: 'John Doe',
          email: 'john@example.com',
          phone: '555-0101',
          loyaltyPoints: 120),
      Customer(
          id: 'c2',
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '555-0202',
          loyaltyPoints: 50),
    ]);

    // sample appointments
    appointments.addAll([
      Appointment(
        id: 'a1',
        serviceId: 'svc1',
        staffId: 's1',
        customerId: 'c1',
        start: DateTime.now().add(const Duration(hours: 2)),
        end: DateTime.now().add(const Duration(hours: 3, minutes: 0)),
        price: 25.0,
      ),
      Appointment(
        id: 'a2',
        serviceId: 'svc3',
        staffId: 's3',
        customerId: 'c2',
        start: DateTime.now().add(const Duration(days: 1, hours: 1)),
        end: DateTime.now().add(const Duration(days: 1, hours: 2)),
        price: 60.0,
      ),
    ]);

    reviews.addAll([
      Review(
          id: 'r1',
          customerId: 'c1',
          staffId: 's1',
          rating: 5,
          comment: 'Great haircut!'),
      Review(
          id: 'r2',
          customerId: 'c2',
          staffId: 's3',
          rating: 4,
          comment: 'Relaxing massage.'),
    ]);
  }

  // Appointments
  List<Appointment> getAppointmentsForDay(DateTime day) {
    return appointments
        .where((a) =>
            a.start.year == day.year &&
            a.start.month == day.month &&
            a.start.day == day.day)
        .toList();
  }

  List<Appointment> getUpcomingAppointments([int limit = 5]) {
    final upcoming =
        appointments.where((a) => a.start.isAfter(DateTime.now())).toList();
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    return upcoming.take(limit).toList();
  }

  void createAppointment(Appointment appt) {
    appointments.add(appt);
    notifyListeners();
  }

  void updateAppointmentStatus(String appointmentId, String status) {
    final appt = appointments.firstWhere((a) => a.id == appointmentId,
        orElse: () => throw Exception('Appointment not found'));
    appt.status = status;
    notifyListeners();
  }

  void cancelAppointment(String appointmentId) {
    updateAppointmentStatus(appointmentId, 'cancelled');
  }

  // Staff
  void addStaff(StaffMember s) {
    staff.add(s);
    notifyListeners();
  }

  void updateCommission(String staffId, double newRate) {
    final s = staff.firstWhere((x) => x.id == staffId);
    s.commissionRate = newRate;
    notifyListeners();
  }

  double getStaffCommissionTotal(String staffId) {
    // sum commission from completed appointments
    final s = staff.firstWhere((x) => x.id == staffId);
    final completed = appointments
        .where((a) => a.staffId == staffId && a.status == 'completed');
    double total = 0.0;
    for (final a in completed) {
      total += a.price * (s.commissionRate / 100.0);
    }
    return total;
  }

  // Services & Products
  void addService(ServiceItem svc) {
    services.add(svc);
    notifyListeners();
  }

  void addProduct(ProductItem p) {
    products.add(p);
    notifyListeners();
  }

  // Customers & Loyalty
  void addCustomer(Customer c) {
    customers.add(c);
    notifyListeners();
  }

  void awardLoyaltyPoints(String customerId, int points) {
    final c = customers.firstWhere((x) => x.id == customerId);
    c.loyaltyPoints += points;
    notifyListeners();
  }

  // Reviews & Ratings
  void addReview(Review r) {
    reviews.add(r);
    // update staff rating simple average
    final staffReviews = reviews
        .where((rv) => rv.staffId == r.staffId)
        .map((e) => e.rating)
        .toList();
    final avg =
        staffReviews.fold<int>(0, (p, e) => p + e) / staffReviews.length;
    final s = staff.firstWhere((x) => x.id == r.staffId);
    s.rating = double.parse(avg.toStringAsFixed(1));
    notifyListeners();
  }

  double getAverageRating() {
    if (reviews.isEmpty) return 0.0;
    final sum = reviews.fold<int>(0, (p, e) => p + e.rating);
    return sum / reviews.length;
  }

  // Inventory
  void adjustProductQuantity(String productId, int delta) {
    final p = products.firstWhere((x) => x.id == productId);
    p.quantity += delta;
    if (p.quantity < 0) p.quantity = 0;
    notifyListeners();
  }
}

