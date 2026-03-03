import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:business_manager/services/notification_service.dart';
import 'package:business_manager/data/repositories/industry_specific/real_estate_repository.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/datetime_utils.dart';
import '../../../../services/device_logger_service.dart';

// ==================== MODELS ====================

class Property {
  final String id;
  final String title;
  final String description;
  final String location;
  final String propertyType; // residential, commercial, land
  final double price;
  final double area; // in square meters
  final int bedrooms;
  final int bathrooms;
  final int parking;
  final List<String> amenities;
  final List<String> imageUrls;
  final String status; // available, sold, rented
  final String? agentId;
  final String? agentName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.propertyType,
    required this.price,
    required this.area,
    required this.bedrooms,
    required this.bathrooms,
    required this.parking,
    required this.amenities,
    required this.imageUrls,
    required this.status,
    this.agentId,
    this.agentName,
    required this.createdAt,
    this.updatedAt,
  });

  Property.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        title = json['title'] ?? '',
        description = json['description'] ?? '',
        location = json['location'] ?? '',
        propertyType = json['propertyType'] ?? 'residential',
        price = (json['price'] ?? 0).toDouble(),
        area = (json['area'] ?? 0).toDouble(),
        bedrooms = json['bedrooms'] ?? 0,
        bathrooms = json['bathrooms'] ?? 0,
        parking = json['parking'] ?? 0,
        amenities = List<String>.from(json['amenities'] ?? []),
        imageUrls = List<String>.from(json['imageUrls'] ?? []),
        status = json['status'] ?? 'available',
        agentId = json['agentId'],
        agentName = json['agentName'],
        createdAt = parseTimestamp(json['createdAt']),
        updatedAt = json['updatedAt'] != null ? parseTimestamp(json['updatedAt']) : null;

  factory Property.empty() => Property(
        id: '',
        title: '',
        description: '',
        location: '',
        propertyType: 'residential',
        price: 0,
        area: 0,
        bedrooms: 0,
        bathrooms: 0,
        parking: 0,
        amenities: [],
        imageUrls: [],
        status: 'available',
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'propertyType': propertyType,
        'price': price,
        'area': area,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'parking': parking,
        'amenities': amenities,
        'imageUrls': imageUrls,
        'status': status,
        'agentId': agentId,
        'agentName': agentName,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class Tenant {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? propertyId;
  final String? leaseId;
  final String status; // active, inactive
  final String? documentUrl;
  final DateTime createdAt;

  Tenant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.propertyId,
    this.leaseId,
    required this.status,
    this.documentUrl,
    required this.createdAt,
  });

  Tenant.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        email = json['email'] ?? '',
        phone = json['phone'] ?? '',
        propertyId = json['propertyId'],
        leaseId = json['leaseId'],
        status = json['status'] ?? 'active',
        documentUrl = json['documentUrl'],
        createdAt = json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(
                json['createdAt'] ?? DateTime.now().toIso8601String());

  factory Tenant.empty() => Tenant(
        id: '',
        name: '',
        email: '',
        phone: '',
        status: 'active',
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'propertyId': propertyId,
        'leaseId': leaseId,
        'status': status,
        'documentUrl': documentUrl,
        'createdAt': createdAt,
      };
}

class Lease {
  final String id;
  final String propertyId;
  final String tenantId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double deposit;
  final String status; // active, expired, terminated
  final String? documentUrl;
  final DateTime createdAt;

  Lease({
    required this.id,
    required this.propertyId,
    required this.tenantId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.deposit,
    required this.status,
    this.documentUrl,
    required this.createdAt,
  });

  Lease.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        propertyId = json['propertyId'] ?? '',
        tenantId = json['tenantId'] ?? '',
        startDate = parseTimestamp(json['startDate']),
        endDate = parseTimestamp(json['endDate']),
        monthlyRent = (json['monthlyRent'] ?? 0).toDouble(),
        deposit = (json['deposit'] ?? 0).toDouble(),
        status = json['status'] ?? 'active',
        documentUrl = json['documentUrl'],
        createdAt = json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(
                json['createdAt'] ?? DateTime.now().toIso8601String());

