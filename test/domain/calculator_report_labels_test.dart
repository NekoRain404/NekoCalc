import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';
import 'package:nekocalc/domain/usecases/calculator_report_labels.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_controller_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import 'calculator_dataset_fakes.dart';

/// 中文：**报告那九个标签的两端必须一致，而这一份是那个"一致"的可执行版本。**
///
///       ### 两端是哪两端
///
///       - **产出方**：`CalculatorControllerStrings` 里九条 `reportXxx` 句子。报告上写的是
///         `'当前值: 42'` 还是 `'Current value: 42'` 跟着界面语言走（`reportXxx` 是
///         `forLanguage` 分派的那九格），所以标签的词是**会随语言变**的。
///       - **判据**：`calculator_paste_result.dart` 的粘贴解析器——它靠这些词认出"这一段是不是
///         本应用自己写出来的报告"、并从报告里取出表达式/角度模式/记忆值。
///
///       本轮之前这两端**各有一份词**（判据那一份是源码里的字面量），于是"词改了"或"换一种语言
///       产出的报告"都会让判据悄悄对不上：报告不再被认出来、标签行被当成表达式。
///       现在两端读同一张表（[CalculatorReportLabels]），下面四条断言就是这件事的护栏：
///
///       1. **每种语言、每一格**：产出方写出来的句子 == `表里的词 + ': ' + 载荷`。这条断了就说明
///          有人把词写回了源码。
///       2. **表里没有一段是死的**：每种语言都在 [CalculatorReportLabels.all] 里认领到一格
///          （加一种语言而忘了往表里加一格，或反过来，都在这里红）。
///       3. **整份报告逐条走一趟**：每种语言下真的产出一份报告（控制器 `copyText()`），粘回去
///          必须认出来、表达式与记忆值原样回来。
///       4. **标签行要跳过**（也就是本轮改的那一处）：每种语言、每一格标签，一行"标签"跟在
///          `2+3` 前面时，取到的表达式是 `2+3`——**这条走的是没有冒号的那种标签行**，所以它
///          绕开"整段算不算报告"那道闸，直接量到 `_firstExpressionLikeLine` 的跳过表。
///          （有冒号的那种会先被"整段是报告"接住，走不到跳过表——两种路的区别写在
///          `calculator_paste_result.dart` 上。）
///
/// English: **the report's nine labels have two ends, and this file is the executable form of "the
///          two agree".**
///
///          ### Which two ends
///
///          - **The producer**: the nine `reportXxx` sentences in `CalculatorControllerStrings`. What
///            a report reads — `'当前值: 42'` or `'Current value: 42'` — follows the interface
///            language (those nine cells are what `forLanguage` dispatches), so the label words **do
///            move with the language**.
///          - **The judgement**: the paste parser in `calculator_paste_result.dart` — those words are
///            how it recognises "is this text a report this app wrote" and pulls the expression, the
///            angle mode and the memory value out of one.
///
///          Before this round the two ends **each held a copy of the words** (the judgement's copy was
///          literals in the source), so a changed word — or a report produced under another language
///          — quietly stopped matching: the report was no longer recognised and its label lines were
///          taken for expressions. Both ends now read one table ([CalculatorReportLabels]); the four
///          assertions below are that fact's guard:
///
///          1. **Every language, every cell**: the sentence the producer writes equals the table's word
///             plus `': '` plus the payload. If this breaks, someone wrote the words back into the
///             source.
///          2. **No dead entry**: every language claims a cell in [CalculatorReportLabels.all] (adding a
///             language without adding an entry — or the reverse — goes red here).
///          3. **A whole report, once per language**: a report is really produced (the controller's
///             `copyText()`) and pasted back; it has to be recognised, with the expression and the
///             memory value coming home unchanged.
///          4. **Label lines are skipped** (the site this round changes): for every language and every
///             label, a "label" line placed above `2+3` leaves `2+3` as the expression — **this uses
///             the colon-less form of the label line**, so it steps around the "is the whole text a
///             report" gate and measures `_firstExpressionLikeLine`'s skip list directly. (The form
///             with a colon is caught by "the whole text is a report" first and never reaches the skip
///             list; the difference between the two roads is written on
///             `calculator_paste_result.dart`.)
void main() {
  /// 中文：一种语言下表里那一格，`reportCurrentValue` 反查——**不在测试里另写一份配对表**，
  ///       所以"表与产出方对不上"会在这里立刻炸，而不是被一份抄本掩盖过去。
  /// English: the entry that language claims, found by looking `reportCurrentValue` up — **no second
  ///          pairing table in this test**, so "the table and the producer disagree" blows up here
  ///          instead of being masked by a copy.
  CalculatorReportLabels labelsFor(AppLanguage language) {
    final strings = CalculatorControllerStrings.forLanguage(language);
    final sentence = strings.reportCurrentValue('42');
    return CalculatorReportLabels.all.firstWhere(
      (labels) => sentence == '${labels.currentValue}: 42',
      orElse: () => fail(
          '产出方写的 `reportCurrentValue` 在表里找不到对应的词：$sentence（语言 ${language.code}）'),
    );
  }

  test('每一种语言、每一格：产出方写的词就是表里的词', () {
    for (final language in AppLanguage.values) {
      final strings = CalculatorControllerStrings.forLanguage(language);
      final labels = labelsFor(language);
      final reason = '语言 ${language.code}';
      expect(strings.reportExpression('2+3'),
          '${labels.expression}: 2+3', reason: reason);
      expect(strings.reportCurrentValue('42'),
          '${labels.currentValue}: 42', reason: reason);
      expect(strings.reportResult('42'), '${labels.result}: 42',
          reason: reason);
      expect(strings.reportDecimal('5.656854'), '${labels.decimal}: 5.656854',
          reason: reason);
      expect(strings.reportStatus(strings.statusResultReusable),
          '${labels.status}: ${strings.statusResultReusable}',
          reason: reason);
      expect(strings.reportAngleMode(strings.angleModeRadians),
          '${labels.angleMode}: ${strings.angleModeRadians}',
          reason: reason);
      // 中文：**`角度模式` 那一行值里的两个词也从表里来。** 它们与那九个标签是同一根因的第七处：
      //       粘贴解析器从这一行的值里恢复角度模式时，除了认 `DEG`/`RAD` 两个令牌，还要认没有令牌
      //       的写法（`角度模式: 角度`），而它原先认的是源码里另抄的一份 `'角度'`。现在产出方
      //       按表拼句、判据按表认词，两处一起动——这里钉住"产出方真的是按表拼的"。
      // English: **the two words inside the `角度模式` line's value come from the table as well.** They
      //          are the seventh site of the same cause as the nine labels: when the paste parser
      //          recovers the angle mode from that line's value it accepts, besides the `DEG`/`RAD`
      //          tokens, the token-less spelling (`角度模式: 角度`) — and it used to accept it through a
      //          second `'角度'` copied into the source. The producer now composes from the table and
      //          the judgement reads words from it, so the two move together; this pins that the
      //          producer really does compose from the table.
      expect(strings.angleModeDegrees, '${labels.angleDegreesWord} DEG',
          reason: reason);
      expect(strings.angleModeRadians, '${labels.angleRadiansWord} RAD',
          reason: reason);
      expect(strings.reportMemory('42'), '${labels.memory}: 42',
          reason: reason);
      expect(strings.reportError(strings.friendlyNotFinite),
          '${labels.error}: ${strings.friendlyNotFinite}',
          reason: reason);
      expect(strings.reportSavedAt('2026-01-01 00:00'),
          '${labels.savedAt}: 2026-01-01 00:00',
          reason: reason);
    }
  });

  test('表里没有死条目：每种语言都认领到一格，每格都有语言在写', () {
    // 中文：**两个方向都查。** 一个方向：每种语言都要在表里找到自己那一格（上面那条已经在查，
    //       这里把它收成一句"认领到了"）。另一个方向：表里每一格都要有语言在写——否则粘贴那一侧
    //       会认识一套**没有人产出**的词，那就是死条目，而这正是本项目对豁免表/表的既有要求。
    // English: **both directions.** One way: every language has to find its own cell in the table
    //          (covered above; collected here as "claim"). The other: every cell in the table has to
    //          be written by some language — otherwise the paste side knows a set of words **nobody
    //          produces**, which is a dead entry, and that is this project's long-standing rule for
    //          tables and exemption lists alike.
    final claimed = <CalculatorReportLabels>{
      for (final language in AppLanguage.values) labelsFor(language),
    };
    expect(claimed.length, CalculatorReportLabels.all.length,
        reason: '表里有语言没认领到的格子（死条目）：'
            '${CalculatorReportLabels.all.where((labels) => !claimed.contains(labels)).length} 格');
    expect(CalculatorReportLabels.all.length, AppLanguage.values.length,
        reason: '表里的语言数与 `AppLanguage` 不一致——加一种语言要同时加一格');
  });

  test('整份报告：每种语言产出的那一份，粘回去都认得出', () {
    for (final language in AppLanguage.values) {
      final controller = _controller(language);
      controller.setExpression('6×7');
      controller.evaluate();
      controller.memoryAdd();
      final report = controller.copyText();
      controller.dispose();

      // 中文：报告确实带着这一门语言的标签（不然下面那条"认得出"就没有意义）。
      // English: the report really carries this language's label (otherwise "recognised" below would
      //          prove nothing).
      final labels = labelsFor(language);
      expect(report, contains('${labels.expression}: 6×7'),
          reason: '语言 ${language.code}');

      final paste = CalculatorPasteResult.fromText(report);
      expect(paste.fromReport, isTrue, reason: '语言 ${language.code}');
      expect(paste.expression, '6×7', reason: '语言 ${language.code}');
      expect(paste.memoryValue, 42, reason: '语言 ${language.code}');
      expect(paste.angleMode, 'RAD', reason: '语言 ${language.code}');
    }
  });

  test('标签行要跳过：每一门语言的每一格标签都不是表达式', () {
    // 中文：**这一条量的就是本轮改的那一处**（`_firstExpressionLikeLine` 的跳过表）。
    //       没有冒号的那种标签行不会让"整段是报告"那道闸动作，于是一路走到跳过表——表里若不认识
    //       这门语言的这个词，`状态` 那一行会被当成"像表达式的一行"返回出去（英文界面下就是这样）。
    //       `表达式` 不在跳过表里（它是报告里唯一"值本身可能像表达式"的一行），所以它单独列出来：
    //       它**会**被当成表达式返回——这是今天的行为，本轮不动它。
    // English: **this measures the very site this round changes** (`_firstExpressionLikeLine`'s skip
    //          list). A colon-less label line does not trip the "is the whole text a report" gate, so
    //          it reaches the skip list — and if the list does not know this language's word, that
    //          `状态` line comes back as "the line that looks like an expression" (which is what an
    //          English interface used to get). `表达式` is not in the skip list (it is the one report
    //          line whose value may itself look like an expression), so it is listed separately: it
    //          **is** returned as the expression — today's behaviour, untouched this round.
    for (final language in AppLanguage.values) {
      final labels = labelsFor(language);
      final reason = '语言 ${language.code}';
      for (final word in <String>[
        labels.currentValue,
        labels.decimal,
        labels.result,
        labels.status,
        labels.angleMode,
        labels.memory,
        labels.error,
      ]) {
        expect(CalculatorPasteResult.fromText('$word\n2+3').expression, '2+3',
            reason: '$reason / $word');
        // 中文：第二种形态是**带尾巴但不带冒号**的一行（`$word abc`）。它同样绕开"整段是报告"
        //       那道闸（那道闸要求标签后面跟一个冒号），所以两行都压在跳过表上。
        //       **刻意不用"全角冒号"那种形态**：实测它会被标签正则接住（`\s*` 跨得过换行，
        //       于是值读到了下一行），走的是取出当前值那条路，与跳过表无关——那一条路本轮没动。
        // English: the second shape is the one **with a tail but no colon** (`$word abc`). It steps
        //          around the "is the whole text a report" gate too (that gate wants a colon after the
        //          label), so both lines lean on the skip list. **The full-width-colon shape is
        //          deliberately not used**: measured, the label regex catches it (`\s*` crosses the
        //          newline, so the value is read off the next line) and it goes down the
        //          current-value road, which has nothing to do with the skip list — and that road is
        //          untouched this round.
        expect(
            CalculatorPasteResult.fromText('$word abc\n2+3').expression, '2+3',
            reason: '$reason / $word（带尾巴、没有冒号）');
      }
      expect(CalculatorPasteResult.fromText('${labels.expression}\n2+3').expression,
          labels.expression,
          reason: '$reason / ${labels.expression}（它不在跳过表里，今天的行为）');
    }
  });

  test('别名的宽容量没变：`memory value` 仍然认', () {
    // 中文：外层/旧版本报告可能写 `memory value`，它不是本应用写的词，所以**不在表里**，而是
    //       解析器那一侧另加的一个别名（两处：`_looksLikeCalculatorReport` 与
    //       `_memoryValueFromText`）。这一轮不动这个宽容量，所以这里把它钉住。
    // English: a foreign or older report may spell it `memory value`; the app never writes that word,
    //          so it is **not in the table** but an alias added on the parser's side (in two places:
    //          `_looksLikeCalculatorReport` and `_memoryValueFromText`). This round leaves that
    //          leniency alone, so it is pinned here.
    final paste = CalculatorPasteResult.fromText('memory value: 42');
    expect(paste.fromReport, isTrue);
    expect(paste.memoryValue, 42);
  });
}

CalculatorController _controller(AppLanguage language) {
  final db = DatasetFakeDatabase();
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
      languageCode: language.code,
    ),
    engine: DatasetFakeMathEngine(datasetEngineUnavailable),
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
  );
}
