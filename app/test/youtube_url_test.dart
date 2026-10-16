import 'package:flutter_test/flutter_test.dart';
import 'package:ytget/core/youtube_url.dart';

void main() {
  test('parses watch url', () {
    expect(
      YoutubeUrl.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ').videoId,
      'dQw4w9WgXcQ',
    );
  });
  test('parses youtu.be', () {
    expect(
      YoutubeUrl.parse('https://youtu.be/dQw4w9WgXcQ').videoId,
      'dQw4w9WgXcQ',
    );
  });
  test('parses shorts', () {
    expect(
      YoutubeUrl.parse(
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      ).videoId,
      'dQw4w9WgXcQ',
    );
  });
  test('rejects playlist-only', () {
    expect(
      () => YoutubeUrl.parse('https://www.youtube.com/playlist?list=abc'),
      throwsArgumentError,
    );
  });
  test('rejects garbage', () {
    expect(YoutubeUrl.isSupportedUrl('https://example.com'), isFalse);
  });
}
