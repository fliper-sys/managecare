import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PumpConfigCache {
  static String _key(String businessId) =>
      'pump_configurations_cache_v1_$businessId';

  static Future<List<Map<String, dynamic>>> load(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(businessId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return _sort(
        decoded
            .whereType<Map<String, dynamic>>()
            .where((pump) => pump['isActive'] != false)
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(
    String businessId,
    List<Map<String, dynamic>> pumps,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final activePumps = _sort(
      pumps.map(_serializablePump).where((pump) {
        return pump['id']?.toString().isNotEmpty == true &&
            pump['isActive'] != false;
      }).toList(),
    );
    await prefs.setString(_key(businessId), jsonEncode(activePumps));
  }

  static Future<void> upsert(
    String businessId,
    String pumpId,
    Map<String, dynamic> data,
  ) async {
    final pumps = await load(businessId);
    final next = _serializablePump({
      ...data,
      'id': pumpId,
      'isActive': data['isActive'] ?? true,
    });
    final existingIndex = pumps.indexWhere((pump) => pump['id'] == pumpId);
    if (existingIndex == -1) {
      pumps.add(next);
    } else {
      pumps[existingIndex] = {
        ...pumps[existingIndex],
        ...next,
      };
    }
    await save(businessId, pumps);
  }

  static Future<void> remove(String businessId, String pumpId) async {
    final pumps = await load(businessId);
    await save(
      businessId,
      pumps.where((pump) => pump['id'] != pumpId).toList(),
    );
  }

  static Map<String, dynamic> fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _serializablePump({
      ...doc.data(),
      'id': doc.id,
    });
  }

  static List<Map<String, dynamic>> sort(List<Map<String, dynamic>> pumps) {
    return _sort(pumps);
  }

  static bool same(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    if (first.length != second.length) return false;
    final left = _sort(first).map(_fingerprint).join('|');
    final right = _sort(second).map(_fingerprint).join('|');
    return left == right;
  }

  static Map<String, dynamic> _serializablePump(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'pumpNumber': data['pumpNumber']?.toString() ?? '',
      'productId': data['productId']?.toString() ?? '',
      'productName': data['productName']?.toString() ?? '',
      'productUnit': data['productUnit']?.toString() ?? '',
      'productPrice': _toDouble(data['productPrice']),
      'model': data['model']?.toString() ?? '',
      'serialNumber': data['serialNumber']?.toString() ?? '',
      'manufacturer': data['manufacturer']?.toString() ?? '',
      'manufactureYear': data['manufactureYear']?.toString() ?? '',
      'isActive': data['isActive'] != false,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> pumps) {
    final sorted = List<Map<String, dynamic>>.from(pumps);
    sorted.sort((a, b) {
      final aNumber = double.tryParse(a['pumpNumber']?.toString() ?? '');
      final bNumber = double.tryParse(b['pumpNumber']?.toString() ?? '');
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return (a['pumpNumber']?.toString() ?? '')
          .compareTo(b['pumpNumber']?.toString() ?? '');
    });
    return sorted;
  }

  static String _fingerprint(Map<String, dynamic> pump) {
    return [
      pump['id'],
      pump['pumpNumber'],
      pump['productId'],
      pump['productName'],
      pump['productUnit'],
      pump['productPrice'],
      pump['model'],
      pump['serialNumber'],
      pump['manufacturer'],
      pump['manufactureYear'],
      pump['isActive'],
    ].map((value) => value?.toString() ?? '').join('::');
  }
}

class PumpAnalogClosingCache {
  static String _key(String businessId) =>
      'pump_analog_closing_cache_v1_$businessId';

  static Future<double?> load(String businessId, String pumpId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(businessId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded[pumpId] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String businessId,
    String pumpId,
    double value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(businessId));
    Map<String, dynamic> cache = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        cache = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        cache = {};
      }
    }
    cache[pumpId] = value;
    await prefs.setString(_key(businessId), jsonEncode(cache));
  }
}

class PumpUploadDraftCache {
  static String _key(String businessId, String pumpId) =>
      'pump_upload_draft_v1_${businessId}_$pumpId';

  static Future<Map<String, dynamic>> load(
    String businessId,
    String pumpId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(businessId, pumpId));
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(
    String businessId,
    String pumpId,
    Map<String, dynamic> draft,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(businessId, pumpId), jsonEncode(draft));
  }

  static Future<void> clear(String businessId, String pumpId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(businessId, pumpId));
  }
}
