import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/math_result.dart';

void main() {
  test('keeps the three forms apart', () {
    const result = MathResult(
      displayText: '4√2',
      displayTex: r'4\times \sqrt{2}',
      decimalText: '5.656854',
    );

    expect(result.displayText, '4√2');
    expect(result.displayTex, r'4\times \sqrt{2}');
    expect(result.decimalText, '5.656854');
    expect(result.decimalValue, 5.656854);
    expect(result.hasTex, isTrue);
    expect(result.displayTextIsParseable, isFalse);
  });

  test('the legacy evaluator display text doubles as the decimal form', () {
    final plain = MathResult.legacy('42');
    final grouped = MathResult.legacy('1,234,567.5');
    final error = MathResult.legacy('等待输入');

    expect(plain.decimalText, '42');
    expect(plain.displayTex, isEmpty);
    expect(plain.hasTex, isFalse);
    expect(grouped.displayText, '1,234,567.5');
    expect(grouped.decimalText, '1234567.5');
    expect(grouped.displayTextIsParseable, isTrue);
    // 中文：错误文案、精确形式、空串都得不到十进制形态，而且必须是空串而不是 null 之外的什么哨兵。
    // English: Error text, exact forms and empty strings all yield no decimal form, and that has to
    //          be an empty string rather than some sentinel.
    expect(error.decimalText, isEmpty);
    expect(error.decimalValue, isNull);
    expect(MathResult.legacy('4√2').decimalText, isEmpty);
    expect(MathResult.decimalTextOf('  7.5  '), '7.5');
    expect(MathResult.decimalTextOf(''), isEmpty);
    expect(MathResult.decimalTextOf('无效'), isEmpty);
  });

  test('reusable text prefers the decimal form and never drops back to it', () {
    const exact = MathResult(
      displayText: '4√2',
      displayTex: r'4\times \sqrt{2}',
      decimalText: '5.656854',
    );
    const grouped = MathResult(displayText: '1,234.5', decimalText: '1234.5');
    // 中文：没有十进制形态时退回显示文本（去掉千分位），这正是「继续使用」在拆分前的取值。
    // English: Without a decimal form it falls back to the display text with grouping separators
    //          stripped — exactly what "continue with result" produced before the split.
    const withoutDecimal = MathResult(displayText: '1,234.5');

    expect(exact.reusableText, '5.656854');
    expect(grouped.reusableText, '1234.5');
    expect(withoutDecimal.reusableText, '1234.5');
  });

  test('equality is by value so undo snapshots still de-duplicate', () {
    const first = MathResult(
      displayText: '4√2',
      displayTex: r'4\times \sqrt{2}',
      decimalText: '5.656854',
    );
    const same = MathResult(
      displayText: '4√2',
      displayTex: r'4\times \sqrt{2}',
      decimalText: '5.656854',
    );
    // 中文：显示文本相同但十进制形态不同**不**相等——否则撤销栈会把两份不同的结果当成同一份。
    // English: Same display text with a different decimal form is *not* equal; otherwise the undo
    //          stack would treat two different results as one.
    const differentDecimal = MathResult(displayText: '4√2');

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(differentDecimal));
    expect(MathResult.zero.displayText, '0');
    expect(MathResult.zero.decimalText, '0');
    expect(MathResult.pending.decimalText, isEmpty);
  });
}
