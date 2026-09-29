import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
  const controller = TextToolController();

  test('text tool output builds reusable copy text and status summaries', () {
    final output = controller.calculate(
        strings: _strings, toolId: 'base64', input: 'NekoCalc');

    expect(output.hasError, isFalse);
    expect(output.statusTitle(_strings.output), '结果可复用');
    expect(output.statusMessage(_strings.output), contains('主结果 12 字符'));
    expect(output.statusMessage(_strings.output), contains('详细结果'));
    expect(output.statusMessage(_strings.output), contains('校核提示'));
    expect(output.primaryCopyText, 'TmVrb0NhbGM=');
    expect(output.detailCopyText, contains('Base64URL: TmVrb0NhbGM'));

    final copyText = output.copyText(
        strings: _strings.output, title: 'Base64', input: 'NekoCalc');
    expect(copyText, startsWith('Base64'));
    expect(copyText, contains('输入:\nNekoCalc'));
    expect(copyText, contains('状态: 结果可复用'));
    expect(copyText, contains('主结果:\nTmVrb0NhbGM='));
    expect(copyText, contains('详细结果:'));
    expect(copyText, contains('校核:'));
  });

  test('text tool output reports invalid state without hiding detail', () {
    final output = controller.calculate(
        strings: _strings, toolId: 'json_format', input: '{bad');

    expect(output.hasError, isTrue);
    expect(output.statusTitle(_strings.output), '输入需要修正');
    expect(output.statusMessage(_strings.output), contains('FormatException'));
    expect(output.primaryCopyText, '输入无效');
    expect(output.detailCopyText, contains('FormatException'));

    final copyText = output.copyText(
        strings: _strings.output, title: 'JSON 格式化', input: '{bad');
    expect(copyText, contains('状态: 输入需要修正'));
    expect(copyText, contains('主结果:\n输入无效'));
    expect(copyText, contains('详细结果:'));
  });

  test('custom formula accepts pasted numeric variants', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'custom_formula',
      input: '',
      formula: 'a * b + c',
      a: '1,200',
      b: '2',
      c: '5％',
    );

    expect(output.primary, '2400.05');
    expect(output.detail, contains('a = 1200'));
    expect(output.detail, contains('展开公式: 1200 * 2 + 0.05'));
    expect(output.insights.join('\n'), contains('公式使用变量: [a, b, c]'));
  });

  test('custom formula extracts formula and variables from pasted text', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'custom_formula',
      input: '''
formula: a^2 + sqrt(b) - c
a = 4
b = 81
c = 3
''',
      formula: 'a + b + c',
      a: '1',
      b: '2',
      c: '3',
    );

    expect(output.primary, '22');
    expect(output.detail, contains('公式: a^2 + sqrt(b) - c'));
    expect(output.detail, contains('展开公式: 4^2 + sqrt(81) - 3'));
    expect(output.detail, contains('a = 4'));
    expect(output.detail, contains('来源: 输入文本 "4"'));
    expect(output.insights, contains('已从输入文本中提取公式。'));
    expect(output.insights, contains('已从输入文本中提取变量: a, b, c。'));
    expect(output.insights.join('\n'), contains('公式使用变量: [a, b, c]'));
  });

  test('custom formula paste draft reuses shared field extraction', () {
    final draft = TextToolController.customFormulaDraftFromPastedText(
      input: '''
a: 4; b: 81; c: 3
a^2 + sqrt(b) - c
''',
      currentFormula: 'a + b + c',
      currentA: '1',
      currentB: '2',
      currentC: '3',
    );

    expect(draft.toolId, 'custom_formula');
    expect(draft.input, contains('a: 4; b: 81; c: 3'));
    expect(draft.formula, 'a^2 + sqrt(b) - c');
    expect(draft.a, '4');
    expect(draft.b, '81');
    expect(draft.c, '3');

    final variableOnlyDraft =
        TextToolController.customFormulaDraftFromPastedText(
      input: 'a=8, b=13',
      currentFormula: 'max(a, b)',
      currentA: '1',
      currentB: '2',
      currentC: '3',
    );
    expect(variableOnlyDraft.formula, 'max(a, b)');
    expect(variableOnlyDraft.a, '8');
    expect(variableOnlyDraft.b, '13');
    expect(variableOnlyDraft.c, '3');
  });

  test('custom formula avoids replacing letters inside function names', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'custom_formula',
      input: '',
      formula: 'abs(a) + max(b, c)',
      a: '-5',
      b: '3',
      c: '7',
    );

    expect(output.primary, '12');
    expect(output.detail, contains('展开公式: abs(-5) + max(3, 7)'));
  });

  test('text tool drafts round trip and stay isolated by tool id', () {
    const draft = TextToolDraft(
      toolId: 'custom_formula',
      input: '',
      formula: 'a^2 + b - c',
      a: '4k',
      b: '2',
      c: '1',
    );

    final encoded = TextToolController.encodeDraft(draft);
    final restored = TextToolController.decodeDraft(
      toolId: 'custom_formula',
      raw: encoded,
    );

    expect(
        TextToolController.draftSettingKey('base64'), 'text_tool_draft_base64');
    expect(restored, isNotNull);
    expect(restored!.toolId, 'custom_formula');
    expect(restored.formula, 'a^2 + b - c');
    expect(restored.a, '4k');
    expect(restored.b, '2');
    expect(restored.c, '1');
    expect(
      TextToolController.decodeDraft(toolId: 'base64', raw: encoded),
      isNull,
    );
    expect(
        TextToolController.decodeDraft(toolId: 'base64', raw: 'bad'), isNull);

    final partial = TextToolController.decodeDraft(
      toolId: 'base64',
      raw: '{"toolId":"base64","values":{}}',
    );
    expect(partial, isNotNull);
    expect(partial!.input, isEmpty);
    expect(partial.formula, TextToolController.defaultFormula);
    expect(partial.a, TextToolController.defaultA);
  });

  test('custom formula reports invalid variable input', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'custom_formula',
      input: '',
      formula: 'a + b',
      a: 'bad value',
      b: '2',
      c: '0',
    );

    expect(output.primary, '输入无效');
    expect(output.detail, contains('变量 a:'));
    expect(output.detail, contains('无法解析数值或表达式'));
    expect(output.insights, contains('请检查输入格式后重试。'));
  });

  test('custom formula reports non finite formula results', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'custom_formula',
      input: '',
      formula: 'a / b',
      a: '1',
      b: '0',
      c: '0',
    );

    expect(output.primary, '输入无效');
    expect(output.detail, contains('公式结果不是有限数值'));
  });

  test('base converter accepts common pasted integer variants', () {
    final hashHex = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '#FF');
    final suffixHex = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: 'FFh');
    final fullWidthDecimal = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '１_０２４');
    final octal = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '0o755');

    expect(hashHex.primary, '255');
    expect(hashHex.detail, contains('十六进制: FF'));
    expect(hashHex.insights.join('\n'), contains('十六进制'));

    expect(suffixHex.primary, '255');
    expect(suffixHex.insights.join('\n'), contains('h 后缀'));

    expect(fullWidthDecimal.primary, '1024');
    expect(fullWidthDecimal.detail, contains('二进制: 10000000000'));

    expect(octal.primary, '493');
    // 中文：**罗马数字是这一轮新加的那一行**，而它**不在引擎上**——引擎的 `roman()` 在边界上
    //       会给错值（`roman(10000)` 把输入原样还回来、`roman(-1)` 回 `"-I"`），
    //       所以它用自己那份纯函数（`roman_numeral.dart`）。**两条分支都在这里钉住。**
    // English: **the Roman line is this round's addition and it does not sit on the engine** — the
    //          engine's `roman()` yields wrong values at the boundaries (`roman(10000)` hands the input
    //          back, `roman(-1)` gives `"-I"`), so it uses our own pure function (`roman_numeral.dart`).
    //          **Both branches are pinned here.**
    expect(hashHex.detail, contains('罗马数字: CCLV'));
    final outOfRange = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '10000');
    expect(outOfRange.detail, contains('罗马数字:'),
        reason: '规范范围之外仍然有这一行，只是不给数字');
    expect(outOfRange.detail, isNot(contains('罗马数字: 10000')),
        reason: '**引擎在这里会把输入原样还回来**，我们不许那样');
    expect(octal.insights.join('\n'), contains('八进制'));
  });

  test('base converter accepts programming suffixes and constants', () {
    final unsignedHex = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '0xFFu');
    final longDecimal = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '255L');
    final binary = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '0b1010_0001UL');
    final constant = controller.calculate(
      strings: _strings,
      toolId: 'base_convert',
      input: 'Integer.MAX_VALUE',
    );

    expect(unsignedHex.primary, '255');
    expect(unsignedHex.insights.join('\n'), contains('U 类型后缀'));

    expect(longDecimal.primary, '255');
    expect(longDecimal.insights.join('\n'), contains('L 类型后缀'));

    expect(binary.primary, '161');
    expect(binary.detail, contains('十六进制: A1'));
    expect(binary.insights.join('\n'), contains('UL 类型后缀'));

    expect(constant.primary, '2147483647');
    expect(constant.insights, contains('输入识别为十进制（编程语言常量）: Integer.MAX_VALUE。'));
  });

  test('bitwise accepts labeled integer variants', () {
    final output = controller.calculate(
      strings: _strings,
      toolId: 'bitwise',
      input: 'A=0xF0, B=0b1010',
    );
    final constants = controller.calculate(
      strings: _strings,
      toolId: 'bitwise',
      input: 'A=Integer.MAX_VALUE, B=0x0Fu',
    );

    expect(output.primary, 'AND = 0');
    expect(output.detail, contains('A: 240  hex:0xF0'));
    expect(output.detail, contains('B: 10  hex:0xA'));
    expect(output.detail, contains('OR: 250'));
    expect(output.detail, contains('XOR: 250'));
    expect(output.insights.join('\n'), contains('A 识别为十六进制'));
    expect(output.insights.join('\n'), contains('B 识别为二进制'));

    expect(constants.primary, 'AND = 15');
    expect(constants.detail, contains('A: 2147483647'));
    expect(constants.detail, contains('B: 15'));
  });

  test('integer tools report actionable invalid input', () {
    final base = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '0b102');
    final bitwise = controller.calculate(
        strings: _strings, toolId: 'bitwise', input: 'A=0xF0');
    final suffix = controller.calculate(
        strings: _strings, toolId: 'base_convert', input: '0xFFuu');

    expect(base.primary, '输入无效');
    expect(base.detail, contains('整数格式无效'));
    expect(base.insights, contains('请检查输入格式后重试。'));

    expect(bitwise.primary, '输入无效');
    expect(bitwise.detail, contains('请输入两个整数'));

    expect(suffix.primary, '输入无效');
    expect(suffix.detail, contains('整数格式无效'));
  });
}

/// 中文：这一族测试钉的是**中文下表里的字**，所以表要显式取中文那一份——`calculate` 的
///       `strings` 是必填的，正是在这里把它变成"漏传就编译不过"。
/// English: These tests pin the **Chinese entries in the table**, so the table is the Chinese one
///          explicitly — `calculate`'s `strings` is required, and this is where that turns into
///          "forget it and the build fails".
final _strings = TextToolStrings.forLanguage(AppLanguage.zh);
