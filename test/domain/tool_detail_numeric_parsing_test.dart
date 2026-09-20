import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/application/controllers/tool_detail_models.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_field_strings.dart';

/// 中文：中文那一侧的表，见 `tool_detail_unit_alias_parsing_test.dart` 里同一段的理由。
/// English: the Chinese side's table; the reasoning is the paragraph with the same job in
///          `tool_detail_unit_alias_parsing_test.dart`.
final zhNumericInput = NumericInputStrings.numericInputZh;

void main() {
  test('parses pasted numeric input variants', () {
    expect(ToolDetailController.parseNumericInput('1,234.5'), 1234.5);
    expect(ToolDetailController.parseNumericInput('1_000 + 2_500.5'), 3500.5);
    expect(ToolDetailController.parseNumericInput('－12.5'), -12.5);
    expect(ToolDetailController.parseNumericInput('12.5％'), 0.125);
    expect(ToolDetailController.parseNumericInput('１.５×２'), 3);
    expect(ToolDetailController.parseNumericInput('√9'), 3);
    expect(ToolDetailController.parseNumericInput('2½'), closeTo(2.5, 1e-12));
    expect(ToolDetailController.parseNumericInput('result: 2*3'), 6);
    expect(ToolDetailController.parseNumericInput('输出 => 1,234.5'), 1234.5);
    expect(ToolDetailController.parseNumericInput('10 ± 5%'), 10);
    expect(ToolDetailController.parseNumericInput('读数：-12.5±0.3'), -12.5);
    expect(ToolDetailController.parseNumericInput('≈3.3'), 3.3);
    expect(ToolDetailController.parseNumericInput('about 1.5'), 1.5);
    expect(ToolDetailController.parseNumericInput('max(2)'), 2);
    expect(ToolDetailController.parseNumericInput('bad value'), 0);
  });

  test('parses numeric input with field units and engineering prefixes', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('10 mA', 'A').value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 nA', 'μA').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4.7kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('470mΩ', 'Ω').value,
      closeTo(0.47, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MΩ', 'Ω').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.1uF', 'nF').value,
      closeTo(100, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mH', 'H').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MH', 'H').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆亨', 'MH').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mF', 'F').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MF', 'F').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2毫法', 'μF').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3兆法', 'MF').value,
      closeTo(3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1,200 Hz', 'kHz').value,
      closeTo(1.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5万元', '元').value,
      closeTo(5000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('current: 10 mA', 'A')
          .value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('电阻 = 4.7kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('温度 -> 77华氏度', '℃').value,
      closeTo(25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4.7kΩ ±5%', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100Ω (±1%)', 'kΩ').value,
      closeTo(0.1, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('≤10mA', 'A').value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('about 4.7 kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3.3V typ.', 'V').value,
      closeTo(3.3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3.0~3.6V', 'mV').value,
      closeTo(3000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500-1000mA', 'A').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2.5V to 5V', 'V').value,
      closeTo(2.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10-2 V', 'V').value,
      closeTo(8, 1e-12),
    );

    final mismatch = ToolDetailController.parseNumericInputForUnit('12 V', 'A');
    expect(mismatch.value, isNull);
    expect(mismatch.issue, NumericInputIssue.unitMismatch);
    expect(mismatch.unitLabel, 'V');
    expect(mismatch.targetUnit, 'A');
    expect(mismatch.issueMessage(zhNumericInput), '单位 V 与 A 不匹配');

    // 中文：**本轮那一格。** 目标单位是**目录声明的**（`_inputUnit(key)`，取的就是工具定义里的
    //       `input.unit`），所以它过目录那张表；用户打的 `unitLabel` 不过——两种语言下都原样出。
    //       **上面那条断言量不出东西**：`V` 对 `A` 两边都是符号，看哪边都没差异；
    //       `万元` 是那张表里的一条（`10k ¥`），用它才量得到。
    // English: **this round's cell.** The target unit is **the catalogue's declaration**
    //          (`_inputUnit(key)`, whose value is the tool definition's `input.unit`), so it goes
    //          through the catalogue's table; the user's `unitLabel` does not — it shows verbatim in
    //          both languages. **The assertion above measures nothing**: `V` against `A` is notation
    //          in either tongue and looks the same on both sides; `万元` is one of that table's
    //          entries (`10k ¥`) and is what makes a difference visible.
    final catalogue = ToolDetailController.parseNumericInputForUnit('12 V', '万元');
    expect(catalogue.issue, NumericInputIssue.unitMismatch);
    expect(catalogue.targetUnit, '万元', reason: '解析层必须原样留住目录里那个单位，一个字符都不许动');
    expect(catalogue.unitLabel, 'V');
    expect(catalogue.issueMessage(zhNumericInput), '单位 V 与 万元 不匹配',
        reason: '中文侧与改动前不是逐字节相同（中文表是空表，查不到原样返回，所以这条必须恒等）');
    final enMessage = catalogue.issueMessage(NumericInputStrings.numericInputEn);
    expect(enMessage, 'Unit V does not match 10k ¥');
    expect(RegExp(r'[一-鿿]').hasMatch(enMessage), isFalse,
        reason: '英文界面上那一格还有汉字：$enMessage');
  });

  test('用户打的单位两种语言下都原样出，只有目录那个过表', () {
    // 中文：**两个槽的分界，正着反着各钉一次。** 用户用中文打了 `12伏`，解析器把单位从数值里切出来，
    //       所以那一格是 `伏`（不是 `12伏`——**这条断言是我第一版写错的地方**：我以为整串都进那一格）。
    //       英文界面上它仍是 `伏`——**那是他打的字，不是我们的话**。而 `targetUnit` 是目录的话，它换。
    // English: **the boundary between the two slots, pinned from both sides.** The user typed `12伏` and
    //          the parser cuts the unit out of the number, so that cell holds `伏` (not `12伏` — **this
    //          is what my first version of the assertion got wrong**: I took the whole string to land
    //          there). An English screen still shows `伏` — **those are their characters, not our
    //          sentence.** `targetUnit` is the catalogue's sentence, and it changes.
    final typed = ToolDetailController.parseNumericInputForUnit('12伏', '万元');
    expect(typed.issue, NumericInputIssue.unitMismatch);
    expect(typed.unitLabel, '伏');
    final enMessage = typed.issueMessage(NumericInputStrings.numericInputEn);
    expect(enMessage, contains('伏'), reason: '用户打的字被翻掉了');
    expect(enMessage, contains('10k ¥'), reason: '目录那个单位没过表');
    expect(enMessage, isNot(contains('万元')), reason: '目录那个单位还是中文');
  });

  test('中文单位表是恒等的，英文单位表把目录里那 11 个中文单位全盖住了', () {
    // 中文：**「中文侧与改动前逐字节相同」不能只靠构造论证。** 显示侧现在把 `targetUnit` 过一遍
    //       `ToolFieldStrings.inputUnit`；中文那一句之所以一字未变，全靠**中文单位表是空的**。
    //       把这件事钉住：哪天有人往中文表里填一条，中文界面上那句话就变了，这一条当场红。
    //
    //       量的是**目录里真实出现过的单位**，不是表里有什么——左边这一列是"目录声明了哪些"，
    //       右边那一列是"表能不能把它们送出去"。两边都不为空，否则这条测试在空转。
    //       （`unit: '单位'` 那种匹配不算数：那是 `ToolMatchTokens.unit` 一个**检索令牌**，
    //       不是任何参数的 `input.unit`。）
    // English: **"the Chinese side is byte-identical to the pre-change one" cannot rest on an argument
    //          from construction.** The display side now passes `targetUnit` through
    //          `ToolFieldStrings.inputUnit`, and the Chinese sentence is unchanged solely because **the
    //          Chinese unit table is empty**. Pin that: the day someone puts an entry in it, the Chinese
    //          sentence moves and this test goes red on the spot.
    //
    //          What is measured is **the units the catalogue actually declares**, not what the table
    //          happens to hold — the left column asks "what did the catalogue declare", the right asks
    //          "can the table send them out". Neither may be empty, or this test spins in place. (A
    //          match like `unit: '单位'` does not count: that is `ToolMatchTokens.unit`, a **search
    //          token**, not any parameter's `input.unit`.)
    final declared = <String>{
      for (final tool in toolCatalog)
        for (final input in tool.inputs)
          if (input.unit.isNotEmpty) input.unit,
    };
    expect(declared, isNotEmpty, reason: '一个单位都没取到，这条测试在空转');

    const enTable = ToolFieldStrings.toolFieldsEn;
    final chineseUnits =
        declared.where((unit) => RegExp(r'[一-鿿]').hasMatch(unit)).toSet();
    expect(chineseUnits.length, 11,
        reason: '目录里含汉字的不同单位数变了（现在是 ${chineseUnits.length}）：$chineseUnits');

    for (final unit in declared) {
      expect(ToolFieldStrings.toolFieldsZh.inputUnit(unit), unit,
          reason: '中文单位表不是恒等的：`$unit` 被查成了别的东西，中文界面那句话就变了');
    }
    for (final unit in chineseUnits) {
      expect(enTable.inputUnit(unit), isNot(unit),
          reason: '目录里的中文单位 `$unit` 过了英文表还是原样，英文界面上它仍是汉字');
      expect(RegExp(r'[一-鿿]').hasMatch(enTable.inputUnit(unit)), isFalse,
          reason: '`$unit` 过了英文表还有汉字：${enTable.inputUnit(unit)}');
    }
  });

  test('parses common Chinese unit aliases for numeric fields', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5公里', 'm').value,
      closeTo(1500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1Mm', 'm').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mm', 'm').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250μm', 'mm').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500nm', 'μm').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('12厘米', 'm').value,
      closeTo(0.12, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2公斤', 'kg').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1Mg', 'kg').value,
      closeTo(1000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mg', 'kg').value,
      closeTo(0.000001, 1e-15),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2吨', 'kg').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500毫升', 'L').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10平方厘米', 'm²').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2公顷', 'm²').value,
      closeTo(20000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3亩', 'm²').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1英亩', 'ha').value,
      closeTo(0.40468564224, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('72公里/小时', 'm/s').value,
      closeTo(20, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5千牛', 'N').value,
      closeTo(5000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mN', 'N').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MN', 'N').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆牛', 'MN').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2度', 'J').value,
      closeTo(7200000, 1e-3),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('7850kg/m³', 'g/cm³').value,
      closeTo(7.85, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.2立方米/小时', 'L/min').value,
      closeTo(20, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2加仑', 'L').value,
      closeTo(7.570823568, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3汤匙', 'mL').value,
      closeTo(44.36029434375, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('12 cubic inches', 'mL')
          .value,
      closeTo(196.644768, 1e-9),
    );
  });

  test('parses composite same-dimension unit input', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('1m20cm', 'm').value,
      closeTo(1.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('6ft 2in', 'cm').value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('6 feet 2 inches', 'cm')
          .value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit("6'2\"", 'cm').value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5′8″', 'cm').value,
      closeTo(172.72, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('72"', 'cm').value,
      closeTo(182.88, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3yd', 'm').value,
      closeTo(2.7432, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5 miles', 'km').value,
      closeTo(2.414016, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2英里', 'km').value,
      closeTo(3.218688, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5lb 8oz', 'kg').value,
      closeTo(2.494758035, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('重量: 1kg 250g', 'kg').value,
      closeTo(1.25, 1e-12),
    );
  });

  test('parses temperature unit aliases and names', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('77华氏度', '℃').value,
      closeTo(25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('300开尔文', '℃').value,
      closeTo(26.85, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('25 celsius', 'K').value,
      closeTo(298.15, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('68 Fahrenheit', 'K').value,
      closeTo(293.15, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('491.67°R', '℃').value,
      closeTo(0, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('536.67 rankine', '℃')
          .value,
      closeTo(25, 1e-12),
    );
  });

  test('tracks invalid numeric input without overwriting current values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValue('current', '2*3');
    expect(controller.values['current'], 6);
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', 'bad value');
    expect(controller.values['current'], 6);
    expect(controller.inputErrors['current'], contains('无法解析'));
    expect(controller.hasInputErrors, isTrue);

    controller.updateValue('current', '4');
    expect(controller.values['current'], 4);
    expect(controller.inputErrors, isEmpty);
  });

  test('updates tool inputs using pasted units without overwriting on mismatch',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': 'current: 10 mA',
      'resistance': '电阻 = 4.7kΩ ±5%',
      'tol': '1% (±0.1%)',
    });

    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], closeTo(4700, 1e-9));
    expect(controller.values['tol'], 1);
    expect(controller.primary?.value, '47');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', '500-1000mA');
    expect(controller.values['current'], closeTo(0.5, 1e-12));
    expect(controller.primary?.value, '2350');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', '12 V');
    expect(controller.values['current'], closeTo(0.5, 1e-12));
    expect(controller.inputErrors['current'], contains('单位 V 与 A 不匹配'));
  });

  test('extracts tool input values from pasted labeled text', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');

    final values = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
欧姆定律记录
电流 I: 10 mA
电阻 R = 4.7kΩ ±5%
tol: 1%
unused = 123
''',
    );

    expect(values, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final compactValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: 'current=25mA; resistance=220Ω; voltage=5V',
    );
    expect(compactValues, {
      'current': '25mA',
      'resistance': '220Ω',
      'voltage': '5V',
    });

    final unitOnlyValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
10 mA
4.7kΩ ±5%
1%
''',
    );
    expect(unitOnlyValues, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final tableValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
参数\t读数
电流 I\t10 mA
电阻 R\t4.7kΩ ±5%
电阻公差\t1%
''',
    );
    expect(tableValues, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final ignoredValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '欧姆定律记录\nignore this line\n功率提示: low',
    );
    expect(ignoredValues, isEmpty);
  });

  test('reports pasted numeric input issues and parses nested JSON values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');

    final jsonResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
{
  "inputs": {
    "电流 I": {"value": "10", "unit": "mA"},
    "电阻 R": "4.7kΩ",
    "电阻公差": "1%"
  }
}
''',
    );
    expect(jsonResult.values, {
      'current': '10mA',
      'resistance': '4.7kΩ',
      'tol': '1%',
    });
    expect(jsonResult.hasIssues, isFalse);
    expect(jsonResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), '已粘贴 3 个参数');

    final mixedResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
电流 I: 10 mA
电流 I: 25 mA
电压 V: 12 V
未知参数: 123
5
''',
    );
    expect(mixedResult.values, {
      'current': '25 mA',
      'voltage': '12 V',
    });
    expect(mixedResult.duplicateKeys, {'current'});
    expect(mixedResult.ignoredSegments, contains('未知参数: 123'));
    expect(mixedResult.ambiguousSegments, contains('5'));
    expect(mixedResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('已粘贴 2 个参数'));
    expect(mixedResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('重复字段已取最后值：电流 I'));
    expect(mixedResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('跳过 1 条歧义值'));
    expect(mixedResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('忽略 1 条未匹配值'));
  });

  test('batch updates keep valid fields when another pasted field is invalid',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': '10 mA',
      'resistance': '12 V',
      'tol': '1%',
    });

    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['tol'], 1);
    expect(controller.values['resistance'], 220);
    expect(controller.primary?.value, '2.2');
    expect(controller.inputErrors.keys, contains('resistance'));
    expect(controller.inputErrors['resistance'], contains('单位 V 与 Ω 不匹配'));
    expect(controller.inputErrorSummary(), contains('电阻 R'));
  });

  test('pasted input apply result reports invalid matched fields', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    final pasteResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
电流 I: 10 mA
电阻 R: 12 V
未知参数: 123
''',
    );
    final applyResult = controller.applyInputPasteResult(pasteResult);

    expect(applyResult.filledKeys, {'current', 'resistance'});
    expect(applyResult.validKeys, {'current'});
    expect(applyResult.invalidKeyErrors.keys, {'resistance'});
    expect(applyResult.inputTexts['current'], '10 mA');
    expect(applyResult.inputTexts['resistance'], '12 V');
    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], 220);
    expect(controller.inputErrors['resistance'], contains('单位 V 与 Ω 不匹配'));
    expect(applyResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('已应用 1 个参数'));
    expect(applyResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('需修正：电阻 R'));
    expect(applyResult.summaryForTool(tool, ToolDetailStrings.toolDetailZh), contains('忽略 1 条未匹配值'));
  });
}
