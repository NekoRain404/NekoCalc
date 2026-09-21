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

  test('calculator paste result restores a parser-safe current value report',
      () {
    final result = CalculatorPasteResult.fromText('''
当前值: 1,234.5
状态: 当前值可继续使用
角度模式: 角度 DEG
记忆值: 12.5
''');

    expect(result.status, CalculatorPasteStatus.calculatorReport);
    expect(result.expression, '1234.5');
    expect(result.angleMode, 'DEG');
    expect(result.memoryValue, 12.5);
    expect(result.summary, contains('恢复当前值'));
  });

  test('calculator paste result normalizes leading decimal current values', () {
    final positive = CalculatorPasteResult.fromText('当前值: .5');
    final negative = CalculatorPasteResult.fromText('当前值: -.5');

    expect(positive.expression, '0.5');
    expect(negative.expression, '-0.5');
  });

  test('metadata-only calculator report has no expression', () {
    final result = CalculatorPasteResult.fromText('''
角度模式: 角度 DEG
记忆值: 12.5
''');

    expect(result.status, CalculatorPasteStatus.calculatorReport);
    expect(result.hasExpression, isFalse);
    expect(result.expression, isEmpty);
    expect(result.angleMode, 'DEG');
    expect(result.memoryValue, 12.5);
  });

  test('memory-only reports are calculator metadata, not expressions', () {
    final chinese = CalculatorPasteResult.fromText('记忆值: 12.5');
    final english = CalculatorPasteResult.fromText('memory: 7.5');

    expect(chinese.fromReport, isTrue);
    expect(chinese.expression, isEmpty);
    expect(chinese.memoryValue, 12.5);
    expect(english.fromReport, isTrue);
    expect(english.expression, isEmpty);
    expect(english.memoryValue, 7.5);
  });

  test('calculator paste result rejects non-finite memory metadata', () {
    final nan = CalculatorPasteResult.fromText('memory: NaN');
    final infinity = CalculatorPasteResult.fromText('记忆值: Infinity');

    expect(nan.fromReport, isTrue);
    expect(nan.memoryValue, isNull);
    expect(infinity.fromReport, isTrue);
    expect(infinity.memoryValue, isNull);
  });

  test('metadata-only reports summarize restored state', () {
    final memory = CalculatorPasteResult.fromText('记忆值: 12.5');
    final angle = CalculatorPasteResult.fromText('angle mode: DEG');

    expect(memory.summary, contains('已恢复记忆值'));
    expect(angle.summary, contains('已恢复角度模式'));
  });

  test('unusable current value report keeps the unrecognized summary', () {
    final result = CalculatorPasteResult.fromText('当前值: not-a-number');

    expect(result.hasExpression, isFalse);
    expect(result.summary, '剪贴板里没有识别到表达式');
  });
}
