import 'package:flutter_test/flutter_test.dart';
import 'package:ytget/core/progress_parser.dart';

void main() {
  test('parses yt-dlp percent', () {
    expect(
      parseProgressLine('[download]  12.5% of 10MiB at 2MiB/s ETA 00:04'),
      closeTo(0.125, 0.001),
    );
  });
  test('ignores non-progress', () {
    expect(parseProgressLine('[info] hello'), isNull);
  });
}
