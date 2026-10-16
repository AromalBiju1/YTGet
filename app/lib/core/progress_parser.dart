double? parseProgressLine(String line) {
  if (!line.contains('[download]')) return null;
  final m = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(line);
  if (m == null) return null;
  return double.parse(m.group(1)!) / 100.0;
}
