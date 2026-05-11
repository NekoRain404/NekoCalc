String formatNumber(num value, {int precision = 6}) {
  if (value.isNaN || value.isInfinite) return value.toString();
  final fixed = value.toStringAsFixed(precision);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
