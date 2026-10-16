import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  static const _key = 'ytget_history_v1';
  static const maxEntries = 100;

  Future<void> add(Map<String, dynamic> e) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await this.list();
    list.insert(0, {...e, 'date': DateTime.now().toIso8601String()});
    final trimmed = list.take(maxEntries).toList();
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
