class YoutubeUrl {
  final String videoId;
  YoutubeUrl(this.videoId);

  static final _idRe = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static YoutubeUrl parse(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || u.host.isEmpty) throw ArgumentError('Invalid URL');
    if (u.host.contains('youtu.be')) {
      final id = u.pathSegments.isNotEmpty ? u.pathSegments.first : '';
      if (_idRe.hasMatch(id)) return YoutubeUrl(id);
    }
    if (u.host.contains('youtube.com') ||
        u.host.contains('music.youtube.com')) {
      final v = u.queryParameters['v'];
      if (v != null && _idRe.hasMatch(v)) return YoutubeUrl(v);
      if (u.pathSegments.length >= 2 &&
          (u.pathSegments[0] == 'shorts' ||
              u.pathSegments[0] == 'embed' ||
              u.pathSegments[0] == 'live')) {
        final id = u.pathSegments[1];
        if (_idRe.hasMatch(id)) return YoutubeUrl(id);
      }
    }
    throw ArgumentError('Unsupported YouTube URL');
  }

  static bool isSupportedUrl(String raw) {
    try {
      parse(raw);
      return true;
    } catch (_) {
      return false;
    }
  }
}
