part of 'tool_detail_controller.dart';

/// 中文：**这个控制器「把状态说成人话」的那一半。** 从 `inputSummary()` 到 `_rawInputField()`：
///       参数行、结果行、状态卡那两句、复制正文、笔记正文、以及两处"原样返回"的标签读法。
///
///       **为什么在这里切开。** 本轮要给 `inputErrorSummary()` 加两个显示侧读法参数与它们的双语说明，
///       而控制器在加之前已经是 784 行、离 800 的上限只剩 16 行，加完 815——越线。按本仓库的惯例
///       （`notes_page.dart`、`settings_page.dart`、`calculator_page.dart` 都这么分；本控制器自己
///       已经有 `tool_detail_paste_parser.dart` 与 `tool_detail_input_parsing.dart` 两个 part）改成
///       `part`。**缝选在这里，是因为这 276 行是同一个职责**：它们都只读已算好的状态、拼出字符串，
///       一行都不写状态、不做解析、不碰数据库；留在主文件里的是"把输入读成数字、算、存取"那一半。
///       `_recalculate()` 留在主文件，是因为它写 `_results` / `_insights`，是状态那一侧的。
///
///       **一个字节都没有搬歪**：下面这 276 行是用 `sed` 按行原样剪下来的，没有重排、没有重写；
///       本轮另有一次探针逐字节量过"切前切后行为相同"（存储值与中文屏幕两句都没动）。
/// English: **the half of this controller that turns state into sentences.** From `inputSummary()` to
///          `_rawInputField()`: the input rows, the result rows, the status card's two sentences, the
///          copied body, the note body, and the two "returns its argument unchanged" label readers.
///
///          **Why the cut is here.** This round had to give `inputErrorSummary()` two display-side
///          readers plus their bilingual note, and the controller was already 784 lines — 16 under the
///          800 cap — so it landed at 815 and crossed the line. Following this repository's idiom
///          (`notes_page.dart`, `settings_page.dart` and `calculator_page.dart` are all split this way,
///          and this controller already has `tool_detail_paste_parser.dart` and
///          `tool_detail_input_parsing.dart`) it becomes a `part`. **The seam is here because these 276
///          lines are one job**: they read state that is already computed and assemble strings, never
///          writing state, parsing, or touching the database; what stays in the main file is the half
///          that reads inputs into numbers, computes, and persists. `_recalculate()` stays with the main
///          file because it writes `_results` / `_insights`, which is the state side.
///
///          **Not one byte moved out of place**: the 276 lines below were lifted verbatim by line with
///          `sed`, not reflowed or rewritten, and this round also ran a byte-for-byte probe that the cut
///          changed no behaviour (neither the stored values nor the two Chinese-screen sentences moved).
///
///       **⚠️ 这个 extension 是公开的，`_` 不能加，这是量出来的不是风格。** 本仓库另外几个 part 里的
///       extension（`_TextToolJsonTools on TextToolController`、`_DataFitActions on
///       _DataFitToolScreenState`…）都是私有的，那是因为**它们管的成员本身也是私有的**——私有
///       extension 的名字出不了本库，别的库既看不见它的名字也就解析不到它的成员。这里被搬走的
///       `inputSummary()` / `resultSummary()` / `copyText()` / `inputErrorSummary()` 这些**是公开
///       接口**（详情页与测试都在别的库里调），所以 extension 必须是公开名：本轮把 `_` 去掉之前先
///       试过私有名，`flutter analyze` 当场报 78 条 `undefined_method`，全在测试库里。
/// English: **⚠️ this extension is public, and the `_` cannot be added back — that is measured, not a
///          style choice.** The extensions in this repository's other parts (`_TextToolJsonTools on
///          TextToolController`, `_DataFitActions on _DataFitToolScreenState`, …) are private, and that
///          works because **the members they manage are private too**: a private extension's name never
///          leaves its library, so a library that cannot see the name cannot resolve its members. What
///          moved here — `inputSummary()`, `resultSummary()`, `copyText()`, `inputErrorSummary()` and the
///          rest — **is public API** (the detail screen and the tests call it from other libraries), so the
///          extension needs a public name: before dropping the `_` this round tried the private name and
///          `flutter analyze` reported 78 `undefined_method` errors, every one of them in a test library.
extension ToolDetailSentences on ToolDetailController {
  String inputSummary() {
    if (tool.inputs.isEmpty) return strings.noInputsNeeded;
    return tool.inputs.map(_inputReportLine).join('\n');
  }

