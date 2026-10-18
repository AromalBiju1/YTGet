import 'package:shared_preferences/shared_preferences.dart';

enum SaveMode { publicDownloads, appPrivate, custom }

class SaveLocation {
  static const _modeKey = 'save_mode_v1';
  static const _customPathKey = 'save_custom_path_v1';

  static Future<SaveMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_modeKey) ?? SaveMode.publicDownloads.index;
    return SaveMode.values[i.clamp(0, SaveMode.values.length - 1)];
  }

  static Future<void> save(SaveMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  static Future<String?> loadCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_customPathKey);
    return (p == null || p.isEmpty) ? null : p;
  }

  static Future<void> saveCustomPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_customPathKey);
    } else {
      await prefs.setString(_customPathKey, path);
    }
  }
}
