import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';
import '../result_form.dart';
import 'math_expression_view.dart';
import 'status_chips.dart';

/// 中文：状态行里按钮的边长——比 Material 默认的 48 小，面板本来就不高，但仍是手指能稳稳点到的
///       方块。状态行的高度就等于它。
/// English: Edge length of a status-row button — smaller than Material's default 48 because the
///          panel itself is short, yet still a square a finger can hit reliably. The status row is
///          exactly this tall.
const double _statusButtonSize = 40;

/// 中文：chip 那三格的度量（24dp 高、6dp 圆角、0.12 的低透明度填充）跟着它们搬到了
///       `status_chips.dart`，因为那里是它们唯一的使用者——度量与用它的东西分开就会漂。
/// English: the metrics of the three chip cells (24dp tall, 6dp radius, a 0.12 low-alpha fill) moved
///          with them to `status_chips.dart`, their only user — metrics separated from their user
///          drift apart.

/// 中文：表达式字号（字号决定整条算式的大小，见 `MathExpressionView`）。
/// English: Expression font size (the size drives the whole equation's metrics, see
///          `MathExpressionView`).
const double _expressionFontSize = 19;

/// 中文：结果与等号的字号——结果行是面板里最重的一行，因此明显大于表达式。
/// English: Font sizes for the result and its equals sign — the result line is the heaviest line
///          in the panel, so it is clearly larger than the expression.
const double _resultFontSize = 30;
const double _equalsFontSize = 22;

/// 中文：错误行标题的字号，以及正文比标题小一号——两级对比就是「哪句是结论、哪句是细节」。
/// English: Font size of the error line's title, with the body one step smaller — that two-step
///          contrast is what says which sentence is the verdict and which is the detail.
const double _errorFontSize = 13;
const double _errorMessageFontSize = 12;