  // ——— 结果行那句「标签: 值」的两个读者：屏幕 与 数据 ———
  //
  // 中文：**屏幕与数据库要的不是同一根字符串，从这里分开。**
  //        · **屏幕侧**（状态卡那两句话）把结果行左边那句话换成显示层查好的那一句——结果卡、
  //          主结果框与它同一个来源，所以英文界面上那句不再是中文；
  //        · **数据侧**（历史 `result` 字段、复制正文、笔记正文）**一个字节没动**：读的还是
  //          `result.label` 本身。历史里已经躺着的行不该因为界面换了语言就"看起来变了"，
  //          而"历史该不该跟着语言走"是一个独立的产品决定，不在这一轮。
  //       两条路共用一份排布（哪几句、怎么连接、超几条），所以它们只可能在"标签怎么念"上不同。
  //
  //       **标签不在这里查表。** `lib/application/controllers/` 里出现结果标签表的名字是越界
  //       （那条边界由 `tool_result_label_strings_test.dart` 的「表只被显示读」钉着：域层与
  //       控制器层一个文件都不提它）。所以这一层收的是一个 `String Function(String label)`——
  //       「结果行左边那句话怎么写」，由调用方给：屏幕递显示层按当前语言查好的那句，数据递
  //       [_rawResultLabel]（原样）。
  // English: **the screen and the database do not need the same string, and they are split here.**
  //          · **The screen side** (the status card's two sentences) replaces the words at the left of
  //            a result row with the ones the display layer looked up — the same source as the result
  //            card and the primary-result box, so in English that sentence is no longer Chinese;
  //          · **the stored side** (the history `result` column, the copied body, the note body) has
  //            **not moved by one byte**: it still reads `result.label` itself. A row already in
  //            history must not appear to change because the interface changed language, and "should
  //            history follow the language?" is a product decision of its own, not this round's.
  //          Both routes share one arrangement (which sentences, how they are joined, what happens
  //          past three), so they can differ only in how a label is written.
  //
  //          **The label is not looked up here.** A mention of the result-label table's name inside
  //          `lib/application/controllers/` is a boundary crossing (the boundary is pinned by
  //          `tool_result_label_strings_test.dart`'s "the table is read for display only": not one
  //          file in the domain or controller layers may mention it). So this layer takes a
  //          `String Function(String label)` — how to write the words at the left of a result row —
  //          from its caller: the screen hands over what the display layer looked up for the active
  //          language, the stored side hands over [_rawResultLabel] (unchanged).

  String resultSummary() {
    if (_results.isEmpty) return strings.noResults;
    return _results.map(_resultReportLine).join('\n');
  }

  /// 中文：**数据侧**的主结果那一行（`标签: 值`）。历史、复制正文、笔记正文读它——
  ///       与拆分前逐字节相同。
  /// English: **the stored side's** primary result row (`label: value`). History, the copied body and
  ///          the note body read it, byte-for-byte as before the split.
  String primaryResultLine() {
    final item = primary;
    return item == null ? strings.noResults : _resultReportLine(item);
  }

  /// 中文：**屏幕侧**的主结果那一行——句子一样，只有结果行左边那句话换成 [resultLabel] 给的
  ///       那一句。中文下 [resultLabel] 原样返回，所以这一句与 [primaryResultLine] 逐字节相同。
  /// English: **the screen side's** primary result row — the same sentence with only the words at the
  ///          left of the result row taken from [resultLabel]. In Chinese [resultLabel] returns its
  ///          argument unchanged, so this is byte-for-byte [primaryResultLine].
  String primaryResultLineForDisplay(String Function(String label) resultLabel) {
    final item = primary;
    return item == null
        ? strings.noResults
        : _resultReportLineWith(resultLabel(item.label), item);
  }

  /// 中文：状态卡那一行的**唯一一处排布**。两个读者各递各的：`primaryLine` 是主结果那一行怎么念，
  ///       `resultLabel` 是一条结果的标签怎么念（需要检查那一支只列标签、不列值）。
  /// English: the status card line's **single arrangement**. Each reader hands in its own two:
  ///          `primaryLine` is how the primary-result row is written, `resultLabel` how one result's
  ///          label is written (the needs-checking branch lists labels only, no values).
  String _resultHealthSentence(
    String Function() primaryLine,
    String Function(String label) resultLabel,
  ) {
    if (_results.isEmpty) return strings.noComputedResults;
    final issues = issueResults;
    if (issues.isNotEmpty) {
      final visible = issues
          .take(3)
          .map((result) => resultLabel(result.label))
          .join(strings.listSeparator);
      final suffix =
          issues.length > 3 ? strings.issueOverflowSuffix(issues.length) : '';
      return strings.resultIssuesNeedCheck(visible, suffix);
    }
    return strings.resultsReusable(usableResults.length, primaryLine());
  }

