import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';

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
    expect(decimalTextOf('  7.5  '), '7.5');
    expect(decimalTextOf(''), isEmpty);
    expect(decimalTextOf('无效'), isEmpty);
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
    expect(decimalTextIsFinite('5.656854'), isTrue);
    expect(decimalTextIsFinite(''), isFalse);
    expect(decimalTextIsFinite('1 m'), isFalse);
  });

  test('whitespace does not smuggle a non-finite literal past the check', () {
    // 中文：`double.tryParse` 自己会跳过首尾空白，`^…$` 那个字面量正则不会——不先 trim 的话
    //       `' Infinity '` 与 `'NaN '` 都会被判成有限数。适配层先 trim 过所以今天走不到，
    //       但那是等着被下一个调用方踩的坑。
    // English: `double.tryParse` skips surrounding whitespace on its own while the `^…$` literal
    //          regex does not — without trimming first, `' Infinity '` and `'NaN '` both came back
    //          as finite numbers. The adapter trims before calling, so it is unreachable today, but
    //          it is a trap for the next caller.
    expect(decimalTextIsFinite(' Infinity '), isFalse);
    expect(decimalTextIsFinite('NaN '), isFalse);
    expect(decimalTextIsFinite('\t-Infinity\n'), isFalse);
    expect(decimalTextIsFinite(' 5 '), isTrue);
    expect(decimalTextIsFinite('   '), isFalse);
    // 中文：`decimalValue` 走同一处实现，所以空白包着的值该给的还是给。
    // English: `decimalValue` runs through the same implementation, so a whitespace-wrapped value
    //          still yields its number.
    expect(
        const MathResult(displayText: 'x', decimalText: ' 5 ').decimalValue, 5);
    expect(
      const MathResult(displayText: 'x', decimalText: ' Infinity ')
          .decimalValue,
      isNull,
    );
  });

  test('the shared judgement is the only place that turns text into a value',
      () {
    // 中文：`decimalValueOf` 是「一段十进制文本 → 可用的 double」在全应用唯一的实现，提交路径、
    //       粘贴路径、记忆寄存器的表达式分支都从这里过。这条测试钉的是它的四个出口。
    // English: `decimalValueOf` is the app's single implementation of "decimal text into a usable
    //          double" — the submit path, the paste path and the memory register's expression branch
    //          all come through it. This pins its four exits.
    expect(decimalValueOf('5.656854'), 5.656854);
    expect(decimalValueOf(''), isNull);
    expect(decimalValueOf('1 m'), isNull);
    expect(decimalValueOf('1e602'), isNull, reason: 'overflow');
    expect(decimalValueOf('9.3e-603'), isNull, reason: 'underflow');
    expect(decimalValueOf('0'), 0);
    expect(decimalValueOf('0e-999'), 0, reason: 'a real zero');
    expect(usableDouble(5), 5);
    expect(usableDouble(double.infinity), isNull);
    expect(usableDouble(double.nan), isNull);
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

  test('the placeholder is an identity, not a sentence', () {
    // 中文：**占位由 [MathResult.isPlaceholder] 回答。** 那句话（`等待输入`）是**显示**，不是判据：
    //       控制器三处判据（`reusableResult` / `canContinueWithResult` / `continueWithResult`）
    //       现在读这个字段——翻译那句话、改一个标点、换一种界面语言，都不会让判据变成永远为假。
    //       所以这里钉两件事：占位那一份为真，**印着同一句话的普通结果为假**。
    //       （`MathResult.legacy('等待输入')` 是后者的构造实例：旧求值器其实产出不了它——
    //       `formatNumber` 只会给数字——所以那是一个测试才造得出的状态，而 `==` 与它必须说"不相等"：
    //       一份是占位、一份是值，行为不同。）
    // English: **the placeholder is answered by [MathResult.isPlaceholder].** The sentence (`等待输入`)
    //          is the **display**, not the judgement: the controller's three judgements
    //          (`reusableResult` / `canContinueWithResult` / `continueWithResult`) read this field now,
    //          so translating the sentence, moving a punctuation mark or switching the interface
    //          language cannot make the judgement permanently false. Two things are pinned here: the
    //          placeholder's flag is true, and **an ordinary result printing the same sentence is
    //          false**. (`MathResult.legacy('等待输入')` builds the latter: the legacy evaluator
    //          cannot really produce it — `formatNumber` only ever yields numbers — so that state is
    //          one only a test can build, and `==` has to call it *unequal*: one is a placeholder,
    //          the other a value, and they behave differently.)
    expect(MathResult.pending.isPlaceholder, isTrue);
    expect(MathResult.pending.displayText, '等待输入');
    expect(MathResult.pending.decimalText, isEmpty);
    expect(MathResult.legacy('等待输入').isPlaceholder, isFalse);
    expect(MathResult.legacy('等待输入'), isNot(MathResult.pending));
    expect(MathResult.zero.isPlaceholder, isFalse);
    expect(MathResult.legacy('5').isPlaceholder, isFalse);
    // 中文：字段是构造时就定下的，不是算出来的——两"份"占位相等（值相等），而它与一份普通结果不等。
    // English: the cell is set at construction rather than computed — two placeholders are equal (value
    //          equality), and neither equals an ordinary result.
    expect(const MathResult(displayText: '等待输入', isPlaceholder: true),
        MathResult.pending);
  });
}
