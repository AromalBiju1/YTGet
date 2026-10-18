import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> removeWhere(
    bool Function(Map<String, dynamic> e) test,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await this.list();
    final kept = list.where((e) => !test(e)).toList();
    await prefs.setString(_key, jsonEncode(kept));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Live, shareable history state so both tabs see downloads the moment
/// they finish. Wraps [HistoryStore] and broadcasts changes.
class HistoryController extends ChangeNotifier {
  HistoryController(this._store);

  final HistoryStore _store;
  List<Map<String, dynamic>> _entries = [];
  bool _loaded = false;

  List<Map<String, dynamic>> get entries => List.unmodifiable(_entries);
  bool get loaded => _loaded;

  Map<String, dynamic>? firstForUrl(String url) {
    for (final e in _entries) {
      if ((e['url'] ?? '').toString() == url) return e;
    }
    return null;
  }

  Future<void> refresh() async {
    _entries = await _store.list();
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Map<String, dynamic> e) async {
    await _store.add(e);
    await refresh();
  }

  Future<void> removeWhere(bool Function(Map<String, dynamic> e) test) async {
    await _store.removeWhere(test);
    await refresh();
  }

  Future<void> clear() async {
    await _store.clear();
    await refresh();
  }
}
