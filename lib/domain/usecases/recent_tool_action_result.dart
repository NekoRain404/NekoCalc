/// 中文：**最近使用那两条动作（移除 / 清空）的结局，以及它自带的载荷——这里一个字都不给用户看。**
///
///       这个对象原先自己拼那五句话（`'已从最近使用移除「$toolTitle」'`、`'这项最近使用已经不存在'`、
///       `'已清空 N 个最近工具'`、`'最近使用已经是空的'`、`'移除最近使用失败：$error'`），
///       而它们真的会上屏：`tools_home_page.dart` 的 `SnackBar` 直接印 `result.message`。
///       **领域对象活得比界面长**，界面那张按语言切的文案表够不着它，所以那五句话在任何界面语言下
///       都是中文——`docs/verification.md` §5i 记着这条层次性缺陷。
///
///       现在的形状是**判断与文案分家**（形状照的是已经转过的四条路径：`CalculatorSubmitStatus`、
///       `CalculatorSaveNoteStatus`、`ToolSaveStatus`、`NotesImportPlanStatus` 那几族）：
///       - **判据是 [status]**（[RecentToolActionStatus]）与 [action]：五个结局与从前的五句话
///         一一对应，`failed` 那一格另外靠 `action` 分「移除失败」还是「清空失败」两支；
///       - **文案在 `ToolsStrings` 里**，由 `recentToolActionMessage(result, strings)` 在**呈现边缘**
///         按令牌取，加一种结局时那个穷尽 `switch` 编译不过，而不是静默印一句别的话。
///
///       **载荷格为什么还是 `String` / `int`**：它们不是这里拼的句子，是调用方递进来的数据
///       （工具名、条数，以及 `error.toString()` 这个技术串），要由呈现层拼进句子里。
/// English: **the outcome of one of the two recently-used actions (remove / clear), with its payload —
///          and not one word here is shown to a user.**
///
///          This object used to compose its own five sentences
///          (`'已从最近使用移除「$toolTitle」'`, `'这项最近使用已经不存在'`, `'已清空 N 个最近工具'`,
///          `'最近使用已经是空的'`, `'移除最近使用失败：$error'` …), and they really did reach the screen:
///          a `SnackBar` in `tools_home_page.dart` printed `result.message` straight. **A domain object
///          outlives the UI**, a widget-level strings table cannot reach it, so those five sentences
///          were Chinese under every interface language — the layering defect recorded in
///          `docs/verification.md` §5i.
///
///          The shape is now **verdict and wording parted** (copied from the four converted families:
///          `CalculatorSubmitStatus`, `CalculatorSaveNoteStatus`, `ToolSaveStatus`,
///          `NotesImportPlanStatus`):
///          - **the verdict is [status]** ([RecentToolActionStatus]) together with [action]: five
///            outcomes one for one with the five old sentences, and `failed` splits into the remove and
///            clear halves through `action`;
///          - **the words are in `ToolsStrings`**, read **at the presentation edge** by
///            `recentToolActionMessage(result, strings)`; adding an outcome breaks that exhaustive
///            `switch` at compile time rather than quietly printing some other sentence.
///
///          **Why the payload slots are still `String`s / `int`s**: they are not sentences composed here
///          but data handed in by the caller (a tool name, a count, an exception's `toString()`) for the
///          presentation layer to splice into the sentence.
library;

/// 中文：这次动作是哪一条——它决定 `failed` 那一格印的是「移除」还是「清空」。
/// English: which of the two actions ran — it decides whether a `failed` receipt reads "remove" or
///          "clear".
enum RecentToolAction {
  remove,
  clear,
}

