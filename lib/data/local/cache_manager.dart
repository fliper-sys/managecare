import 'package:hive/hive.dart';

/// Cache manager using Hive for local caching
class CacheManager {
  static final CacheManager _instance = CacheManager._init();
  late Box<Map> _cacheBox;

  CacheManager._init();

  static CacheManager get instance => _instance;

  Future<void> init() async {
    _cacheBox = await Hive.openBox<Map>('cache');
  }

  Future<void> set(String key, Map<String, dynamic> value) async {
    await _cacheBox.put(key, value);
  }

  Map<String, dynamic>? get(String key) {
    final value = _cacheBox.get(key);
    if (value != null) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> remove(String key) async {
    await _cacheBox.delete(key);
  }

  Future<void> clear() async {
    await _cacheBox.clear();
  }

  bool exists(String key) {
    return _cacheBox.containsKey(key);
  }

  List<String> getAllKeys() {
    return _cacheBox.keys.cast<String>().toList();
  }
}

