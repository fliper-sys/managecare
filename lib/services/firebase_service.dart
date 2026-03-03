import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Firebase service for backend operations with error handling and offline support
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  late final FirebaseFirestore _firestore;
  bool _initialized = false;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  FirebaseFirestore get firestore => _firestore;
  bool get isInitialized => _initialized;

  /// Initialize Firebase
  static Future<void> initialize() async {
    if (_instance._initialized) return; // Prevent re-initialization

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _instance._firestore = FirebaseFirestore.instance;

      // Enable offline persistence
      _instance._firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _instance._initialized = true;
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // Firebase already initialized (e.g., hot reload), use existing instance
        _instance._firestore = FirebaseFirestore.instance;
        _instance._initialized = true;
        return;
      }
      throw FirebaseInitializationException(
        message: 'Failed to initialize Firebase: $e',
      );
    } catch (e) {
      throw FirebaseInitializationException(
        message: 'Failed to initialize Firebase: $e',
      );
    }
  }

  /// Fetch data from a collection with optional query constraints
  static Future<List<Map<String, dynamic>>> fetchData(
    String collection, {
    String? whereField,
    dynamic whereValue,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseService()._firestore.collection(collection);

      if (whereField != null && whereValue != null) {
        query = query.where(whereField, isEqualTo: whereValue);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to fetch data from $collection: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(
        message: 'Unexpected error fetching data: $e',
      );
    }
  }

  /// Fetch a single document by ID
  static Future<Map<String, dynamic>?> fetchDocument(
    String collection,
    String docId,
  ) async {
    try {
      final doc = await FirebaseService()
          ._firestore
          .collection(collection)
          .doc(docId)
          .get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to fetch document: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Save data to Firebase (create or update)
  static Future<void> saveData(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    try {
      await FirebaseService()._firestore.collection(collection).doc(docId).set(
        {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: merge),
      );
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to save data: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Add a new document with auto-generated ID
  static Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    try {
      final doc =
          await FirebaseService()._firestore.collection(collection).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to add document: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Delete data from Firebase
  static Future<void> deleteData(String collection, String docId) async {
    try {
      await FirebaseService()
          ._firestore
          .collection(collection)
          .doc(docId)
          .delete();
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to delete data: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Update specific fields in a document
  static Future<void> updateData(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseService()
          ._firestore
          .collection(collection)
          .doc(docId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Failed to update data: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Batch write operation for multiple documents
  static Future<void> batchWrite(
    List<BatchOperation> operations,
  ) async {
    try {
      final batch = FirebaseService()._firestore.batch();

      for (final op in operations) {
        final ref = FirebaseService()
            ._firestore
            .collection(op.collection)
            .doc(op.docId);
        switch (op.type) {
          case OperationType.set:
            batch.set(ref, op.data ?? {}, SetOptions(merge: op.merge ?? false));
            break;
          case OperationType.update:
            batch.update(ref, op.data ?? {});
            break;
          case OperationType.delete:
            batch.delete(ref);
            break;
        }
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirebaseDataException(
        message: 'Batch write failed: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseDataException(message: 'Unexpected error: $e');
    }
  }

  /// Stream real-time data from Firestore
  static Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    String? whereField,
    dynamic whereValue,
  }) {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseService()._firestore.collection(collection);

      if (whereField != null && whereValue != null) {
        query = query.where(whereField, isEqualTo: whereValue);
      }

      return query.snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList(),
          );
    } catch (e) {
      throw FirebaseDataException(message: 'Failed to create stream: $e');
    }
  }
}

/// Exception for Firebase initialization errors
class FirebaseInitializationException implements Exception {
  final String message;

  FirebaseInitializationException({required this.message});

  @override
  String toString() => message;
}

/// Exception for Firebase data operations
class FirebaseDataException implements Exception {
  final String message;
  final String? code;

  FirebaseDataException({
    required this.message,
    this.code,
  });

  @override
  String toString() => '$message${code != null ? ' ($code)' : ''}';
}

/// Batch operation model
class BatchOperation {
  final String collection;
  final String docId;
  final OperationType type;
  final Map<String, dynamic>? data;
  final bool? merge;

  BatchOperation({
    required this.collection,
    required this.docId,
    required this.type,
    this.data,
    this.merge,
  });
}

enum OperationType { set, update, delete }

