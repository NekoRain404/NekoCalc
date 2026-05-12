import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_capabilities.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

  test('solves quadratic equations with two real roots', () {
    final results = calculateTool(tool('quadratic'), {'a': 1, 'b': -3, 'c': 2});
    expect(results.first.label, '解 (x1, x2)');
    expect(results.first.value, contains('2'));
    expect(results.first.value, contains('1'));
  });

  test('detects invalid quadratic coefficient', () {
    final results = calculateTool(tool('quadratic'), {'a': 0, 'b': 1, 'c': 2});
    expect(results.first.value, 'a 不能为 0');
  });

  test('calculates ohms law voltage and tolerance range', () {
    final results = calculateTool(
        tool('ohms_law'), {'current': 2, 'resistance': 5, 'tol': 10});
    expect(results.first.label, '电压 V');
    expect(results.first.value, '10');
    expect(results.any((item) => item.label.contains('范围')), isTrue);
  });

  test('calculates matrix determinant', () {
    final results =
        calculateTool(tool('matrix'), {'a': 1, 'b': 2, 'c': 3, 'd': 4});
    expect(results.first.label, '行列式 det');
    expect(results.first.value, '-2');
  });

  test('all numeric tools calculate with default inputs', () {
    for (final item in toolCatalog.where((tool) => !tool.usesTextDetail)) {
      final values = {
        for (final input in item.inputs) input.key: input.defaultValue ?? 0,
      };
      final results = calculateTool(item, values);
      expect(results, isNotEmpty, reason: item.id);
    }
  });
}
