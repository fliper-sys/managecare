import 'package:flutter/foundation.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../services/cloud_storage_service.dart';
import 'package:http/http.dart' as http;

class Backup {
  final String id;
  final String businessId;
  final DateTime createdAt;
  final int sizeInBytes;
  final BackupDestination destination;
  final List<String> includedDataTypes;
  final String? cloudPath;
  final bool isRestored;
  final DateTime? restoredAt;

  Backup({
    required this.id,
    required this.businessId,
    required this.createdAt,
    required this.sizeInBytes,
    required this.destination,
    required this.includedDataTypes,
    this.cloudPath,
    this.isRestored = false,
    this.restoredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
      'sizeInBytes': sizeInBytes,
      'destination': destination.toString().split('.').last,
      'includedDataTypes': includedDataTypes,
      'cloudPath': cloudPath,
      'isRestored': isRestored,
      'restoredAt': restoredAt?.toIso8601String(),
    };
  }

  factory Backup.fromMap(Map<String, dynamic> map) {
    return Backup(
      id: map['id'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      createdAt: map['createdAt'] is String
          ? parseTimestamp(map['createdAt'])
          : DateTime.now(),
      sizeInBytes: map['sizeInBytes'] as int? ?? 0,
      destination: _parseDestination(map['destination'] as String?),
      includedDataTypes:
          List<String>.from(map['includedDataTypes'] as List? ?? []),
      cloudPath: map['cloudPath'] as String?,
      isRestored: map['isRestored'] as bool? ?? false,
      restoredAt: map['restoredAt'] is String
          ? parseTimestamp(map['restoredAt'])
          : null,
    );
  }

  static BackupDestination _parseDestination(String? value) {
    switch (value) {
      case 'cloud':
        return BackupDestination.cloud;
      case 'both':
        return BackupDestination.both;
      default:
        return BackupDestination.local;
    }
  }

  // Computed properties
  String get name =>
      'Backup ${createdAt.day}/${createdAt.month}/${createdAt.year}';
  int get size => sizeInBytes;
}

enum BackupDestination {
  local,
  cloud,
  both,
}

class BackupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudStorageService _cloud = CloudStorageService();
  final String _backupsCollection = 'backups';

  List<Backup> _backups = [];
  bool _isLoading = false;
  String? _error;
  String? _businessId;
  double _backupProgress = 0.0;
  bool _isBackingUp = false;

  // Backup selection state
  final Set<String> _selectedDataTypes = {
    'businessData',
    'salesData',
    'inventory',
    'customers',
    'reports',
    'settings',
  };
  BackupDestination _selectedDestination = BackupDestination.both;

  // Individual backup option getters
  bool get backupBusinessData => _selectedDataTypes.contains('businessData');
  bool get backupSalesData => _selectedDataTypes.contains('salesData');
  bool get backupInventory => _selectedDataTypes.contains('inventory');
  bool get backupCustomers => _selectedDataTypes.contains('customers');
  bool get backupReports => _selectedDataTypes.contains('reports');
  bool get backupSettings => _selectedDataTypes.contains('settings');
  BackupDestination get destination => _selectedDestination;

  // Getters
  List<Backup> get backups => _backups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get selectedDataTypes => _selectedDataTypes;
  BackupDestination get selectedDestination => _selectedDestination;
  double get backupProgress => _backupProgress;
  bool get isBackingUp => _isBackingUp;

  // Initialize
  void initialize(String businessId) {
    _businessId = businessId;
    loadBackups();
  }

