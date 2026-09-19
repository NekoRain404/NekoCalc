part of 'tool_detail_screen.dart';

/// 中文：**数值工具详情页的「产出」那一半**——把算出来的东西交给用户的那几处：复制（整份结果、
///       参数、单条结果）、参数有错时那句拒绝提示、状态卡、主结果框、校核卡。
///
///       **为什么在这里切开。** 这个文件到 797 行时离 800 的上限只剩 3 行，而"状态卡那句
///       `inputErrorSummary` 也要走参数标签表"这一轮至少要再加一处查表与它的双语说明（本目录的
///       惯例是每一处取词都带一段注释，这个文件的另外四处都带了），加完必然越线。按本仓库的
///       惯例（`notes_page.dart`、`settings_page.dart`、`data_fit_tool_screen.dart`、
///       `calculator_page.dart` 都是这么分的）改成 `part`：**切在这条缝上，是因为这半边的每一个
///       成员都只做一件事——把已经算好的东西送出去**（送到剪贴板、送到 SnackBar、送到屏幕上那几张
///       卡），而留在主文件里的那半边负责**把数字弄进来并算出来**（草稿、输入卡、步进、粘贴、
///       应用、重算）。两半之间只有单向的取用：这一半读 `_detailController`，主文件不读这一半的
///       任何状态（这一半没有自己的状态）。
///
///       **一个字节都没有搬歪**：本文件里的 209 行是从 `tool_detail_screen.dart` 原样剪下来的
///       （`sed` 取行，没有重排、没有重写），主文件对应的位置只少了一段、多了一行 `part`，
///       所以两个文件加起来与切之前逐字节相同——这一轮的探针量的就是这件事。
/// English: **the "output" half of the numeric tool detail screen** — the places that hand the computed
///          thing to the user: the copy actions (the whole result, the inputs, one result), the refusal
///          hint when an input is invalid, the status card, the primary-result box and the insight card.
///
///          **Why the cut is here.** At 797 lines this file had 3 lines left under the 800 cap, and this
///          round's change (the status card's `inputErrorSummary` has to go through the parameter-label
///          table too) needs at least one more lookup plus its bilingual note — every lookup in this
///          directory carries one by house style, and the file's other four all do — so it would have
///          gone over. Following this repository's idiom (`notes_page.dart`, `settings_page.dart`,
///          `data_fit_tool_screen.dart` and `calculator_page.dart` are all split this way) it becomes a
///          `part`: **the seam is here because every member of this half does exactly one thing — hand
///          over something already computed** (to the clipboard, to a SnackBar, to the cards on screen),
///          while the half left in the main file **brings the numbers in and computes them** (drafts,
///          the input card, stepping, paste, apply, recalculation). Between the two the traffic runs one
///          way only: this half reads `_detailController`, and the main file reads no state of this
///          half (this half has none).
///
///          **Not one byte moved out of place**: the 209 lines below were lifted verbatim out of
///          `tool_detail_screen.dart` (pulled by line with `sed`, not reflowed or rewritten) and the main
///          file lost exactly that span and gained one `part` line, so the two files together are
///          byte-for-byte what the one file was before the cut — which is what this round's probe
///          measures.

