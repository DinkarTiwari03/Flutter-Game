/// Formats [value] with thousands separators, e.g. `25000` -> `25,000`.
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// Short form for tight spaces: `950` -> `950`, `25000` -> `25K`,
/// `1250000` -> `1.3M`.
String formatCompact(int value) {
  final abs = value.abs();
  if (abs >= 1000000) return '${_trim(value / 1000000)}M';
  if (abs >= 10000) return '${_trim(value / 1000)}K';
  return formatNumber(value);
}

String _trim(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
