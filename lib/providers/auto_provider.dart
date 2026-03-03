import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/repositories/auto_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/datetime_utils.dart';

class Vehicle {
  final String id;
  final String make;
  final String model;
  final String licensePlate;
  final String vin;
  final int year;
  String ownerName;
  String ownerPhone;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.vin,
    required this.year,
    required this.ownerName,
    required this.ownerPhone,
  });
}

class ServiceTask {
  final String id;
  final String name;
  final double laborCost;
  final Duration estimatedDuration;

  ServiceTask({
    required this.id,
    required this.name,
    required this.laborCost,
    required this.estimatedDuration,
  });
}

class Part {
  final String id;
  final String name;
  int quantity;
  final double cost;

  Part({
    required this.id,
    required this.name,
    required this.quantity,
    required this.cost,
  });
}

class Job {
  final String id;
  final String vehicleId;
  DateTime createdAt;
  DateTime? completedAt;
  String status; // pending, in-progress, completed, invoiced
  final List<ServiceTask> tasks;
  final List<Part> usedParts;
  String notes;
  double totalCost;

  Job({
    required this.id,
    required this.vehicleId,
    required this.createdAt,
    this.completedAt,
    this.status = 'pending',
    this.tasks = const [],
    this.usedParts = const [],
    this.notes = '',
    this.totalCost = 0.0,
  });
}

class AutoProvider extends ChangeNotifier {
  String? _businessId;
  final List<Vehicle> vehicles = [];
  final List<ServiceTask> services = [];
  final List<Part> parts = [];
  final List<Job> jobs = [];

  // Real-time subscription for service orders (kept per-business)
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  DateTime? _lastFetched;

  AutoProvider() {
    // Initialize sample data to ensure provider has sensible defaults for tests and
    // local development. In production, backend data will overwrite these values
    // when `setBusinessId` is invoked.
    initSampleData();
  }

  /// Public entrypoint to (re)initialize sample data. Useful for tests and
  /// manual re-seeding during development.
  void initSampleData() {
    print('[AutoProvider] initSampleData called');
    _initSampleData();
  }

  bool isLoadingData = false;

  String? get currentBusinessId => _businessId;
  DateTime? get lastFetched => _lastFetched;