extension _ToolDetailOutputSection on _ToolDetailScreenState {
  Future<void> _copyResult() async {
    if (_detailController.hasInputErrors) {
      _showInputErrorSnack();
      return;
    }
    await Clipboard.setData(ClipboardData(text: _detailController.copyText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ToolsStrings.of(context).resultCopied)));
    }
  }

  Future<void> _copyInputs() async {
    await Clipboard.setData(
      ClipboardData(text: _detailController.inputCopyText()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ToolsStrings.of(context).inputsCopied)));
    }
  }

  Future<void> _copySingleResult(ToolResult result) async {
    if (_detailController.hasInputErrors) {
      _showInputErrorSnack();
      return;
    }
    await Clipboard.setData(
        ClipboardData(text: _detailController.singleResultCopyText(result)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          // 中文：**这句提示里的标签走表，剪贴板里那份不走。** 屏幕上的字是渲染出来的字，
          //       剪贴板里的是复制出去的数据——后者与历史、笔记一样属于持久化，本轮一个字节没动
          //       （见 `tool_result_label_strings.dart` 的文件头）。英文界面下这两处因此不一致，
          //       这是本轮认下的代价。
          // English: **the label in this hint goes through the table; the one in the clipboard does
          //          not.** Text on screen is rendered text, the clipboard is copied-out data — the
          //          latter is persistence, like history and notes, and not one byte moved this round
          //          (see `tool_result_label_strings.dart`'s head). In English those two therefore
          //          disagree, a cost this round knowingly accepts.
          content: Text(ToolsStrings.of(context)
              .copiedLabel(ToolResultLabelStrings.of(context).label(result.label)))));
    }
  }

  // 中文：**参数有错时那句提示与状态卡同源，两处一起走参数卡表。** 表格是 `label (unit): message`，
  //       左边两格（标签、单位）都是显示层的字段（与输入卡左侧那列、输入框里那个 `suffixText` 同一个
  //       `ToolFieldStrings` 的同一对 `of(context)`），第三格是判据写下的那句话。控制器收的是两个
  //       读法而不是表本身——本表的读方向与结果标签那一轮一样只走显示层。
  // English: **the hint raised when an input is invalid shares its source with the status card, and both
  //          go through the input-card table.** The row is `label (unit): message`, whose first two cells
  //          (label, unit) are display-layer fields — the same pair of `ToolFieldStrings` lookups that the
  //          input card's left column and the field's `suffixText` use — and whose third cell is the
  //          sentence the verdict wrote. The controller takes two ways of reading rather than the table
  //          itself: the reading direction for this table, as for the result labels, runs through the
  //          display layer only.
  void _showInputErrorSnack() {
    final strings = ToolsStrings.of(context);
    final fields = ToolFieldStrings.of(context);
    final summary = _detailController.inputErrorSummary(
      inputLabel: fields.inputLabel,
      inputUnit: fields.inputUnit,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.isEmpty
            ? strings.fixInputsFirst
            : strings.fixInputsFirstWith(summary)),
      ),
    );
  }

  Widget _resultStatusCard() {
    final strings = ToolsStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasInputErrors = _detailController.hasInputErrors;
    final hasResultIssues = _detailController.hasResultIssues;
    final color = hasInputErrors
        ? scheme.error
        : hasResultIssues
            ? Colors.orange.shade700
            : scheme.primary;
    final icon = hasInputErrors
        ? Icons.error_outline
        : hasResultIssues
            ? Icons.report_problem_outlined
            : Icons.verified_outlined;
    final title = hasInputErrors
        ? strings.statusInputInvalid
        : hasResultIssues
            ? strings.statusResultCheck
            : strings.statusResultReusable;
    // 中文：状态卡里的结果标签走结果标签表——与结果卡、主结果框同一个来源；写进库里的那份
    //       （历史、复制正文、笔记）读的还是 `result.label` 本身，一个字节没动。
    // English: the result labels inside the status card go through the result-label table — the same
    //          source as the result card and the primary-result box; what is written to the database
    //          (history, the copied body, the note body) still reads `result.label` itself.
    final resultLabel = ToolResultLabelStrings.of(context).label;
    // 中文：**参数有错那一支的两格走参数卡表**（与输入卡左侧那列、输入框里那个 `suffixText` 同一个
    //       来源）。这一支是屏幕自己的：`inputErrorSummary()` 在库里没有读者，另外两条调用它的路
    //       （保存到历史、保存到笔记）都走默认的原样读法——那句 `请先修正输入参数：…` 的外壳由
    //       `ToolSaveResult` 在域层拼、本来就是中文——所以那些路一个字节没动。
    // English: **the invalid-input branch's two cells go through the input-card table** (the same source
    //          as the input card's left column and the field's `suffixText`). This branch is the screen's
    //          own: `inputErrorSummary()` has no reader that writes to the database, and its two other
    //          callers (save to history, save to note) take the default raw reading — the
    //          `请先修正输入参数：…` wrapper around them is assembled by `ToolSaveResult` in the domain
    //          layer and is Chinese anyway — so those routes have not moved by a byte.
    final inputFields = ToolFieldStrings.of(context);
    final details = hasInputErrors
        ? _detailController.inputErrorSummary(
            inputLabel: inputFields.inputLabel,
            inputUnit: inputFields.inputUnit,
          )
        : hasResultIssues
            ? _detailController.resultIssueSummary(resultLabel: resultLabel)
            : _detailController.resultHealthSummaryForDisplay(resultLabel);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(details,
                    style: TextStyle(
                        color: hasInputErrors || hasResultIssues
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryResult(ToolResult primary) {
    final strings = ToolsStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // 中文：主结果框那句标签与结果卡上那一格同源（`ToolResultLabelStrings`）——
                //       同一个 `result.label` 在同一屏上的两处落点不该各翻各的。
                //       这一格最宽（实测 242dp、字号 14），没有长度问题。
                // English: the primary result's label comes from the same table as the result card's
                //          cell (`ToolResultLabelStrings`) — one `result.label` with two landing places
                //          on one screen should not be translated twice. This cell is the widest
                //          (measured 242dp at 14sp) and has no length problem.
                child: Text(ToolResultLabelStrings.of(context).label(primary.label),
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                tooltip: strings.copyPrimaryResult,
                onPressed: () => _copySingleResult(primary),
                iconSize: 18,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  primary.value,
                  style: TextStyle(
                      color: scheme.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(primary.unit,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard() {
    final strings = ToolsStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(strings.insights),
            ..._detailController.insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 17, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, height: 1.35))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
