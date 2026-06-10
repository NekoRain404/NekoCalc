String formatNumber(num value, {int precision = 6}) {
  if (value.isNaN || value.isInfinite) return '无效';
  if (value == 0) return '0';
  final magnitude = value.abs();
  if (magnitude < 1e-6 || magnitude >= 1e9) {
    return _trimScientific(value.toStringAsExponential(precision));
  }
  final fixed = value.toStringAsFixed(precision);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _trimScientific(String value) {
  final normalized = value.replaceFirstMapped(
    RegExp(r'^([+-]?\d+)(?:\.(\d*?))?e([+-]?)(0*)(\d+)$'),
    (match) {
      final integer = match.group(1)!;
      final decimals = (match.group(2) ?? '').replaceFirst(RegExp(r'0+$'), '');
      final sign = match.group(3) == '-' ? '-' : '+';
      final exponent = match.group(5)!;
      return '${decimals.isEmpty ? integer : '$integer.$decimals'}e$sign$exponent';
    },
  );
  return normalized == '-0' ? '0' : normalized;
}
