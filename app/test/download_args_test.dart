import 'package:flutter_test/flutter_test.dart';
import 'package:ytget/core/download_args.dart';

void main() {
  test('mp3 args contain extract-audio', () {
    final a = buildMp3Args(
      'https://youtu.be/abc12345678',
      192,
      '/tmp/a.%(ext)s',
    );
    expect(a.join(' '), contains('--extract-audio'));
    expect(a.join(' '), contains('192K'));
  });
  test('mp4 720 args cap height', () {
    final a = buildMp4Args(
      'https://youtu.be/abc12345678',
      720,
      '/tmp/v.%(ext)s',
    );
    expect(a.join(' '), contains('height<=720'));
  });
}
