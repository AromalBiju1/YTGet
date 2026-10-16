import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class BinaryManager {
  static Future<String> ensureExecutable() async {
    final support = await getApplicationSupportDirectory();
    final binDir = Directory('${support.path}/bin');
    await binDir.create(recursive: true);
    final target = File('${binDir.path}/yt-dlp');

    if (!await target.exists()) {
      const assetKey = 'assets/bin/arm64-v8a/yt-dlp';
      try {
        final data = await rootBundle.load(assetKey);
        await target.writeAsBytes(data.buffer.asUint8List());
      } catch (_) {
        throw Exception(
          'yt-dlp binary not bundled. Run tool/fetch_ytdlp.sh then rebuild.',
        );
      }
    }
    try {
      await Process.run('chmod', ['+x', target.path]);
    } catch (_) {}
    return target.path;
  }

  static Future<String> version(String binPath) async {
    try {
      final r = await Process.run(binPath, ['--version']);
      return (r.stdout as String).trim();
    } catch (e) {
      return 'unknown';
    }
  }
}