/// 中文：**这一次最近使用动作是五种结局里的哪一种——它既是判据，也是呈现层取那句话用的令牌。**
///
///       每一格与 `ToolsStrings` 里的一格一一对应（`recentToolRemoved` / `recentToolNotFound` /
///       `recentToolsCleared` / `recentToolsAlreadyEmpty` / `recentToolRemoveFailed` ×
///       `recentToolClearFailed`），由 `recentToolActionMessage` 那个穷尽 `switch` 接上；
///       工具名、条数与错误串是**载荷**，留在结果上由呈现层拼进句子。
///
///       **五格互斥**：`removed` 与 `notFound` 由「真的移除了没有」分开（条数为零即后者），
///       `cleared` 与 `alreadyEmpty` 同理由「真的清掉了没有」分开，`failed` 由异常那一支独占——
///       它不可能是前四格里的任何一格，前四格也不会在抛过异常之后再被写出来。
/// English: **which of the five outcomes this recently-used action is — a verdict, and the token the
///          presentation layer resolves the sentence with.**
///
///          Each value corresponds one for one with a cell in `ToolsStrings` (`recentToolRemoved` /
///          `recentToolNotFound` / `recentToolsCleared` / `recentToolsAlreadyEmpty` /
///          `recentToolRemoveFailed` × `recentToolClearFailed`), wired up by the exhaustive `switch`
///          in `recentToolActionMessage`; the tool name, the count and the error string are
///          **payload** and stay on the result for the presentation layer to splice in.
///
///          **The five are mutually exclusive**: `removed` against `notFound` is "did anything really
///          get removed" (a count of zero means the latter), `cleared` against `alreadyEmpty` is the
///          same question for the clear road, and `failed` is held by the exception branch alone — it
///          cannot be any of the first four, and none of those is written after an exception is thrown.
enum RecentToolActionStatus {
  removed,
  notFound,
  cleared,
  alreadyEmpty,
  failed,
}

class RecentToolActionResult {
  /// 中文：**无名构造是私有的**：`removed` 要求 `toolTitle` 非空、`cleared` 要求条数大于零、
  ///       `failed` 要求非空错误串，而呈现层读载荷时用的是 `!`。留一个公开的无名构造，就等于留一条
  ///       「令牌说 removed、工具名却是 null」的路，那条路上屏幕会印出半句话或者崩掉——两种都不该
  ///       由调用方决定（同 `CalculatorSubmitResult` 那条理由）。
  /// English: **the unnamed constructor is private**: `removed` requires a non-null `toolTitle`,
  ///          `cleared` requires a positive count and `failed` requires a non-null error string, while
  ///          the presentation layer reads those payloads with `!`. A public unnamed constructor would
  ///          leave a road where the token says `removed` while the tool name is null — down that road
  ///          the screen prints half a sentence or throws, and neither is a caller's decision to make
  ///          (the same reasoning as `CalculatorSubmitResult`).
  const RecentToolActionResult._({
    required this.action,
    required this.status,
    this.toolTitle,
    this.affectedCount = 0,
    this.errorMessage,
  });

  factory RecentToolActionResult.remove({
    required String toolTitle,
    required int affectedCount,
  }) {
    final normalizedCount = affectedCount < 0 ? 0 : affectedCount;
    if (normalizedCount == 0) {
      return const RecentToolActionResult._(
        action: RecentToolAction.remove,
        status: RecentToolActionStatus.notFound,
      );
    }
    return RecentToolActionResult._(
      action: RecentToolAction.remove,
      status: RecentToolActionStatus.removed,
      toolTitle: toolTitle,
      affectedCount: normalizedCount,
    );
  }

  factory RecentToolActionResult.clear({
    required int affectedCount,
  }) {
    final normalizedCount = affectedCount < 0 ? 0 : affectedCount;
    if (normalizedCount == 0) {
      return const RecentToolActionResult._(
        action: RecentToolAction.clear,
        status: RecentToolActionStatus.alreadyEmpty,
      );
    }
    return RecentToolActionResult._(
      action: RecentToolAction.clear,
      status: RecentToolActionStatus.cleared,
      affectedCount: normalizedCount,
    );
  }

  RecentToolActionResult.failed({
    required RecentToolAction action,
    required Object error,
  }) : this._(
          action: action,
          status: RecentToolActionStatus.failed,
          errorMessage: error.toString(),
        );

  final RecentToolAction action;
  final RecentToolActionStatus status;

  /// 中文：递给呈现层的载荷（不是这里拼的句子）：`removed` 时是被移除的那个工具名，两个 `failed`
  ///       构造路径上仍是同一个字段——它由 [action] 决定印进哪一句。
  /// English: the payload handed to the presentation layer (not a sentence composed here): the removed
  ///          tool's name for `removed`; both `failed` paths fill the same slot, and [action] decides
  ///          which sentence it lands in.
  final String? toolTitle;
  final int affectedCount;
  final String? errorMessage;

  bool get succeeded => status != RecentToolActionStatus.failed;

  bool get changed =>
      status == RecentToolActionStatus.removed ||
      status == RecentToolActionStatus.cleared;

  bool get needsAttention => status == RecentToolActionStatus.failed;
}
