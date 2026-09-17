import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';
import 'math_expression_view.dart';

/// 中文：状态行里按钮的边长——比 Material 默认的 48 小，面板本来就不高，但仍是手指能稳稳点到的
///       方块。状态行的高度就等于它。
/// English: Edge length of a status-row button — smaller than Material's default 48 because the
///          panel itself is short, yet still a square a finger can hit reliably. The status row is
///          exactly this tall.
const double _statusButtonSize = 40;

/// 中文：角度模式 chip 与记忆指示的高度。
/// English: Height of the angle-mode chip and the memory indicator.
const double _chipHeight = 24;

/// 中文：chip / 指示灯的圆角半径。
/// English: Corner radius of the chip and the indicators.
const double _chipRadius = 6;

/// 中文：chip 底色在显示区底上的浓度——用指示色的低透明度版本，因此底色仍全部来自
///       `CalcDisplayColors`，没有第二个色位，也没有硬编码色值。
/// English: How strongly the chip's fill sits on the display background — a low-alpha version of
///          the indicator colour, so the fill still comes entirely from `CalcDisplayColors`: no
///          second colour slot and no hardcoded value.
const double _chipFillAlpha = 0.12;

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
///       记忆指示 `M`（`hasMemory` 为假时留空），`Spacer` 把 `More...` 推到最右
///       （`onMore` 为空则不渲染）；2) 表达式行：`MathExpressionView`，右对齐，外面套一圈横向
///       滚动，算式比屏幕宽时滚动而不是溢出；3) 结果行：右对齐，`=` 前缀 + 结果——引擎给出精确
///       形式且它排得出来时，那一段走 `MathExpressionView` 自然排版并在后面跟上 `≈ 近似值`，
///       否则整行仍是纯文本；4) 错误行：仅 `hasError` 为真时渲染，`statusTitle` 在上、
///       `statusMessage` 在下。
/// English: 1) status row: the drawer button leftmost (not rendered when `onOpenDrawer` is null),
///          then the angle-mode chip, the `M` memory indicator (nothing when `hasMemory` is
///          false), and a `Spacer` pushing `More...` to the right edge (not rendered when
///          `onMore` is null); 2) expression line: `MathExpressionView`, right-aligned, inside a
///          horizontal scroll view so a long expression scrolls instead of overflowing; 3) result
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
///       本身没有变。brief 里记的「176dp + 2× 溢出 27px」在本机**复现不出来**——同样条件下结果行
///       自然高度 54.8dp、分到 88dp，没有溢出；真正的缺陷是它**没有上限**：形态再高一点就拿走
///       85.68dp（上限 53dp），把表达式行挤到 0 附近，再往下压整列就报溢出（100dp 那条实测）。
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
///          recorded in the brief does **not** reproduce here — under exactly those conditions the
///          row is 54.8dp naturally against 88dp available and nothing overflows; the real defect was
///          that it had **no ceiling at all**: a slightly taller form took 85.68dp (against a 53dp
///          share), squeezing the expression line towards zero, and pressing further makes the
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
/// 中文：结果行有两种形态，由**引擎有没有给出一个排得出来的精确形式**决定，两者都在同一个
///       `FittedBox` 里右对齐：
///
///       1. **纯文本**（`= 2.828427`）：没有精确形式、精确形式排不出来、显示文本本身就是那个精确
///          形式（引擎对普通数字印出来的 LaTeX 就是那串十进制），或者自然排版被关掉时走这一种。
///          它与接入引擎之前逐字符相同，因此「引擎没答上来」对屏幕完全不可见。
///       2. **自然排版 + 近似值**（`= 2√2 ≈ 2.828427`）：精确形式走 `MathExpressionView`（与表达式
///          行同一个组件、同一个 `Math.tex`、同一套降级），`≈` 后面跟十进制读数。近似值就是
///          [CalculatorDisplay.result]，取整仍由控制器的 `formatNumber` 按精度设置完成——精度
///          设置管的正是这一半，精确形式那一半本来就与取整无关。
///
///       为什么精确形式那一段不自己调 `Math.tex`：排版只有一套机制，失败了也要退回纯文本读数，
///       另起一套就会多出第二个降级分支与第二份「排不出来时显示什么」的判断。
/// English: The result line has two shapes, decided by whether the engine supplied an exact form
///          that typesets; both sit right-aligned inside the same `FittedBox`:
///
///          1. **Plain text** (`= 2.828427`) when there is no exact form, when the exact form does
///             not typeset, when the display text *is* that exact form (for an ordinary number the
///             engine's LaTeX is the decimal itself), or when natural typesetting is switched off.
///             This is character-for-character what the line showed before the engine was wired in,
///             so "the engine could not answer" is invisible on screen.
///          2. **Natural typesetting plus an approximation** (`= 2√2 ≈ 2.828427`): the exact form
///             goes through `MathExpressionView` — the same widget, the same `Math.tex`, the same
///             fallback the expression line uses — followed by `≈` and the decimal reading. That
///             reading is [CalculatorDisplay.result], still rounded by the controller's
///             `formatNumber` at the user's precision: the precision setting governs that half, and
///             the exact half has nothing to round.
///
///          The exact form does not call `Math.tex` on its own for the same reason: there is one
///          typesetting mechanism, it falls back to the plain reading, and a second one would add a
///          second fallback branch and a second "what to show when it fails" decision.
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
    this.resultDecimal = '',
    this.onTapOffset,
    this.onMore,
    this.onOpenDrawer,
    super.key,
  });

  /// 中文：表达式原文，交给 `MathExpressionView` 解析排版。
  /// English: The expression source, handed to `MathExpressionView`.
  final String expression;

  /// 中文：结果文本（十进制读数，见类注释：它是近似值那一半，也是没有精确形式时的整行）。
  /// English: The result text (the decimal reading — see the class comment: it is the
  ///          approximation half, and the whole line when there is no exact form).
  final String result;

  /// 中文：结果的 LaTeX 形态（引擎的精确形式，不含 `$` 定界符）；引擎未参与时为空串，那时结果行
  ///       整行纯文本。它排不出来时同样退回 [result]，绝不显示空白。
  /// English: The result's LaTeX form (the engine's exact form, no `$` delimiters); empty while no
  ///          engine is involved, and the result line is then plain text throughout. When it cannot
  ///          be typeset it degrades to [result] as well, never to a blank.
  final String resultTex;

  /// 中文：结果的十进制形态（引擎给的、未取整的那一串）。**只用于一处判断**：精确形式与它逐字符
  ///       相同时说明那只是同一个数的另一种写法（引擎对普通数字印的 LaTeX 就是这串十进制），
  ///       于是不排两遍、也不加 `≈`。数值消费者读控制器，不读这里。
  /// English: The result's decimal form (the engine's, unrounded). It is used for exactly one
  ///          decision: when the exact form is character-for-character this string, that exact form
  ///          is the same number written differently (for an ordinary number the engine's LaTeX *is*
  ///          this decimal), so nothing is typeset twice and no `≈` is added. Numeric consumers read
  ///          the controller, not this.
  final String resultDecimal;

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
            _statusRow(),
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
            //       字号等比放大——2 倍文字缩放 + 176dp 下限时它比可用的高度高出 27px，于是整列
            //       报 RenderFlex 溢出（debug 红屏、release 里用户的字被切掉）。
            //       宽松的 `Flexible` 把「最多能有多高」交给它，里面的 `FittedBox` 于是能把内容
            //       等比缩到放得下——缩的是这一行，不是把内容裁掉，也不是把面板的下限调高
            //       （调高会波及所有结果）。松配时它按自然高度排布，只在真放不下时才缩，所以
            //       常规字号下这一行的尺寸与之前逐像素相同。
            // English: the result line **may shrink**. Once the exact form is on screen (`\frac{1}
            //          {\sqrt{2}}` and friends) it is the one row in this panel whose height is not
            //          fixed: a plain-text result is one line tall, while a stacked fraction scales
            //          with the font size — at a 2× text scale and the 176dp floor it is 27px taller
            //          than there is room for, and the whole column reports a RenderFlex overflow
            //          (a red screen in debug; the user's text cut off in release). A loose
            //          `Flexible` hands it "the most you may be", and the `FittedBox` inside can
            //          then scale the content down to fit — what shrinks is this row, not the
            //          content being clipped, and the panel's floor is not raised (raising it would
            //          affect every result). Laid out loose it still takes its natural height and
            //          only scales when it genuinely does not fit, so at ordinary font sizes this
            //          row is pixel-for-pixel what it was.
            Flexible(fit: FlexFit.loose, flex: 1, child: _resultLine()),
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

  /// 中文：状态行——抽屉按钮、角度模式 chip、记忆指示，`Spacer` 之后是 `More...`。
  /// English: The status row — drawer button, angle-mode chip, memory indicator, then `More...`
  ///          after a `Spacer`.
  Widget _statusRow() {
    return SizedBox(
      height: _statusButtonSize,
      child: Row(
        children: <Widget>[
          if (onOpenDrawer != null) ...<Widget>[
            _drawerButton(),
            const SizedBox(width: 4),
          ],
          _statusChip(angleMode),
          if (hasMemory) ...<Widget>[
            const SizedBox(width: 6),
            _memoryIndicator(),
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

  /// 中文：角度模式 chip——底色是指示色的低透明度版本，文字用次要状态色（该色位的注释里
  ///       点名的第一用途就是角度制）。
  /// English: The angle-mode chip — its fill is a low-alpha indicator colour and its text uses the
  ///          secondary status colour, whose own doc comment names the angle mode as its first
  ///          use.
  Widget _statusChip(String label) {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: _chipFillAlpha),
        borderRadius: BorderRadius.circular(_chipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.statusFg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// 中文：记忆指示 `M`——一个徽标，所以用指示色；没有值时整块不渲染（不是画一个空徽标）。
  /// English: The `M` memory indicator — a badge, hence the indicator colour; with no value the
  ///          whole thing is absent rather than drawn empty.
  Widget _memoryIndicator() {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: _chipFillAlpha),
        borderRadius: BorderRadius.circular(_chipRadius),
      ),
      child: Text(
        'M',
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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

  /// 中文：结果行——`=` 与结果各自是一个 `Text`（不是拼成一行的 `RichText`），`FittedBox`
  ///       只缩不放，很长的数值因此缩到可用宽度里而不是溢出。精确形式那一段是唯一不是 `Text`
  ///       的东西：它是一个 `MathExpressionView`，与上面那行表达式同一套排版。
  ///
  ///       精确形式要同时满足三条才会出现（见类注释里的两种形态）：
  ///       [naturalDisplay] 开着；引擎给了一段**排得出来**的 LaTeX；而且它不是 [resultDecimal]
  ///       逐字符的重复——最后这条挡掉的是普通数字：引擎对 `2+2` 印的 LaTeX 就是 `4`，左边已经
  ///       是这个数，再来一个 `≈ 4` 只是把同一个数写两遍。
  ///
  ///       两条分支共用同一份样式对象，所以「精确形式 + 近似值」与「纯文本」的 `=`、字号、颜色
  ///       完全一致——差别只在中间那一段是不是排出来的。
  /// English: The result line — the `=` and the result are separate `Text` widgets (not one
  ///          `RichText`), and the `FittedBox` only scales down, so a very long numeric result
  ///          shrinks into the available width instead of overflowing. The exact form is the one
  ///          part that is not a `Text`: it is a `MathExpressionView`, the same typesetting the
  ///          expression line above uses.
  ///
  ///          The exact form appears only when three things hold (see the two shapes in the class
  ///          comment): [naturalDisplay] is on, the engine supplied LaTeX that **typesets**, and it
  ///          is not a character-for-character repeat of [resultDecimal] — that last one rules out
  ///          ordinary numbers: the engine's LaTeX for `2+2` is `4`, the left side is already that
  ///          number, and a `≈ 4` beside it would just write the same number twice.
  ///
  ///          Both branches share one set of style objects, so the `=`, the sizes and the colours are
  ///          identical in both — only the middle part differs in whether it is typeset.
  Widget _resultLine() {
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
    final tex = resultTex.trim();
    final exactTex = naturalDisplay &&
            tex.isNotEmpty &&
            tex != resultDecimal.trim() &&
            MathExpressionView.typesetsTex(tex)
        ? tex
        : '';
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
            if (exactTex.isEmpty)
              Text(result, style: resultStyle)
            else ...<Widget>[
              MathExpressionView(
                // 中文：走到这里说明解析已经通过（上面那道 `typesetsTex` 用的就是渲染器自己的
                //       解析器）。剩下的失败面只有**渲染阶段**的异常，那时这一段退化成这个
                //       `Text`，即最多把近似值写两遍——绝不空白、也绝不是乱码，这是这里唯一
                //       能给出的保证。
                // English: Reaching here means the parse already succeeded (that `typesetsTex` above
                //          asks the renderer's own parser). The only failure surface left is an
                //          exception in the **render** stage, and then this fragment degrades to the
                //          `Text` below — the approximation written twice at worst, never blank and
                //          never garbled. That is the only promise available at this point.
                expression: result,
                tex: exactTex,
                naturalDisplay: naturalDisplay,
                textStyle: resultStyle,
              ),
              const SizedBox(width: 8),
              Text('≈', style: equalsStyle),
              const SizedBox(width: 8),
              Text(result, style: resultStyle),
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