  factory Lease.empty() => Lease(
        id: '',
        propertyId: '',
        tenantId: '',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        monthlyRent: 0,
        deposit: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'tenantId': tenantId,
        'startDate': startDate,
        'endDate': endDate,
        'monthlyRent': monthlyRent,
        'deposit': deposit,
        'status': status,
        'documentUrl': documentUrl,
        'createdAt': createdAt,
      };
}

class RentPayment {
  final String id;
  final String leaseId;
  final String tenantId;
  final double amount;
  final String paymentMethod;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // pending, paid, overdue
  final String? receiptUrl;
  final DateTime createdAt;

  RentPayment({
    required this.id,
    required this.leaseId,
    required this.tenantId,
    required this.amount,
    required this.paymentMethod,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.receiptUrl,
    required this.createdAt,
  });

  RentPayment.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        leaseId = json['leaseId'] ?? '',
        tenantId = json['tenantId'] ?? '',
        amount = (json['amount'] ?? 0).toDouble(),
        paymentMethod = json['paymentMethod'] ?? 'transfer',
        dueDate = parseTimestamp(json['dueDate']),
        paidDate = json['paidDate'] != null ? parseTimestamp(json['paidDate']) : null,
        status = json['status'] ?? 'pending',
        receiptUrl = json['receiptUrl'],
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'leaseId': leaseId,
        'tenantId': tenantId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'dueDate': dueDate,
        'paidDate': paidDate,
        'status': status,
        'receiptUrl': receiptUrl,
        'createdAt': createdAt,
      };
}

// Booking, Documents and Inventory models for typed provider
class Booking {
  final String id;
  final String title;
  final String propertyId;
  final String propertyName;
  final DateTime startAt;
  final DateTime? endAt;
  final String? notes;
  final DateTime createdAt;

  Booking(
      {required this.id,
      required this.title,
      required this.propertyId,
      required this.propertyName,
      required this.startAt,
      this.endAt,
      this.notes,
      required this.createdAt});

  Booking.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        title = json['title'] ?? '',
        propertyId = json['propertyId'] ?? '',
        propertyName = json['propertyName'] ?? '',
        startAt = parseTimestamp(json['startAt']),
        endAt = json['endAt'] != null ? parseTimestamp(json['endAt']) : null,
        notes = json['notes'],
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'propertyId': propertyId,
        'propertyName': propertyName,
        'startAt': startAt,
        'endAt': endAt,
        'notes': notes,
        'createdAt': createdAt,
      };
}

class DocumentItem {
  final String id;
  final String name;
  final String? propertyId;
  final String? url;
  final DateTime createdAt;

  DocumentItem(
      {required this.id,
      required this.name,
      this.propertyId,
      this.url,
      required this.createdAt});

  DocumentItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        propertyId = json['propertyId'],
        url = json['url'],
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'propertyId': propertyId,
        'url': url,
        'createdAt': createdAt
      };
}

class InventoryItem {
  final String id;
  final String name;
  final int qty;
  final String? location;
  final DateTime createdAt;

  InventoryItem(
      {required this.id,
      required this.name,
      required this.qty,
      this.location,
      required this.createdAt});

  InventoryItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        qty = (json['qty'] ?? 0) as int,
        location = json['location'],
        createdAt = json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(
                json['createdAt'] ?? DateTime.now().toIso8601String());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'qty': qty,
        'location': location,
        'createdAt': createdAt
      };
}

// ==================== PROVIDER ====================

class RealEstateProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Dio _dio;

  String _businessId; // Setable for compatibility
  final String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';
  // Point to the correct upload endpoint used by the server
  final String _uploadUrl =
      'https://globalthrivealliance.com/emailtemplate/upload.php';

  List<Property> _properties = [];
  List<Tenant> _tenants = [];
  List<Lease> _leases = [];
  List<RentPayment> _rentPayments = [];
  List<Booking> _bookings = [];
  List<DocumentItem> _documentsList = [];
  List<InventoryItem> _inventoryList = [];
  String _errorMessage = '';
  bool _isLoading = false;

  List<Property> get properties => _properties;
  List<Tenant> get tenants => _tenants;
  List<Lease> get leases => _leases;
  List<RentPayment> get rentPayments => _rentPayments;
  List<Booking> get bookings => _bookings;
  List<DocumentItem> get documents => _documentsList;
  List<InventoryItem> get inventory => _inventoryList;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  RealEstateProvider(
      {String businessId = 'demo', RealEstateRepository? repository})
      : _businessId = businessId {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Set the current business context for the provider
  void setBusinessId(String businessId) {
    _businessId = businessId;
    if (businessId.isNotEmpty) {
      // reload data for this business
      loadAll();
    }
  }

  /// Convenience method to load all relevant data sets at once
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadProperties(),
        loadTenants(),
        loadLeases(),
        loadRentPayments(),
        loadBookings(),
        loadDocuments(),
        loadInventory()
      ]);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== PROPERTIES ====================

  Future<void> loadProperties() async {
    try {
      _isLoading = true;
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('properties')
          .where('status', isNotEqualTo: 'deleted')
          .get();
      _properties =
          snapshot.docs.map((doc) => Property.fromJson(doc.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> addProperty(Property property) async {
    try {
      final collection = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('properties');
      final docRef =
          property.id.isEmpty ? collection.doc() : collection.doc(property.id);
      final id = docRef.id;
      final p = Property(
        id: id,
        title: property.title,
        description: property.description,
        location: property.location,
        propertyType: property.propertyType,
        price: property.price,
        area: property.area,
        bedrooms: property.bedrooms,
        bathrooms: property.bathrooms,
        parking: property.parking,
        amenities: property.amenities,
        imageUrls: property.imageUrls,
        status: property.status,
        agentId: property.agentId,
        agentName: property.agentName,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
      );
      await docRef.set(p.toJson());
      _properties.insert(0, p);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateProperty(Property property) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('properties')
          .doc(property.id)
          .update(property.toJson());
      final index = _properties.indexWhere((p) => p.id == property.id);
      if (index != -1) {
        _properties[index] = property;
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('properties')
          .doc(propertyId)
          .delete();
      _properties.removeWhere((p) => p.id == propertyId);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== IMAGE UPLOAD ====================

  Future<List<String>> uploadPropertyImages(List<dynamic> imageFiles,
      {void Function(int index, int sent, int total)? onProgress}) async {
    try {
      _isLoading = true;
      final List<String> urls = [];

      for (int i = 0; i < imageFiles.length; i++) {
        final item = imageFiles[i];
        late final MultipartFile multipart;
        late final String fileExtension;
        late final String mimeType;

        if (kIsWeb) {
          // Expecting XFile or bytes
          if (item is XFile) {
            final bytes = await item.readAsBytes();
            fileExtension = item.name.split('.').last.toLowerCase();
            mimeType = _getMimeType(fileExtension);
            multipart = MultipartFile.fromBytes(bytes,
                filename:
                    'property_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension',
                contentType: MediaType.parse(mimeType));
          } else if (item is List<int>) {
            // raw bytes with filename not provided
            fileExtension = 'jpg';
            mimeType = _getMimeType(fileExtension);
            multipart = MultipartFile.fromBytes(item,
                filename:
                    'property_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                contentType: MediaType.parse(mimeType));
          } else {
            // Unsupported web payload
            continue;
          }
        } else {
          // Native platforms: expect File
          if (item is File) {
            final file = item;
            fileExtension = file.path.split('.').last.toLowerCase();
            mimeType = _getMimeType(fileExtension);
            multipart = MultipartFile.fromFileSync(
              file.path,
              filename:
                  'property_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension',
              contentType: MediaType.parse(mimeType),
            );
          } else {
            // Try to handle XFile on non-web if passed accidentally
            if (item is XFile) {
              final bytes = await item.readAsBytes();
              fileExtension = item.name.split('.').last.toLowerCase();
              mimeType = _getMimeType(fileExtension);
              multipart = MultipartFile.fromBytes(bytes,
                  filename:
                      'property_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension',
                  contentType: MediaType.parse(mimeType));
            } else {
              continue;
            }
          }
        }

        final singleFormData = FormData();
        singleFormData.fields.add(MapEntry('api_key', _apiKey));
        singleFormData.files.add(MapEntry('image', multipart));

        final response = await _dio.post(
          _uploadUrl,
          data: singleFormData,
          options: Options(
            // Avoid sending Authorization header on the web (triggers preflight). The server
            // already accepts `api_key` in the form fields so we rely on that for web.
            headers: kIsWeb ? {} : {'Authorization': 'Bearer $_apiKey'},
          ),
          onSendProgress: (int sent, int total) {
            try {
              onProgress?.call(i, sent, total);
            } catch (_) {}
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data['urls'] is List) {
            urls.addAll(List<String>.from(data['urls']));
          } else if (data['url'] is String) {
            urls.add(data['url']);
          }
        } else {
          _errorMessage = 'Upload failed: ${response.statusCode}';
          notifyListeners();
          return [];
        }
      }
      _errorMessage = '';
      notifyListeners();
      return urls;
    } catch (e) {
      if (e is DioException) {
        final uri = e.requestOptions.uri.toString();
        debugPrint('Upload DioException when contacting $uri: ${e.message}');
        if (e.response == null) {
          _errorMessage = 'Upload failed: Network or CORS error contacting $uri';
        } else {
          _errorMessage =
              'Upload failed: ${e.message} (status ${e.response?.statusCode})';
        }
      } else {
        _errorMessage = 'Upload error: $e';
      }
      notifyListeners();
      return [];
    } finally {
      _isLoading = false;
    }
  }

  Future<String?> uploadPropertyDocument(File documentFile) async {
    try {
      _isLoading = true;
      final formData = FormData();
      formData.fields.add(MapEntry('api_key', _apiKey));

      final fileExtension = documentFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(fileExtension);

      formData.files.add(
        MapEntry(
          'attachments',
          MultipartFile.fromFileSync(
            documentFile.path,
            filename:
                'document_${DateTime.now().millisecondsSinceEpoch}.$fileExtension',
            contentType: MediaType.parse(mimeType),
          ),
        ),
      );

      final response = await _dio.post(
        _uploadUrl,
        data: formData,
        options: Options(
          // Avoid sending Authorization and manual Content-Type on web; rely on `api_key`
          // form field and let the browser set the multipart boundary.
          headers: kIsWeb ? {} : {'Authorization': 'Bearer $_apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        String? url;

        if (data['url'] is String) {
          url = data['url'];
        } else if (data['urls'] is List && (data['urls'] as List).isNotEmpty) {
          url = (data['urls'] as List)[0];
        }

        _errorMessage = '';
        notifyListeners();
        return url;
      } else {
        _errorMessage = 'Document upload failed: ${response.statusCode}';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Document upload error: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
    }
  }

  String _getMimeType(String extension) {
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'csv': 'text/csv',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  // ==================== TENANTS ====================

  Future<void> loadTenants() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('tenants')
          .where('status', isNotEqualTo: 'deleted')
          .get();
      _tenants =
          snapshot.docs.map((doc) => Tenant.fromJson(doc.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addTenant(Tenant tenant) async {
    try {
      final collection = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('tenants');
      final docRef = tenant.id.isEmpty ? collection.doc() : collection.doc(tenant.id);
      final id = docRef.id;
      final t = Tenant(
        id: id,
        name: tenant.name,
        email: tenant.email,
        phone: tenant.phone,
        propertyId: tenant.propertyId,
        leaseId: tenant.leaseId,
        status: tenant.status,
        documentUrl: tenant.documentUrl,
        createdAt: tenant.createdAt,
      );
      await docRef.set(t.toJson());
      _tenants.add(t);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTenant(Tenant tenant) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('tenants')
          .doc(tenant.id)
          .update(tenant.toJson());
      final index = _tenants.indexWhere((t) => t.id == tenant.id);
      if (index != -1) {
        _tenants[index] = tenant;
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTenant(String tenantId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('tenants')
          .doc(tenantId)
          .delete();
      _tenants.removeWhere((t) => t.id == tenantId);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== LEASES ====================

  Future<void> loadLeases() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('leases')
          .where('status', isNotEqualTo: 'deleted')
          .get();
      _leases = snapshot.docs.map((doc) => Lease.fromJson(doc.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addLease(Lease lease) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('leases')
          .doc(lease.id)
          .set(lease.toJson());
      _leases.add(lease);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== RENT PAYMENTS ====================

  Future<void> loadRentPayments() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('rent_payments')
          .get();
      _rentPayments =
          snapshot.docs.map((doc) => RentPayment.fromJson(doc.data())).toList();
      // schedule reminders for due rent payments
      try {
        await _scheduleRentReminders();
      } catch (_) {}
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> recordRentPayment(RentPayment payment) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('rent_payments')
          .doc(payment.id)
          .set(payment.toJson());
      _rentPayments.add(payment);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateRentPaymentStatus(String paymentId, String status,
      {DateTime? paidDate, String? receiptUrl, String? paymentMethod}) async {
    try {
      final docRef = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('rent_payments')
          .doc(paymentId);
      final Map<String, dynamic> updateData = {
        'status': status,
      };
      if (paidDate != null) updateData['paidDate'] = paidDate;
      if (receiptUrl != null) updateData['receiptUrl'] = receiptUrl;
      if (paymentMethod != null) updateData['paymentMethod'] = paymentMethod;
      await docRef.update(updateData);
      final idx = _rentPayments.indexWhere((p) => p.id == paymentId);
      if (idx != -1) {
        final p = _rentPayments[idx];
        final updated = RentPayment(
          id: p.id,
          leaseId: p.leaseId,
          tenantId: p.tenantId,
          amount: p.amount,
          paymentMethod: paymentMethod ?? p.paymentMethod,
          dueDate: p.dueDate,
          paidDate: paidDate ?? p.paidDate,
          status: status,
          receiptUrl: receiptUrl ?? p.receiptUrl,
          createdAt: p.createdAt,
        );
        _rentPayments[idx] = updated;
        if (status == 'paid') {
          try {
            final nid = _computeNotificationIdForPayment(updated.id);
            await NotificationService.instance.cancelNotification(nid);
          } catch (_) {}
        }
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== BOOKINGS ====================

  Future<void> loadBookings() async {
    try {
      _isLoading = true;
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('bookings')
          .get();
      _bookings = snapshot.docs.map((d) => Booking.fromJson(d.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveBooking(Booking booking) async {
    try {
      final collection = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('bookings');
      final docRef =
          booking.id.isEmpty ? collection.doc() : collection.doc(booking.id);
      final id = docRef.id;
      final b = Booking(
          id: id,
          title: booking.title,
          propertyId: booking.propertyId,
          propertyName: booking.propertyName,
          startAt: booking.startAt,
          endAt: booking.endAt,
          notes: booking.notes,
          createdAt: booking.createdAt);
      await docRef.set(b.toJson());
      final idx = _bookings.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _bookings[idx] = b;
      } else {
        _bookings.insert(0, b);
      }
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteBooking(String id) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('bookings')
          .doc(id)
          .delete();
      _bookings.removeWhere((b) => b.id == id);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== DOCUMENTS ====================

  Future<void> loadDocuments() async {
    try {
      _isLoading = true;
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('documents')
          .get();
      _documentsList =
          snapshot.docs.map((d) => DocumentItem.fromJson(d.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveDocument(DocumentItem doc) async {
    try {
      final collection = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('documents');
      final docRef = doc.id.isEmpty ? collection.doc() : collection.doc(doc.id);
      final id = docRef.id;
      final d = DocumentItem(
          id: id,
          name: doc.name,
          propertyId: doc.propertyId,
          url: doc.url,
          createdAt: doc.createdAt);
      await docRef.set(d.toJson());
      final idx = _documentsList.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _documentsList[idx] = d;
      } else {
        _documentsList.insert(0, d);
      }
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== INVENTORY ====================

  Future<void> loadInventory() async {
    try {
      _isLoading = true;
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .get();
      _inventoryList =
          snapshot.docs.map((d) => InventoryItem.fromJson(d.data())).toList();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    try {
      final collection = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory');
      final docRef =
          item.id.isEmpty ? collection.doc() : collection.doc(item.id);
      final id = docRef.id;
      final v = InventoryItem(
          id: id,
          name: item.name,
          qty: item.qty,
          location: item.location,
          createdAt: item.createdAt);
      await docRef.set(v.toJson());
      final idx = _inventoryList.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _inventoryList[idx] = v;
      } else {
        _inventoryList.insert(0, v);
      }
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteInventoryItem(String id) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(id)
          .delete();
      _inventoryList.removeWhere((x) => x.id == id);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ==================== UTILITIES ====================

  List<Property> getAvailableProperties() =>
      _properties.where((p) => p.status == 'available').toList();

  List<Property> getRentedProperties() =>
      _properties.where((p) => p.status == 'rented').toList();

  double getTotalPropertyValue() =>
      _properties.fold(0, (sum, p) => sum + p.price);

  double getTotalMonthlyRent() => _leases.fold(
      0, (sum, l) => l.status == 'active' ? sum + l.monthlyRent : sum);

  int getActiveTenants() => _tenants.where((t) => t.status == 'active').length;

  List<RentPayment> getOverduePayments() => _rentPayments
      .where((p) => p.status == 'overdue' && p.dueDate.isBefore(DateTime.now()))
      .toList();

  double getPendingRent() => _rentPayments
      .where((p) => p.status == 'pending')
      .fold(0, (sum, p) => sum + p.amount);

  double getCollectedRent(DateTime startDate, DateTime endDate) => _rentPayments
      .where((p) =>
          p.status == 'paid' &&
          p.paidDate != null &&
          p.paidDate!.isAfter(startDate) &&
          p.paidDate!.isBefore(endDate))
      .fold(0, (sum, p) => sum + p.amount);

  Future<void> _scheduleRentReminders() async {
    try {
      final now = DateTime.now();
      for (final p in _rentPayments) {
        if (p.status == 'pending') {
          final days = p.dueDate.difference(now).inDays;
          if (days >= 0 && days <= 7) {
            final notifyAt = p.dueDate.subtract(const Duration(days: 1));
            if (notifyAt.isAfter(now)) {
              final id = _computeNotificationIdForPayment(p.id);
              await NotificationService.instance.scheduleNotificationAt(
                  id: id,
                  title: 'Rent due soon',
                  body:
                      'Rent of ₦${p.amount.toStringAsFixed(0)} is due on ${p.dueDate.toLocal().toIso8601String().split('T').first}',
                  at: notifyAt);
            }
          }
        }
      }
    } catch (e) {
      // ignore scheduling errors
    }
  }

  int _computeNotificationIdForPayment(String paymentId) =>
      _businessId.hashCode ^ paymentId.hashCode;
}

