import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'file_upload_service.dart';
import '../data/models/sale_model.dart';
import '../data/models/business_model.dart';
import '../data/models/user_model.dart';
import 'email_service.dart';
import 'export_service.dart';

/// Comprehensive data synchronization service
/// Handles: file exports, image uploads, Firestore sync, PHP API calls
class DataSyncService {
  static const String _uploadEndpoint =
      'https://globalthrivealliance.com/emailtemplate/upload.php';
  static const String _profileEndpoint =
      'https://globalthrivealliance.com/api/profile-sync.php';
  static const String _businessEndpoint =
      'https://globalthrivealliance.com/api/business-sync.php';
  static const String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();

  // Track sync status
  final Map<String, DateTime?> _lastSyncTimes = {};
  final Map<String, bool> _isSyncing = {};

  /// Upload user profile image to PHP endpoint and Firebase Storage
  Future<Map<String, dynamic>> uploadProfileImage({
    required String userId,
    required String businessId,
    required File imageFile,
    String? userEmail,
  }) async {
    try {
      // Upload to server using centralized FileUploadService
      final uploader = FileUploadService();
      final serverUrl = await uploader.uploadFile(imageFile);

      String? finalUrl = serverUrl;
      String? phpUrl;
      String? uploadError = uploader.lastError;

      // If server upload failed, attempt PHP endpoint as fallback
      if (finalUrl == null) {
        try {
          phpUrl = await _uploadProfileImageToPhp(imageFile, userId);
          finalUrl = phpUrl;
        } catch (e) {
          print('[DataSync] PHP fallback failed: $e');
        }
      }

      // If both methods failed, return an error and do not write null URLs to Firestore
      if (finalUrl == null) {
        final msg = uploadError ?? 'Upload failed for unknown reasons';
       print('[DataSync] Upload profile image failed: $msg');
        return {
          'success': false,
          'error': 'Failed to upload profile image: $msg',
        };
      }

      // Update Firestore user profile now that we have a valid URL
      await _firestore.collection('users').doc(userId).update({
        'profilePhotoUrl': finalUrl,
        'phpProfileUrl': finalUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firestore business profile
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('team')
          .doc(userId)
          .update({
        'profilePhotoUrl': finalUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      }).catchError((_) => null); // Ignore if doesn't exist

      return {
        'success': true,
        'serverUrl': finalUrl,
        'phpUrl': phpUrl,
        'message': 'Profile image uploaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to upload profile image: $e',
      };
    }
  }

  /// Upload profile image to PHP endpoint
  Future<String?> _uploadProfileImageToPhp(
      File imageFile, String userId) async {
    final uri = Uri.parse(_uploadEndpoint);
    final request = http.MultipartRequest('POST', uri);

    request.fields['api_key'] = _apiKey;
    request.fields['type'] = 'profile';
    request.fields['user_id'] = userId;

    final multipart =
        await http.MultipartFile.fromPath('image', imageFile.path);
    request.files.add(multipart);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
       print('[DataSync] uploadProfileImageToPhp response: $body');
        // Support either 'url' or 'urls' keys
        String? url;
        if (body['url'] is String) {
          url = body['url'] as String;
        } else if (body['urls'] is List && (body['urls'] as List).isNotEmpty) {
          url = (body['urls'] as List)[0] as String?;
        }

        if (url != null && !url.contains('/emailtemplate/')) {
          // Fix path: /uploads/... -> /emailtemplate/uploads/...
          url = url.replaceFirst('/uploads/', '/emailtemplate/uploads/');
        }
        return url;
      } catch (e) {
       print('[DataSync] Failed to parse PHP upload response: ${response.body}');
        return null;
      }
    }
   print('[DataSync] PHP upload returned status ${response.statusCode}: ${response.body}');
    return null;
  }

