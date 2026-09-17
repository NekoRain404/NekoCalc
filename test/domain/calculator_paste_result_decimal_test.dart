import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';

/// 中文：粘贴路径的「当前值」规则（3c 评审的第 2 条）。
///
///       报告里的 `当前值` 行是**显示形态**，只在它本身已经是一个可解析、有限的十进制时才被采用：
///
///       - 旧求值器下显示形态就是十进制形态，复制粘贴的往返靠的正是这一条，必须照旧；
///       - 精确形式（`4√2`）没有十进制形态，于是粘贴什么都不恢复——**绝不把显示文本解析成数字**，
///         更不会用一个失败解析出的 0 冒充一个值。
///
///       这两半放在同一个文件里，因为只有放在一起才看得出这条规则的边界在哪。
///
/// English: The paste path's current-value rule (finding 2 of the 3c review).
///
///          A report's current-value line is *display text* and is only taken when it is itself a
///          parseable, finite decimal:
///
///          - under the legacy evaluator the display form *is* the decimal form, which is what keeps
///            the copy/paste round trip working and has to stay that way;
///          - an exact form (`4√2`) has no decimal form, so the paste restores nothing — display text
///            is *never* parsed as a number, and a failed parse's 0 is never passed off as a value.
///
///          Both halves live in one file because the boundary is only visible with both in view.
void main() {
  test('a current value that is a decimal is restored', () {
    // 中文：旧求值器产出的报告就是这一种：显示形态即十进制形态，没有 `十进制:` 行。
    //       （`calculator_result_split_test.dart` 里那条 `pasting a report without a decimal line
    //       behaves as before` 把守同一件事；这里紧挨着它的反例放着。）
    // English: This is what a legacy report looks like: the display form is the decimal form, and
    //          there is no `十进制:` line. (`pasting a report without a decimal line behaves as
    //          before` in `calculator_result_split_test.dart` guards the same thing; it sits here
    //          beside its counterexample.)
    final paste = CalculatorPasteResult.fromText('''
当前值: 1,234.5
状态: 当前值可继续使用
角度模式: 角度 DEG
''');

    expect(paste.expression, '1234.5');
    expect(paste.fromReport, isTrue);
    expect(paste.summary, contains('已从计算详情恢复当前值'));
  });

  test('a decimal line still wins over the current value', () {
    final paste = CalculatorPasteResult.fromText('''
当前值: 4√2
十进制: 5.656854
状态: 当前值可继续使用
''');

    expect(paste.expression, '5.656854');
  });

  test('a current value with no decimal form is not parsed as a number', () {
    // 中文：精确形式且**没有**十进制形态——报告因此没有 `十进制:` 行，而 `当前值` 行本身不是数字。
    //       粘贴不接受它：没有表达式、不崩、也不会拿一个解析失败的 0 当结果。失败是「闭」的。
    // English: An exact form with *no* decimal form — so the report carries no `十进制:` line, and
    //          the current-value line is not a number. The paste refuses it: no expression, no
    //          crash, and no 0 from a failed parse presented as a result. The failure is closed.
    final paste = CalculatorPasteResult.fromText('''
当前值: 4√2
状态: 当前值可继续使用
角度模式: RAD
''');

    expect(paste.expression, isEmpty);
    expect(paste.hasExpression, isFalse);
    expect(paste.fromReport, isTrue);
    // 中文：元数据照旧恢复——只有「当前值」这一半被拒。
    // English: The metadata is still restored — only the current-value half is refused.
    expect(paste.angleMode, 'RAD');
  });

  test('a current value that is not a number at all is refused the same way',
      () {
    final paste = CalculatorPasteResult.fromText('''
当前值: not-a-number
状态: 当前值可继续使用
''');

    expect(paste.expression, isEmpty);
    expect(paste.hasExpression, isFalse);
  });

  test('a decimal written without its integer digit is still a decimal', () {
    // 中文：`.5` 本身就是一个可解析的十进制，所以它照旧可用——被拒的是「不是十进制」的显示文本，
    //       不是写法不好看的十进制。写回表达式时补上整数位是给解析器用的形状，与「解释一个非数字」
    //       是两回事。
    // English: `.5` is itself a parseable decimal, so it stays usable — what gets refused is display
    //          text that is not a decimal, not a decimal that is written untidily. Adding the integer
    //          digit when writing it back is a shape for the parser, not an interpretation of a
    //          non-number.
    expect(
      CalculatorPasteResult.fromText('当前值: .5').expression,
      '0.5',
    );
    expect(
      CalculatorPasteResult.fromText('当前值: -.5').expression,
      '-0.5',
    );
  });

  test('a value that does not survive a double is not a value', () {
    // 中文：`9.303768583076e-603` 能被 `double.tryParse` 解析成一个**有限的** `0.0`，于是它以前
    //       被当成可用值粘回来——**「解析成功」不等于「值保住了」**：粘回来的是一个比原值小
    //       10^600 倍的数，静默错值。`1.148130695274255E602` 是同一根因的另一端（解析成
    //       `Infinity`）。两者现在与提交路径、记忆寄存器共用同一处判定，一律拒绝（fail-closed）。
    // English: `9.303768583076e-603` used to be accepted because `double.tryParse` turns it into a
    //          *finite* `0.0` — but "it parsed" is not "the value survived": pasting it back yields a
    //          number 10^600 times smaller, a silent wrong value. `1.148130695274255E602` is the
    //          other end of the same root cause (it parses into `Infinity`). Both now share one
    //          judgement implementation with the submit path and the memory register and are refused
    //          (fail-closed).
    expect(
      CalculatorPasteResult.fromText('当前值: 9.303768583076e-603').expression,
      isEmpty,
    );
    expect(
      CalculatorPasteResult.fromText('当前值: 1.148130695274255E602').expression,
      isEmpty,
    );
    // 中文：`十进制:` 行走的是同一个取值函数，所以同样拒绝——精确形式那份报告也不会被粘错。
    // English: The `十进制:` line goes through the same accessor and is refused the same way, so an
    //          exact form's report cannot paste a wrong number either.
    expect(
      CalculatorPasteResult.fromText('十进制: 9.303768583076e-603').expression,
      isEmpty,
    );
  });

  test('a non-finite current value is not a value', () {
    // 中文：`Infinity`/`NaN` 能被 `double.tryParse` 认出来，却不是可以写回表达式的数值。
    // English: `double.tryParse` accepts `Infinity`/`NaN`, but neither is a value that can be
    //          written back into the expression.
    expect(CalculatorPasteResult.fromText('当前值: Infinity').expression, isEmpty);
    expect(CalculatorPasteResult.fromText('当前值: NaN').expression, isEmpty);
  });
}
