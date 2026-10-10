/// 中文：**一次工具结果保存的结局，以及它自带的载荷——这里一个字都不给用户看。**
///
///       这个对象原先自己拼那几句话（`'结果已保存到历史记录'`、`'已保存到笔记'`、
///       `'请先修正输入参数：$summary'`、`'没有可保存的计算结果'`、`'历史记录没有写入，请重试'`、
///       `'保存历史失败：$error'`…），而它们真的会上屏：工具详情页、文本工具详情页与拟合页三处
///       `SnackBar` 都直接印 `result.message`。**领域对象活得比界面长**，界面那张按语言切的文案表
///       够不着它，所以那几句话在任何界面语言下都是中文——`docs/verification.md` §5i 记着这条
///       层次性缺陷（提交路径与保存笔记路径先一步改成了这个形状，照的又是工具结果那条老路：
///       `ToolResult.conclusion` + `toolResultConclusion`）。
///
///       **令牌用的是两个已有的枚举**：[ToolSaveStatus]（哪种结局）与 [ToolSaveTarget]（存到哪里）
///       ——一句话由**这一对**决定，所以没有发明第三个类型；两个 `switch` 都穷尽各自的枚举，
///       加一种结局或一个去处都在呈现层编译不过，而不是静默印一句别的话。字在
///       `ToolsStrings` 里，由 `toolSaveMessage(result, strings)` 在**呈现边缘**取用。
///
///       **载荷格为什么还是 `String`**：它们不是这里拼的句子，是**调用方递进来的数据**——
///       `summary` 是控制器（或拟合页）递进来的那串参数错误说明，`errorMessage` 是异常的
///       `toString()`（两种语言里同一个技术串）；`recordId` 是写库回执，屏幕不读。呈现层要把它们
///       拼进句子里（`'请先修正输入参数：$summary'`、`'保存历史失败：$error'`），所以留作载荷。
///       **无名构造因此是私有的**：它不要求载荷合法。
/// English: **the outcome of one tool-result save, with its payloads — and not one word here is shown
///          to a user.**
///
///          This object used to compose its own sentences (`'结果已保存到历史记录'`, `'已保存到笔记'`,
///          `'请先修正输入参数：$summary'`, `'没有可保存的计算结果'`, `'历史记录没有写入，请重试'`,
///          `'保存历史失败：$error'` …), and they really did reach the screen: three `SnackBar`s — the
///          tool detail screen, the text tool detail screen and the fit screen — printed
///          `result.message` straight. **A domain object outlives the UI**, a widget-level strings
///          table cannot reach it, so those sentences were Chinese under every interface language —
///          the layering defect recorded in `docs/verification.md` §5i.
///
///          **The tokens are the two enums that already existed**: [ToolSaveStatus] (which outcome) and
///          [ToolSaveTarget] (where it was being stored) — one sentence is fixed by **the pair**, so no
///          third type was invented; both `switch`es exhaust their enum, so adding an outcome or a
///          destination breaks the presentation layer at compile time rather than quietly printing some
///          other sentence. The words live in `ToolsStrings`, read **at the presentation edge** by
///          `toolSaveMessage(result, strings)`.
///
///          **Why the payload slots are still `String`s**: they are not sentences composed here but
///          **data handed in by the caller** — `summary` is the run of parameter complaints the
///          controller (or the fit screen) hands over, `errorMessage` an exception's `toString()` (one
///          technical string in either language); `recordId` is the write receipt and is not read by the
///          screen. The presentation edge splices them into a sentence
///          (`'请先修正输入参数：$summary'`, `'保存历史失败：$error'`), so they stay payloads. **The
///          unnamed constructor is therefore private**: it does not require the payloads to be legal.
library;

enum ToolSaveTarget {
  history,
  note,
}

/// 中文：**这一次保存是五种结局里的哪一种**——呈现层与 [ToolSaveTarget] 一起拿它取那句话（同一句
///       话在两个去处上写法不同的有 `saved` / `notWritten` / `failed` 三种）。
/// English: **which of the five outcomes this save is** — the presentation layer resolves the sentence
///          from it together with [ToolSaveTarget] (three of them word the sentence differently per
///          destination: `saved` / `notWritten` / `failed`).
enum ToolSaveStatus {
  saved,
  inputInvalid,
  noResult,
  notWritten,
  failed,
}

class ToolSaveResult {
  /// 中文：**无名构造是私有的**：`inputInvalid` 要求非空 `summary`、`failed` 要求非空
  ///       `errorMessage`，而呈现层读这两个载荷时用的是 `!`。留一个公开的无名构造，就等于留一条
  ///       「令牌说 inputInvalid、载荷却是 null」的路，那条路上屏幕会印出半句话或者崩掉。
  /// English: **the unnamed constructor is private**: `inputInvalid` requires a non-null `summary`,
  ///          `failed` a non-null `errorMessage`, and the presentation layer reads both with `!`. A
  ///          public unnamed constructor would leave a road where the token says `inputInvalid` while
  ///          the payload is null — down that road the screen prints half a sentence or throws.
  const ToolSaveResult._({
    required this.target,
    required this.status,
    this.recordId,
    this.summary,
    this.errorMessage,
  });

  const ToolSaveResult.savedHistory(int historyId)
      : this._(
          target: ToolSaveTarget.history,
          status: ToolSaveStatus.saved,
          recordId: historyId,
        );

  const ToolSaveResult.savedNote(int noteId)
      : this._(
          target: ToolSaveTarget.note,
          status: ToolSaveStatus.saved,
          recordId: noteId,
        );

  ToolSaveResult.inputInvalid({
    required ToolSaveTarget target,
    required String summary,
  }) : this._(
          target: target,
          status: ToolSaveStatus.inputInvalid,
          summary: summary,
        );

  ToolSaveResult.noResult(ToolSaveTarget target)
      : this._(
          target: target,
          status: ToolSaveStatus.noResult,
        );

  ToolSaveResult.notWritten(ToolSaveTarget target)
      : this._(
          target: target,
          status: ToolSaveStatus.notWritten,
        );

  ToolSaveResult.failed({
    required ToolSaveTarget target,
    required Object error,
  }) : this._(
          target: target,
          status: ToolSaveStatus.failed,
          errorMessage: error.toString(),
        );

  final ToolSaveTarget target;
  final ToolSaveStatus status;

  /// 中文：写库回执（历史 id 或笔记 id），屏幕不读它。
  /// English: the write receipt (a history id or a note id); the screen does not read it.
  final int? recordId;

  /// 中文：`inputInvalid` 时递给呈现层的载荷——控制器或拟合页写下的那串参数错误说明。呈现层用
  ///       一条与从前逐字节相同的判据决定句子形状：**去掉空白后为空就不加那个冒号**。
  /// English: the payload handed to the presentation layer for `inputInvalid` — the parameter
  ///          complaints the controller or the fit screen wrote down. The presentation layer decides
  ///          the sentence's shape with the same rule as before, byte for byte: **empty after trimming
  ///          means no colon**.
  final String? summary;

  /// 中文：`failed` 时递给呈现层的载荷——异常的 `toString()`；构造保证这一支里它非空。
  /// English: the payload handed to the presentation layer for `failed` — an exception's
  ///          `toString()`; the constructor guarantees it is non-null in that branch.
  final String? errorMessage;

  bool get saved => status == ToolSaveStatus.saved;

  bool get needsAttention => !saved;
}