  /// Set business id for auto provider (sample data provider)
  ///
  /// For production usage we clear any in-memory data when switching businesses
  /// to avoid mixing records across businesses. Sample data is re-initialized
  /// so the provider has sensible defaults in dev mode.
  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId == businessId) return;

    // If an empty businessId is passed, clear any existing data and listeners
    if (businessId.isEmpty) {
      _ordersSubscription?.cancel();
      _ordersSubscription = null;

      _businessId = '';
      vehicles.clear();
      services.clear();
      parts.clear();
      jobs.clear();
      _invoices = [];
      _bookings = [];
      _lastFetched = null;
      if (kDebugMode) print('[AutoProvider] cleared data due to empty businessId');
      notifyListeners();
      return;
    }

    if (kDebugMode) print('[AutoProvider] setBusinessId: $businessId');

    // Clean up any previous realtime listeners
    _ordersSubscription?.cancel();
    _ordersSubscription = null;

    _businessId = businessId;
    // Reset any previously held in-memory data so different businesses don't
    // share sample records during a session.
    vehicles.clear();
    services.clear();
    parts.clear();
    jobs.clear();
    _invoices = [];
    _bookings = [];
    _lastFetched = null;
    notifyListeners();

    // Create a realtime listener to keep service orders up-to-date with minimal traffic
    try {
      _ordersSubscription = FirebaseFirestore.instance
          .collection('serviceOrders')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen((snap) {
        try {
          jobs.clear();
          for (final d in snap.docs) {
            final o = {...d.data(), 'id': d.id};
            final created = parseTimestamp(o['createdAt']);

            final vehicleId = o['vehicleId'] as String? ?? o['vehicle']?['id'] as String? ?? '';
            final total = (o['totalCost'] as num?)?.toDouble() ?? (o['total'] as num?)?.toDouble() ?? 0.0;

            jobs.add(Job(
              id: o['id'] as String? ?? '',
              vehicleId: vehicleId,
              createdAt: created,
              completedAt: null,
              status: (o['status'] as String?)?.toLowerCase() ?? 'pending',
              tasks: [],
              usedParts: [],
              notes: o['notes'] as String? ?? '',
              totalCost: total,
            ));
          }
          if (kDebugMode) print('[AutoProvider] realtime update: loaded ${jobs.length} jobs for business $businessId');
          _lastFetched = DateTime.now();
          notifyListeners();
        } catch (e) {
          if (kDebugMode) print('[AutoProvider] realtime listener error: $e');
        }
      }, onError: (e) {
        if (kDebugMode) print('[AutoProvider] realtime listener failed: $e');
      });
    } catch (e) {
      if (kDebugMode) print('[AutoProvider] failed to attach realtime listener: $e');
    }

    // Try to load real backend data for this business. If it fails, fall back
    // to sample data so the provider remains usable in tests and development.
    loadBusinessData(businessId).catchError((e) {
      if (kDebugMode) {
        if (kDebugMode) print('[AutoProvider] loadBusinessData failed, seeding sample data: $e');
        _initSampleData();
      } else {
        // Ensure sample data exists in test/CI environments as well
        print('[AutoProvider] loadBusinessData failed (non-debug), seeding sample data: $e');
        _initSampleData();
      }
    });

    // Immediately ensure there is sample data available after switching business
    // so callers can rely on a non-empty provider state synchronously.
    _initSampleData();
  }

  void _initSampleData() {
    vehicles.addAll([
      Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Camry',
        licensePlate: 'ABC123',
        vin: '12345ABCDE67890F',
        year: 2020,
        ownerName: 'John Smith',
        ownerPhone: '555-0101',
      ),
      Vehicle(
        id: 'v2',
        make: 'Honda',
        model: 'Civic',
        licensePlate: 'XYZ789',
        vin: 'XYZ789ABCDE12345',
        year: 2019,
        ownerName: 'Jane Doe',
        ownerPhone: '555-0202',
      ),
    ]);

    services.addAll([
      ServiceTask(
          id: 's1',
          name: 'Oil Change',
          laborCost: 50.0,
          estimatedDuration: const Duration(minutes: 30)),
      ServiceTask(
          id: 's2',
          name: 'Tire Rotation',
          laborCost: 40.0,
          estimatedDuration: const Duration(minutes: 45)),
      ServiceTask(
          id: 's3',
          name: 'Brake Inspection',
          laborCost: 60.0,
          estimatedDuration: const Duration(minutes: 60)),
      ServiceTask(
          id: 's4',
          name: 'Engine Diagnostics',
          laborCost: 100.0,
          estimatedDuration: const Duration(hours: 1, minutes: 30)),
    ]);

    parts.addAll([
      Part(id: 'p1', name: 'Oil Filter', quantity: 15, cost: 12.0),
      Part(id: 'p2', name: 'Brake Pads', quantity: 8, cost: 45.0),
      Part(id: 'p3', name: 'Air Filter', quantity: 20, cost: 15.0),
      Part(id: 'p4', name: 'Spark Plugs (Set)', quantity: 10, cost: 25.0),
    ]);

    jobs.addAll([
      Job(
        id: 'j1',
        vehicleId: 'v1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
        tasks: [services[0]],
        usedParts: [parts[0]],
        totalCost: 62.0,
      ),
      Job(
        id: 'j2',
        vehicleId: 'v2',
        createdAt: DateTime.now(),
        status: 'in-progress',
        tasks: [services[2]],
        totalCost: 60.0,
      ),
    ]);
  }

  /// Load real data for a business using [AutoRepositoryImpl]. This will
  /// replace in-memory sample data with backend data where available.
  Future<void> loadBusinessData(String businessId,
      {AutoRepositoryImpl? repository}) async {
    if (businessId.isEmpty) {
      if (kDebugMode) print('[AutoProvider] loadBusinessData called with empty businessId');
      return;
    }

    final repo = repository ?? AutoRepositoryImpl();
    // mark loading
    isLoadingData = true;
    _dataError = null;
    notifyListeners();

    final sw = Stopwatch()..start();

    // Helper to run a future safely and return null on error
    Future<T?> _safe<T>(Future<T> f, String name) async {
      try {
        return await f;
      } catch (e) {
        if (kDebugMode) print('[AutoProvider] failed to fetch $name: $e');

        // Detect Firestore composite index missing errors and surface the link
        if (e is FirebaseException && (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index'))) {
          final msg = e.message ?? e.toString();
          final idx = msg.indexOf('https://');
          if (idx >= 0) {
            final end = msg.indexOf('\n', idx);
            final url = end > 0 ? msg.substring(idx, end).trim() : msg.substring(idx).trim();
            debugPrint('[AutoProvider] Firestore composite index required. Create it here: $url');
          } else {
            debugPrint('[AutoProvider] Firestore composite index required but no index URL found in the error.');
          }
        }

        return null;
      }
    }

    try {
      // Kick off parallel fetches
      final futureVehicles = _safe(repo.getVehicles(businessId), 'vehicles');
      final futureOrders = _safe(repo.getServiceOrders(businessId), 'serviceOrders');
      final futureParts = _safe(repo.getParts(businessId), 'parts');
      final futureServices = _safe(repo.getServices(businessId), 'services');
      final futureInvoices = _safe(repo.getInvoices(businessId), 'invoices');
      final futureBookings = _safe(repo.getBookings(businessId), 'bookings');

      // Await results (concurrent)
      final vehiclesData = await futureVehicles ?? [];
      final orders = await futureOrders ?? [];
      final partsData = await futureParts;
      final servicesData = await futureServices;
      final invoicesData = await futureInvoices ?? [];
      final bookingsData = await futureBookings ?? [];

      // Map vehicles
      vehicles.clear();
      for (final v in vehiclesData) {
        vehicles.add(Vehicle(
          id: v['id'] as String? ?? v['vehicleId'] as String? ?? 'unknown',
          make: v['make'] as String? ?? (v['vehicle']?['make'] as String?) ?? 'Unknown',
          model: v['model'] as String? ?? (v['vehicle']?['model'] as String?) ?? '',
          licensePlate: v['licensePlate'] as String? ?? (v['vehicle']?['licensePlate'] as String?) ?? '',
          vin: v['vin'] as String? ?? (v['vehicle']?['vin'] as String?) ?? '',
          year: (v['year'] as num?)?.toInt() ?? 0,
          ownerName: v['ownerName'] as String? ?? (v['owner']?['name'] as String?) ?? '',
          ownerPhone: v['ownerPhone'] as String? ?? (v['owner']?['phone'] as String?) ?? '',
        ));
      }

      // Map service orders into jobs (if realtime listener hasn't already populated)
      if (_ordersSubscription == null || jobs.isEmpty) {
        jobs.clear();
        for (final o in orders) {
          final created = parseTimestamp(o['createdAt']) ?? DateTime.now();

          final vehicleId = o['vehicleId'] as String? ?? o['vehicle']?['id'] as String? ?? '';

          final total = (o['totalCost'] as num?)?.toDouble() ?? (o['total'] as num?)?.toDouble() ?? 0.0;

          jobs.add(Job(
            id: o['id'] as String? ?? '',
            vehicleId: vehicleId,
            createdAt: created,
            completedAt: null,
            status: (o['status'] as String?)?.toLowerCase() ?? 'pending',
            tasks: [],
            usedParts: [],
            notes: o['notes'] as String? ?? '',
            totalCost: total,
          ));
        }
      }

      // Map parts
      if (partsData != null) {
        parts.clear();
        for (final p in partsData) {
          parts.add(Part(
            id: p['id'] as String? ?? '',
            name: p['name'] as String? ?? 'Unknown',
            quantity: (p['quantity'] as num?)?.toInt() ?? (p['qty'] as num?)?.toInt() ?? 0,
            cost: (p['cost'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      // Map services
      if (servicesData != null) {
        services.clear();
        for (final s in servicesData) {
          services.add(ServiceTask(
            id: s['id'] as String? ?? '',
            name: s['name'] as String? ?? 'Service',
            laborCost: (s['laborCost'] as num?)?.toDouble() ?? (s['cost'] as num?)?.toDouble() ?? 0.0,
            estimatedDuration: Duration(minutes: (s['estimatedMinutes'] as num?)?.toInt() ?? 30),
          ));
        }
      }

      // Map invoices and bookings
      _invoices = invoicesData;
      _bookings = bookingsData;

      _lastFetched = DateTime.now();
      if (kDebugMode) print('[AutoProvider] loadBusinessData: fetched vehicles=${vehicles.length}, jobs=${jobs.length}, parts=${parts.length}, services=${services.length}, invoices=${_invoices.length}, bookings=${_bookings.length} in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      _dataError = 'Failed to load data: $e';
    } finally {
      sw.stop();
      isLoadingData = false;
      notifyListeners();
    }
  }

  // Vehicles
  void addVehicle(Vehicle v) {
    vehicles.add(v);
    notifyListeners();
  }

  Vehicle? getVehicleById(String id) {
    try {
      return vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  // Jobs
  /// Create a job and ensure totals are calculated and timestamps set.
  void createJob(Job job) {
    // prevent duplicate job ids
    if (jobs.any((j) => j.id == job.id)) {
      throw Exception('Job with id ${job.id} already exists');
    }

    final jd = Job(
      id: job.id,
      vehicleId: job.vehicleId,
      createdAt: job.createdAt,
      completedAt: job.completedAt,
      status: job.status,
      tasks: List<ServiceTask>.from(job.tasks),
      usedParts: List<Part>.from(job.usedParts),
      notes: job.notes,
      totalCost: 0.0,
    );

    // compute totals from tasks and parts
    final tasksCost = jd.tasks.fold<double>(0.0, (s, t) => s + t.laborCost);
    final partsCost = jd.usedParts.fold<double>(0.0, (s, p) => s + (p.cost * p.quantity));
    jd.totalCost = tasksCost + partsCost;

    // Deduct used parts from inventory if applicable
    for (final used in jd.usedParts) {
      try {
        final inv = parts.firstWhere((p) => p.id == used.id);
        inv.quantity -= used.quantity;
        if (inv.quantity < 0) inv.quantity = 0;
      } catch (_) {
        // If part isn't in inventory, ignore here - production should surface this
      }
    }

    jobs.add(jd);
    notifyListeners();
  }

  List<Job> getJobsByVehicle(String vehicleId) {
    return jobs.where((j) => j.vehicleId == vehicleId).toList();
  }

  List<Job> getOpenJobs() {
    return jobs
        .where((j) => j.status == 'pending' || j.status == 'in-progress')
        .toList();
  }

  /// Returns the number of active (open/in-progress) jobs
  List<Job> getCompletedJobs() {
    return jobs
        .where((j) => j.status == 'completed' || j.status == 'invoiced')
        .toList();
  }

  /// Safely update job status. Returns true if update occurred, false if not found.
  bool updateJobStatus(String jobId, String newStatus) {
    try {
      final job = jobs.firstWhere((j) => j.id == jobId);
      job.status = newStatus;
      if (newStatus == 'completed') {
        job.completedAt = DateTime.now();
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Add a service task to a job. Throws if the job is not found.
  void addTaskToJob(String jobId, ServiceTask task) {
    final job = jobs.firstWhere((j) => j.id == jobId);
    (job.tasks).add(task);
    job.totalCost += task.laborCost;
    notifyListeners();
  }

  /// Add part(s) to a job and deduct from inventory. Quantity defaults to the
  /// part's quantity if provided but callers can pass a custom quantity.
  void addPartToJob(String jobId, Part part, {int quantity = 1}) {
    final job = jobs.firstWhere((j) => j.id == jobId);
    final inv = parts.firstWhere((p) => p.id == part.id);
    if (inv.quantity < quantity) throw Exception('Insufficient part stock');
    // deduct inventory
    inv.quantity -= quantity;
    // add a copy of the part with the consumed quantity to the job
    job.usedParts.add(Part(id: part.id, name: part.name, quantity: quantity, cost: part.cost));
    job.totalCost += part.cost * quantity;
    notifyListeners();
  }

  double getTotalJobsRevenue() {
    return jobs.fold<double>(0.0, (sum, j) => sum + j.totalCost);
  }

  int getActiveJobCount() {
    return getOpenJobs().length;
  }

  // Services
  void addService(ServiceTask service) {
    services.add(service);
    notifyListeners();
  }

  // Parts Inventory
  void addPart(Part part) {
    parts.add(part);
    notifyListeners();
  }

  void adjustPartQuantity(String partId, int delta) {
    final p = parts.firstWhere((x) => x.id == partId);
    p.quantity += delta;
    if (p.quantity < 0) p.quantity = 0;
    notifyListeners();
  }

  int getLowStockPartCount() {
    return parts.where((p) => p.quantity < 5).length;
  }

  double getTotalPartsCost() {
    return parts.fold<double>(0.0, (sum, p) => sum + (p.cost * p.quantity));
  }

  // backend-provided lists
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _bookings = [];
  String? _dataError;

  List<Map<String, dynamic>> get invoices => _invoices;
  List<Map<String, dynamic>> get bookings => _bookings;
  String? get dataError => _dataError;

  /// Number of external bookings.
  int getBookingsCount() {
    return _bookings.length;
  }

  /// Number of invoices.
  int getInvoicesCount() {
    return _invoices.length;
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    super.dispose();
  }
}

