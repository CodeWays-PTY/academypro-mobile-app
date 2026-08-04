import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const String sessionBoxName = 'session_box';
  static const String cacheBoxName = 'cache_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(cacheBoxName);
  }

  // ==========================================
  // SESSION METHODS (JWT & Profile)
  // ==========================================

  static Box get _sessionBox => Hive.box(sessionBoxName);

  static Future<void> saveSession(String token, Map<String, dynamic> userProfile) async {
    await _sessionBox.put('token', token);
    await _sessionBox.put('user', jsonEncode(userProfile));
  }

  static String? getToken() {
    return _sessionBox.get('token') as String?;
  }

  static Map<String, dynamic>? getUserProfile() {
    final rawUser = _sessionBox.get('user') as String?;
    if (rawUser == null) return null;
    return jsonDecode(rawUser) as Map<String, dynamic>;
  }

  static Future<void> clearSession() async {
    await _sessionBox.clear();
  }

  // ==========================================
  // CACHE METHODS (Roster & Summary JSONs)
  // ==========================================

  static Box get _cacheBox => Hive.box(cacheBoxName);

  static Future<void> cacheData(String key, dynamic data) async {
    await _cacheBox.put(key, jsonEncode(data));
  }

  static dynamic getCachedData(String key) {
    final rawData = _cacheBox.get(key) as String?;
    if (rawData == null) return null;
    return jsonDecode(rawData);
  }
}
