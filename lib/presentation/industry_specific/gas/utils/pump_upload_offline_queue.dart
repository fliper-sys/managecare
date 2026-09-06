import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/email_service.dart';
import '../../../../services/managecare_api_client.dart';

/// Mirrors the pending-pump-sale queue in RetailProvider (SharedPreferences,
/// one JSON list per business, drained opportunistically): the upload POST
/// in the daily upload screen had no offline path at all, so a worker
/// submitting while offline got a sale (fuelSale() already queues that half)
/// with no matching pump_daily_uploads row - the sale was the only durable
/// record, and retrying after the "failed to save" error just queued another
/// sale each time. This gives the upload half the same queue-and-sync
/// treatment so the two always stay paired.
class PumpUploadOfflineQueue {
  static const _keyPrefix = 'pending_pump_uploads_v1_';

  static String _key(String businessId) => '$_keyPrefix$businessId';

  static Future<List<Map<String, dynamic>>> _load(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(businessId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(
    String businessId,
    List<Map<String, dynamic>> uploads,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(businessId), jsonEncode(uploads));
  }

  static Future<int> pendingCount(String businessId) async {
    final pending = await _load(businessId);
    return pending.length;
  }

  static Future<List<Map<String, dynamic>>> pendingEntries(
    String businessId,
  ) async {
    return _load(businessId);
  }

  static Future<void> remove(String businessId, String queuedId) async {
    final pending = await _load(businessId);
    pending.removeWhere((entry) => entry['queuedId']?.toString() == queuedId);
    await _save(businessId, pending);
  }

  /// [body] is the same field set _saveUpload() would otherwise POST
  /// directly. Photo fields may carry a local file path instead of (or
  /// alongside) a URL - resolved at sync time once a connection exists.
  static Future<void> enqueue(
    String businessId,
    Map<String, dynamic> body, {
    required Map<String, String?> photoPaths,
    String? queuedId,
  }) async {
    final pending = await _load(businessId);
    final entryId =
        queuedId ?? 'PUMPUPLOAD-${DateTime.now().millisecondsSinceEpoch}';
    final queuedAt = DateTime.now().toIso8601String();
    final fingerprint = body['upload_fingerprint']?.toString();
    if (fingerprint != null && fingerprint.isNotEmpty) {
      final alreadyQueued = pending.any((entry) {
        final pendingBody = entry['body'];
        return pendingBody is Map &&
            pendingBody['upload_fingerprint']?.toString() == fingerprint;
      });
      if (alreadyQueued && queuedId == null) return;
    }
    body['submitted_at'] ??= queuedAt;
    if (queuedId != null) {
      pending.removeWhere((entry) => entry['queuedId']?.toString() == queuedId);
    }
    pending.add({
      'queuedId': entryId,
      'queuedAt': queuedAt,
      'body': body,
      'photoPaths': photoPaths,
    });
    await _save(businessId, pending);
  }

  static Future<String?> _resolvePhotoUrl({
    required String? existingUrl,
    required String? localPath,
  }) async {
    if (existingUrl != null && existingUrl.isNotEmpty) return existingUrl;
    if (localPath == null || localPath.isEmpty || kIsWeb) return null;
    try {
      return await EmailService().uploadFile(File(localPath));
    } catch (_) {
      return null;
    }
  }

  static const _photoFields = [
    'shift_opening_cash_photo_url',
    'shift_close_cash_photo_url',
    'opening_photo_url',
    'closing_photo_url',
  ];

  /// Attempts every queued upload for [businessId]. Entries that still can't
  /// reach the server (or whose photos still can't upload) are left queued
  /// for the next attempt; a 409 means a prior attempt already landed
  /// server-side, so it's dropped from the queue same as a fresh success.
  static Future<int> sync(String businessId) async {
    final pending = await _load(businessId);
    if (pending.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var synced = 0;

    for (final entry in pending) {
      try {
        final body = Map<String, dynamic>.from(
          entry['body'] as Map? ?? const {},
        );
        final photoPaths = Map<String, dynamic>.from(
          entry['photoPaths'] as Map? ?? const {},
        );

        var allPhotosResolved = true;
        for (final field in _photoFields) {
          final resolved = await _resolvePhotoUrl(
            existingUrl: body[field]?.toString(),
            localPath: photoPaths[field]?.toString(),
          );
          if (resolved == null) {
            allPhotosResolved = false;
            break;
          }
          body[field] = resolved;
        }

        if (!allPhotosResolved) {
          remaining.add(entry);
          continue;
        }

        try {
          await ManagecareApiClient.instance.post(
            '/api/pumps/$businessId/uploads',
            body: body,
          );
          synced += 1;
        } on ManagecareApiException catch (e) {
          if (e.statusCode == 409) {
            // Already landed from an earlier attempt - treat as synced.
            synced += 1;
          } else {
            rethrow;
          }
        }
      } catch (_) {
        remaining.add(entry);
      }
    }

    await _save(businessId, remaining);
    return synced;
  }
}
