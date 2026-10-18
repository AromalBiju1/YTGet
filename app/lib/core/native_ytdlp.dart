import 'dart:async';

import 'package:flutter/services.dart';

import 'ytdlp_service.dart';

class NativeYtDlp {
  static const _method = MethodChannel('com.ytget/ytdlp');
  static const _events = EventChannel('com.ytget/ytdlp_events');

  Future<void> init() async {
    await _method.invokeMethod('init');
  }

  Future<VideoMeta> getInfo(String url) async {
    final m = await _method.invokeMethod<Map>('getInfo', {'url': url});
    return VideoMeta(
      (m?['title'] ?? 'Unknown').toString(),
      (m?['author'] ?? '').toString(),
      (m?['thumb'] ?? '').toString(),
      ((m?['durSec'] ?? 0) as num).toInt(),
    );
  }

  /// Emits 0.0–1.0 progress for [processId], completes on done, throws on error.
  /// [onLog] receives raw yt-dlp output lines for the log view.
  Stream<double> download({
    required String processId,
    required String url,
    required List<String> options,
    void Function(String line)? onLog,
  }) {
    final controller = StreamController<double>();
    late final StreamSubscription sub;
    sub = _events.receiveBroadcastStream().listen(
      (event) {
        final m = Map<String, dynamic>.from(event as Map);
        if (m['processId'] != processId) return;
        if (m.containsKey('error')) {
          controller.addError(m['error'].toString());
          sub.cancel();
          controller.close();
        } else if (m['done'] == true) {
          sub.cancel();
          controller.close();
        } else if (m.containsKey('progress')) {
          final line = m['line'];
          if (line != null && onLog != null) onLog(line.toString());
          controller.add(((m['progress'] as num).toDouble()).clamp(0.0, 1.0));
        }
      },
      onError: (Object e) {
        controller.addError(e);
        sub.cancel();
        controller.close();
      },
    );
    _method
        .invokeMethod('download', {
          'processId': processId,
          'url': url,
          'options': options,
        })
        .catchError((Object e) {
          controller.addError(e);
          sub.cancel();
          controller.close();
        });
    return controller.stream;
  }

  Future<void> cancel(String processId) async {
    await _method.invokeMethod('cancel', {'processId': processId});
  }

  Future<String> update() async {
    final s = await _method.invokeMethod<String>('update');
    return s ?? 'UNKNOWN';
  }

  Future<String> version() async {
    final s = await _method.invokeMethod<String>('version');
    return s ?? 'unknown';
  }
}