  /// 中文：**数据侧**的状态卡那一行（`N 个结果可复用，主结果 …`）。复制正文与笔记正文读它——
  ///       与拆分前逐字节相同。
  /// English: **the stored side's** status-card line (`N results are reusable; primary result …`).
  ///          The copied body and the note body read it, byte-for-byte as before the split.
  String resultHealthSummary() =>
      _resultHealthSentence(primaryResultLine, _rawResultLabel);

  /// 中文：**屏幕侧**的状态卡那一行——结果行左边那句话走 [resultLabel]。
  /// English: **the screen side's** status-card line — the words at the left of the result row go
  ///          through [resultLabel].
  String resultHealthSummaryForDisplay(
          String Function(String label) resultLabel) =>
      _resultHealthSentence(
          () => primaryResultLineForDisplay(resultLabel), resultLabel);

  /// 中文：需要检查的那几条结果，一行一条。**它只有屏幕一个读者**（有结果需要检查时，状态卡显示的
  ///       是这一份），所以没有数据侧的孪生兄弟；[resultLabel] 由调用方给，与
  ///       [resultHealthSummaryForDisplay] 同一个来源。
  /// English: the results that need checking, one row each. **The screen is its only reader** (this is
  ///          what the status card shows when results need checking), so it has no stored-side twin;
  ///          [resultLabel] comes from the caller, the same source as [resultHealthSummaryForDisplay].
  String resultIssueSummary({
    required String Function(String label) resultLabel,
    int limit = 4,
  }) {
    final issues = issueResults;
    if (issues.isEmpty) return '';
    final visibleLimit = limit <= 0 ? issues.length : limit;
    final visible = issues
        .take(visibleLimit)
        .map((result) => _resultReportLineWith(resultLabel(result.label), result))
        .join('\n');
    final remaining = issues.length - visibleLimit;
    if (remaining <= 0) return visible;
    return strings.moreIssuesNeedCheck(visible, remaining);
  }

  String insightSummary() {
    if (_insights.isEmpty) return strings.noCheckNotes;
    return _insights.join('\n');
  }

  /// 中文：**这一句有屏幕一个读者，另外两条保存路径各一个。** 屏幕侧（状态卡与那句拒绝提示）要的
  ///       是显示层查好的参数标签与单位，所以按 [resultIssueSummary] 同一形状**收**两个读法；
  ///       **这两个参数有默认值，不是可选的礼貌**：两条保存路径（[saveResult] / [saveNote]）不递，
  ///       拿到的就是原样，那句 `请先修正输入参数：…` 由 `ToolSaveResult` 在域层拼、外壳本来就是中文，
  ///       所以这两条路一个字节没动。**参数卡这张表不在结果标签那条边界里**——那条「域层与控制器层
  ///       一个文件都不提它」的断言只钉结果标签表，没有一条断言禁止控制器提 `ToolFieldStrings`
  ///       （本轮加的是**结果标签那张表的名字**，加了就会当场变红，所以这里连名字都不写）；形状仍按
  ///       结果标签那一轮办，读方向只走显示层。
  /// English: **the screen is one reader of this sentence and the two save paths are the others.** The
  ///          screen side (the status card and the refusal hint) needs the parameter label and unit the
  ///          display layer looked up, so it **takes** two ways of reading them, the same shape as
  ///          [resultIssueSummary]; **the defaults are not politeness**: the two save paths
  ///          ([saveResult] / [saveNote]) hand nothing in and get the raw reading, because their sentence
  ///          is assembled in the domain layer by `ToolSaveResult` and its wrapper is Chinese anyway, so
  ///          those two routes have not moved by a byte. **The input-card table is not inside the result
  ///          label's boundary** — that "not one file in the domain or controller layers may mention it"
  ///          assertion pins the result-label table only, and no assertion forbids a controller mentioning
  ///          `ToolFieldStrings` (what would turn red at once is **writing the result-label table's name
  ///          here**, so this comment does not); the shape of the result-label round is followed anyway,
  ///          so the reading direction still runs through the display layer only.
  String inputErrorSummary({
    String Function(String label) inputLabel = _rawInputField,
    String Function(String unit) inputUnit = _rawInputField,
  }) {
    if (_inputErrors.isEmpty) return '';
    final byKey = {
      for (final input in tool.inputs) input.key: input,
    };
    return _inputErrors.entries.map((entry) {
      final input = byKey[entry.key];
      return strings.inputErrorLine(
        inputLabel(input?.label ?? entry.key),
        inputUnit(input?.unit ?? ''),
        entry.value,
      );
    }).join('\n');
  }

