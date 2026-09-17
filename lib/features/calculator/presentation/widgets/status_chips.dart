import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';

/// 中文：**状态行里那几格小标记**——角度模式 chip、记忆徽标 `M`、进制读数。它们原来长在
///       `calculator_display.dart` 里（作为那个组件的私有方法），2026-09 这一次只是**搬家**：
///       每一行原样搬过来，只有「私有方法」变成「同一个包的公开静态方法」，以及三个度量常量跟着
///       它们一起走（度量必须跟着用它的东西走，否则两处各留一份就会漂）。搬家的理由与上一次拆
///       Kotlin 那份选项一样：`calculator_display.dart` 要回到 800 行以内，而**加一个参数**不能
///       靠删注释腾地方。
///
///       三格的排版共用同一套度量（同样的 24dp 高、同样的圆角、同样的低透明度指示色填充），所以
///       状态行看起来仍是一排同类的东西；颜色一律由调用方从 `CalcDisplayColors` 传进来——
///       这里**没有硬编码色值**，也没有第二个色位。
/// English: **the small marks on the status row** — the angle-mode chip, the `M` memory badge and
///          the base read-out. They used to live inside `calculator_display.dart` as that widget's
///          private methods; the 2026-09 pass is a **move**: every line came across as it was, only
///          `private method` became `public static on a class in the same package`, and the three
///          metric constants travelled with them (metrics have to travel with their only user, or two
///          copies drift apart). The reason for the move is the same as the last Kotlin split:
///          `calculator_display.dart` has to come back under 800 lines, and **adding a parameter**
///          cannot be paid for by deleting comments.
///
///          All three cells share one set of metrics (the same 24dp height, corner radius and
///          low-alpha indicator fill), so the status row still reads as one row of like things; the
///          colours always arrive from `CalcDisplayColors` — **nothing is hardcoded here**, and there
///          is no second colour slot.
class StatusChips {
  const StatusChips._();

  /// 中文：角度模式 chip 与记忆指示的高度。
  /// English: Height of the angle-mode chip and the memory indicator.
  static const double height = 24;

  /// 中文：chip / 指示灯的圆角半径。
  /// English: Corner radius of the chip and the indicators.
  static const double radius = 6;

  /// 中文：chip 底色在显示区底上的浓度——用指示色的低透明度版本，因此底色仍全部来自
  ///       `CalcDisplayColors`，没有第二个色位，也没有硬编码色值。
  /// English: How strongly the chip's fill sits on the display background — a low-alpha version of
  ///          the indicator colour, so the fill still comes entirely from `CalcDisplayColors`: no
  ///          second colour slot and no hardcoded value.
  static const double fillAlpha = 0.12;

  /// 中文：角度模式 chip——底色是指示色的低透明度版本，文字用次要状态色（该色位的注释里
  ///       点名的第一用途就是角度制）。
  /// English: The angle-mode chip — its fill is a low-alpha indicator colour and its text uses the
  ///          secondary status colour, whose own doc comment names the angle mode as its first
  ///          use.
  static Widget angleMode(String label, CalcDisplayColors colors) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
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
  static Widget memory(CalcDisplayColors colors) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
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

