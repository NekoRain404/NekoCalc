import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';

void main() {
  test('calculator paste result reports empty clipboard text', () {
    const result = CalculatorPasteResult.empty();

    expect(result.status, CalculatorPasteStatus.empty);
    expect(result.hasExpression, isFalse);
    expect(result.fromReport, isFalse);
    expect(result.summary, '剪贴板里没有识别到表达式');
  });

  test('calculator paste result identifies plain expressions', () {
    final result = CalculatorPasteResult.fromText('sqrt(81) + 1');

    expect(result.status, CalculatorPasteStatus.plainExpression);
    expect(result.hasExpression, isTrue);
    expect(result.fromReport, isFalse);
    expect(result.expression, 'sqrt(81) + 1');
    expect(result.summary, '已粘贴表达式');
  });

  test('calculator paste result restores calculator report metadata', () {
    final result = CalculatorPasteResult.fromText('''
表达式: sin(90)
结果: 1
角度模式: 角度 DEG
记忆值: 12.5
''');

    expect(result.status, CalculatorPasteStatus.calculatorReport);
    expect(result.hasExpression, isTrue);
    expect(result.fromReport, isTrue);
    expect(result.expression, 'sin(90)');
    expect(result.angleMode, 'DEG');
    expect(result.memoryValue, 12.5);
    expect(result.summary, contains('已从计算详情提取表达式'));
    expect(result.summary, contains('角度模式 DEG'));
    expect(result.summary, contains('记忆值 12.5'));
  });
}