  /// Upload a subscription receipt to the server and PHP fallback endpoint
  /// Returns a map with 'success', 'serverUrl' (if available), 'phpUrl' (if PHP fallback succeeded) and 'error' on failure
  Future<Map<String, dynamic>> uploadReceipt({
    required File receiptFile,
    String? userId,
    String? businessId,
  }) async {
    try {
      final uploader = FileUploadService();
      final serverUrl = await uploader.uploadFile(receiptFile);

      String? finalUrl = serverUrl;
      String? phpUrl;
      String? uploadError = uploader.lastError;

      // If primary server upload failed, try PHP fallback
      if (finalUrl == null) {
        try {
          phpUrl = await _uploadReceiptToPhp(receiptFile, userId: userId, businessId: businessId);
          finalUrl = phpUrl;
        } catch (e) {
          print('[DataSync] PHP fallback for receipt failed: $e');
        }
      }

      if (finalUrl == null) {
        final msg = uploadError ?? 'Upload failed for unknown reasons';
        print('[DataSync] Upload receipt failed: $msg');
        return {
          'success': false,
          'error': 'Failed to upload receipt: $msg',
        };
      }

      return {
        'success': true,
        'serverUrl': finalUrl,
        'phpUrl': phpUrl,
        'message': 'Receipt uploaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to upload receipt: $e',
      };
    }
  }