/// 中文：两行显示面板——状态行、表达式行、结果行，出错时再多一行错误提示。
///       组件是**纯函数**：所有值都从构造参数进来，组件自身不持有任何状态、不读控制器、
///       不访问数据库，因此可以脱离应用直接测试。
/// English: The two-line display panel — a status row, the expression line and the result line,
///          plus an error line while there is an error. The widget is a **pure function**: every
///          value arrives as a constructor parameter, it holds no state, reads no controller and
///          touches no database, so it is testable without the app around it.
///
/// 布局 / Layout（自上而下 / top to bottom）:
/// 中文：1) 状态行：最左是抽屉按钮（`onOpenDrawer` 为空则不渲染），接着角度模式 chip、
///       记忆指示 `M`（`hasMemory` 为假时留空）、**结果形式指示**（`EXPR` / `DMS`，没有时整格
///       不存在，见 [ResultForm.indicator]）、读数（[baseReadout] / [notationReadout]，
///       各自为空时整格不存在）、`Spacer` 把 `More...` 推到最右
///       （`onMore` 为空则不渲染）；2) 表达式行：`MathExpressionView`，右对齐，外面套一圈横向
///       滚动，算式比屏幕宽时滚动而不是溢出；3) 结果行：右对齐，`=` 前缀 + 结果——引擎给出精确
///       形式且它排得出来时，那一段走 `MathExpressionView` 自然排版并在后面跟上 `≈ 近似值`，
///       否则整行仍是纯文本；4) 错误行：仅 `hasError` 为真时渲染，`statusTitle` 在上、
///       `statusMessage` 在下。
/// English: 1) status row: the drawer button leftmost (not rendered when `onOpenDrawer` is null),
///          then the angle-mode chip, the `M` memory indicator (nothing when `hasMemory` is
///          false), the **result-form indicator** (`EXPR` / `DMS`; the whole cell is absent when
///          there is none — see [ResultForm.indicator]), the read-outs ([baseReadout] /
///          [notationReadout]; each is absent while empty), and a `Spacer` pushing `More...` to the
///          right edge (not
///          rendered when `onMore` is null); 2) expression line: `MathExpressionView`, right-aligned,
///          inside a horizontal scroll view so a long expression scrolls instead of overflowing; 3) result
///          line: right-aligned, an `=` prefix followed by the result — when the engine supplied an
///          exact form and that form typesets, it goes through `MathExpressionView` and is followed
///          by `≈ approximation`; otherwise the whole line stays plain text. Its height is a
///          ceiling rather than a fixed size, because an exact form is not one line tall; 4) error
///          line: rendered only while `hasError` is true — `statusTitle` above `statusMessage`.
/// 中文：`statusTitle` 出现在错误行（仅 `hasError` 为真时）的上半，见该字段与 `_errorLine` 的
///       注释。
/// English: `statusTitle` appears on the upper half of the error line, which is rendered only
///          while `hasError` is true — see that field and `_errorLine`.
///
/// 高度契约 / Height contract:
/// 中文：调用方必须给本组件一个**有界**的高度，且错误行可见时**不低于 176dp**。面板里与字体无关的
///       固定部分共 74dp：状态行 40 + 间距 16（状态行下 6、结果行上 6、错误行上 4）+ 上下内边距
///       8/10。其余全归内容：表达式行、结果行，以及最多两行的错误提示——按真实 Android 字体度量
///       （拉丁 ≈1.17em、CJK ≈1.45em）算，整套内容一行错误提示时约需 147.5dp、两行时约需 165dp。
///       `lib/` 里没有任何地方限制系统字体缩放，所以 150dp 这类下限会在窗口高度低于约 395dp 时
///       必然放不下（横屏、分屏、自由窗口都命中），上层的显示区高度因此 clamp 在 176–230dp。
/// English: The caller must give this widget a **bounded** height, and **at least 176dp** while the
///          error line is showing. Font-independent chrome is 74dp: the 40dp status row, 16dp of
///          gaps (6 under the status row, 6 above the result, 4 above the error) and 18dp of
///          padding. Everything else belongs to content — the expression line, the result line and
///          an error line of up to two lines: under real Android font metrics (≈1.17em for Latin,
///          ≈1.45em for CJK) the whole content needs ≈147.5dp with a one-line error and ≈165dp
///          with a two-line one. Nothing in `lib/` clamps the OS font scale, so a 150dp floor like
///          that one cannot fit whenever the window is under roughly 395dp tall — landscape, split
///          screen and freeform all land there — and the screen's display band is therefore clamped
///          to 176–230dp.
/// 中文：高度真被压到下限以下（矮窗口 + 大字体缩放）时，先挤表达式行，再由错误行收缩、多出来的
///       笔画被裁掉——错误行不再是 RenderFlex 溢出的来源。**结果行同样可以缩**：引擎的精确形式
///       （堆叠分数、根号套分数）让这一行的高度不再固定，它拿到的是「最多能有多高」的上限，
///       真放不下时由 `FittedBox` 等比缩小，而不是把内容裁掉。（状态行是唯一真正固定的行：
///       它连同内边距与间隙约需 58dp。）
///
///       **实测数字**（`flutter_test`，320dp 宽；「结果行高度」= 结果行那一个 `Align` 的高度；
///       面板 176dp 无错误行时它分到的上限是 53dp =（176 − 40 − 12 − 18）/ 2）：
///
///       | 场景 | 结果行 | 整列 |
///       |---|---|---|
///       | 176dp / 1×，精确形式 `\frac{1}{\sqrt{2}}` | 32.4dp（自然高度） | 无溢出 |
///       | 230dp / 1×，同一形式 | 32.4dp（逐像素相同） | 无溢出 |
///       | 176dp / 2×，同一形式 | 53.0dp（被上限截住） | 无溢出 |
///       | 176dp / 2×，`\frac{\frac{\frac{1}{2}}{\frac{3}{4}}}{\frac{5}{6}}` | **85.68dp → 53.0dp** | 无溢出 |
///       | 100dp / 1×，`\frac{1}{\sqrt{2}}` | — | **修之前 `A RenderFlex overflowed by 22 pixels on the bottom.`**，修之后无溢出 |
///
///       即：结果行在 2× 及更大的字号下**先缩**（缩的是这一行，不是内容被裁），176dp 这条下限
///       本身没有变。brief 里记的「176dp + 2× 溢出 27px」在本机**复现不出来**：同样条件下
///       `\frac{1}{\sqrt{2}}` 的结果行自然高度 54.8dp，而它分到的上限是 53.0dp（上表那一行），
///       表达式行还剩 25.3dp，没有溢出。真正的缺陷是它**没有上限**：形态再高一点就拿走 85.68dp
///       （上限 53dp），把表达式行挤到 0 附近，再往下压整列就报溢出（100dp 那条实测）。
/// English: Below that minimum (a short window plus a large font scale), the expression line is
///          squeezed first and the error line then shrinks with its spare pixels clipped — the
///          error line is no longer a source of RenderFlex overflow. **The result row may shrink
///          too**: the engine's exact form (a stacked fraction, a radical around a fraction) makes
///          this row's height no longer fixed, so what it receives is a ceiling and the `FittedBox`
///          inside scales the content down when it genuinely does not fit rather than clipping it.
///          (The status row is the only genuinely fixed row: with padding and gaps it needs about
///          58dp.)
///
///          **Measured numbers** (`flutter_test`, 320dp wide; "result row height" is the height of
///          that row's `Align`; in a 176dp panel with no error line its ceiling is 53dp =
///          (176 − 40 − 12 − 18) / 2):
///
///          | case | result row | column |
///          |---|---|---|
///          | 176dp / 1×, exact form `\frac{1}{\sqrt{2}}` | 32.4dp (natural) | no overflow |
///          | 230dp / 1×, same form | 32.4dp (pixel-for-pixel) | no overflow |
///          | 176dp / 2×, same form | 53.0dp (held at the ceiling) | no overflow |
///          | 176dp / 2×, `\frac{\frac{\frac{1}{2}}{\frac{3}{4}}}{\frac{5}{6}}` | **85.68dp → 53.0dp** | no overflow |
///          | 100dp / 1×, `\frac{1}{\sqrt{2}}` | — | **before the fix: `A RenderFlex overflowed by 22 pixels on the bottom.`** — after it, none |
///
///          So the result row **shrinks first** at 2× and above (this row shrinks; the content is not
///          clipped), and the 176dp floor itself is unchanged. The "27px overflow at 176dp + 2×"
///          recorded in the brief does **not** reproduce here: under exactly those conditions
///          `\frac{1}{\sqrt{2}}`'s result row is 54.8dp naturally while its ceiling is 53.0dp (the
///          table row above), the expression line keeps 25.3dp, and nothing overflows. The real defect
///          was that the row had **no ceiling at all**: a slightly taller form took 85.68dp (against a
///          53dp share), squeezing the expression line towards zero, and pressing further makes the
///          column overflow (the 100dp case, measured).
///
/// 抽屉按钮（跨任务约定）/ The drawer button (cross-task contract):
/// 中文：主屏的 ☰ 由本组件渲染，`tooltip: '打开导航'`——任务 4 的主屏与任务 5 的外壳测试都靠
///       这个 tooltip 找到它，因此**主屏不得再另造一个 ☰**；`onOpenDrawer` 为空时它整个不渲染。
/// English: The screen's ☰ lives here and carries `tooltip: '打开导航'` — the Task 4 screen and
///          the Task 5 shell test both find it by that tooltip, so **no second ☰ may be built on
///          the screen**; when `onOpenDrawer` is null it is not rendered at all.
///
/// 结果行的两种形态 / The result line's two shapes:
/// 中文：结果行画的是**哪几种形态里的哪一种**，由 [ResultPresentation]（`result_form.dart`）算出来，
///       本文件不自己判：默认形态就是接这几颗键之前那一行（`= 2√2 ≈ 2.828427`，或没有精确形式时的
///       `= 2.828427`），另外三种是精确形态、分数形态与十进制形态，各自画法见 [_resultLine]。
///       默认形态在 [CalculatorDisplay.resultForm] 取默认值 [ResultForm.auto] 时**逐字符相同**，
///       所以不碰这两颗键的调用方（含全部既有组件测试）看到的一个字节都没变。
/// English: Which of the result line's forms is drawn is computed by [ResultPresentation]
///          (`result_form.dart`) rather than judged here: the default form is the line from before
///          these keys existed (`= 2√2 ≈ 2.828427`, or `= 2.828427` with no exact form), and the
///          other three are the exact, fraction and decimal forms, each drawn as [_resultLine]
///          describes. With [CalculatorDisplay.resultForm] left at its default [ResultForm.auto]
///          the default form is **character for character** what was there before, so callers that
///          do not touch these keys — every existing widget test included — see no change at all.
class CalculatorDisplay extends StatelessWidget {
  const CalculatorDisplay({
    required this.expression,
    required this.result,
    required this.hasError,
    required this.statusTitle,
    required this.statusMessage,
    required this.cursorIndex,
    required this.angleMode,
    required this.hasMemory,
    required this.colors,
    required this.naturalDisplay,
    this.resultTex = '',
    this.resultFractionTex = '',
    this.resultDmsText = '',
    this.resultForm = ResultForm.auto,
    this.resultDecimal = '',
    this.baseReadout = '',
    this.notationReadout = '',
    this.onTapOffset,
    this.onMore,
    this.onOpenDrawer,
    super.key,
  });

