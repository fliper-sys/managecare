import 'package:flutter/foundation.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:hive/hive.dart';
import '../data/repositories/industry_specific/pharmacy_repository_impl.dart';
import '../data/models/industry_specific/pharmacy/drug_model.dart' as dm;
import '../data/models/industry_specific/pharmacy/prescription_model.dart'
    as pm;
import '../data/models/industry_specific/pharmacy/patient_model.dart';
import '../services/business_notification_manager.dart';

class Drug {
  final String id;
  final String name;
  final String batch;
  DateTime expiry;
  int stock;
  double price; // Price per unit
  double costPrice; // Buying price per unit
  final List<Map<String, dynamic>> prescriptions; // [{ageRange: '8-12', intensity: '1-3', dosage: '2 tablets daily'}, ...]

  Drug({
    required this.id,
    required this.name,
    required this.batch,
    required this.expiry,
    required this.stock,
    this.price = 0.0,
    this.costPrice = 0.0,
    this.prescriptions = const [],
  });
}

class Prescription {
  final String id;
  final String patientId;
  final String? patientName; // optional, for walk-ins or when patient not in patients list
  final List<Map<String, dynamic>> items; // {drugId, qty}
  final DateTime createdAt;
  String status; // pending, dispensed, cancelled
  final String? prescriber;
  final String? notes;
  final String? attachmentReference;
  final bool attachmentRequired;
  final DateTime? patientDateOfBirth;

  Prescription(
      {required this.id,
      required this.patientId,
      this.patientName,
      required this.items,
      DateTime? createdAt,
      this.status = 'pending',
      this.prescriber,
      this.notes,
      this.attachmentReference,
      this.attachmentRequired = false,
      this.patientDateOfBirth})
      : createdAt = createdAt ?? DateTime.now();
}

class Treatment {
  final String id;
  final String patientId;
  final String name;
  final String drugName;
  final String dosage;
  final int frequencyPerDay;
  final int durationDays;
  final DateTime startDate;
  final DateTime endDate;
  bool isActive;
  /// Each entry records one administered dose: when it was given and
  /// which staff member logged it ({'date': DateTime, 'userId': String,
  /// 'userName': String}). Replaces the old plain administeredDates list
  /// so each dose can be attributed to the staff member who gave it.
  final List<Map<String, dynamic>> administeredLog;

  Treatment({
    required this.id,
    required this.patientId,
    required this.name,
    required this.drugName,
    required this.dosage,
    required this.frequencyPerDay,
    required this.durationDays,
    required this.startDate,
    DateTime? endDate,
    this.isActive = true,
    this.administeredLog = const [],
  }) : endDate = endDate ?? startDate.add(Duration(days: durationDays));

  bool get isCompleted => DateTime.now().isAfter(this.endDate);
  int get daysRemaining => this.endDate.difference(DateTime.now()).inDays;
  int get dosesGiven => administeredLog.length;
  int get totalDosesExpected => frequencyPerDay * durationDays;
}

class Patient {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? dateOfBirth;
  final String? allergies;
  final String? bloodType;
  final String? additionalNotes;

  Patient({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.dateOfBirth,
    this.allergies,
    this.bloodType,
    this.additionalNotes,
  });

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromModel(PatientModel model) {
    return Patient(
      id: model.id,
      name: model.name,
      phone: model.phone,
      email: model.email,
      address: model.address,
      dateOfBirth: model.dateOfBirth,
      allergies: model.allergies,
      bloodType: model.bloodType,
      additionalNotes: model.additionalNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (allergies != null) 'allergies': allergies,
        if (bloodType != null) 'bloodType': bloodType,
        if (additionalNotes != null) 'additionalNotes': additionalNotes,
      };

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      allergies: json['allergies'] as String?,
      bloodType: json['bloodType'] as String?,
      additionalNotes: json['additionalNotes'] as String?,
    );
  }
}

class PharmacyProvider extends ChangeNotifier {
  final PharmacyRepositoryImpl? _repository;
  String? _businessId;
  final List<Drug> _drugs = [];
  final List<Prescription> _prescriptions = [];
  final List<Patient> _patients = [];
  final List<Treatment> _treatments = [];

  PharmacyProvider({PharmacyRepositoryImpl? repository})
      : _repository = repository {
    // If a repository is provided we'll try to load remote data and controlled set.
    // For local/testing usage (no repository) populate sample data to keep provider usable.
    if (_repository == null) {
      _populateSampleData();
    } else {
      _init();
    }
  }

  void _populateSampleData() {
    _drugs.addAll(List.generate(
      6,
      (i) => Drug(
        id: 'D${i + 1}',
        name: 'Drug ${i + 1}',
        batch: 'BATCH-${i + 100}',
        expiry: DateTime.now().add(Duration(days: 30 + i * 10)),
        stock: 50 - i * 4,
        price: 5.0 + (i * 2.5), // Add price
        costPrice: 3.0 + i,
      ),
    ));

    _patients.addAll(List.generate(
        3,
        (i) => Patient(
            id: 'P${i + 1}',
            name: 'Patient ${i + 1}',
            phone: '0800${i + 1}',
            dateOfBirth: DateTime.now().subtract(Duration(days: 365 * (22 + i))))));

    // no prescriptions initially
    notifyListeners();
  }

  Future<void> _init() async {
    await _loadControlledSet();
    try {
      await loadFromRepository();
    } catch (_) {
      // If remote load fails, fallback to local cache
      await _loadLocalDrugs();
      await _loadLocalPrescriptions();
      await _loadLocalPatients();
      await _loadLocalTreatments();
    }
  }

  List<Drug> get drugs => List.unmodifiable(_drugs);
  List<Prescription> get prescriptions => List.unmodifiable(_prescriptions);
  List<Patient> get patients => List.unmodifiable(_patients);
  List<Treatment> get treatments => List.unmodifiable(_treatments);