  /// Upload receipt to PHP endpoint
  Future<String?> _uploadReceiptToPhp(File receiptFile, {String? userId, String? businessId}) async {
    final uri = Uri.parse(_uploadEndpoint);
    final request = http.MultipartRequest('POST', uri);

    request.fields['api_key'] = _apiKey;
    request.fields['type'] = 'subscription_receipt';
    if (userId != null) request.fields['user_id'] = userId;
    if (businessId != null) request.fields['business_id'] = businessId;

    final multipart = await http.MultipartFile.fromPath('image', receiptFile.path);
    request.files.add(multipart);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        print('[DataSync] uploadReceiptToPhp response: $body');
        String? url;
        if (body['url'] is String) {
          url = body['url'] as String;
        } else if (body['urls'] is List && (body['urls'] as List).isNotEmpty) {
          url = (body['urls'] as List)[0] as String?;
        }

        if (url != null && !url.contains('/emailtemplate/')) {
          url = url.replaceFirst('/uploads/', '/emailtemplate/uploads/');
        }
        return url;
      } catch (e) {
        print('[DataSync] Failed to parse PHP upload response: ${response.body}');
        return null;
      }
    }
    print('[DataSync] PHP upload returned status ${response.statusCode}: ${response.body}');
    return null;
  }

  /// Export and save sales data to local storage
  Future<Map<String, dynamic>> exportSalesData({
    required String businessId,
    required List<SaleModel> sales,
    required String format, // 'csv', 'json', 'tsv', 'pdf'
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    bool uploadToServer = true,
  }) async {
    try {
      String fileContent;
      String fileExtension;

      // Generate export based on format
      switch (format.toLowerCase()) {
        case 'csv':
          fileContent = await ExportService.exportToCSV(sales);
          fileExtension = 'csv';
          break;
        case 'json':
          fileContent = await ExportService.exportToJSON(sales);
          fileExtension = 'json';
          break;
        case 'tsv':
          fileContent = await ExportService.exportToTSV(sales);
          fileExtension = 'tsv';
          break;
        default:
          return {
            'success': false,
            'error': 'Unsupported format: $format',
          };
      }

      // Create file
      final now = DateTime.now();
      final fileName =
          'sales_export_${businessId}_${now.millisecondsSinceEpoch}.$fileExtension';
      final file = File('${(await _getLocalPath())}/$fileName');
      await file.writeAsString(fileContent);

      // Save metadata to Firestore
      final metadata = {
        'businessId': businessId,
        'userId': userId,
        'fileName': fileName,
        'format': fileExtension,
        'recordCount': sales.length,
        'fileSize': await file.length(),
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'localPath': file.path,
      };

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('exports')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set(metadata);

      // Upload to server if enabled
      String? serverUrl;
      if (uploadToServer) {
        serverUrl = await _uploadExportFileToServer(file, businessId, userId);
      }

      return {
        'success': true,
        'fileName': fileName,
        'filePath': file.path,
        'fileSize': await file.length(),
        'recordCount': sales.length,
        'serverUrl': serverUrl,
        'message': 'Sales data exported successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to export sales data: $e',
      };
    }
  }

  /// Upload export file to PHP server
  Future<String?> _uploadExportFileToServer(
      File file, String businessId, String userId) async {
    try {
      final uri = Uri.parse(_uploadEndpoint);
      final request = http.MultipartRequest('POST', uri);

      request.fields['api_key'] = _apiKey;
      request.fields['type'] = 'export';
      request.fields['business_id'] = businessId;
      request.fields['user_id'] = userId;

      final multipart = await http.MultipartFile.fromPath('file', file.path,
          filename: file.path.split('/').last);
      request.files.add(multipart);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return body['url'];
        } catch (e) {
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Server upload failed: $e');
      return null;
    }
  }

  /// Sync all user data to PHP endpoint
  Future<Map<String, dynamic>> syncUserDataToPhp({
    required String userId,
    required String businessId,
    required UserModel? userModel,
    required BusinessModel? businessModel,
  }) async {
    try {
      final syncKey = 'user_$userId';
      _isSyncing[syncKey] = true;

      final payload = {
        'userId': userId,
        'businessId': businessId,
        'user': userModel?.toJson() ?? {},
        'business': businessModel?.toJson() ?? {},
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      final uri = Uri.parse(_profileEndpoint);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _lastSyncTimes[syncKey] = DateTime.now();
        _isSyncing[syncKey] = false;

        return {
          'success': true,
          'message': 'User data synced successfully',
          'response': body,
        };
      }

      _isSyncing[syncKey] = false;
      return {
        'success': false,
        'error': 'Server returned status code: ${response.statusCode}',
      };
    } catch (e) {
      _isSyncing['user_$userId'] = false;
      return {
        'success': false,
        'error': 'Failed to sync user data: $e',
      };
    }
  }

  /// Sync business data to PHP endpoint
  Future<Map<String, dynamic>> syncBusinessDataToPhp({
    required String businessId,
    required BusinessModel businessModel,
    required String userId,
  }) async {
    try {
      final syncKey = 'business_$businessId';
      _isSyncing[syncKey] = true;

      final payload = {
        'businessId': businessId,
        'userId': userId,
        'business': businessModel.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      final uri = Uri.parse(_businessEndpoint);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _lastSyncTimes[syncKey] = DateTime.now();
        _isSyncing[syncKey] = false;

        return {
          'success': true,
          'message': 'Business data synced successfully',
          'response': body,
        };
      }

      _isSyncing[syncKey] = false;
      return {
        'success': false,
        'error': 'Server returned status code: ${response.statusCode}',
      };
    } catch (e) {
      _isSyncing['business_$businessId'] = false;
      return {
        'success': false,
        'error': 'Failed to sync business data: $e',
      };
    }
  }

  /// Comprehensive data sync to Firestore
  Future<Map<String, dynamic>> syncToFirestore({
    required String businessId,
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update user profile
      if (data.containsKey('userProfile')) {
        batch.update(
          _firestore.collection('users').doc(userId),
          {
            ...data['userProfile'],
            'lastSyncAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // Update business settings
      if (data.containsKey('businessSettings')) {
        batch.update(
          _firestore.collection('businesses').doc(businessId),
          {
            ...data['businessSettings'],
            'lastSyncAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // Update sales
      if (data.containsKey('sales') && data['sales'] is List) {
        final salesCol = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales');
        for (final sale in data['sales']) {
          batch.set(
            salesCol.doc(sale['id']),
            {
              ...sale,
              'syncedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      // Commit batch
      await batch.commit();

      return {
        'success': true,
        'message': 'Data synced to Firestore successfully',
        'itemsUpdated': _countDataItems(data),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to sync to Firestore: $e',
      };
    }
  }

  /// Get last sync time for a key
  DateTime? getLastSyncTime(String key) {
    return _lastSyncTimes[key];
  }

  /// Check if currently syncing
  bool isSyncing(String key) {
    return _isSyncing[key] ?? false;
  }

  /// Get local app documents path
  Future<String> _getLocalPath() async {
    final directory = Directory.systemTemp;
    final appDir = Directory('${directory.path}/manage_care_exports');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir.path;
  }

  /// Count total data items in sync payload
  int _countDataItems(Map<String, dynamic> data) {
    int count = 0;
    if (data.containsKey('userProfile')) count += 1;
    if (data.containsKey('businessSettings')) count += 1;
    if (data.containsKey('sales')) count += (data['sales'] as List).length;
    return count;
  }

  /// Send sync notification email
  Future<bool> sendSyncNotification({
    required String userEmail,
    required String businessName,
    required Map<String, dynamic> syncResult,
  }) async {
    return await _emailService.sendTemplateEmail(
      'data-sync',
      userEmail,
      {
        'businessName': businessName,
        'status': syncResult['success'] == true ? 'Completed' : 'Failed',
        'itemsCount': syncResult['itemsUpdated']?.toString() ?? '0',
        'timestamp': DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
        'message': syncResult['message'] ?? '',
      },
      subject: 'Data Sync Report - $businessName',
    );
  }
}