  /// 中文：表达式原文，交给 `MathExpressionView` 解析排版。
  /// English: The expression source, handed to `MathExpressionView`.
  final String expression;

  /// 中文：结果文本（十进制读数，见类注释：它是近似值那一半、没有精确形式时的整行，以及精确形式
  ///       排版失败时的降级文本）。
  /// English: The result text (the decimal reading — see the class comment: the approximation half,
  ///          the whole line when there is no exact form, and the fallback text when the exact form
  ///          fails to typeset).
  final String result;

  /// 中文：结果的 LaTeX 形态（引擎的精确形式，不含 `$` 定界符）；引擎未参与时为空串，那时结果行
  ///       整行纯文本。它排不出来时同样退回 [result]，绝不显示空白。
  /// English: The result's LaTeX form (the engine's exact form, no `$` delimiters); empty while no
  ///          engine is involved, and the result line is then plain text throughout. When it cannot
  ///          be typeset it degrades to [result] as well, never to a blank.
  final String resultTex;

  /// 中文：结果的十进制形态（引擎给的、未取整的那一串）。**只用于结果行里的两处判断**：
  ///       1. 精确形式与它逐字符相同时说明那只是同一个数的另一种写法（引擎对普通数字印的 LaTeX
  ///          就是这串十进制），于是不排两遍、也不加 `≈`；
  ///       2. 它为空时这一次**没有十进制读数**，`≈` 那一半整个不出现——符号结果就是这一种
  ///          （`11.31370849898476 * sqrt(x)` 不是近似值，是同一个式子的另一种印法）。
  ///       数值消费者读控制器，不读这里。
  /// English: The result's decimal form (the engine's, unrounded). It is used for exactly two
  ///          decisions, both in the result line: (1) when the exact form is character-for-character
  ///          this string it is the same number written differently (for an ordinary number the
  ///          engine's LaTeX *is* this decimal), so nothing is typeset twice and no `≈` is added;
  ///          (2) when it is empty there is **no decimal reading** this time, so the `≈` half is
  ///          dropped entirely — the symbolic case (`11.31370849898476 * sqrt(x)` is not an
  ///          approximation but the same expression spelled differently). Numeric consumers read the
  ///          controller, not this.
  final String resultDecimal;

  /// 中文：**分数写法**（引擎对同一个结构换一种分数格式印出来的那一份，见 `MathResult.fractionTex`）。
  ///       它只在 `d/c` 请求 [ResultForm.fraction] 时才上场；空串表示这一次没有分数写法，那时
  ///       排出来的就是纯文本读数——**绝不空白、也绝不去猜一个分数**。
  ///       与 [resultTex] 一样，**它绝不能被喂给任何数值消费者**。
  /// English: **the fraction spelling** (the engine's other fraction format for the same structure —
  ///          see `MathResult.fractionTex`). It only takes the stage when `d/c` asks for
  ///          [ResultForm.fraction]; an empty string means there is no fraction spelling this time,
  ///          and the plain reading is drawn instead — **never blank, and never a guessed
  ///          fraction**. Like [resultTex] it must **never** be fed to a numeric consumer.
  final String resultFractionTex;

  /// 中文：**度分秒写法**（引擎终端印法的原文，`12°34′55.92″`，见 `MathResult.dmsText`）。它只在
  ///       `D°M'S` 请求 [ResultForm.dms] 时才上场，而那要求结果是在 `DEG` 下算出来的
  ///       （[angleMode]，理由见 `ResultPresentation`）；空串表示这一次没有这一格，排出来的就是
  ///       纯文本读数——**绝不空白、也绝不去猜一个**。与 [resultTex] 一样，**它绝不能被喂给任何
  ///       数值消费者**。
  /// English: **the DMS spelling** (the engine's terminal render, `12°34′55.92″`; see
  ///          `MathResult.dmsText`). It only takes the stage when `D°M'S` asks for
  ///          [ResultForm.dms], which requires the result to have been produced under `DEG`
  ///          ([angleMode]; the reason is in `ResultPresentation`). An empty string means there is no
  ///          such cell this time and the plain reading is drawn — **never blank, and never a
  ///          guess**. Like [resultTex] it must **never** be fed to a numeric consumer.
  final String resultDmsText;

