import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/application/controllers/tool_detail_models.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';

import '../domain/calculator_dataset_fakes.dart';
import '../shared/source_scan.dart';

/// 中文：**控制器那两句"人话"的源码护栏与判据护栏。**
///
///       ### 它问的问题
///
///       `lib/application/controllers/` 里还有没有**没走文案表的界面文案**？这一轮的答案是
///       "没有，除了下面那张豁免表点名的那些"——它们不是句子，是**输入文法、判据与日志**。
///       （上一轮那张豁免表里还有**与结果比较的哨兵** `'等待输入'`一条；本轮三处判据改读
///       `MathResult.isPlaceholder`，哨兵字面量在控制器目录里一条不剩，那一条豁免因此被拆掉，
///       总数从 53 变成 52——**理由被删掉时该说一声**，见「占位由身份回答」那条测试。）
///       三张表（`ToolDetailStrings` / `NumericInputStrings` / `CalculatorControllerStrings`）里
///       "表里的字对不对"的断言在各自的测试文件里；这一份只问"源码里还剩什么"。
///
///       ### 尺子与覆盖范围
///
///       尺子是 `test/shared/source_scan.dart` 的 `containsWideOrFullwidth`——与设置页、计算器页、
///       工具子树、拟合领域层那四条护栏**同一把**（不是同一段文字，是同一个函数）。
///
///       扫的目录是 `lib/application/controllers`（递归、全部 `.dart`）。**按名字跳过的有四类**，
///       每一类都有自己的理由，而**没有一类是"这个文件写起来麻烦"**：
///       1. 那张**双语检索索引**：`tool_search_aliases_a/b/c.dart` 与 `tool_search_data.dart`。
///          那里的中文是**搜索词本身**（中英各一份），是刻意双语的索引；把它们"翻"掉等于删掉
///          中文搜索能力。文件头写着这件事。
///       2. `notes_controller.dart`——**用户未提交的那个文件**。本轮一个字都没动，它那 17 条
///          中文仍在源码里，这是**已知的残留**，不是漏翻；等用户那笔改动落地后这一行应当撤掉，
///          那时它会被下面这条扫描逼着走表。
///       3. `text_tool_*.dart`——文本工具那一族，**已经有自己的护栏**
///          （`text_tool_strings_test.dart` 第 3 条、`text_tool_stats_data_strings_test.dart`），
///          豁免逐条带理由地列在那里。这里再列一遍就是同一份豁免两个地方各自漂。
///       4. 下面那张豁免表点名的字面量。
///
///       ### 豁免表不是垃圾桶
///
///       与 `data_fit_copy_test.dart` 同一条规矩：**每一条豁免都必须真的命中一次**，
///       所以下面有一个 `used` 计数断言。一条只会放行、永远不生效的豁免，与一条界面文案一样糟——
///       它会让下一个人以为这里已经查过了。
/// English: **the source guard and the verdict guard for the controllers' two kinds of sentence.**
///
///          ### What it asks
///
///          Is there **interface copy that never went through a table** left in
///          `lib/application/controllers/`? This round's answer is "no, apart from what the exemption
///          table below names" — those are not sentences but **input grammar, branch conditions and
///          logs**. (Last round's table also held a sixth entry, **the sentinel compared against
///          results**, `'等待输入'`; this round the three judgements read `MathResult.isPlaceholder`
///          instead, not one sentinel literal is left in the controllers directory, and that
///          exemption was therefore removed — the total goes from 53 to 52. **A reason that is
///          removed should say so**; see the "占位由身份回答" test.) The "are the tables' words right" assertions live in each table's own test file;
///          this one asks only what is left in the source.
///
///          ### The ruler and the coverage
///
///          The ruler is `test/shared/source_scan.dart`'s `containsWideOrFullwidth` — **the same one**
///          as the four guards for the settings page, the calculator page, the tools subtree and the fit
///          domain layer (the same *function*, not the same paragraph).
///
///          The directory scanned is `lib/application/controllers` (recursive, every `.dart`). **Four
///          kinds are skipped by name**, each for its own reason, and **none of them is "that file
///          would be awkward"**:
///          1. The **bilingual search index**: `tool_search_aliases_a/b/c.dart` and
///             `tool_search_data.dart`. The Chinese there *is* the search term (one per language) — a
///             deliberately bilingual index; "translating" it would delete Chinese search. Its file
///             head says so.
///          2. `notes_controller.dart` — **the user's uncommitted file**. Not one character of it was
///             touched this round, so its 17 Chinese literals are still in the source: a **known
///             remainder**, not a missed translation. Once the user's change lands this line should be
///             removed and the scan below will push them through a table.
///          3. `text_tool_*.dart` — the text-tool family **already has its own guard**
///             (`text_tool_strings_test.dart` clause 3, `text_tool_stats_data_strings_test.dart`), with
///             its exemptions each carrying a reason. Listing them again here would be one exemption
///             drifting in two places.
///          4. The literals the exemption table below names.
///
///          ### The exemption table is not a bin
///
///          The same rule as `data_fit_copy_test.dart`: **every exemption must actually fire once**, so
///          there is a `used` count assertion below. An exemption that only ever permits and never
///          takes effect is as bad as a piece of interface copy — it makes the next reader believe this
///          ground was already checked.
void main() {
  test('控制器目录里除了三张文案表与豁免表再没有中文字符串字面量', () {
    final directory = Directory('lib/application/controllers');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    final used = <String>{};
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：四类跳过，理由在文件头上，逐条对应。
      // English: four kinds of skip; the reasons are on the file head, one for one.
      if (_bilingualSearchIndex.contains(name)) continue;
      if (name == 'notes_controller.dart') continue;
      if (name.startsWith('text_tool_')) continue;
      final source = stripComments(entity.readAsStringSync());
      for (final literal in stringLiterals(source)) {
        if (!containsWideOrFullwidth(literal)) continue;
        if (_dataLiterals.contains(literal) ||
            _logLiterals.contains(literal)) {
          used.add(literal);
          continue;
        }
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 ToolDetailStrings / NumericInputStrings / '
            'CalculatorControllerStrings：\n${offenders.join('\n')}');
    final dead = _allExemptions.difference(used);
    expect(dead, isEmpty,
        reason: '豁免表里这些条目一条都没用到，是死条目：${dead.join(' | ')}');
  });

  // 中文：**名字里的分组数就是每一组的实测条数**，加起来是 52：输入文法 21、粘贴 JSON 键与正则 17、
  //       检索归一化 10、日志 2。**哨兵那一条本轮拆掉了**（53 → 52）：三处判据改读
  //       `MathResult.isPlaceholder` 之后，`'等待输入'` 在控制器目录里一个字符串字面量都不剩，
  //       留着它就成了一条永远不生效的死豁免。名字写错一个数不会让测试变红，所以下面那条断言量的
  //       是**总数**——分组数靠这一段与源码里的注释对齐。
  // English: **the group counts in the name are the measured counts**, and they add up to 52: input
  //          grammar 21, paste JSON keys and regexes 17, search normalisation 10, truncation ellipses
  //          2, logs 2. **The sentinel entry was removed this round** (53 → 52): once the three
  //          judgements read `MathResult.isPlaceholder`, not one `'等待输入'` string literal is left in
  //          the controllers directory, so keeping it would have been a permanently idle exemption. A
  //          wrong number in a name does not turn the test red, so what the assertion below measures
  //          is the **total** — the group counts are kept honest by this paragraph and the comments in
  //          the source.
  test('豁免表逐条命中：输入文法 21 条、粘贴 JSON 键与正则 17 条、检索归一化 10 条、'
      '日志 2 条', () {
    // 中文：**这一条量的是"豁免表的形状没变"。** 数字会随中文措辞与新增文件一起动，所以它的用处
    //       不是"证明 51 这个数很对"，而是"豁免表没有空转、也没有在没人看的时候长胖"。
    //       上面那条测试已经在数量上钉住了"没有死条目"，这一条钉住的是总量。
    // English: **this measures the shape of the exemption table.** The number moves with Chinese wording
    //          and new files, so its job is not "52 is the right number" but "the table is neither
    //          idling nor quietly fattening when nobody is looking". The test above already pins "no
    //          dead entry"; this one pins the total.
    expect(_allExemptions.length, 51);
  });

  test('占位由身份回答：三处判据读 isPlaceholder，不拿那句话去比', () {
    // 中文：**上一轮记下、这一轮拆掉的那一条。** `reusableResult` / `canContinueWithResult` /
    //       `continueWithResult` 原先写的是 `result == '等待输入'`——拿一句**要显示给用户的话**当
    //       判据。与 `TextToolOutput.hasError` 当初那一份是同一种病：翻译它，判据就永远为假。
    //       现在的处置是给它一个真正的答案：`MathResult.isPlaceholder`（身份是字段，那句话只是
    //       它印出来的样子）。这条测试从**行为**那一侧钉住它，不钉源码的字形：
    //       1. 占位本身：身份为真，而印出来的那句话**一字未动**（显示没有跟着改）；
    //       2. 只是印出同一句话、身份却是「值」的结果**不是**占位——这正是"判据不读文案"的含义；
    //       3. 三处判据在控制器上一起动：不能继续、写回 `0`、按下「继续使用」表达式不动。
    // English: **the row this round removes, recorded last round.** `reusableResult` /
    //          `canContinueWithResult` / `continueWithResult` used to read `result == '等待输入'` — a
    //          **sentence meant for the user** doubling as a branch condition, the same disease
    //          `TextToolOutput.hasError` had: translate it and the condition is forever false. The
    //          disposal is to give that question a real answer — `MathResult.isPlaceholder` (the
    //          identity is a field; the sentence is only how it prints). This test pins it **from the
    //          behaviour side**, not by matching source shapes:
    //          1. the placeholder itself: the flag is true while the sentence it prints is **not moved
    //             by one character** (the display did not change with the judgement);
    //          2. a result that merely prints the same sentence but is a *value* is **not** the
    //             placeholder — which is exactly what "the judgement does not read the copy" means;
    //          3. all three judgements move together on a controller: not continuable, writes `0`
    //             back, and pressing continue-with-result leaves the expression alone.
    expect(MathResult.pending.isPlaceholder, isTrue);
    expect(MathResult.pending.displayText, '等待输入');
    expect(MathResult.pending.decimalText, isEmpty);
    expect(MathResult.zero.isPlaceholder, isFalse);
    expect(MathResult.legacy('等待输入').isPlaceholder, isFalse);

    final db = DatasetFakeDatabase();
    final controller = CalculatorController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      settingsRepository: SettingsRepository(db),
      settings: AppSettings.fallback,
      engine: DatasetFakeMathEngine(datasetEngineUnavailable),
      liveEvaluationDelay: const Duration(minutes: 10),
      liveEngineFollowUpDelay: const Duration(minutes: 10),
    );
    addTearDown(controller.dispose);
    controller.applyMathResult(MathResult.pending);
    expect(controller.result, '等待输入');
    expect(controller.canContinueWithResult, isFalse);
    expect(controller.reusableResult, '0');
    controller.continueWithResult();
    expect(controller.expression, isEmpty);
    // 中文：有结果时三处照旧——判据只换了个问法，没有变宽也没有变窄。
    // English: with a result on screen all three are what they were — the judgement changed its
    //          question, not its width.
    controller.applyMathResult(MathResult.legacy('5'));
    expect(controller.canContinueWithResult, isTrue);
    expect(controller.reusableResult, '5');
    controller.continueWithResult();
    expect(controller.expression, '5');
  });

  test('持久化令牌 `数学符号` 只有一处：`SettingsTokens`，kill switch 直接引用它', () {
    // 中文：**"存储格式不是标签"这一类里最贵的一个。** `kEngineBackedLiveExpressionDisplay` 是
    //       「边打边算走引擎」的判据，比的是**存进库的那个值**。它现在直接引用
    //       `SettingsTokens.expressionDisplaySymbols`，不再把字面量抄进控制器——所以
    //       `lib/application/controllers/calculator_controller.dart` 里一条中文字面量都没有了。
    //       这条断言证明两件事：判据还是那个值，且控制器没有第二份。
    // English: **the most expensive member of the "storage format, not a label" class.**
    //          `kEngineBackedLiveExpressionDisplay` is the "as-you-type uses the engine" condition, and
    //          it compares **the value stored in the database**. It now references
    //          `SettingsTokens.expressionDisplaySymbols` directly instead of copying the literal into
    //          the controller — so `lib/application/controllers/calculator_controller.dart` holds no
    //          Chinese literal at all. This assertion proves two things: the condition still holds that
    //          value, and the controller carries no second copy of it.
    expect(kEngineBackedLiveExpressionDisplay,
        SettingsTokens.expressionDisplaySymbols);
    expect(kEngineBackedLiveExpressionDisplay, '数学符号');
  });

  test('数值解析的失败判据与它说的话分家：判据是枚举，话由调用方递表', () {
    // 中文：**同一件事在数据通道上的版本。** `NumericInputParseResult.error` 原先是一个
    //       `String`，值就是那四句中文；现在字段是 `NumericInputIssue` 加两个载荷格，
    //       渲染要调用方把表递进来。这条断言钉住"递哪张表就说哪种话"，
    //       以及"判据不随语言变"。
    // English: **the same story on the data channel.** `NumericInputParseResult.error` used to be a
    //          `String` whose value was those four Chinese sentences; the field is now a
    //          `NumericInputIssue` plus two payload slots, and rendering takes a table from the caller.
    //          This pins "which table you hand in is which language you get" and "the verdict does not
    //          move with the language".
    const parsed = NumericInputParseResult(
      value: null,
      issue: NumericInputIssue.unitMismatch,
      unitLabel: 'V',
      targetUnit: 'A',
    );
    expect(parsed.value, isNull);
    expect(parsed.hasError, isTrue);
    expect(parsed.issue, NumericInputIssue.unitMismatch);
    expect(parsed.issueMessage(ToolDetailStrings.toolDetailZh.numericInput),
        '单位 V 与 A 不匹配');
    expect(parsed.issueMessage(ToolDetailStrings.toolDetailEn.numericInput),
        'Unit V does not match A');

    const empty = NumericInputParseResult(
      value: null,
      issue: NumericInputIssue.empty,
    );
    expect(empty.unitLabel, isEmpty);
    expect(empty.targetUnit, isEmpty);

    const ok = NumericInputParseResult(value: 2.5);
    expect(ok.hasError, isFalse);
    expect(ok.issue, isNull);
    expect(ok.issueMessage(ToolDetailStrings.toolDetailZh.numericInput), isEmpty);
  });

  test('工具详情页那张表的语言由 `ToolDetailStrings.forCode` 决定，代码认不出时是中文', () {
    // 中文：详情页在 `initState` 里造控制器、那一刻不许查 `BuildContext`，所以构造走 `forCode`
    //       （按 `AppSettings.languageCode`），随后 `didChangeDependencies` 用作用域里当场生效的
    //       那一张覆盖。这条断言钉住 `forCode` 那条路——**包括"认不出的代码回落到中文"**，
    //       那是 `AppLanguage.fromCode` 的既有约定。
    // English: the detail screen builds its controller in `initState`, where a `BuildContext` may not be
    //          queried, so construction goes through `forCode` (by `AppSettings.languageCode`) and
    //          `didChangeDependencies` then overwrites it with the scope's live table. This pins the
    //          `forCode` route — **including "an unrecognised code falls back to Chinese"**, which is
    //          `AppLanguage.fromCode`'s existing convention.
    expect(ToolDetailStrings.forCode('zh'), same(ToolDetailStrings.toolDetailZh));
    expect(ToolDetailStrings.forCode('en'), same(ToolDetailStrings.toolDetailEn));
    expect(ToolDetailStrings.forCode(null), same(ToolDetailStrings.toolDetailZh));
    expect(ToolDetailStrings.forCode('de'), same(ToolDetailStrings.toolDetailZh));
  });

  test('计算器那张表跟着 `AppSettings.languageCode` 走，且是**每次取一次**', () {
    // 中文：这份控制器顺着已经在手上的设置取表，所以"换语言之后下一句话就是新语言的"这件事
    //       取决于**没有缓存**。这条断言从设置那一侧钉它：同一个控制器，设置换过之后立刻换语言。
    // English: this controller resolves the table from settings it already holds, so "the next sentence
    //          after a language change is in the new language" depends on **there being no cache**. This
    //          pins it from the settings side: one controller, and the language moves the moment the
    //          settings do.
    final db = DatasetFakeDatabase();
    final controller = CalculatorController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      settingsRepository: SettingsRepository(db),
      settings: AppSettings.fallback,
      engine: DatasetFakeMathEngine(datasetEngineUnavailable),
      liveEvaluationDelay: const Duration(minutes: 10),
      liveEngineFollowUpDelay: const Duration(minutes: 10),
    );
    addTearDown(controller.dispose);
    expect(controller.strings.statusNeedsFix, '表达式需要修正');
    controller.updateSettings(const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: true,
      autoSaveHistory: true,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: SettingsTokens.themeModeSystem,
      expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
      languageCode: 'en',
    ));
    expect(controller.strings.statusNeedsFix, 'The expression needs fixing');
    expect(controller.strings.statusRetryHint, 'Check the expression and try again.');
  });
}

