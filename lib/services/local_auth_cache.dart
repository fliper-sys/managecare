import 'dart:convert';

import '../data/local/database_helper.dart';
import '../data/models/user_model.dart';

class LocalAuthCache {
  static const _table = 'auth_cache';
  static const _currentUserKey = 'current_user';

  final DatabaseHelper _database;

  LocalAuthCache({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  Future<UserModel?> readUser() async {
    final rows = await _database.query(
      _table,
      where: 'id = ?',
      whereArgs: const [_currentUserKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final userJson = rows.first['userJson'];
    if (userJson is! String || userJson.isEmpty) {
      throw const FormatException('Cached user profile is not valid JSON text');
    }

    final decoded = jsonDecode(userJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Cached user profile is not a JSON object');
    }
    return UserModel.fromJson(decoded);
  }

  Future<void> saveUser(UserModel user) async {
    final userJson = Map<String, dynamic>.from(user.toJson())
      ..remove('pin')
      ..remove('referralEmail');
    await _database.insert(_table, {
      'id': _currentUserKey,
      'userJson': jsonEncode(userJson),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearUser() async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: const [_currentUserKey],
    );
  }
}
