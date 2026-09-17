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

  test('a decimal that fits a finite double gives that double', () {
    const exact = MathResult(displayText: '4√2', decimalText: '5.656854');
    const zero = MathResult(displayText: '0', decimalText: '0');
    const negativeZero = MathResult(displayText: '-0', decimalText: '-0');

    expect(exact.decimalValue, 5.656854);
    expect(exact.hasFiniteDecimal, isTrue);
    expect(zero.decimalValue, 0);
    expect(zero.hasFiniteDecimal, isTrue);
    // 中文：真的零仍然是零——下溢的判定看的是「数字部分里有没有非零数字」，`-0` 与 `0e-999` 都没有。
    // English: A real zero is still a zero — underflow is decided by "does the significand contain a
    //          non-zero digit", and neither `-0` nor `0e-999` does.
    expect(negativeZero.decimalValue, 0);
    expect(
        const MathResult(displayText: '0e-999', decimalText: '0e-999')
            .decimalValue,
        0);
  });

  test('a finite decimal that overflows a double is finite, and has no value',
      () {
    // 中文：`2^2000 ≈ 1.148e+602` 是精确引擎给出的**正确答案**，只是超出 double 上限。
    //       `double.tryParse` 对它返回 `Infinity`——但那是 double 的量程，不是数的性质。
    // English: `2^2000 ≈ 1.148e+602` is a *correct* answer from an exact engine that merely exceeds
    //          a double. `double.tryParse` returns `Infinity` for it — but that is the double's
    //          range, not a property of the number.
    const huge =
        MathResult(displayText: '1.148e+602', decimalText: '1.148e+602');

    expect(huge.hasFiniteDecimal, isTrue);
    expect(huge.decimalValue, isNull);
    expect(huge.reusableText, '1.148e+602');
  });

  test('a decimal that underflows must not come back as a silent zero', () {
    // 中文：`2^-2000 ≈ 9.3e-603`。`double.tryParse` 返回 `0.0` 而不是 null，`isFinite` 也为真——
    //       若照单全收，`Ans`、`last` 与记忆寄存器拿到的都是一个**静默的 0**。
    // English: `2^-2000 ≈ 9.3e-603`. `double.tryParse` returns `0.0` rather than null, and `isFinite`
    //          is true — taking that at face value hands `Ans`, `last` and the memory register a
    //          *silent zero*.
    const tiny = MathResult(displayText: '9.3e-603', decimalText: '9.3e-603');

    expect(tiny.hasFiniteDecimal, isTrue);
    expect(tiny.decimalValue, isNull);
    expect(tiny.reusableText, '9.3e-603');
  });

  test('the Infinity and NaN literals are not finite decimals', () {
    // 中文：`decimalTextOf` 认得这两个字面量（`double.tryParse` 接受它们），所以有限性必须在
    //       文本层面另判一次——`1/0` 的引擎回包走的正是这条路。
    // English: `decimalTextOf` accepts these two literals (so does `double.tryParse`), which is why
    //          finiteness needs a separate text-level test — the engine's receipt for `1/0` takes
    //          exactly this path.
    const infinity =
        MathResult(displayText: 'Infinity', decimalText: 'Infinity');
    const negative =
        MathResult(displayText: '-Infinity', decimalText: '-Infinity');
    const notANumber = MathResult(displayText: 'NaN', decimalText: 'NaN');

    // 中文：`decimalTextOf` **放它过去**（它确实能被 `tryParse` 解析成 `Infinity`），所以挡下它的
    //       必须是 [MathResult.hasFiniteDecimal] ——这正是那道判定必须存在的原因。
    // English: `decimalTextOf` lets it through (it really does parse into `Infinity`), so what stops
    //          it has to be [MathResult.hasFiniteDecimal] — which is why that check exists.
    expect(infinity.decimalText, 'Infinity');
    expect(double.tryParse('Infinity')!.isFinite, isFalse);
    expect(infinity.hasFiniteDecimal, isFalse);
    expect(negative.hasFiniteDecimal, isFalse);
    expect(notANumber.hasFiniteDecimal, isFalse);
    expect(MathResult.decimalTextIsFinite('5.656854'), isTrue);
    expect(MathResult.decimalTextIsFinite(''), isFalse);
    expect(MathResult.decimalTextIsFinite('1 m'), isFalse);
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
