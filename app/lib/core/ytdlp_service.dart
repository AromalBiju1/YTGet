import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'download_args.dart';
import 'progress_parser.dart';

class VideoMeta {
  final String title;
  final String author;
  final String thumb;
  final int durSec;
  VideoMeta(this.title, this.author, this.thumb, this.durSec);
}

class YtDlp {
  final String binPath;
  YtDlp(this.binPath);

  Future<VideoMeta> fetchInfo(String url) async {
    final r = await Process.run(binPath, buildInfoArgs(url));
    if (r.exitCode != 0) {
      final err = (r.stderr as String).split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => 'yt-dlp failed',
      );
      throw Exception(err);
    }
    final lines = (r.stdout as String).split('\n');
    final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
    final j = jsonDecode(jsonLine) as Map;
    return VideoMeta(
      (j['title'] ?? 'Unknown').toString(),
      (j['uploader'] ?? '').toString(),
      (j['thumbnail'] ?? '').toString(),
      ((j['duration'] ?? 0) as num).toInt(),
    );
  }

  Stream<double> download(List<String> args, {void Function(String)? onLog}) {
    final c = StreamController<double>();
    Process.start(binPath, args).then((p) {
      p.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((l) {
            onLog?.call(l);
            final v = parseProgressLine(l);
            if (v != null) c.add(v);
          });
      p.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((l) => onLog?.call(l));
      p.exitCode.then((e) {
        if (e == 0) {
          c.close();
        } else {
          c.addError('yt-dlp exit $e');
        }
      });
    });
    return c.stream;
  }
}
