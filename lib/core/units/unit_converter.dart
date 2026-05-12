class UnitConversion {
  const UnitConversion({
    required this.unit,
    required this.value,
  });

  final String unit;
  final double value;
}

class UnitConverter {
  const UnitConverter(this.factors);

  final Map<String, double> factors;

  List<UnitConversion> convert(double baseValue) {
    return factors.entries
        .map((entry) =>
            UnitConversion(unit: entry.key, value: baseValue * entry.value))
        .toList();
  }
}