  /// 中文：**结果行画哪几种形态里的哪一种**（HiPER 的 `x⇔E` 与 `d/c` 管的就是这一个）。它只是一个
  ///       请求：[ResultPresentation] 会拿它对照这一份结果真正有的形态，没有的一律回落到
  ///       [ResultForm.auto]，所以请求本身不可能把某一段画成空白或画成另一个数。默认是
  ///       [ResultForm.auto]，也就是接这两颗键之前那一行——**逐字符相同**。
  /// English: **which of the result line's forms to draw** (what HiPER's `x⇔E` and `d/c` own). It is
  ///          only a request: [ResultPresentation] resolves it against the forms this result really
  ///          has and falls back to [ResultForm.auto] for any it does not, so the request itself can
  ///          never draw a stretch blank or draw a different number. The default is
  ///          [ResultForm.auto] — the line from before these two keys existed, **character for
  ///          character**.
  final ResultForm resultForm;

  /// 中文：是否处于错误态——只决定错误行渲染与否，不改结果行的颜色。
  /// English: Whether the panel is in an error state — it decides only whether the error line is
  ///          rendered, not the result line's colour.
  final bool hasError;

  /// 中文：当前状态的标题（如「等待输入」「表达式需要修正」）——它是 spec 里那张常驻状态卡
  ///       改为「仅在出错时出现」之后留下的上半句，与 `statusMessage` 一起构成错误行：标题在上、
  ///       用 `errorFg` 并加重，正文退到次要状态色。`hasError` 为假时两者都不渲染。
  /// English: Title of the current state (e.g. "waiting for input", "the expression needs
  ///          fixing") — the upper half of what survives from the spec's permanent status card
  ///          once it is "shown only on error": together with `statusMessage` it makes up the
  ///          error line, the title on top in emphasised `errorFg`, the body dropping to the
  ///          secondary status colour. Neither is rendered while `hasError` is false.
  final String statusTitle;

  /// 中文：错误态下的提示正文（如「缺少右括号」），错误行的下半句，字重与颜色都比标题轻。
  /// English: The message body while in the error state (e.g. "missing closing bracket") — the
  ///          error line's lower half, lighter in both weight and colour than the title.
  final String statusMessage;

  /// 中文：光标所在的原文字符偏移，原样转交给 `MathExpressionView`。
  /// English: Cursor position as a source character offset, passed through to
  ///          `MathExpressionView`.
  final int? cursorIndex;

  /// 中文：当前角度模式，状态行左侧的 chip 显示它（`DEG` / `RAD`）。
  /// English: The current angle mode, shown by the chip on the left of the status row
  ///          (`DEG` / `RAD`).
  final String angleMode;

  /// 中文：记忆寄存器里是否有值——为真时状态行显示 `M` 徽标，为假时该位置空着。
  /// English: Whether the memory register holds a value — a truthy value shows the `M` badge in
  ///          the status row, and when false the slot stays empty.
  final bool hasMemory;

  /// 中文：**进制读数**（`HEX 64`），空串表示没有。它是四个进制胶囊那一次换算的产物，由控制器
  ///       （`CalculatorController.baseReadout`）决定此刻还成不成立。[notationReadout] 是它的同类，
  ///       下面这段对两者都成立。
  ///
  ///       读数落在**状态行**上，而不是结果行上，理由有两条：
  ///       - 结果行是「这一次求值的值」，而读数是**另一个写法**。两个数字并排放在同一行里，
  ///         读者无法一眼看出哪个是答案；状态行本来就在放这一类标注（`DEG`/`RAD`、记忆徽标）。
  ///       - 结果行的高度契约（见类注释）是按真实字体度量量出来的，多一行要重新量一遍；
  ///         状态行有 40dp 高、里面那些 chip 只有 24dp，多一格不影响任何既有高度。
  ///
  ///       太长时它不换行、不溢出：外面是 `Flexible`，里面一行省略号——**截断是看得见的**，
  ///       绝不悄悄少印几位（那与「屏幕上的错值」是同一件事）。
  /// English: **the base read-out** (`HEX 64`); an empty string means there is none. It is what the
  ///          four base pills' conversion produced, and the controller
  ///          (`CalculatorController.baseReadout`) decides whether it still holds right now.
  ///          [notationReadout] is its sibling, and everything below holds for both.
  ///
  ///          A read-out sits on the **status row** rather than the result line for two reasons:
  ///          - the result line is "this evaluation's value" while a read-out is **another way of
  ///            writing it**. Side by side on one line, a reader cannot tell at a glance which is the
  ///            answer; the status row already carries exactly this kind of annotation (`DEG`/`RAD`,
  ///            the memory badge);
  ///          - the result line's height contract (see the class comment) was measured against real
  ///            font metrics and a third row would mean measuring it all again, whereas the status row
  ///            is 40dp tall with 24dp chips in it — one more cell moves nothing.
  ///
  ///          When it is too long it neither wraps nor overflows: a `Flexible` outside, one line with
  ///          an ellipsis inside — **the cut is visible**, never a few digits quietly missing (which
  ///          is the same thing as a wrong value on screen).
  final String baseReadout;

  /// 中文：**数字记法读数**（`SCI 1.23456789E4`），`FSE` 那一颗键按出来的。契约与 [baseReadout]
  ///       逐条相同（空串即整格不存在、控制器决定它此刻还成不成立）；内容来自
  ///       `CalculatorController.notationReadout`，**绝不来自 `decimalText`**。
  /// English: **the number-notation read-out** (`SCI 1.23456789E4`), produced by the `FSE` key. Its
  ///          contract is item-for-item [baseReadout]'s; it comes from
  ///          `CalculatorController.notationReadout` and **never from `decimalText`**.
  final String notationReadout;

  /// 中文：显示区语义色，面板里的每一个色值都取自它。
  /// English: Semantic display colours; every colour in the panel comes from here.
  final CalcDisplayColors colors;