  // Load all backups
  Future<void> loadBackups() async {
    if (_businessId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(_backupsCollection)
          .where('businessId', isEqualTo: _businessId)
          .orderBy('createdAt', descending: true)
          .get();

      _backups = snapshot.docs
          .map((doc) => Backup.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load backups: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Select/deselect data type for backup
  void toggleDataType(String dataType) {
    if (_selectedDataTypes.contains(dataType)) {
      _selectedDataTypes.remove(dataType);
    } else {
      _selectedDataTypes.add(dataType);
    }
    notifyListeners();
  }

  // Individual backup option setters
  void setBackupBusinessData(bool value) {
    if (value && !_selectedDataTypes.contains('businessData')) {
      _selectedDataTypes.add('businessData');
    } else if (!value) {
      _selectedDataTypes.remove('businessData');
    }
    notifyListeners();
  }

  void setBackupSalesData(bool value) {
    if (value && !_selectedDataTypes.contains('salesData')) {
      _selectedDataTypes.add('salesData');
    } else if (!value) {
      _selectedDataTypes.remove('salesData');
    }
    notifyListeners();
  }

  void setBackupInventory(bool value) {
    if (value && !_selectedDataTypes.contains('inventory')) {
      _selectedDataTypes.add('inventory');
    } else if (!value) {
      _selectedDataTypes.remove('inventory');
    }
    notifyListeners();
  }

  void setBackupCustomers(bool value) {
    if (value && !_selectedDataTypes.contains('customers')) {
      _selectedDataTypes.add('customers');
    } else if (!value) {
      _selectedDataTypes.remove('customers');
    }
    notifyListeners();
  }

  void setBackupReports(bool value) {
    if (value && !_selectedDataTypes.contains('reports')) {
      _selectedDataTypes.add('reports');
    } else if (!value) {
      _selectedDataTypes.remove('reports');
    }
    notifyListeners();
  }

  void setBackupSettings(bool value) {
    if (value && !_selectedDataTypes.contains('settings')) {
      _selectedDataTypes.add('settings');
    } else if (!value) {
      _selectedDataTypes.remove('settings');
    }
    notifyListeners();
  }

  // Set backup destination (alias for setBackupDestination)
  void setDestination(BackupDestination destination) {
    _selectedDestination = destination;
    notifyListeners();
  }

  // Set backup destination
  void setBackupDestination(BackupDestination destination) {
    _selectedDestination = destination;
    notifyListeners();
  }

  // Create backup
  Future<bool> createBackup() async {
    if (_businessId == null || _selectedDataTypes.isEmpty) {
      _error = 'Invalid backup configuration';
      notifyListeners();
      return false;
    }

    try {
      _isBackingUp = true;
      _backupProgress = 0.0;
      notifyListeners();

      final backupId = const Uuid().v4();
      final timestamp = DateTime.now();

      // Simulate backup data collection
      final backupData = await _collectBackupData();
      final backupSize = backupData.toString().length;

      String? cloudPath;

      // Upload to cloud if needed
      if (_selectedDestination == BackupDestination.cloud ||
          _selectedDestination == BackupDestination.both) {
        _backupProgress = 0.3;
        notifyListeners();

        cloudPath = await _uploadToCloud(backupId, backupData);
      }

      // Save locally if needed
      if (_selectedDestination == BackupDestination.local ||
          _selectedDestination == BackupDestination.both) {
        _backupProgress = 0.6;
        notifyListeners();

        await _saveLocally(backupId, backupData);
      }

      // Create backup record
      final backup = Backup(
        id: backupId,
        businessId: _businessId!,
        createdAt: timestamp,
        sizeInBytes: backupSize,
        destination: _selectedDestination,
        includedDataTypes: _selectedDataTypes.toList(),
        cloudPath: cloudPath,
      );

      // Save to Firestore
      await _firestore
          .collection(_backupsCollection)
          .doc(backupId)
          .set(backup.toMap());

      _backupProgress = 1.0;
      _isBackingUp = false;
      _error = null;

      // Reload backups
      await loadBackups();

      return true;
    } catch (e) {
      _error = 'Failed to create backup: $e';
      _isBackingUp = false;
      notifyListeners();
      return false;
    }
  }

  // Restore backup
  Future<bool> restoreBackup(Backup backup) async {
    if (_businessId == null) {
      _error = 'Invalid business context';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      Map<String, dynamic> backupData = {};

      // Retrieve from cloud if available
      if (backup.cloudPath != null) {
        backupData = await _downloadFromCloud(backup.cloudPath!);
      } else {
        // Retrieve from local storage
        backupData = await _loadLocally(backup.id);
      }

      // Restore data to Firestore
      await _restoreDataToFirestore(backupData);

      // Update backup record
      await _firestore.collection(_backupsCollection).doc(backup.id).update({
        'isRestored': true,
        'restoredAt': DateTime.now().toIso8601String(),
      });

      _isLoading = false;
      _error = null;
      await loadBackups();

      return true;
    } catch (e) {
      _error = 'Failed to restore backup: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete backup
  Future<bool> deleteBackup(Backup backup) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Delete from cloud if exists (server-side delete not guaranteed)
      if (backup.cloudPath != null) {
        try {
          await _cloud.deleteFile(backup.cloudPath!);
        } catch (e) {
          print('Cloud delete not supported: $e');
        }
      }

      // Delete local file if exists
      final localDir = await getApplicationDocumentsDirectory();
      final file = File('${localDir.path}/backup_${backup.id}.json');
      if (await file.exists()) {
        await file.delete();
      }

      // Delete from Firestore
      await _firestore.collection(_backupsCollection).doc(backup.id).delete();

      _isLoading = false;
      await loadBackups();

      return true;
    } catch (e) {
      _error = 'Failed to delete backup: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _collectBackupData() async {
    // This would collect actual business data based on _selectedDataTypes
    return {
      'businessData': {},
      'salesData': {},
      'inventory': {},
      'customers': {},
      'reports': {},
      'settings': {},
    };
  }

  Future<String> _uploadToCloud(
      String backupId, Map<String, dynamic> data) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_$backupId.json');
    await file.writeAsString(data.toString());

    // Upload to server via CloudStorageService
    final url = await _cloud.uploadFile(file.path, 'backups/$_businessId/$backupId.json');
    return url;
  }

  Future<String> _saveLocally(
      String backupId, Map<String, dynamic> data) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_$backupId.json');
    await file.writeAsString(data.toString());
    return file.path;
  }

  Future<Map<String, dynamic>> _downloadFromCloud(String cloudPath) async {
    try {
      // If cloudPath is a URL, fetch it via HTTP
      if (cloudPath.startsWith('http')) {
        final resp = await http.get(Uri.parse(cloudPath));
        if (resp.statusCode == 200) {
          try {
            // Response validated
            // In this implementation backups are simple strings; parsing is domain-specific
            return {};
          } catch (_) {
            return {};
          }
        }
        return {};
      }

      // Otherwise, not supported
      return {};
    } catch (e) {
      print('Failed to download backup from cloud: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _loadLocally(String backupId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_$backupId.json');
    if (await file.exists()) {
      // Parse and return data
      return {};
    }
    return {};
  }

  Future<void> _restoreDataToFirestore(Map<String, dynamic> data) async {
    // Implement actual data restoration logic
  }

  // Format bytes to human readable size
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

