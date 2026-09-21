String formatNumber(
  num value, {
  int precision = 6,
  bool groupThousands = false,
}) {
  if (value.isNaN || value.isInfinite) return '无效';
  if (value == 0) return '0';
  final magnitude = value.abs();
  if (magnitude < 1e-6 || magnitude >= 1e9) {
    return _trimScientific(value.toStringAsExponential(precision));
  }
  final fixed = value.toStringAsFixed(precision);
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return groupThousands ? _groupThousands(trimmed) : trimmed;
}

String _groupThousands(String value) {
  final negative = value.startsWith('-');
  final unsigned = negative ? value.substring(1) : value;
  final decimalIndex = unsigned.indexOf('.');
  final integer =
      decimalIndex < 0 ? unsigned : unsigned.substring(0, decimalIndex);
  final decimal = decimalIndex < 0 ? '' : unsigned.substring(decimalIndex);
  final firstGroupLength = integer.length % 3;
  final groups = <String>[
    if (firstGroupLength > 0) integer.substring(0, firstGroupLength),
    for (var index = firstGroupLength; index < integer.length; index += 3)
      integer.substring(index, index + 3),
  ];
  return '${negative ? '-' : ''}${groups.join(',')}$decimal';
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