  /// 中文：是否自然排版，原样转交给 `MathExpressionView`（关闭时表达式退化为**一个**纯文本
  ///       `Text`，这是那个分支的对外契约）。
  /// English: Whether to typeset naturally, passed through to `MathExpressionView` (switched off,
  ///          the expression degrades to a **single** plain `Text` — that branch's contract).
  final bool naturalDisplay;

  /// 中文：点击某个显示单元时收到该单元在原串里的起始偏移。
  /// English: Called with the tapped display unit's start offset in the source string.
  final void Function(int sourceOffset)? onTapOffset;

  /// 中文：`More...` 按钮的回调；为空时按钮不渲染。
  /// English: Callback for the `More...` button; the button is not rendered when null.
  final VoidCallback? onMore;

  /// 中文：抽屉按钮的回调；为空时按钮不渲染（见类注释里的跨任务约定）。
  /// English: Callback for the drawer button; the button is not rendered when null (see the
  ///          cross-task contract in the class comment).
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    // 中文：**形态只算一次，两处读同一份**——结果行按它决定画哪一段，状态行按它决定点哪一盏灯。
    //       两处各算一次迟早会漂（`resultDmsText` 或 `angleMode` 在一处传错就够了），漂开的后果
    //       正是这条路上最不能有的东西：灯说的与行上画的是两回事。见 [_presentation]。
    // English: **the forms are computed once and read by both** — the result line decides which
    //          stretch to draw from them, the status row which lamp to light. Computing them twice
    //          would drift (one mis-passed `resultDmsText` or `angleMode` is enough), and what drifts
    //          is a lamp contradicting the line. See [_presentation].
    final presentation = _presentation();
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // 中文：`spaceBetween` 只在**出错时**起作用：那时错误行是可伸缩的，而宽松分配不会把用不
          //       完的份额还给表达式行，余量按 flex 规则堆在列尾，错误行于是浮在面板底边上方
          //       （量过：`flex: 1` 的版本在 230dp 面板上浮起 18.5dp；`flex: 2` 份额更大——75dp
          //       对着 38dp 的自然高度——不摊会浮起约 37dp）。`spaceBetween` 把这点余量摊到各行
          //       之间，错误行因此仍贴着底边、留在没有它时的同一个位置。没出错时没有可伸缩行，
          //       余量为 0，这条对齐方式是空操作。
          // English: `spaceBetween` matters only while an error is showing: the error row is then
          //          flexible, and the loose fit does not hand its unused share back to the
          //          expression row — the flex rules pile that slack up at the end of the column,
          //          floating the error line away from the bottom edge (measured: the `flex: 1`
          //          version sat 18.5dp above the bottom of a 230dp panel; `flex: 2` takes a bigger
          //          share — 75dp against a 38dp natural height — and would float about 37dp).
          //          Spreading that slack between the rows keeps the error line flush with the
          //          bottom, where it sits without it. With no error there is no flexible row, the
          //          slack is zero and this alignment is a no-op.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _statusRow(presentation),
            const SizedBox(height: 6),
            // 中文：表达式行吃掉全部剩余高度（面板高度由上层决定，本组件填满它）：面板高度够
            //       类注释里那条下限时，fixed 的状态行与结果行不会被裁掉；再矮下去就先挤这一行，
            //       挤不动了由下面的错误行收缩裁切——两者都不会让 RenderFlex 溢出报错。
            // English: The expression line takes all the leftover height (the panel's height is
            //          decided above, and this widget fills it). At or above the minimum in the
            //          class comment's height contract the fixed status and result rows are never
            //          clipped; below it this line is squeezed first, and what is left over is taken
            //          from the error line below — neither throws a RenderFlex overflow.
            Expanded(child: _expressionLine()),
            const SizedBox(height: 6),
            // 中文：结果行**可以缩**。精确形式（`\frac{1}{\sqrt{2}}` 这类高瘦形状）上屏之后，
            //       它成了这个面板里唯一一个高度不确定的行：纯文本结果一行高，而一个堆叠分数按
            //       字号等比放大——2 倍文字缩放 + 176dp 下限时它按**自然高度**排（`\frac{1}{\sqrt{2}}`
            //       量到 54.8dp，而分到的上限是 53dp；更高的形态量到 85.68dp），把表达式行挤到 0 附近，
            //       面板再矮一点（100dp）整列就报 RenderFlex 溢出（debug 红屏、release 里用户的字被切掉）。
            //       宽松的 `Flexible` 把「最多能有多高」交给它，里面的 `FittedBox` 于是能把内容
            //       等比缩到放得下——缩的是这一行，不是把内容裁掉，也不是把面板的下限调高
            //       （调高会波及所有结果）。松配时它按自然高度排布，只在真放不下时才缩，所以
            //       常规字号下这一行的尺寸与之前逐像素相同。
            // English: the result line **may shrink**. Once the exact form is on screen (`\frac{1}
            //          {\sqrt{2}}` and friends) it is the one row in this panel whose height is not
            //          fixed: a plain-text result is one line tall, while a stacked fraction scales
            //          with the font size — at a 2× text scale and the 176dp floor it takes its
            //          **natural height** (54.8dp measured for `\frac{1}{\sqrt{2}}` against a 53dp
            //          ceiling; 85.68dp for a taller form), squeezing the expression line towards
            //          zero, and a slightly shorter panel (100dp) makes the whole column report a
            //          RenderFlex overflow (a red screen in debug; the user's text cut off in
            //          release). A loose
            //          `Flexible` hands it "the most you may be", and the `FittedBox` inside can
            //          then scale the content down to fit — what shrinks is this row, not the
            //          content being clipped, and the panel's floor is not raised (raising it would
            //          affect every result). Laid out loose it still takes its natural height and
            //          only scales when it genuinely does not fit, so at ordinary font sizes this
            //          row is pixel-for-pixel what it was.
            Flexible(
              fit: FlexFit.loose,
              flex: 1,
              child: _resultLine(presentation),
            ),
            if (hasError) ...<Widget>[
              const SizedBox(height: 4),
              // 中文：错误行是可收缩的兜底，并且按 2:1 的份额比表达式行拿得多：错误块最多三行文字
              //       （标题 1 行 + 正文 2 行），表达式行只有一行。量出来的差别正好落在下限高度上：
              //       176dp 面板里可分配 59dp，按 1:1 分错误行拿 29.5dp，而它自然高度要 38dp——日常
              //       的「缺少右括号」在下限高度上会被削掉两成；按 2:1 分它拿 39.3dp，刚好完整，被
              //       挤的是表达式行（本组件里那个让位的角色）。宽松（loose）分配让它在高度充裕时
              //       仍按自然尺寸排布，`ClipRect` 负责裁掉极端字体缩放下真正多出来的笔画。
              // English: The error line is the shrinkable safety net, and at 2:1 it takes a bigger
              //          share than the expression row: the error block runs to three lines of text
              //          (a title plus two message lines) where the expression line is a single
              //          line. The measured difference lands exactly at the floor: a 176dp panel
              //          offers 59dp to share, a 1:1 split hands the error 29.5dp against the 38dp
              //          it naturally needs — the everyday "missing closing bracket" is shaved by a
              //          fifth at the minimum height — while 2:1 gives it 39.3dp, just enough, and
              //          squeezes the expression line instead (this widget's designated victim).
              //          The loose fit still lays it out at its natural size while there is room, and
              //          the `ClipRect` cuts off the pixels that genuinely do not fit under an
              //          extreme font scale.
              Flexible(
                fit: FlexFit.loose,
                flex: 2,
                child: ClipRect(child: _errorLine()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 中文：状态行——抽屉按钮、角度模式 chip、记忆指示、**结果形式指示**、读数（进制 / 记法），
  ///       `Spacer` 之后是 `More...`。两类格子都是宽松 [Flexible]：旁边的 `Spacer` 是
  ///       `Expanded`，两者按 flex 分余量，所以格子**永远放得下**——内容比份额长时自己按省略号
  ///       收窄而不让整行溢出（不给 `Flexible` 时实测报
  ///       `A RenderFlex overflowed by 30 pixels on the right.`）；空串时整格不存在。
  ///       读数为什么落在这一行见 [baseReadout]，形式指示见 [ResultForm.indicator]。
  /// English: The status row — drawer button, angle-mode chip, memory indicator, **the result-form
  ///          indicator**, the read-outs (base / notation), then `More...` after a `Spacer`. Both
  ///          kinds of cell are a loose `Flexible`: the `Spacer` beside them is an `Expanded`, the
  ///          two share the slack by flex, so a cell **always fits** — longer than its share it
  ///          narrows itself with an ellipsis rather than overflowing the row (measured: `A
  ///          RenderFlex overflowed by 30 pixels on the right.` without it); empty means absent.
  ///          Why the read-outs land here is in [baseReadout], the form indicator in
  ///          [ResultForm.indicator].
  Widget _statusRow(ResultPresentation presentation) {
    // 中文：**请求的形态落到这一份结果上**之后才念名字。少了 `resolve` 这一步，上一份结果上选的
    //       形态会留在状态行上给新结果点一盏假灯——「这一份结果没有那一格」时就该一个字都不说。
    //       判据只有 `ResultPresentation` 那一份（rule 6），这里不重判。
    // English: the word is read off **after the requested form is resolved against this result**.
    //          Without that `resolve` step a form chosen for the previous result would leave a false
    //          lamp lit over the new one — when this result has no such cell, nothing must be said.
    //          The judgement is `ResultPresentation`'s alone (rule 6) and is not repeated here.
    final indicator = presentation.resolve(resultForm).indicator;
    return SizedBox(
      height: _statusButtonSize,
      child: Row(
        children: <Widget>[
          if (onOpenDrawer != null) ...<Widget>[
            _drawerButton(),
            const SizedBox(width: 4),
          ],
          StatusChips.angleMode(angleMode, colors),
          if (hasMemory) ...<Widget>[
            const SizedBox(width: 6),
            StatusChips.memory(colors),
          ],
          if (indicator.isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            // 中文：宽松 `Flexible`——与进制读数那一格同一契约，实测见 `_statusRow` 的注释。
            // English: a loose `Flexible` — the base read-out's contract; the measurement is in
            //          `_statusRow`'s note.
            Flexible(child: StatusChips.resultForm(indicator, colors)),
          ],
          // 中文：两格读数（进制 / 记法）走同一段渲染——它们是同一类东西，形状、配色与省略规则不该
          //       分家；各自为空时各自不存在，布局与从前逐像素相同。
          // English: the two read-outs (base / notation) share one stretch of rendering — the same
          //          kind of thing, with a shape and elision rule that must not drift apart. Each is
          //          absent while empty, so the layout is pixel-for-pixel what it was.
          for (final readout in <String>[baseReadout, notationReadout])
            if (readout.trim().isNotEmpty) ...<Widget>[
              const SizedBox(width: 6),
              Flexible(child: StatusChips.baseReadout(readout, colors)),
            ],
          const Spacer(),
          if (onMore != null) _moreButton(),
        ],
      ),
    );
  }

  /// 中文：主屏的 ☰。tooltip 是本组件对外的固定契约（见类注释），图标色取次要状态色。
  ///       `shrinkWrap` 关掉 Material 默认把命中区撑到 48 的行为：那个隐形的 48 宽盒子会让状态行
  ///       的左间距忽大忽小，而这里的尺寸是自己定死的正方形，图标因此正好居中。
  /// English: The screen's ☰. Its tooltip is this widget's fixed outward contract (see the class
  ///          comment) and its icon takes the secondary status colour. `shrinkWrap` turns off
  ///          Material's default padding of the hit area out to 48: that invisible 48-wide box
  ///          makes the status row's left spacing read as uneven, while this size is a square of
  ///          our own choosing — so the icon sits exactly in its middle.
  Widget _drawerButton() {
    return IconButton(
      onPressed: onOpenDrawer,
      tooltip: '打开导航',
      icon: const Icon(Icons.menu),
      iconSize: 20,
      color: colors.statusFg,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _statusButtonSize,
        height: _statusButtonSize,
      ),
    );
  }

  /// 中文：`More...` 按钮——本阶段接入现有能力（复制结果、保存笔记等）的入口。
  ///       它只把点击转给上层，自身不关心菜单内容；`shrinkWrap` 与抽屉按钮同理，命中区不外扩，
  ///       于是它与右侧内边距的关系是可预算的。
  /// English: The `More...` button — the entry point to what already exists (copying the result,
  ///          saving a note, ...). It only forwards the tap and does not care what the menu holds;
  ///          `shrinkWrap` as on the drawer button keeps the hit area from expanding, so where its
  ///          right edge lands against the padding is predictable.
  Widget _moreButton() {
    return TextButton(
      onPressed: onMore,
      style: TextButton.styleFrom(
        foregroundColor: colors.indicatorFg,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'More...',
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 中文：表达式行——右对齐，外面套一圈横向滚动并 `reverse`，因此长算式停在**末尾**
  ///       （光标所在的那一端）而不是开头。`Align` 在有界宽度里把内容推到右边；算式比可用宽度
  ///       窄时滚动视图收缩成内容宽度，宽过可用宽度时才真的滚动——两种情况都不溢出。
  /// English: The expression line — right-aligned inside a horizontal, reversed scroll view, so a
  ///          long expression rests at its **end** (the end the caret is at) rather than its
  ///          start. `Align` pushes the content right within the bounded width; the scroll view
  ///          shrinks to the content while it fits and only then scrolls once it does not — no
  ///          overflow either way.
  Widget _expressionLine() {
    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: MathExpressionView(
          expression: expression,
          naturalDisplay: naturalDisplay,
          cursorIndex: cursorIndex,
          onTapOffset: onTapOffset,
          textStyle: TextStyle(
            color: colors.expressionFg,
            fontSize: _expressionFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 中文：**这一份结果的形态，算一次**。构造过程与它接这两颗键时逐字相同（`build` 里那一处原来
  ///       内联在 [_resultLine] 内），只是搬到了两处调用者都够得着的地方：结果行要按它决定画哪一段，
  ///       状态行要按它决定点哪一盏结果形式灯（`EXPR` / `DMS`）。两处读的因此是**同一份**判断，
  ///       而那份判断本身仍然只在 `ResultPresentation` 里（rule 6：没有第二份判据）。
  ///
  ///       六个入参逐字来自本组件的字段，一个都没有新加：`ResultPresentation.of` 的后两个入参
  ///       （度分秒那一格的引擎原文与角度模式）在下面写着理由，它们只影响那一格存不存在。
  /// English: **this result's forms, computed once.** The construction is character-for-character what
  ///          it was when these two keys landed (`build` used to inline it inside [_resultLine]); it
  ///          only moved somewhere both callers can reach: the result line uses it to decide which
  ///          stretch to draw, the status row to decide which result-form lamp to light (`EXPR` /
  ///          `DMS`). Both therefore read **one** judgement, and that judgement still lives only in
  ///          `ResultPresentation` (rule 6: no second copy of the test).
  ///
  ///          All six arguments come verbatim from this widget's fields; not one is new. The reason for
  ///          `ResultPresentation.of`'s last two (the DMS cell's engine string and the angle mode) is
  ///          below; they only affect whether that cell exists.
  ResultPresentation _presentation() {
    return ResultPresentation.of(
      resultTex: resultTex,
      fractionTex: resultFractionTex,
      resultDecimal: resultDecimal,
      naturalDisplay: naturalDisplay,
      // 中文：度分秒那一格的另外两个入参——引擎那一串原文，以及**这一份结果算出来时的角度模式**
      //       （`DEG` 才是「这个数是若干度」成立的那一半，判据在 `ResultPresentation` 里，不在
      //       这里）。两者都只影响那一格存不存在，不影响别的形态。
      // English: the DMS cell's other two inputs — the engine's string, and **the angle mode this
      //          result was produced under** (`DEG` is the half where "this number is so many degrees"
      //          holds; the judgement lives in `ResultPresentation`, not here). Both only affect
      //          whether that cell exists; no other form moves.
      dmsText: resultDmsText,
      degreesMode: angleMode == 'DEG',
    );
  }

  /// 中文：结果行——`=` 与结果各自是一个 `Text`（不是拼成一行的 `RichText`），`FittedBox`
  ///       只缩不放，很长的数值因此缩到可用宽度里而不是溢出。要排版的那一段是唯一不是 `Text`
  ///       的东西：它是一个 `MathExpressionView`，与上面那行表达式同一套排版。
  ///
  ///       **「要画哪一段」不在这里判断**：它整个搬到了 [ResultPresentation]（同目录的
  ///       `result_form.dart`），因为 `x⇔E` / `d/c` 两颗键要问同一个问题——「这一份结果有哪几种
  ///       画法」，而两份判断迟早会漂。这里只做两件事：把 [resultForm] 落到这一份结果上（没有的
  ///       形态一律回落到 [ResultForm.auto]），然后照着画。
  ///
  ///       三种画法与它们共用的样式对象：
  ///       - 默认形态：有排得出来的精确形式时是「排版 + `≈` 十进制读数」，否则整行纯文本读数
  ///         ——与接这两颗键之前逐字符相同；
  ///       - 精确 / 分数形态：只有那一段排版，**没有 `≈`**；[result] 仍作为渲染失败的降级文本；
  ///       - 十进制形态：整行就是 [result]。
  ///
  ///       两条分支共用同一份样式对象，所以三个画法的 `=`、字号、颜色完全一致——差别只在中间那
  ///       一段排不排。
  /// English: The result line — the `=` and the result are separate `Text` widgets (not one
  ///          `RichText`), and the `FittedBox` only scales down, so a very long numeric result
  ///          shrinks into the available width instead of overflowing. The stretch that typesets is
  ///          the one part that is not a `Text`: it is a `MathExpressionView`, the same typesetting
  ///          the expression line above uses.
  ///
  ///          **"Which stretch to draw" is not judged here**: it all moved to
  ///          [ResultPresentation] (`result_form.dart` beside this file), because the `x⇔E` / `d/c`
  ///          keys ask the same question — "which ways can this result be drawn" — and two answers
  ///          would drift. This method does two things: resolve [resultForm] against this result
  ///          (any form it does not have falls back to [ResultForm.auto]), then draw it.
  ///
  ///          The three drawings and the style objects they share:
  ///          - the default form: "typeset + `≈` decimal reading" when an exact form typesets, the
  ///            plain reading throughout otherwise — character for character the line from before
  ///            these two keys existed;
  ///          - the exact / fraction forms: that stretch alone, **no `≈`**; [result] still travels
  ///            as the render-failure fallback;
  ///          - the decimal form: the whole line is [result].
  ///
  ///          Both branches share one set of style objects, so the `=`, the sizes and the colours are
  ///          identical across all three — only the middle stretch differs in whether it typesets.
  Widget _resultLine(ResultPresentation presentation) {
    final resultStyle = TextStyle(
      color: colors.resultFg,
      fontSize: _resultFontSize,
      fontWeight: FontWeight.w900,
    );
    final equalsStyle = TextStyle(
      color: colors.resultFg,
      fontSize: _equalsFontSize,
      fontWeight: FontWeight.w700,
    );
    // 中文：请求 → 这一份结果真正有的形态。没有的那一种回落到 `auto`，所以下面 `texFor` 拿到的
    //       那一段一定是这一份结果自己有的，不会画出别的东西。
    // English: the request → the forms this result really has. A form it lacks falls back to `auto`,
    //          so the stretch `texFor` returns below always belongs to this result.
    final form = presentation.resolve(resultForm);
    final typeset = presentation.texFor(form);
    final showApproximation = presentation.showsApproximation(form);
    return Align(
      alignment: Alignment.centerRight,
      // 中文：`heightFactor: 1` 让这一行**按内容取高**，也就是把上面那个宽松上限只当上限用：
      //       内容矮时它不会撑满分配到的份额。少了这一格，`Align` 会在有界高度里长到上限，
      //       结果行在常规字号下也会白白占掉表达式行的高度。
      // English: `heightFactor: 1` makes this row **take its content's height**, i.e. it treats the
      //          loose ceiling above as a ceiling only: with short content it does not grow into its
      //          whole share. Without it `Align` would expand to the ceiling inside a bounded
      //          height, and the result row would eat the expression row's height even at ordinary
      //          font sizes.
      heightFactor: 1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('=', style: equalsStyle),
            const SizedBox(width: 8),
            if (typeset.isEmpty)
              Text(result, style: resultStyle)
            else ...<Widget>[
              MathExpressionView(
                // 中文：走到这里说明解析已经通过（`ResultPresentation` 用的就是渲染器自己的
                //       解析器）。剩下的失败面只有**渲染阶段**的异常，那时这一段退化成这个
                //       `Text`，即最多把读数写两遍——绝不空白、也绝不是乱码，这是这里唯一
                //       能给出的保证。
                // English: Reaching here means the parse already succeeded (that `ResultPresentation`
                //          asks the renderer's own parser). The only failure surface left is an
                //          exception in the **render** stage, and then this fragment degrades to the
                //          `Text` below — the reading written twice at worst, never blank and never
                //          garbled. That is the only promise available at this point.
                expression: result,
                tex: typeset,
                naturalDisplay: naturalDisplay,
                textStyle: resultStyle,
              ),
              if (showApproximation) ...<Widget>[
                const SizedBox(width: 8),
                Text('≈', style: equalsStyle),
                const SizedBox(width: 8),
                Text(result, style: resultStyle),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 中文：错误行——只有 `hasError` 为真时才会走到这里（见 `build`）。它是 spec 里那张常驻状态卡
  ///       出错时的形态：**标题在上、正文在下**，标题用 `errorFg` 并加重，正文退到次要状态色、
  ///       用常规字重——一行块，不是带内边距的卡片。两行都限行并省略，长提示既不会溢出宽度也不会
  ///       把显示区撑破。
  /// 中文：两条 `Flexible` 让这个块**自己**也能缩：`Flexible` 与调用处的宽松分配一起，把不够的
  ///       高度按比例分给两行文字，`ClipRect` 再把多出来的笔画裁掉。少了这一层，`Flexible` 只是
  ///       把外面的列救下来，里面的这一列仍会自己报 RenderFlex 溢出——兜底也就白做了。
  /// English: The error line — reached only while `hasError` is true (see `build`). It is what the
  ///          spec's permanent status card becomes while something is wrong: **title first, body
  ///          under it**, the title in `errorFg` and emphasised, the body dropping to the secondary
  ///          status colour at a normal weight — a one-line block, not a padded card. Both are
  ///          line-capped with an ellipsis, so a long message neither overflows the width nor
  ///          bursts the panel.
  /// English: The two `Flexible`s let the block **itself** shrink as well: together with the loose
  ///          fit at the call site they hand the shortfall to the two texts, and the `ClipRect` cuts
  ///          off whatever pixels no longer fit. Without them the outer `Flexible` would only save
  ///          the column around it — this inner column would still report a RenderFlex overflow of
  ///          its own, and the safety net would be worth nothing.
  Widget _errorLine() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: Text(
            statusTitle,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.errorFg,
              fontSize: _errorFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Flexible(
          child: Text(
            statusMessage,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.statusFg,
              fontSize: _errorMessageFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