  // Controlled drugs are stored locally in Hive
  static const String _controlledBox = 'pharmacy_controlled';
  static const String _drugsBox = 'pharmacy_drugs';
  static const String _prescriptionsBox = 'pharmacy_prescriptions';
  static const String _patientsBox = 'pharmacy_patients';
  static const String _treatmentsBox = 'pharmacy_treatments';

  Set<String> _controlled = {};

  Future<void> _loadControlledSet() async {
    try {
      final box = await Hive.openBox(_controlledBox);
      final values =
          box.get('controlled', defaultValue: <String>[]) as List<dynamic>;
      _controlled = values.cast<String>().toSet();
    } catch (_) {
      _controlled = {};
    }
  }

  Future<void> _saveControlledSet() async {
    final box = await Hive.openBox(_controlledBox);
    await box.put('controlled', _controlled.toList());
  }

  // Local persistence helpers
  Future<void> _saveLocalDrugs() async {
    try {
      final box = await Hive.openBox(_drugsBox);
      final data = _drugs
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'batch': d.batch,
                'expiry': d.expiry.toIso8601String(),
                'stock': d.stock,
                'price': d.price,
                'costPrice': d.costPrice,
                'prescriptions': d.prescriptions,
              })
          .toList();
      await box.put('drugs', data);
    } catch (_) {}
  }

  Future<void> _loadLocalDrugs() async {
    try {
      final box = await Hive.openBox(_drugsBox);
      final data = box.get('drugs', defaultValue: <dynamic>[]) as List<dynamic>;
      _drugs
        ..clear()
        ..addAll(data.map((e) {
          final m = e as Map<dynamic, dynamic>;
          return Drug(
            id: m['id'] as String,
            name: m['name'] as String,
            batch: m['batch'] as String,
            expiry: parseTimestamp(m['expiry']),
            stock: (m['stock'] as num).toInt(),
            price: (m['price'] as num).toDouble(),
            costPrice:
                ((m['costPrice'] ?? m['cost']) as num?)?.toDouble() ?? 0.0,
            prescriptions:
                (m['prescriptions'] as List<dynamic>? ?? const [])
                    .map((entry) => Map<String, dynamic>.from(entry as Map))
                    .toList(),
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLocalPrescriptions() async {
    try {
      final box = await Hive.openBox(_prescriptionsBox);
      final data = _prescriptions
          .map((p) => {
                'id': p.id,
                'patientId': p.patientId,
                'patientName': (p as dynamic).patientName ?? '',
                'items': p.items,
                'createdAt': p.createdAt.toIso8601String(),
                'status': p.status,
                'prescriber': (p as dynamic).prescriber ?? '',
                'notes': p.notes,
                'attachmentReference': p.attachmentReference,
                'attachmentRequired': p.attachmentRequired,
                'patientDateOfBirth': p.patientDateOfBirth?.toIso8601String(),
              })
          .toList();
      await box.put('prescriptions', data);
    } catch (_) {}
  }

  Future<void> _loadLocalPrescriptions() async {
    try {
      final box = await Hive.openBox(_prescriptionsBox);
      final data =
          box.get('prescriptions', defaultValue: <dynamic>[]) as List<dynamic>;
      _prescriptions
        ..clear()
        ..addAll(data.map((e) {
          final m = e as Map<dynamic, dynamic>;
          return Prescription(
            id: m['id'] as String,
            patientId: m['patientId'] as String,
            patientName: (m['patientName'] as String?)?.isNotEmpty == true ? m['patientName'] as String : null,
            items: List<Map<String, dynamic>>.from(m['items'] as List),
            createdAt: parseTimestamp(m['createdAt']),
            status: m['status'] as String,
            prescriber: m['prescriber'] as String? ?? '',
            notes: m['notes'] as String?,
            attachmentReference: m['attachmentReference'] as String?,
            attachmentRequired: m['attachmentRequired'] == true,
            patientDateOfBirth: m['patientDateOfBirth'] != null
                ? parseTimestamp(m['patientDateOfBirth'])
                : null,
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLocalPatients() async {
    try {
      final box = await Hive.openBox(_patientsBox);
      final data = _patients
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'phone': p.phone,
                'email': p.email,
                'address': p.address,
                'dateOfBirth': p.dateOfBirth?.toIso8601String(),
                'allergies': p.allergies,
                'bloodType': p.bloodType,
                'additionalNotes': p.additionalNotes,
              })
          .toList();
      await box.put('patients', data);
    } catch (_) {}
  }

  Future<void> _loadLocalPatients() async {
    try {
      final box = await Hive.openBox(_patientsBox);
      final data = box.get('patients', defaultValue: <dynamic>[]) as List<dynamic>;
      _patients
        ..clear()
        ..addAll(data.map((e) {
          final m = e as Map<dynamic, dynamic>;
          return Patient(
            id: m['id'] as String,
            name: m['name'] as String,
            phone: m['phone'] as String,
            email: m['email'] as String?,
            address: m['address'] as String?,
            dateOfBirth: m['dateOfBirth'] != null
                ? parseTimestamp(m['dateOfBirth'])
                : null,
            allergies: m['allergies'] as String?,
            bloodType: m['bloodType'] as String?,
            additionalNotes: m['additionalNotes'] as String?,
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLocalTreatments() async {
    try {
      final box = await Hive.openBox(_treatmentsBox);
      final data = _treatments
          .map((t) => {
                'id': t.id,
                'patientId': t.patientId,
                'name': t.name,
                'drugName': t.drugName,
                'dosage': t.dosage,
                'frequencyPerDay': t.frequencyPerDay,
                'durationDays': t.durationDays,
                'startDate': t.startDate.toIso8601String(),
                'endDate': t.endDate.toIso8601String(),
                'isActive': t.isActive,
                'administeredLog': t.administeredLog
                    .map((e) => {
                          'date': (e['date'] as DateTime).toIso8601String(),
                          'userId': e['userId'],
                          'userName': e['userName'],
                        })
                    .toList(),
              })
          .toList();
      await box.put('treatments', data);
    } catch (_) {}
  }

  Future<void> _loadLocalTreatments() async {
    try {
      final box = await Hive.openBox(_treatmentsBox);
      final data = box.get('treatments', defaultValue: <dynamic>[]) as List<dynamic>;
      _treatments
        ..clear()
        ..addAll(data.map((e) {
          final m = e as Map<dynamic, dynamic>;
          return Treatment(
            id: m['id'] as String,
            patientId: m['patientId'] as String,
            name: m['name'] as String,
            drugName: m['drugName'] as String,
            dosage: m['dosage'] as String,
            frequencyPerDay: m['frequencyPerDay'] as int,
            durationDays: m['durationDays'] as int,
            startDate: parseTimestamp(m['startDate']),
            endDate: parseTimestamp(m['endDate']),
            isActive: m['isActive'] as bool? ?? true,
            administeredLog: ((m['administeredLog'] as List<dynamic>?) ?? const [])
                .map((e) {
                  final entry = e as Map;
                  return {
                    'date': parseTimestamp(entry['date'] as String),
                    'userId': entry['userId'],
                    'userName': entry['userName'],
                  };
                })
                .toList(),
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Patient? getPatientById(String patientId) {
    try {
      return _patients.firstWhere((patient) => patient.id == patientId);
    } catch (_) {
      return null;
    }
  }

  int? getPatientAge(String patientId) => calculateAge(getPatientById(patientId)?.dateOfBirth);

  int? calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    final birthdayThisYear = DateTime(now.year, dateOfBirth.month, dateOfBirth.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    return age < 0 ? 0 : age;
  }

  bool requiresAttachmentForPatient(Patient? patient) {
    final age = calculateAge(patient?.dateOfBirth);
    return age != null && age < 18;
  }

  bool isControlled(String drugId) => _controlled.contains(drugId);

  Future<void> markControlled(String drugId, bool controlled) async {
    if (controlled) {
      _controlled.add(drugId);
    } else {
      _controlled.remove(drugId);
    }
    await _saveControlledSet();
    notifyListeners();
  }

  bool _partialRemoteLoad = false;

  /// Whether the previous remote load required local fallback (e.g. missing Firestore index)
  bool get partialRemoteLoad => _partialRemoteLoad;

  bool _usingLocalCache = false;

  /// Whether data is coming from local cache (no successful remote load)
  bool get usingLocalCache => _usingLocalCache;

  Future<void> loadFromRepository({String? businessId}) async {
    if (_repository == null) return;

    // reset state
    _partialRemoteLoad = false;
    _usingLocalCache = false;

    try {
      final remoteDrugs = await _repository!.fetchDrugs(businessId: businessId);
      _drugs
        ..clear()
        ..addAll(remoteDrugs.map((d) => Drug(
              id: d.id,
              name: d.name,
              batch: d.manufacturer,
              expiry: d.expiryDate,
              stock: (d.quantity),
              price: (d.price),
              costPrice: d.costPrice,
              prescriptions: d.prescriptions,
            )));

      final remotePres =
          await _repository!.fetchPrescriptions(businessId: businessId);

      // Keep a snapshot of local prescriptions in case some were created locally and not yet persisted remotely
      final localSnapshot = Map<String, Prescription>.fromEntries(_prescriptions.map((p) => MapEntry(p.id, p)));

      final incoming = remotePres.map((p) => Prescription(
            id: p.id,
            patientId: p.patientId,
            patientName: p.patientName,
            items: p.items,
            createdAt: p.issuedAt,
            status: p.status,
            prescriber: p.prescriberName ?? p.prescriber,
            notes: p.notes,
            attachmentReference: p.attachmentReference,
            attachmentRequired: p.attachmentRequired,
            patientDateOfBirth: p.patientDateOfBirth,
          )).toList();

      // Merge: start with remote list, then add any local-only prescriptions that don't exist remotely
      final remoteIds = incoming.map((p) => p.id).toSet();
      _prescriptions
        ..clear()
        ..addAll(incoming);

      for (final lp in localSnapshot.values) {
        if (!remoteIds.contains(lp.id)) {
          // local-only entry; keep it so it's not lost on reload
          _prescriptions.insert(0, lp);
        } else {
          // if local indicates a non-pending status that differs from remote, try to re-apply
          final remoteMatch = _prescriptions.firstWhere((p) => p.id == lp.id);
          if (remoteMatch.status != lp.status && lp.status != 'pending') {
            try {
              await _repository!.updatePrescription(lp.id, {
                'status': lp.status,
                if (lp.status == 'dispensed') 'dispensedAt': DateTime.now().toIso8601String(),
                if (lp.status == 'cancelled') 'cancelledAt': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              if (kDebugMode) debugPrint('[PharmacyProvider] Failed to re-apply local prescription status for ${lp.id}: $e');
            }
          }
        }
      }

      // If repository signalled that a fallback was used, mark partial remote load
      if ((_repository is PharmacyRepositoryImpl) && (_repository as PharmacyRepositoryImpl).lastPrescriptionsFetchUsedFallback) {
        _partialRemoteLoad = true;
        if (kDebugMode) debugPrint('[PharmacyProvider] Remote prescriptions loaded via local fallback (missing composite index)');
      }

      final remotePatients =
          await _repository!.fetchPatients(businessId: businessId);
      _patients
        ..clear()
        ..addAll(remotePatients
            .map((p) => Patient(
                  id: p.id,
                  name: p.name,
                  phone: p.phone,
                  email: p.email,
                  address: p.address,
                  dateOfBirth: p.dateOfBirth,
                  allergies: p.allergies,
                  bloodType: p.bloodType,
                  additionalNotes: p.additionalNotes,
                )));

      final remoteTreatments =
          await _repository!.fetchTreatments(businessId: businessId);
      _treatments
        ..clear()
        ..addAll(remoteTreatments.map((t) => Treatment(
              id: (t['id'] as String?) ?? '',
              patientId: (t['patientId'] as String?) ?? '',
              name: (t['name'] as String?) ?? '',
              drugName: (t['drugName'] as String?) ?? '',
              dosage: (t['dosage'] as String?) ?? '',
              frequencyPerDay: (t['frequencyPerDay'] as num?)?.toInt() ?? 1,
              durationDays: (t['durationDays'] as num?)?.toInt() ?? 1,
              startDate: parseTimestamp(t['startDate']),
              endDate: parseTimestamp(
                t['endDate'] ??
                    t['startDate'] ??
                    DateTime.now().toIso8601String(),
              ),
              isActive: t['isActive'] != false,
              administeredLog: (t['administeredLog'] as List<dynamic>?)
                      ?.map((e) {
                    final entry = e as Map;
                    return {
                      'date': parseTimestamp(entry['date']),
                      'userId': entry['userId'],
                      'userName': entry['userName'],
                    };
                  }).toList() ??
                  // Backward-compat: older records may only have the
                  // plain administeredDates list with no staff attribution.
                  (t['administeredDates'] as List<dynamic>? ?? const [])
                      .map((e) => {
                            'date': parseTimestamp(e),
                            'userId': null,
                            'userName': null,
                          })
                      .toList(),
            )));

      // persist to local cache
      await _saveLocalDrugs();
      await _saveLocalPrescriptions();
      await _saveLocalPatients();
      await _saveLocalTreatments();

      if (kDebugMode) {
        debugPrint('[PharmacyProvider] Loaded ${_drugs.length} drugs, ${_prescriptions.length} prescriptions, ${_patients.length} patients for businessId=$businessId');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PharmacyProvider] Failed to load remote pharmacy data for businessId=$businessId: $e');
        // Provide guidance for index issues
        final em = e is Exception ? e.toString() : '$e';
        if (em.contains('requires an index') || em.contains('failed-precondition')) {
          debugPrint('[PharmacyProvider] Firestore query requires a composite index. To fix: create an index for collection "pharmacy_prescriptions" with fields (businessId ASC, issuedAt DESC). See Firebase console index creation link shown in the original error.');
        }
      }
      // On error, load local cache
      _usingLocalCache = true;
      await _loadLocalDrugs();
      await _loadLocalPrescriptions();
      await _loadLocalPatients();
      await _loadLocalTreatments();
    }
  }

  /// Set business id and load remote pharmacy data for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    await loadFromRepository(businessId: businessId);
    notifyListeners();
  }

  dm.DrugModel _toDrugModel(Drug drug) {
    return dm.DrugModel(
      id: drug.id,
      name: drug.name,
      manufacturer: drug.batch,
      dosageForm: '',
      strength: '',
      expiryDate: drug.expiry,
      quantity: drug.stock,
      price: drug.price,
      costPrice: drug.costPrice,
      prescriptions: drug.prescriptions,
    );
  }

  Future<void> _syncDrugToRepository(Drug drug, {String? businessId}) async {
    if (_repository == null) return;
    await _repository!.syncDrug(
      _toDrugModel(drug),
      businessId: businessId,
      extraData: {
        'quantity': drug.stock,
        'price': drug.price,
        'cost': drug.costPrice,
        'costPrice': drug.costPrice,
        'prescriptions': drug.prescriptions,
      },
    );
  }

  void addDrug(Drug drug, {bool persist = false, String? businessId}) {
    _drugs.add(drug);
    notifyListeners();

    // Save locally
    _saveLocalDrugs();

    if (persist && _repository != null) {
      _syncDrugToRepository(drug, businessId: businessId);
    }
  }

  Future<void> updateDrugStock(String drugId, int newStock,
      {bool persist = false, String? businessId}) async {
    final d = _drugs.firstWhere((e) => e.id == drugId,
        orElse: () => throw Exception('Drug not found'));
    d.stock = newStock;
    notifyListeners();

    // update local cache
    await _saveLocalDrugs();

    if (persist && _repository != null) {
      await _syncDrugToRepository(d, businessId: businessId);
    }
  }

  /// Update full drug record (name, batch, expiry, stock, price)
  Future<void> updateDrug(Drug updated,
      {bool persist = false, String? businessId}) async {
    final idx = _drugs.indexWhere((d) => d.id == updated.id);
    if (idx == -1) return;
    _drugs[idx] = updated;
    notifyListeners();
    await _saveLocalDrugs();

    if (persist && _repository != null) {
      await _syncDrugToRepository(updated, businessId: businessId);
    }
  }

  /// Remove a drug from local cache and optionally persist delete remotely
  Future<void> removeDrug(String drugId, {bool persist = false, String? businessId}) async {
    final idx = _drugs.indexWhere((d) => d.id == drugId);
    if (idx == -1) return;

    _drugs.removeAt(idx);
    notifyListeners();

    // persist local cache
    await _saveLocalDrugs();

    if (persist && _repository != null) {
      try {
        final bid = businessId ?? _businessId ?? '';
        if (bid.isNotEmpty) {
          await (_repository as PharmacyRepositoryImpl).deleteDrug(businessId: bid, drugId: drugId);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to delete drug remotely: $e');
      }
    }
  }

  List<Drug> expiringWithin(Duration within) {
    final cutoff = DateTime.now().add(within);
    return _drugs.where((d) => d.expiry.isBefore(cutoff)).toList();
  }

  List<Drug> lowStock({int threshold = 5}) {
    return _drugs.where((d) => d.stock <= threshold).toList();
  }

  Future<Prescription> addPrescription(
      String patientId, List<Map<String, dynamic>> items,
      {String? patientName,
      String? notes,
      String? attachmentReference,
      bool attachmentRequired = false,
      DateTime? patientDateOfBirth,
      bool persist = true,
      String? businessId,
      String? userId}) async {
    final pres = Prescription(
        id: 'RX-${_prescriptions.length + 1000}',
        patientId: patientId,
        patientName: patientName,
        items: items,
        prescriber: userId ?? 'system',
        notes: notes,
        attachmentReference: attachmentReference,
        attachmentRequired: attachmentRequired,
        patientDateOfBirth: patientDateOfBirth);
    _prescriptions.insert(0, pres);
    notifyListeners();

    // save locally
    _saveLocalPrescriptions();

    if (persist && _repository != null) {
      final pmModel = pm.PrescriptionModel(
          id: pres.id,
          patientId: pres.patientId,
          drugIds: items.map((e) => e['drugId'] as String).toList(),
          items: items,
          issuedAt: pres.createdAt,
          prescriber: userId ?? 'system',
          patientName: patientName,
          status: pres.status,
          notes: notes,
          attachmentReference: attachmentReference,
          attachmentRequired: attachmentRequired,
          patientDateOfBirth: patientDateOfBirth);

      // repository now returns the document id for created prescription
      String? remoteId;
      try {
        remoteId = await _repository!.addPrescription(pmModel,
            businessId: businessId, extraData: (patientName != null) ? {'patientName': patientName} : null);
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to add prescription remotely: $e');
      }

      // If remoteId differs, replace local entry with one that has the remote id so future updates target correct doc
      if (remoteId != null && remoteId.isNotEmpty && remoteId != pres.id) {
        final newPres = Prescription(
            id: remoteId,
            patientId: pres.patientId,
            patientName: pres.patientName,
            items: pres.items,
            createdAt: pres.createdAt,
            status: pres.status,
            prescriber: pres.prescriber,
            notes: pres.notes,
            attachmentReference: pres.attachmentReference,
            attachmentRequired: pres.attachmentRequired,
            patientDateOfBirth: pres.patientDateOfBirth);
        // replace the old temp prescription
        _prescriptions.removeWhere((p) => p.id == pres.id);
        _prescriptions.insert(0, newPres);
        await _saveLocalPrescriptions();
        notifyListeners();
        // Use remote id for logging
        if (items.isNotEmpty) {
          final controlledInvolved = items
              .map((e) => e['drugId'] as String)
              .where((id) => isControlled(id))
              .toList();
          if (controlledInvolved.isNotEmpty) {
            await _repository!.logAudit({
              'action': 'prescription_created',
              'prescriptionId': newPres.id,
              'userId': userId ?? 'system',
              'drugIds': items.map((e) => e['drugId']).toList(),
              'controlledDrugIds': controlledInvolved,
            });
          }
        }
        return newPres;
      } else {
        // remoteId not returned or same as local; log audit with local id
        final controlledInvolved = items
            .map((e) => e['drugId'] as String)
            .where((id) => isControlled(id))
            .toList();
        if (controlledInvolved.isNotEmpty) {
          await _repository!.logAudit({
            'action': 'prescription_created',
            'prescriptionId': pres.id,
            'userId': userId ?? 'system',
            'drugIds': items.map((e) => e['drugId']).toList(),
            'controlledDrugIds': controlledInvolved,
          });
        }
      }
    }

    return pres;
  }

  Future<void> dispensePrescription(String prescriptionId,
      {bool persist = true, String? businessId, String? userId}) async {
    final pres = _prescriptions.firstWhere((p) => p.id == prescriptionId,
        orElse: () => throw Exception('Prescription not found'));
    if (pres.status != 'pending') return;

    // decrement stock
    for (final it in pres.items) {
      final drug = _drugs.firstWhere((d) => d.id == it['drugId'],
          orElse: () => throw Exception('Drug not found'));
      drug.stock = (drug.stock - (it['qty'] as int)).clamp(0, 999999);

      // persist local stock change
      await _saveLocalDrugs();

      // Check if drug is now low stock or out
      if (drug.stock == 0) {
        await BusinessNotificationManager.instance.notifyOutOfStock(
          businessId: businessId ?? 'current_business',
          itemName: drug.name,
        );
      } else if (drug.stock < 5) {
        await BusinessNotificationManager.instance.notifyLowStock(
          businessId: businessId ?? 'current_business',
          itemName: drug.name,
          currentStock: drug.stock,
          reorderPoint: 5,
        );
      }

      // Check for expiry
      final daysUntilExpiry = drug.expiry.difference(DateTime.now()).inDays;
      if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
        await BusinessNotificationManager.instance.notifyExpiryWarning(
          businessId: businessId ?? 'current_business',
          itemName: drug.name,
          expiryDate: drug.expiry,
          daysUntilExpiry: daysUntilExpiry,
        );
      }
    }

    pres.status = 'dispensed';
    notifyListeners();

    // save prescriptions locally
    await _saveLocalPrescriptions();

    if (persist && _repository != null) {
      // log audit
      final controlledInvolved = pres.items
          .map((e) => e['drugId'] as String)
          .where((id) => isControlled(id))
          .toList();
      if (controlledInvolved.isNotEmpty) {
        await _repository!.logAudit({
          'action': 'prescription_dispensed',
          'prescriptionId': pres.id,
          'userId': userId ?? 'system',
          'drugIds': pres.items.map((e) => e['drugId']).toList(),
          'controlledDrugIds': controlledInvolved,
        });
      }

      // Update prescription doc status remotely
      try {
        await _repository!.updatePrescription(pres.id, {
          'status': 'dispensed',
          'dispensedAt': DateTime.now().toIso8601String(),
          'dispensedBy': userId ?? 'system',
        });
      } catch (e) {
        // log and continue
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to update prescription on remote: $e');
      }

      // optionally sync drug stocks
      for (final d in _drugs) {
        await _syncDrugToRepository(d, businessId: businessId);
      }
    }
  }

  Future<void> syncDrugInventory({String? businessId}) async {
    if (_repository == null) return;
    for (final d in _drugs) {
      await _syncDrugToRepository(d, businessId: businessId);
    }
    notifyListeners();
  }

  /// Whether this provider is backed by a remote repository (Firestore).
  bool get hasRemote => _repository != null;

  // ==================== COMPREHENSIVE BUSINESS LOGIC ====================

  /// Get all drugs with low stock
  List<Drug> getLowStockDrugs({int threshold = 5}) {
    return _drugs.where((d) => d.stock <= threshold).toList();
  }

  /// Get all drugs expiring within specified days
  List<Drug> getExpiringDrugs({int daysThreshold = 30}) {
    final cutoff = DateTime.now().add(Duration(days: daysThreshold));
    return _drugs
        .where((d) =>
            d.expiry.isBefore(cutoff) && d.expiry.isAfter(DateTime.now()))
        .toList();
  }

  /// Get all expired drugs
  List<Drug> getExpiredDrugs() {
    return _drugs.where((d) => d.expiry.isBefore(DateTime.now())).toList();
  }

  /// Calculate total inventory value
  double calculateInventoryValue() {
    return _drugs.fold(0.0, (sum, drug) => sum + (drug.price * drug.stock));
  }

  /// Calculate inventory statistics
  Map<String, dynamic> getInventoryStats() {
    final totalDrugs = _drugs.length;
    final totalStock = _drugs.fold(0, (sum, d) => sum + d.stock);
    final lowStockCount = getLowStockDrugs().length;
    final expiringCount = getExpiringDrugs().length;
    final expiredCount = getExpiredDrugs().length;
    final inventoryValue = calculateInventoryValue();

    return {
      'totalDrugs': totalDrugs,
      'totalStock': totalStock,
      'lowStockCount': lowStockCount,
      'expiringCount': expiringCount,
      'expiredCount': expiredCount,
      'inventoryValue': inventoryValue,
      'averageDrugPrice': totalDrugs > 0 ? inventoryValue / totalStock : 0.0,
    };
  }

  /// Get prescription statistics
  Map<String, dynamic> getPrescriptionStats() {
    final totalPrescriptions = _prescriptions.length;
    final pendingCount =
        _prescriptions.where((p) => p.status == 'pending').length;
    final dispensedCount =
        _prescriptions.where((p) => p.status == 'dispensed').length;
    final cancelledCount =
        _prescriptions.where((p) => p.status == 'cancelled').length;

    // Calculate revenue from dispensed prescriptions
    double totalRevenue = 0;
    for (final pres in _prescriptions.where((p) => p.status == 'dispensed')) {
      for (final item in pres.items) {
        final drug = _drugs
            .cast<Drug?>()
            .firstWhere((d) => d?.id == item['drugId'], orElse: () => null);
        if (drug != null) {
          totalRevenue += drug.price * (item['qty'] as int);
        }
      }
    }

    return {
      'totalPrescriptions': totalPrescriptions,
      'pendingCount': pendingCount,
      'dispensedCount': dispensedCount,
      'cancelledCount': cancelledCount,
      'totalRevenue': totalRevenue,
      'averageRevenuePerPrescription':
          dispensedCount > 0 ? totalRevenue / dispensedCount : 0.0,
    };
  }

  /// Get top prescribed drugs
  List<Map<String, dynamic>> getTopPrescribedDrugs({int limit = 5}) {
    final drugCounts = <String, int>{};
    for (final pres in _prescriptions) {
      for (final item in pres.items) {
        final drugId = item['drugId'] as String;
        drugCounts[drugId] = (drugCounts[drugId] ?? 0) + (item['qty'] as int);
      }
    }

    final sortedEntries = drugCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(limit).map((entry) {
      final drug = _drugs.firstWhere((d) => d.id == entry.key,
          orElse: () => Drug(id: entry.key, name: 'Unknown Drug', batch: '', expiry: DateTime.now(), stock: 0, price: 0.0));
      return {
        'drugId': entry.key,
        'drugName': drug.name,
        'totalPrescribed': entry.value,
        'totalQuantityDispensed': entry.value,
        'timesIssued': _prescriptions
            .where((p) => p.items.any((i) => i['drugId'] == entry.key))
            .length,
      };
    }).toList();
  }

  /// Search drugs by name (case-insensitive) - local filter
  List<Drug> searchDrugs(String query) {
    final lowerQuery = query.toLowerCase();
    return _drugs
        .where((d) => d.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Remote search (async). Returns remote inventory matches if available.
  Future<List<Drug>> searchDrugsRemote(String query, {String? businessId}) async {
    if (_repository == null || (businessId ?? _businessId) == null) return [];
    try {
      final results = await _repository!.searchDrugs(businessId: businessId ?? _businessId, query: query);
      return results
          .map((d) => Drug(
                id: d.id,
                name: d.name,
                batch: d.manufacturer,
                expiry: d.expiryDate,
                stock: d.quantity,
                price: d.price,
                costPrice: d.costPrice,
                prescriptions: d.prescriptions,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Filter drugs by batch number
  List<Drug> getDrugsByBatch(String batchNumber) {
    return _drugs.where((d) => d.batch == batchNumber).toList();
  }

  /// Get all patients with their prescription count
  List<Map<String, dynamic>> getPatientsWithPrescriptionCount() {
    return _patients.map((patient) {
      final prescriptionCount =
          _prescriptions.where((p) => p.patientId == patient.id).length;
      return {
        'id': patient.id,
        'name': patient.name,
        'phone': patient.phone,
        'dateOfBirth': patient.dateOfBirth,
        'age': calculateAge(patient.dateOfBirth),
        'prescriptionCount': prescriptionCount,
        'activeTreatmentCount': getActivePatientTreatments(patient.id).length,
        'completedTreatmentCount':
            getPatientTreatmentHistory(patient.id).length,
        'lastPrescriptionDate':
            _prescriptions.where((p) => p.patientId == patient.id).isEmpty
                ? null
                : _prescriptions
                    .where((p) => p.patientId == patient.id)
                    .fold<DateTime?>(
                        null,
                        (prev, p) => prev == null || p.createdAt.isAfter(prev)
                            ? p.createdAt
                            : prev),
        'lastTreatmentDate': _treatments.where((t) => t.patientId == patient.id)
                .isEmpty
            ? null
            : _treatments
                .where((t) => t.patientId == patient.id)
                .fold<DateTime?>(
                    null,
                    (prev, t) =>
                        prev == null || t.startDate.isAfter(prev)
                            ? t.startDate
                            : prev),
      };
    }).toList();
  }

  /// Add a new patient (optionally persist remotely)
  Future<void> addPatient(Patient patient, {bool persist = false, String? businessId}) async {
    _patients.add(patient);
    notifyListeners();
    await _saveLocalPatients();
    if (persist && _repository != null) {
      try {
        await _repository!.addPatient({
          'id': patient.id,
          'name': patient.name,
          'phone': patient.phone,
          'email': patient.email,
          'address': patient.address,
          'dateOfBirth': patient.dateOfBirth?.toIso8601String(),
          'allergies': patient.allergies,
          'bloodType': patient.bloodType,
          'additionalNotes': patient.additionalNotes,
        }, businessId: businessId);
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to persist patient: $e');
      }
    }
  }

  /// Update patient information (optionally persist remotely)
  Future<void> updatePatient(String patientId, {
    String? name,
    String? phone,
    String? email,
    String? address,
    DateTime? dateOfBirth,
    String? allergies,
    String? bloodType,
    String? additionalNotes,
    bool persist = false,
    String? businessId
  }) async {
    final patient = _patients.firstWhere((p) => p.id == patientId,
        orElse: () => throw Exception('Patient not found'));
    // Patients are immutable, so we need to remove and re-add
    _patients.remove(patient);
    _patients.add(Patient(
      id: patientId,
      name: name ?? patient.name,
      phone: phone ?? patient.phone,
      email: email ?? patient.email,
      address: address ?? patient.address,
      dateOfBirth: dateOfBirth ?? patient.dateOfBirth,
      allergies: allergies ?? patient.allergies,
      bloodType: bloodType ?? patient.bloodType,
      additionalNotes: additionalNotes ?? patient.additionalNotes,
    ));
    notifyListeners();
    await _saveLocalPatients();
    if (persist && _repository != null) {
      try {
        await _repository!.updatePatient(patientId, {
          'name': name ?? patient.name,
          'phone': phone ?? patient.phone,
          'email': email ?? patient.email,
          'address': address ?? patient.address,
          'businessId': businessId,
          'dateOfBirth': (dateOfBirth ?? patient.dateOfBirth)?.toIso8601String(),
          'allergies': allergies ?? patient.allergies,
          'bloodType': bloodType ?? patient.bloodType,
          'additionalNotes': additionalNotes ?? patient.additionalNotes,
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to update patient remotely: $e');
      }
    }
  }

  /// Cancel a prescription
  Future<void> cancelPrescription(String prescriptionId,
      {bool persist = true, String? businessId, String? userId}) async {
    final pres = _prescriptions.firstWhere((p) => p.id == prescriptionId,
        orElse: () => throw Exception('Prescription not found'));

    if (pres.status == 'dispensed') {
      throw Exception('Cannot cancel a dispensed prescription');
    }

    pres.status = 'cancelled';
    notifyListeners();

    if (persist && _repository != null) {
      await _repository!.logAudit({
        'action': 'prescription_cancelled',
        'prescriptionId': pres.id,
        'userId': userId ?? 'system',
      });

      // Persist cancellation to remote prescription document
      try {
        await _repository!.updatePrescription(pres.id, {
          'status': 'cancelled',
          'cancelledAt': DateTime.now().toIso8601String(),
          'cancelledBy': userId ?? 'system',
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to update prescription cancellation on remote: $e');
      }
    }
  }

  /// Check for critical drug interactions (basic implementation)
  List<Map<String, dynamic>> checkDrugInteractions(List<String> drugIds) {
    // Simple interaction database (in real app, this would be from Firestore)
    final knownInteractions = {
      'aspirin|warfarin': {
        'severity': 'severe',
        'description': 'Increased bleeding risk'
      },
      'aspirin|ibuprofen': {
        'severity': 'moderate',
        'description': 'NSAID combination increases GI risk'
      },
      'metformin|alcohol': {
        'severity': 'moderate',
        'description': 'Lactic acidosis risk'
      },
      'lisinopril|potassium': {
        'severity': 'severe',
        'description': 'Hyperkalemia risk'
      },
    };

    final interactions = <Map<String, dynamic>>[];

    for (int i = 0; i < drugIds.length; i++) {
      for (int j = i + 1; j < drugIds.length; j++) {
        final key1 = '${drugIds[i]}|${drugIds[j]}'.toLowerCase();
        final key2 = '${drugIds[j]}|${drugIds[i]}'.toLowerCase();

        for (final knownKey in knownInteractions.keys) {
          if (knownKey == key1 || knownKey == key2) {
            final drug1 = _drugs.firstWhere((d) => d.id == drugIds[i]);
            final drug2 = _drugs.firstWhere((d) => d.id == drugIds[j]);
            interactions.add({
              'drug1': drug1.name,
              'drug2': drug2.name,
              'severity': knownInteractions[knownKey]!['severity'],
              'description': knownInteractions[knownKey]!['description'],
            });
          }
        }
      }
    }

    return interactions;
  }

  /// Get prescription history for a patient
  List<Prescription> getPatientPrescriptionHistory(String patientId) {
    return _prescriptions.where((p) => p.patientId == patientId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Calculate drug turnover rate (for inventory management)
  Map<String, dynamic> calculateDrugTurnover(String drugId,
      {Duration? period}) {
    final drug = _drugs.firstWhere((d) => d.id == drugId,
        orElse: () => throw Exception('Drug not found'));

    final startDate = period != null ? DateTime.now().subtract(period) : null;

    var timesDispensed = 0;
    var totalQuantityDispensed = 0;

    for (final pres in _prescriptions.where((p) => p.status == 'dispensed')) {
      if (startDate != null && pres.createdAt.isBefore(startDate)) continue;

      for (final item in pres.items) {
        if (item['drugId'] == drugId) {
          timesDispensed++;
          totalQuantityDispensed += item['qty'] as int;
        }
      }
    }

    return {
      'drugId': drugId,
      'drugName': drug.name,
      'timesDispensed': timesDispensed,
      'totalQuantityDispensed': totalQuantityDispensed,
      'currentStock': drug.stock,
      'turnoverRate':
          drug.stock > 0 ? totalQuantityDispensed / drug.stock : 0.0,
      'period': period?.toString() ?? 'All time',
    };
  }

  /// Generate inventory report
  Future<Map<String, dynamic>> generateInventoryReport(
      {String? businessId}) async {
    final stats = getInventoryStats();
    final lowStockDrugs = getLowStockDrugs();
    final expiringDrugs = getExpiringDrugs();
    final topDrugs = getTopPrescribedDrugs();

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'businessId': businessId,
      'stats': stats,
      'lowStockDrugs': lowStockDrugs
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'stock': d.stock,
                'batch': d.batch,
              })
          .toList(),
      'expiringDrugs': expiringDrugs
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'expiryDate': d.expiry.toIso8601String(),
                'daysUntilExpiry': d.expiry.difference(DateTime.now()).inDays,
                'stock': d.stock,
              })
          .toList(),
      'topPrescribedDrugs': topDrugs,
    };
  }

  /// Remove expired drugs from inventory
  Future<void> removeExpiredDrugs(
      {bool persist = true, String? businessId}) async {
    final expiredDrugs = getExpiredDrugs();

    for (final drug in expiredDrugs) {
      _drugs.remove(drug);

      if (persist && _repository != null) {
        await _repository!.logAudit({
          'action': 'expired_drug_removed',
          'drugId': drug.id,
          'drugName': drug.name,
          'expiryDate': drug.expiry.toIso8601String(),
          'businessId': businessId,
        });
      }
    }

    notifyListeners();
  }

  /// Update drug price
  Future<void> updateDrugPrice(String drugId, double newPrice,
      {bool persist = false, String? businessId}) async {
    final drug = _drugs.firstWhere((d) => d.id == drugId,
        orElse: () => throw Exception('Drug not found'));

    drug.price = newPrice;
    notifyListeners();
    await _saveLocalDrugs();

    if (persist && _repository != null) {
      await _syncDrugToRepository(drug, businessId: businessId);
      await _repository!.logAudit({
        'action': 'price_updated',
        'drugId': drugId,
        'newPrice': newPrice,
        'businessId': businessId,
      });
    }
  }

  // ==================== TREATMENT METHODS ====================

  /// Add a new treatment for a patient
  Future<void> addTreatment(Treatment treatment, {bool persist = false, String? businessId}) async {
    _treatments.add(treatment);
    notifyListeners();
    await _saveLocalTreatments();
    if (persist && _repository != null) {
      try {
        await _repository!.addTreatment({
          'id': treatment.id,
          'patientId': treatment.patientId,
          'name': treatment.name,
          'drugName': treatment.drugName,
          'dosage': treatment.dosage,
          'frequencyPerDay': treatment.frequencyPerDay,
          'durationDays': treatment.durationDays,
          'startDate': treatment.startDate.toIso8601String(),
          'endDate': treatment.endDate.toIso8601String(),
          'isActive': treatment.isActive,
          'administeredLog': treatment.administeredLog
              .map((e) => {
                    'date': (e['date'] as DateTime).toIso8601String(),
                    'userId': e['userId'],
                    'userName': e['userName'],
                  })
              .toList(),
        }, businessId: businessId);
      } catch (e) {
        if (kDebugMode) debugPrint('[PharmacyProvider] Failed to persist treatment: $e');
      }
    }
  }

  /// Get treatments for a patient
  List<Treatment> getPatientTreatments(String patientId) {
    return _treatments.where((t) => t.patientId == patientId).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  /// Get active treatments for a patient
  List<Treatment> getActivePatientTreatments(String patientId) {
    return _treatments.where((t) => t.patientId == patientId && t.isActive && !t.isCompleted).toList();
  }

  /// Mark treatment dose as administered. Records which staff member gave
  /// the dose (and when) so the patient's treatment log shows who
  /// administered each dose - the "attendance" / administration log
  /// requested in item #10 of the pharmacy update document.
  Future<void> administerTreatmentDose(String treatmentId, DateTime date,
      {bool persist = false,
      String? businessId,
      String? userId,
      String? userName}) async {
    final treatment = _treatments.firstWhere((t) => t.id == treatmentId,
        orElse: () => throw Exception('Treatment not found'));

    treatment.administeredLog.add({
      'date': date,
      'userId': userId,
      'userName': userName,
    });

    notifyListeners();
    await _saveLocalTreatments();

    if (persist && _repository != null) {
      final bid = businessId ?? _businessId;
      if (bid != null && bid.isNotEmpty) {
        await _repository!.updateTreatment(
          treatmentId,
          {
            'administeredLog': treatment.administeredLog
                .map((e) => {
                      'date': (e['date'] as DateTime).toIso8601String(),
                      'userId': e['userId'],
                      'userName': e['userName'],
                    })
                .toList(),
          },
          businessId: bid,
        );
      }
      await _repository!.logAudit({
        'action': 'treatment_dose_administered',
        'treatmentId': treatmentId,
        'patientId': treatment.patientId,
        'date': date.toIso8601String(),
        'userId': userId ?? 'system',
        'userName': userName,
        'businessId': businessId,
      });
    }
  }

  /// Complete a treatment
  Future<void> completeTreatment(String treatmentId,
      {bool persist = false, String? businessId, String? userId}) async {
    final treatment = _treatments.firstWhere((t) => t.id == treatmentId,
        orElse: () => throw Exception('Treatment not found'));

    treatment.isActive = false;
    notifyListeners();
    await _saveLocalTreatments();

    if (persist && _repository != null) {
      final bid = businessId ?? _businessId;
      if (bid != null && bid.isNotEmpty) {
        await _repository!.updateTreatment(
          treatmentId,
          {
            'isActive': false,
            'endDate': treatment.endDate.toIso8601String(),
          },
          businessId: bid,
        );
      }
      await _repository!.logAudit({
        'action': 'treatment_completed',
        'treatmentId': treatmentId,
        'patientId': treatment.patientId,
        'userId': userId ?? 'system',
        'businessId': businessId,
      });
    }
  }

  /// Get treatment history for a patient
  List<Treatment> getPatientTreatmentHistory(String patientId) {
    return _treatments.where((t) => t.patientId == patientId && !t.isActive).toList()
      ..sort((a, b) => b.endDate.compareTo(a.endDate));
  }
}