  /// 中文：**结果形式那一格**（`EXPR` / `DMS`）。排版与角度 chip、记忆徽标共用同一套度量
  ///       （同样的 24dp 高、同样的圆角、同样的低透明度指示色填充），所以状态行仍是一排同类的东西。
  ///
  ///       字面本身的判据**不在这里**：它由 `ResultForm.indicator`（`result_form.dart`）给出，
  ///       也就是「当前画出来的那一格叫什么」。这一格只负责画——与角度 chip 的关系一样，
  ///       度量与画法在这里，判据在它自己的文件里，**没有第二份**。
  ///
  ///       前景取 `indicatorFg` 而不是角度 chip 那一个 `statusFg`：HiPER 自己把这类字面叫做
  ///       `<ind:EXPR>`（它的帮助文本「Selected format is indicated by … **indicators on the
  ///       display**」），而 `CalcDisplayColors.indicatorFg` 这一色位注释里点名的用途正是
  ///       「状态**指示灯** / 徽标」——`M` 徽标与进制读数已经用的是它，三者同族。
  ///       角度 chip 用 `statusFg` 是因为它说的是计算器**模式**，而这一格说的是结果**怎么写**。
  ///
  ///       空串**不应该**走到这里（调用方在空串时整格不渲染，见 `CalculatorDisplay._statusRow`），
  ///       所以这里不画空盒子：画一个空 chip 就等于在状态行上说了一句空话。
  ///
  ///       **`maxLines: 1` + `ellipsis` 与进制读数那一格逐字相同**，理由也相同：这一格是 `Flexible`
  ///       里的一格，放不下时**看得见地被省略**，而不是把状态行撑破（`RenderFlex overflowed by 30
  ///       pixels on the right` 是实测过的，见下面那条）。它的自然宽度只有两到四个拉丁字母，所以
  ///       寻常字号下拿到的都是全字；只有在「抽屉按钮 + 角度 chip + 记忆徽标 + 一个四十字符的读数 +
  ///       `More...` 同时在场」这种最挤的组合里才会收窄——那时**整个状态行本来就没有余量**，
  ///       收窄是本组件给出的唯一诚实的降级。
  /// English: **the result-form cell** (`EXPR` / `DMS`). Its typesetting shares the angle chip's and
  ///          memory badge's metrics (the same 24dp height, corner radius and low-alpha indicator
  ///          fill), so the status row still reads as one row of like things.
  ///
  ///          What the word *is* is **not judged here**: it comes from `ResultForm.indicator`
  ///          (`result_form.dart`), i.e. "what the cell being drawn right now is called". This cell
  ///          only draws it — exactly as with the angle chip, the metrics and the drawing live here
  ///          and the judgement lives in its own file; there is **no second copy**.
  ///
  ///          Its foreground takes `indicatorFg` rather than the angle chip's `statusFg`: HiPER calls
  ///          this class of word `<ind:EXPR>` in its own help ("Selected format is indicated by …
  ///          **indicators on the display**"), and `CalcDisplayColors.indicatorFg`'s own comment
  ///          names "status **indicators** and badges" as its use — the `M` badge and the base
  ///          read-out already take it, so the three are one family. The angle chip takes `statusFg`
  ///          because it says which **mode** the calculator is in, while this one says how the result
  ///          is **written**.
  ///
  ///          An empty string **must not** arrive here (the caller does not render the cell at all
  ///          when it is empty — see `CalculatorDisplay._statusRow`), so no empty box is drawn here:
  ///          an empty chip would be the status row saying nothing.
  static Widget resultForm(String label, CalcDisplayColors colors) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// 中文：进制读数那一格。排版与角度 chip、记忆徽标共用同一套度量（同样的 24dp 高、同样的圆角、
  ///       同样的低透明度指示色填充），所以状态行看起来仍是一排同类的东西；它说的是**另一个
  ///       写法**（`HEX 64`），因此用指示色前景把它与 `DEG`/`M` 那两格区分开。
  ///       `maxLines: 1` + `ellipsis`：读数的位数最多由控制器按 `kBaseReadoutMaxDigits` 截一次，
  ///       这里是第二道——极端字体缩放下真正放不下的笔画**看得见地被省略**，而不是被裁掉。
  /// English: the base read-out's cell. It shares the angle chip's and memory badge's metrics (the
  ///          same 24dp height, corner radius and low-alpha indicator fill), so the status row still
  ///          reads as one row of like things; what it says is **another way of writing the result**
  ///          (`HEX 64`), so its foreground takes the indicator colour to set it apart from the
  ///          `DEG`/`M` cells. `maxLines: 1` plus `ellipsis`: the controller already caps the digits
  ///          once (`kBaseReadoutMaxDigits`), and this is the second line of defence — under an
  ///          extreme font scale what genuinely does not fit is **visibly elided** rather than
  ///          clipped.
  static Widget baseReadout(String label, CalcDisplayColors colors) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
