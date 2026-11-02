/// Formats [bytes] as a short, human-readable size such as `3.4 MB`.
///
/// Uses binary units (1 KB = 1024 B) and keeps at most one decimal place, so a
/// card or an app bar can show the size of an uploaded file in a fixed width.
String formatFileSize(int bytes) {
  if (bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes ${units[unit]}';
  final rounded = (value * 10).round() / 10;
  return '${rounded.toStringAsFixed(rounded == rounded.roundToDouble() ? 0 : 1)} ${units[unit]}';
}
