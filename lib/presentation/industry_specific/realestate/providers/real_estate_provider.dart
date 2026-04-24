import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:business_manager/services/notification_service.dart';
import 'package:business_manager/data/repositories/industry_specific/real_estate_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:business_manager/services/email_service.dart';

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
  final String? whatsapp;
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
    this.whatsapp,
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
        whatsapp = json['whatsapp'],
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
        'whatsapp': whatsapp,
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
  final String leaseType; // short_let, monthly_rent, yearly_rent
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
    required this.leaseType,
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
        leaseType = json['leaseType'] ?? 'monthly_rent',
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
        leaseType: 'monthly_rent',
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
        'leaseType': leaseType,
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
  final int durationMonths; // Number of months this payment covers
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
    required this.durationMonths,
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
        durationMonths = json['durationMonths'] ?? 1,
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
        'durationMonths': durationMonths,
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
  final String? paymentId;
  final String? url;
  final DateTime createdAt;

  DocumentItem(
      {required this.id,
      required this.name,
      this.propertyId,
      this.paymentId,
      this.url,
      required this.createdAt});

  DocumentItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        name = json['name'] ?? '',
        propertyId = json['propertyId'],
        paymentId = json['paymentId'],
        url = json['url'],
        createdAt = parseTimestamp(json['createdAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'propertyId': propertyId,
        'paymentId': paymentId,
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
  final EmailService _emailService = EmailService();
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

      // Send push notification for new property
      await notifyPropertyCreated(p);

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

  Future<Property?> getPropertyById(String propertyId) async {
    try {
      // First check if it's already loaded
      final existingProperty = _properties.firstWhere(
        (p) => p.id == propertyId,
        orElse: () => Property.empty(),
      );
      if (existingProperty.id.isNotEmpty) {
        return existingProperty;
      }

      // If not loaded, fetch from Firestore
      final doc = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('properties')
          .doc(propertyId)
          .get();

      if (doc.exists) {
        final property = Property.fromJson(doc.data()!);
        // Add to loaded properties to avoid future fetches
        _properties.add(property);
        return property;
      }

      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  // ==================== DOCUMENT UPLOAD ====================

  Future<List<String>> uploadPropertyDocuments(List<dynamic> documentFiles,
      {void Function(int index, int sent, int total)? onProgress}) async {
    try {
      _isLoading = true;
      final List<String> urls = [];

      for (int i = 0; i < documentFiles.length; i++) {
        final item = documentFiles[i];
        late final MultipartFile multipart;
        late final String fileExtension;
        late final String mimeType;

        if (kIsWeb) {
          // Expecting PlatformFile or bytes
          if (item is PlatformFile && item.bytes != null) {
            final bytes = item.bytes!;
            fileExtension = item.extension ?? 'pdf';
            mimeType = _getDocumentMimeType(fileExtension);
            multipart = MultipartFile.fromBytes(bytes,
                filename: '${item.name}',
                contentType: MediaType.parse(mimeType));
          } else if (item is List<int>) {
            // raw bytes
            fileExtension = 'pdf';
            mimeType = _getDocumentMimeType(fileExtension);
            multipart = MultipartFile.fromBytes(item,
                filename: 'document_${DateTime.now().millisecondsSinceEpoch}_$i.pdf',
                contentType: MediaType.parse(mimeType));
          } else {
            continue;
          }
        } else {
          // Mobile/desktop - File
          if (item is File) {
            final bytes = await item.readAsBytes();
            fileExtension = item.path.split('.').last.toLowerCase();
            mimeType = _getDocumentMimeType(fileExtension);
            multipart = MultipartFile.fromBytes(bytes,
                filename: 'document_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension',
                contentType: MediaType.parse(mimeType));
          } else {
            continue;
          }
        }

        final formData = FormData.fromMap({
          'file': multipart,
          'api_key': _apiKey,
        });

        final response = await _dio.post(
          _uploadUrl,
          data: formData,
          options: Options(
            headers: kIsWeb ? {} : {'Authorization': 'Bearer $_apiKey'},
          ),
          onSendProgress: onProgress != null ? (sent, total) => onProgress(i, sent, total) : null,
        );

        if (response.statusCode == 200) {
          final data = response.data;
          String? url;

          if (data['url'] is String) {
            url = data['url'];
          } else if (data['urls'] is List && (data['urls'] as List).isNotEmpty) {
            url = (data['urls'] as List)[0];
          }

          if (url != null) {
            urls.add(url);
          }
        }
      }

      _errorMessage = '';
      notifyListeners();
      return urls;
    } catch (e) {
      _errorMessage = 'Document upload error: $e';
      notifyListeners();
      return [];
    } finally {
      _isLoading = false;
    }
  }

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

  // ==================== PUSH NOTIFICATIONS ====================

  Future<void> sendPropertyNotification({
    required String title,
    required String body,
    required String propertyId,
    String? tenantId,
    String? agentId,
    Map<String, String>? additionalData,
  }) async {
    try {
      // Get target users (tenants and agents)
      List<String> targetUserIds = [];

      if (tenantId != null) {
        targetUserIds.add(tenantId);
      }

      if (agentId != null) {
        targetUserIds.add(agentId);
      }

      // If no specific targets, send to all users (for property updates)
      if (targetUserIds.isEmpty) {
        // Get all users from Firestore
        final usersSnapshot = await _firestore.collection('users').get();
        targetUserIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      }

      // Send push notifications to each target user
      for (final userId in targetUserIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          final data = {
            'type': 'property_notification',
            'propertyId': propertyId,
            'userId': userId,
            'timestamp': DateTime.now().toIso8601String(),
            ...?additionalData,
          };

          await _sendPushNotificationToUser(
            token: fcmToken,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      // Ignore notification errors
      debugPrint('Failed to send property notification: $e');
    }
  }

  Future<void> _sendPushNotificationToUser({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Store notification in Firestore for cloud function to pick up
      await _firestore.collection('push_notifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'scheduledFor': FieldValue.serverTimestamp(),
        'type': 'property',
        'businessId': _businessId,
      });
    } catch (e) {
      debugPrint('Failed to queue push notification: $e');
    }
  }

  // Send notification when property is created
  Future<void> notifyPropertyCreated(Property property) async {
    await sendPropertyNotification(
      title: 'New Property Listed',
      body: '${property.title} is now available at ${property.location}',
      propertyId: property.id,
      additionalData: {
        'action': 'property_created',
        'propertyType': property.propertyType,
        'price': property.price.toString(),
      },
    );
  }

  // Send notification when property is updated
  Future<void> notifyPropertyUpdated(Property property) async {
    await sendPropertyNotification(
      title: 'Property Updated',
      body: '${property.title} has been updated',
      propertyId: property.id,
      additionalData: {
        'action': 'property_updated',
        'status': property.status,
      },
    );
  }

  // Send notification when tenant is assigned to property
  Future<void> notifyTenantAssigned(Property property, String tenantId, String tenantName) async {
    await sendPropertyNotification(
      title: 'Tenant Assigned',
      body: '${tenantName} has been assigned to ${property.title}',
      propertyId: property.id,
      tenantId: tenantId,
      additionalData: {
        'action': 'tenant_assigned',
        'tenantName': tenantName,
      },
    );
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
        whatsapp: tenant.whatsapp,
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
      unawaited(_sendTenantWelcomeEmail(t));
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

      // Check for expired leases
      final now = DateTime.now();
      for (final lease in _leases) {
        if (lease.status == 'active' && lease.endDate.isBefore(now)) {
          await updateLeaseStatus(lease.id, 'expired');
        }
      }

      _errorMessage = '';
      notifyListeners();
      unawaited(_sendLeaseCreatedEmail(lease));
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

      // Update property status to 'rented'
      final propertyIndex = _properties.indexWhere((p) => p.id == lease.propertyId);
      if (propertyIndex != -1) {
        final property = _properties[propertyIndex];
        final updatedProperty = Property(
          id: property.id,
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
          status: 'rented',
          agentId: property.agentId,
          agentName: property.agentName,
          createdAt: property.createdAt,
          updatedAt: DateTime.now(),
        );
        await updateProperty(updatedProperty);
      }

      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateLeaseStatus(String leaseId, String status) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('leases')
          .doc(leaseId)
          .update({'status': status});

      final index = _leases.indexWhere((l) => l.id == leaseId);
      if (index != -1) {
        final lease = _leases[index];
        final updatedLease = Lease(
          id: lease.id,
          propertyId: lease.propertyId,
          tenantId: lease.tenantId,
          startDate: lease.startDate,
          endDate: lease.endDate,
          monthlyRent: lease.monthlyRent,
          deposit: lease.deposit,
          leaseType: lease.leaseType,
          status: status,
          documentUrl: lease.documentUrl,
          createdAt: lease.createdAt,
        );
        _leases[index] = updatedLease;

        // If lease is terminated or expired, update property status to available
        if (status == 'terminated' || status == 'expired') {
          final propertyIndex = _properties.indexWhere((p) => p.id == lease.propertyId);
          if (propertyIndex != -1) {
            final property = _properties[propertyIndex];
            final updatedProperty = Property(
              id: property.id,
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
              status: 'available',
              agentId: property.agentId,
              agentName: property.agentName,
              createdAt: property.createdAt,
              updatedAt: DateTime.now(),
            );
            await updateProperty(updatedProperty);
          }
        }
      }

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
      if (payment.status.toLowerCase() == 'paid') {
        unawaited(_sendRentReceiptEmail(payment));
      }
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
          durationMonths: p.durationMonths,
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
          unawaited(_sendRentReceiptEmail(updated));
        }
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _sendTenantWelcomeEmail(Tenant tenant) async {
    try {
      final recipient = tenant.email.trim();
      if (recipient.isEmpty) return;

      final businessContext = await _loadBusinessEmailContext();
      await _emailService.sendTenantWelcomeEmail(
        recipient,
        {
          'businessName': businessContext['businessName'] ?? 'Manage Care',
          'tenantName': tenant.name,
          'propertyTitle': _propertyTitleForId(tenant.propertyId),
          'contactEmail': businessContext['businessEmail'],
          'contactPhone': businessContext['businessPhone'],
          'whatsapp': tenant.whatsapp,
        },
      );
    } catch (e) {
      debugPrint('Error sending tenant welcome email: $e');
    }
  }

  Future<void> _sendLeaseCreatedEmail(Lease lease) async {
    try {
      final tenant = _tenantForId(lease.tenantId);
      final recipient = tenant.email.trim();
      if (recipient.isEmpty) return;

      final propertyTitle = _propertyTitleForId(lease.propertyId);
      final businessContext = await _loadBusinessEmailContext();

      await _emailService.sendLeaseCreatedEmail(
        recipient,
        {
          'businessName': businessContext['businessName'] ?? 'Manage Care',
          'tenantName': tenant.name,
          'propertyTitle':
              propertyTitle.isNotEmpty ? propertyTitle : 'Assigned Property',
          'leaseType': lease.leaseType,
          'startDate': lease.startDate.toIso8601String(),
          'endDate': lease.endDate.toIso8601String(),
          'monthlyRent': lease.monthlyRent,
          'deposit': lease.deposit,
          'contactEmail': businessContext['businessEmail'],
          'contactPhone': businessContext['businessPhone'],
        },
      );
    } catch (e) {
      debugPrint('Error sending lease created email: $e');
    }
  }

  Future<void> _sendRentReceiptEmail(RentPayment payment) async {
    try {
      final tenant = _tenantForId(payment.tenantId);
      final lease = _leaseForId(payment.leaseId);
      final propertyTitle = _propertyTitleForId(lease.propertyId);
      final businessContext = await _loadBusinessEmailContext();

      final emailData = {
        'businessName': businessContext['businessName'] ?? 'Manage Care',
        'tenantName': tenant.name.isNotEmpty ? tenant.name : 'Tenant',
        'propertyTitle':
            propertyTitle.isNotEmpty ? propertyTitle : 'Assigned Property',
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'paidDate': (payment.paidDate ?? DateTime.now()).toIso8601String(),
        'durationMonths': payment.durationMonths,
        'nextDueDate': payment.dueDate
            .add(Duration(days: 30 * (payment.durationMonths <= 0 ? 1 : payment.durationMonths)))
            .toIso8601String(),
        'receiptUrl': payment.receiptUrl,
      };

      final tenantEmail = tenant.email.trim();
      if (tenantEmail.isNotEmpty) {
        await _emailService.sendRentReceiptEmail(tenantEmail, emailData);
      }

      final businessEmail =
          (businessContext['businessEmail']?.toString() ?? '').trim();
      if (businessEmail.isNotEmpty &&
          businessEmail.toLowerCase() != tenantEmail.toLowerCase()) {
        await _emailService.sendRentReceiptEmail(businessEmail, emailData);
      }
    } catch (e) {
      debugPrint('Error sending rent receipt email: $e');
    }
  }

  Future<Map<String, String?>> _loadBusinessEmailContext() async {
    try {
      final doc = await _firestore.collection('businesses').doc(_businessId).get();
      final data = doc.data() ?? <String, dynamic>{};
      return {
        'businessName':
            data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : 'Manage Care',
        'businessEmail': data['email']?.toString(),
        'businessPhone': data['phone']?.toString(),
      };
    } catch (e) {
      debugPrint('Error loading business email context: $e');
      return {
        'businessName': 'Manage Care',
        'businessEmail': null,
        'businessPhone': null,
      };
    }
  }

  Tenant _tenantForId(String tenantId) {
    return _tenants.firstWhere(
      (tenant) => tenant.id == tenantId,
      orElse: Tenant.empty,
    );
  }

  Lease _leaseForId(String leaseId) {
    return _leases.firstWhere(
      (lease) => lease.id == leaseId,
      orElse: Lease.empty,
    );
  }

  String _propertyTitleForId(String? propertyId) {
    if (propertyId == null || propertyId.isEmpty) return '';
    final property = _properties.firstWhere(
      (item) => item.id == propertyId,
      orElse: Property.empty,
    );
    return property.title;
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
          // Find the lease to determine reminder timing based on lease type
          final lease = _leases.firstWhere(
            (l) => l.id == p.leaseId,
            orElse: () => Lease.empty(),
          );

          final reminderDaysBefore = lease.leaseType == 'short_let' ? 1 : 30;
          final notifyAt = p.dueDate.subtract(Duration(days: reminderDaysBefore));
          final days = p.dueDate.difference(now).inDays;

          if (notifyAt.isAfter(now)) {
            final id = _computeNotificationIdForPayment(p.id);

              // Schedule local notification for owner
              await NotificationService.instance.scheduleNotificationAt(
                  id: id,
                  title: 'Rent Due Soon - Owner Reminder',
                  body:
                      'Rent of ₦${p.amount.toStringAsFixed(0)} is due on ${p.dueDate.toLocal().toIso8601String().split('T').first}',
                  at: notifyAt);

              // Also schedule push notification for owner
              await _scheduleOwnerRentReminder(p, days < 0 ? 0 : days);

              // Also schedule push notification if tenant has FCM token
              await _schedulePushRentReminder(p, days < 0 ? 0 : days);
            }
          }

          // Send immediate notification for overdue payments
          if (p.dueDate.isBefore(now.subtract(const Duration(days: 1)))) {
            await _sendOverdueRentNotification(p);
            await _sendOwnerOverdueNotification(p);
          }
        }

    } catch (e) {
      // ignore scheduling errors
    }
  }

  Future<void> _schedulePushRentReminder(RentPayment payment, int daysUntilDue) async {
    try {
      // Find the tenant for this payment
      final tenant = _tenants.firstWhere(
        (t) => t.id == payment.tenantId,
        orElse: () => Tenant.empty(),
      );

      if (tenant.id.isEmpty || tenant.email.isEmpty) return;

      // Get tenant's FCM token from Firestore
      final userDoc = await _firestore.collection('users').doc(tenant.email).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) return;

      String title;
      String body;

      if (daysUntilDue == 0) {
        title = 'Rent Due Today';
        body = 'Your rent payment of ₦${payment.amount.toStringAsFixed(0)} is due today for ${payment.leaseId}';
      } else if (daysUntilDue == 1) {
        title = 'Rent Due Tomorrow';
        body = 'Your rent payment of ₦${payment.amount.toStringAsFixed(0)} will be due tomorrow for ${payment.leaseId}';
      } else {
        title = 'Rent Reminder';
        body = 'Your rent payment of ₦${payment.amount.toStringAsFixed(0)} is due in $daysUntilDue days for ${payment.leaseId}';
      }

      // Send push notification via FCM
      await _sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'rent_reminder',
          'paymentId': payment.id,
          'leaseId': payment.leaseId,
          'tenantId': payment.tenantId,
          'amount': payment.amount.toString(),
          'dueDate': payment.dueDate.toIso8601String(),
        },
      );
    } catch (e) {
      // Ignore push notification errors
    }
  }

  Future<void> _sendOverdueRentNotification(RentPayment payment) async {
    try {
      // Find the tenant for this payment
      final tenant = _tenants.firstWhere(
        (t) => t.id == payment.tenantId,
        orElse: () => Tenant.empty(),
      );

      if (tenant.id.isEmpty || tenant.email.isEmpty) return;

      // Get tenant's FCM token from Firestore
      final userDoc = await _firestore.collection('users').doc(tenant.email).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken != null) {
        final overdueDays = DateTime.now().difference(payment.dueDate).inDays;

        await _sendPushNotification(
          token: fcmToken,
          title: 'Rent Overdue',
          body: 'Your rent payment of ₦${payment.amount.toStringAsFixed(0)} is $overdueDays days overdue for ${payment.leaseId}',
          data: {
            'type': 'rent_overdue',
            'paymentId': payment.id,
            'leaseId': payment.leaseId,
            'tenantId': payment.tenantId,
            'amount': payment.amount.toString(),
            'dueDate': payment.dueDate.toIso8601String(),
            'overdueDays': overdueDays.toString(),
          },
        );
      }
    } catch (e) {
      // Ignore push notification errors
    }
  }

  Future<void> _scheduleOwnerRentReminder(RentPayment payment, int daysUntilDue) async {
    try {
      // Find the tenant and property for this payment
      final tenant = _tenants.firstWhere(
        (t) => t.id == payment.tenantId,
        orElse: () => Tenant.empty(),
      );

      final lease = _leases.firstWhere(
        (l) => l.id == payment.leaseId,
        orElse: () => Lease.empty(),
      );

      final property = _properties.firstWhere(
        (p) => p.id == lease.propertyId,
        orElse: () => Property.empty(),
      );

      if (property.id.isEmpty) return;

      String title;
      String body;

      if (daysUntilDue == 0) {
        title = 'Rent Due Today - ${property.title}';
        body = 'Rent payment of ₦${payment.amount.toStringAsFixed(0)} from ${tenant.name} is due today';
      } else if (daysUntilDue == 1) {
        title = 'Rent Due Tomorrow - ${property.title}';
        body = 'Rent payment of ₦${payment.amount.toStringAsFixed(0)} from ${tenant.name} will be due tomorrow';
      } else {
        title = 'Upcoming Rent Due - ${property.title}';
        body = 'Rent payment of ₦${payment.amount.toStringAsFixed(0)} from ${tenant.name} is due in $daysUntilDue days';
      }

      // Send push notification to business owner/admin users
      await _sendOwnerNotification(
        title: title,
        body: body,
        data: {
          'type': 'owner_rent_reminder',
          'paymentId': payment.id,
          'leaseId': payment.leaseId,
          'tenantId': payment.tenantId,
          'propertyId': property.id,
          'amount': payment.amount.toString(),
          'dueDate': payment.dueDate.toIso8601String(),
          'daysUntilDue': daysUntilDue.toString(),
        },
      );
    } catch (e) {
      // Ignore push notification errors
    }
  }

  Future<void> _sendOwnerOverdueNotification(RentPayment payment) async {
    try {
      // Find the tenant and property for this payment
      final tenant = _tenants.firstWhere(
        (t) => t.id == payment.tenantId,
        orElse: () => Tenant.empty(),
      );

      final lease = _leases.firstWhere(
        (l) => l.id == payment.leaseId,
        orElse: () => Lease.empty(),
      );

      final property = _properties.firstWhere(
        (p) => p.id == lease.propertyId,
        orElse: () => Property.empty(),
      );

      if (property.id.isEmpty) return;

      final overdueDays = DateTime.now().difference(payment.dueDate).inDays;

      await _sendOwnerNotification(
        title: 'Overdue Rent - ${property.title}',
        body: 'Rent payment of ₦${payment.amount.toStringAsFixed(0)} from ${tenant.name} is $overdueDays days overdue',
        data: {
          'type': 'owner_rent_overdue',
          'paymentId': payment.id,
          'leaseId': payment.leaseId,
          'tenantId': payment.tenantId,
          'propertyId': property.id,
          'amount': payment.amount.toString(),
          'dueDate': payment.dueDate.toIso8601String(),
          'overdueDays': overdueDays.toString(),
        },
      );
    } catch (e) {
      // Ignore push notification errors
    }
  }

  Future<void> _sendOwnerNotification({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Get all business users (owners/admins) for this business
      final businessUsers = await _firestore
          .collection('business_users')
          .where('businessId', isEqualTo: _businessId)
          .where('role', whereIn: ['owner', 'admin'])
          .get();

      for (final userDoc in businessUsers.docs) {
        final userId = userDoc.data()['userId'] as String?;
        if (userId == null) continue;

        // Get user's FCM token
        final userTokenDoc = await _firestore.collection('users').doc(userId).get();
        final fcmToken = userTokenDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          await _sendPushNotification(
            token: fcmToken,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      // Ignore notification sending errors
    }
  }

  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // This would typically use Firebase Cloud Messaging to send the notification
      // For now, we'll store it in Firestore to be picked up by a cloud function
      await _firestore.collection('notifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'scheduledFor': FieldValue.serverTimestamp(),
        'type': 'rent_reminder',
        'businessId': _businessId,
      });
    } catch (e) {
      // Ignore notification sending errors
    }
  }

  int _computeNotificationIdForPayment(String paymentId) =>
      _businessId.hashCode ^ paymentId.hashCode;

  int _computeNotificationIdForOwnerReminder(String paymentId) =>
      _businessId.hashCode ^ paymentId.hashCode ^ 'owner'.hashCode;

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg'; // fallback
    }
  }

  String _getDocumentMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      default:
        return 'application/octet-stream'; // fallback
    }
  }

  // ==================== OWNER RENT REMINDERS ====================

  /// Send reminder notifications to owner about pending rent payments
  Future<void> sendOwnerPendingRentReminders() async {
    try {
      final now = DateTime.now();
      for (final payment in _rentPayments) {
        if (payment.status == 'pending') {
          final daysUntilDue = payment.dueDate.difference(now).inDays;
          // Send reminder 3 days before due date and 1 day after due date
          if ((daysUntilDue >= 0 && daysUntilDue <= 3) || (daysUntilDue < 0 && daysUntilDue >= -7)) {
            await _sendOwnerRentReminder(payment, daysUntilDue);
          }
        }
      }
    } catch (e) {
      debugPrint('Error sending owner rent reminders: $e');
    }
  }

  /// Send specific reminder for a rent payment to owner
  Future<void> _sendOwnerRentReminder(RentPayment payment, int daysUntilDue) async {
    try {
      final tenant = _tenants.firstWhere(
        (t) => t.id == payment.tenantId,
        orElse: () => Tenant.empty(),
      );

      final lease = _leases.firstWhere(
        (l) => l.id == payment.leaseId,
        orElse: () => Lease.empty(),
      );

      final property = _properties.firstWhere(
        (p) => p.id == lease.propertyId,
        orElse: () => Property.empty(),
      );

      if (tenant.id.isEmpty || property.id.isEmpty) return;

      String title;
      String body;
      
      if (daysUntilDue > 0) {
        title = 'Upcoming Rent Payment Due';
        body = 'Tenant ${tenant.name} at ${property.title} has rent of ₦${payment.amount.toStringAsFixed(0)} due in $daysUntilDue days';
      } else if (daysUntilDue == 0) {
        title = 'Rent Due Today';
        body = 'Tenant ${tenant.name} at ${property.title} has rent of ₦${payment.amount.toStringAsFixed(0)} due today';
      } else {
        title = 'Rent Payment Overdue';
        body = 'Tenant ${tenant.name} at ${property.title} has overdue rent of ₦${payment.amount.toStringAsFixed(0)} (${-daysUntilDue} days late)';
      }

      // Store notification in Firestore for owner
      await _firestore.collection('businesses').doc(_businessId).collection('owner_notifications').add({
        'title': title,
        'body': body,
        'type': 'rent_reminder',
        'paymentId': payment.id,
        'leaseId': payment.leaseId,
        'tenantId': payment.tenantId,
        'propertyId': property.id,
        'amount': payment.amount,
        'daysUntilDue': daysUntilDue,
        'dueDate': payment.dueDate,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Send local notification to owner
      final id = _computeNotificationIdForOwnerReminder(payment.id);
      await NotificationService.instance.sendNotification(
        title,
        body,
        id: id,
      );
    } catch (e) {
      debugPrint('Error sending owner reminder: $e');
    }
  }

  /// Get rent history for a specific property
  List<RentPayment> getRentHistoryByProperty(String propertyId) {
    try {
      final propertyLeases = _leases.where((l) => l.propertyId == propertyId).map((l) => l.id).toList();
      final rentHistory = _rentPayments.where((p) => propertyLeases.contains(p.leaseId)).toList();
      rentHistory.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return rentHistory;
    } catch (e) {
      debugPrint('Error getting rent history: $e');
      return [];
    }
  }

  /// Get pending rent payments for a specific property
  List<RentPayment> getPendingRentByProperty(String propertyId) {
    try {
      final propertyLeases = _leases.where((l) => l.propertyId == propertyId).map((l) => l.id).toList();
      return _rentPayments.where((p) => propertyLeases.contains(p.leaseId) && p.status == 'pending').toList();
    } catch (e) {
      debugPrint('Error getting pending rent: $e');
      return [];
    }
  }

  /// Get overdue rent payments for a specific property
  List<RentPayment> getOverdueRentByProperty(String propertyId) {
    try {
      final propertyLeases = _leases.where((l) => l.propertyId == propertyId).map((l) => l.id).toList();
      return _rentPayments.where((p) => propertyLeases.contains(p.leaseId) && p.status == 'overdue').toList();
    } catch (e) {
      debugPrint('Error getting overdue rent: $e');
      return [];
    }
  }

  /// Get total collected rent for a specific property in a time period
  double getTotalCollectedRentByProperty(String propertyId, {DateTime? startDate, DateTime? endDate}) {
    try {
      final propertyLeases = _leases.where((l) => l.propertyId == propertyId).map((l) => l.id).toList();
      final paidPayments = _rentPayments.where((p) {
        if (!propertyLeases.contains(p.leaseId)) return false;
        if (p.status != 'paid' || p.paidDate == null) return false;
        if (startDate != null && p.paidDate!.isBefore(startDate)) return false;
        if (endDate != null && p.paidDate!.isAfter(endDate)) return false;
        return true;
      });
      return paidPayments.fold<double>(0, (sum, p) => sum + p.amount);
    } catch (e) {
      debugPrint('Error calculating collected rent: $e');
      return 0;
    }
  }

  /// Get tenant rent payment summary for a property
  Map<String, dynamic> getTenantRentSummary(String propertyId, String tenantId) {
    try {
      final propertyLeases = _leases.where((l) => l.propertyId == propertyId).map((l) => l.id).toList();
      final tenantPayments = _rentPayments.where((p) => propertyLeases.contains(p.leaseId) && p.tenantId == tenantId).toList();
      
      final totalAmount = tenantPayments.fold<double>(0, (sum, p) => sum + p.amount);
      final totalPaid = tenantPayments.where((p) => p.status == 'paid').fold<double>(0, (sum, p) => sum + p.amount);
      final totalPending = tenantPayments.where((p) => p.status == 'pending').fold<double>(0, (sum, p) => sum + p.amount);
      final totalOverdue = tenantPayments.where((p) => p.status == 'overdue').fold<double>(0, (sum, p) => sum + p.amount);
      final paymentCount = tenantPayments.length;
      final paidCount = tenantPayments.where((p) => p.status == 'paid').length;
      final overdueCount = tenantPayments.where((p) => p.status == 'overdue').length;
      
      return {
        'totalAmount': totalAmount,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'totalOverdue': totalOverdue,
        'paymentCount': paymentCount,
        'paidCount': paidCount,
        'pendingCount': paymentCount - paidCount - overdueCount,
        'overdueCount': overdueCount,
        'lastPaymentDate': tenantPayments.where((p) => p.status == 'paid').isEmpty 
            ? null 
            : tenantPayments.where((p) => p.status == 'paid').first.paidDate,
      };
    } catch (e) {
      debugPrint('Error getting tenant rent summary: $e');
      return {};
    }
  }

  /// Reset all provider state - called during logout to clear business data
  void reset() {
    _properties.clear();
    _tenants.clear();
    _leases.clear();
    _rentPayments.clear();
    _bookings.clear();
    _documentsList.clear();
    _inventoryList.clear();
    _errorMessage = '';
    print('[RealEstateProvider] State cleared for next business');
    notifyListeners();
  }
}