  String copyText() {
    return [
      tool.title,
      tool.description,
      '',
      if (tool.inputs.isNotEmpty) ...[
        strings.copyInputsLabel,
        inputSummary(),
        '',
      ],
      strings.copyResultsLabel,
      resultSummary(),
      '',
      strings.copyResultStatusLabel,
      resultHealthSummary(),
      '',
      strings.copyChecksLabel,
      insightSummary(),
      '',
      strings.copyFormula(tool.formula),
    ].join('\n');
  }

  String inputCopyText() {
    return [
      tool.title,
      if (tool.inputs.isNotEmpty) ...[
        strings.copyInputsLabel,
        inputSummary(),
      ] else
        strings.noInputsNeeded,
    ].join('\n');
  }

  String noteBody() {
    return [
      tool.description,
      if (tool.inputs.isNotEmpty) ...[strings.copyInputsLabel, inputSummary()],
      if (tool.inputs.isNotEmpty) '',
      strings.copyResultsLabel,
      resultSummary(),
      '',
      strings.copyResultStatusLabel,
      resultHealthSummary(),
      '',
      strings.copyChecksLabel,
      insightSummary(),
      strings.copyFormula(tool.formula),
    ].join('\n');
  }

  String singleResultCopyText(ToolResult result) {
    return [
      tool.title,
      _resultReportLine(result),
      if (tool.inputs.isNotEmpty) ...[
        '',
        strings.copyInputsLabel,
        inputSummary(),
      ],
      '',
      strings.copyFormula(tool.formula),
      if (_insights.isNotEmpty) ...[
        '',
        strings.copyChecksLabel,
        _insights.take(3).join('\n'),
      ],
    ].join('\n');
  }

  String _inputReportLine(ToolInputDefinition input) {
    final value = _values[input.key];
    if (value == null && input.optional) {
      return strings.inputNotFilled(input.label);
    }
    final formatted = formatNumber(value ?? 0, precision: 8);
    return '${input.label}: $formatted${input.unit}';
  }

  /// 中文：**数据侧**的一行结果——标签就是 `result.label` 本身。历史 `result` 字段、复制正文、
  ///       笔记正文读的是这一份，与拆分前逐字节相同。
  /// English: **the stored side's** result row — the label is `result.label` itself. The history
  ///          `result` column, the copied body and the note body read this one, byte-for-byte as
  ///          before the split.
  String _resultReportLine(ToolResult result) =>
      _resultReportLineWith(result.label, result);

  /// 中文：一行结果的**唯一一处排布**（`标签: 值`）。两个读者各自把左边那句话递进来，
  ///       所以这里没有第二种写法可以漂。
  /// English: the **single arrangement** of a result row (`label: value`). Each reader hands in the
  ///          words on the left, so there is no second spelling here to drift from.
  String _resultReportLineWith(String label, ToolResult result) =>
      '$label: ${result.valueWithUnit}';

  /// 中文：数据侧的标签读法——**原样返回**。写成一个有名字的函数，是为了让"数据那一侧"是一个
  ///       能点开的名字，而不是散在几处的 `(label) => label`。
  /// English: the stored side's way of writing a label — **returns its argument unchanged**. It is a
  ///          named function so that "the stored side" is a name one can follow rather than a
  ///          `(label) => label` sprinkled around.
  static String _rawResultLabel(String label) => label;

  /// 中文：参数卡那两格（标签与单位）的**数据侧**读法——原样返回，理由与 [_rawResultLabel] 相同：
  ///       写成一个有名字的函数，"原样"才是一个能点开的名字，而不是散在调用点的 `(x) => x`。
  ///       **单位这一格也要**：`input.unit` 与 `input.label` 一样进了 `ToolFieldStrings`，
  ///       只翻标签会让同一句里的 `(元)` 留在英文界面上。
  /// English: the **stored side's** way of reading the input card's two fields (label and unit) —
  ///          returns its argument unchanged, for the same reason as [_rawResultLabel]: a named function
  ///          makes "unchanged" a name one can follow instead of a `(x) => x` at the call site. **The
  ///          unit is in here too**: `input.unit` entered `ToolFieldStrings` just like `input.label`, so
  ///          translating only the label would leave the `(元)` of the same sentence on the English
  ///          screen.
  static String _rawInputField(String value) => value;
}