/// 中文：那张**刻意双语**的检索索引。理由见文件头第 1 条。
/// English: the deliberately **bilingual** search index; see item 1 on the file head.
const Set<String> _bilingualSearchIndex = <String>{
  'tool_search_aliases_a.dart',
  'tool_search_aliases_b.dart',
  'tool_search_aliases_c.dart',
  'tool_search_data.dart',
};

/// 中文：**写给开发者看的日志**。两条 `debugPrint` 的正文；用户看不到，而且日志保持一种语言才好
///       grep。理由见 `tool_detail_strings.dart` 第 4 条。
/// English: **logs written for developers.** The bodies of two `debugPrint`s; they never reach a user,
///          and a log is easier to grep in one language. See item 4 on `tool_detail_strings.dart`.
const Set<String> _logLiterals = <String>{
  r'$qalculateLogTag 引擎没有可用结果，提交路径回落到旧解析器: ',
  r'$qalculateLogTag 表达式翻译不了，直接走旧解析器: $translated',
};

/// 中文：**输入文法、粘贴文本里的中文标签、检索归一化表，以及一个省略号。** 逐条分三组，
///       共同点是**它们不是句子**——它们匹配的是用户会敲进来或粘进来的中文，或者只是被替换掉的
///       记号。翻了它们，中文输入就再也读不懂了。
///
///       **别把界面文案加进这三个集合**：入选条件是上面这些理由，不是方便。
/// English: **input grammar, the Chinese labels inside pasted text, the search normalisation table, and
///          one ellipsis.** Three groups, one common property: **they are not sentences** — they match
///          Chinese the user types or pastes, or they are merely tokens that get replaced. Translating
///          them would stop Chinese input being read at all.
///
///          **Do not add interface copy to these three sets**: the reasons above qualify an entry, not
///          convenience.
final Set<String> _dataLiterals = <String>{
  // —— 输入文法：用户可能敲进来的中文单位写法（`_normalizeDurationText` /
  //    `_durationTargetFactor` / `_normalizeConductorAreaText` 拿它们当查表键）——
  '纳秒', '微秒', '毫秒', '分', '分钟', '时', '小时', '秒', '天', '周', '星期',
  '直径', '直徑', '线径', '線徑', '半径', '半徑', '股', '根', '芯', '：',
  // —— 粘贴文本里的中文标签：JSON/容器键与那些用来匹配它们的正则 ——
  '参数', '输入', '输入参数', '读数', '值', '单位',
  r'[\s/()（）\[\]【】]+',
  r'[\s:：=,，;；\(\)（）\[\]【】]+',
  r'[;；]',
  r'(?:^|[\s,;，；])',
  r'\s*(?:=>|->|[:：=])\s*([^\s,;，；]+)',
  r'\s*(?:=>|->|[:：=])\s*(.+?)\s*$',
  r'(?:=>|->|[:：=])',
  r'\s{2,}|[,，]',
  r'[,，]',
  r'[\d０-９]',
  // 中文：**一条标点判据**：粘贴的那一段里有没有用全角逗号当列分隔符。它是分支条件
  //       （`_pastedTableColumns`），不是句子里那个逗号——注意别与上面 `_dataLiterals` 之外
  //       的 `'，'`（`ToolDetailStrings.sentenceSeparator`）混为一谈，那一个**已经进表了**。
  // English: **a punctuation verdict**: whether the pasted segment uses a fullwidth comma as a column
  //          separator. It is a branch condition (`_pastedTableColumns`), not the comma inside a
  //          sentence — do not confuse it with `'，'` outside this set
  //          (`ToolDetailStrings.sentenceSeparator`), which **has** gone into a table.
  '，',
  // —— 检索归一化：`searchTextVariants` / `compactMatchText` 拿它们换成 ASCII 写法或截断 ——
  '平方', '立方', '欧姆', '（', '）', '＊', '／', '·', '　',
  r'[\s*/.·-]+',
  // —— 截断省略号：附在被截断的字符串后面，两种语言里都是这一个字形，不是句子 ——
  // 中文：⚠️ **进制读数那一条本轮删掉了**——它的截断搬进了 `convertToBase`（`lib/core/math/`，
  //       不在控制器目录里，所以这条豁免够不着它，也不需要）。护栏如实报了"死条目"，
  //       这就是那张表存在的意义：**豁免会过期，而过期的豁免是一处没人看得见的空洞**。
  // English: ⚠️ **the base read-out's entry was deleted this round** — its truncation moved into
  //          `convertToBase` (`lib/core/math/`, outside the controllers directory, so this exemption
  //          cannot reach it and is not needed). The guard truthfully reported a **dead entry**, which
  //          is what that table is for: **exemptions expire, and an expired exemption is a hole nobody
  //          can see**.
  r'${normalized.substring(0, 33)}…',
};

Set<String> get _allExemptions => _dataLiterals.union(_logLiterals);
