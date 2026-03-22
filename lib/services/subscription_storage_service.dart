import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Service for uploading subscription proof documents to Firebase Storage
class SubscriptionStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a subscription proof file and returns the download URL
  Future<String?> uploadSubscriptionProof(File file, String userId, String planId) async {
    try {
      // Create a unique filename
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final storageRef = _storage.ref().child('subscription_proofs/$userId/$planId/$fileName');

      // Upload the file
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading subscription proof: $e');
      return null;
    }
  }

  /// Uploads a subscription proof file with progress tracking
  Future<UploadResult> uploadSubscriptionProofWithProgress(
    File file,
    String userId,
    String planId, {
    Function(double progress)? onProgress,
  }) async {
    try {
      // Create a unique filename
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final storageRef = _storage.ref().child('subscription_proofs/$userId/$planId/$fileName');

      // Upload the file with progress tracking
      final uploadTask = storageRef.putFile(file);

      // Listen to upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return UploadResult(
        success: true,
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      print('Error uploading subscription proof: $e');
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Uploads subscription proof from bytes (for web compatibility)
  Future<String?> uploadSubscriptionProofBytes(List<int> bytes, String fileName, String userId, String planId) async {
    try {
      final storageRef = _storage.ref().child('subscription_proofs/$userId/$planId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      // Upload the bytes
      final uploadTask = storageRef.putData(Uint8List.fromList(bytes));
      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading subscription proof bytes: $e');
      return null;
    }
  }

  /// Uploads subscription proof from bytes with progress tracking
  Future<UploadResult> uploadSubscriptionProofBytesWithProgress(
    List<int> bytes,
    String fileName,
    String userId,
    String planId, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final storageRef = _storage.ref().child('subscription_proofs/$userId/$planId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      // Upload the bytes with progress tracking
      final uploadTask = storageRef.putData(Uint8List.fromList(bytes));

      // Listen to upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return UploadResult(
        success: true,
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      print('Error uploading subscription proof bytes: $e');
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Deletes a subscription proof file
  Future<bool> deleteSubscriptionProof(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting subscription proof: $e');
      return false;
    }
  }
}

/// Result class for upload operations with progress tracking
class UploadResult {
  final bool success;
  final String? downloadUrl;
  final String? fileName;
  final String? error;

  UploadResult({
    required this.success,
    this.downloadUrl,
    this.fileName,
    this.error,
  });
}