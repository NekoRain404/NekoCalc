import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';

/// 中文：把表达式渲染成自然排版的数学显示（真正的分数堆叠、根号与上标）。
///       表达式字符串始终是唯一真源：本组件只把它解析成语法树、切成显示单元、转成 TeX，
///       再让**每个单元各自成为一棵独立的 widget 子树**。这一点是有意的——
///       每个单元都带着它在源码里的区间，于是"点到了哪一段"由 Flutter 自己的命中测试回答，
///       不需要依赖 flutter_math_fork 的任何内部结构，也不需要在渲染结果里反查字符位置。
/// English: Renders an expression as naturally typeset mathematics (real stacked fractions,
///          radicals and superscripts). The expression string stays the single source of truth:
///          this widget only parses it, splits it into display units and converts those to TeX,
///          then gives **each unit its own widget subtree**. That is deliberate — every unit
///          carries its source span, so "which piece was tapped" is answered by Flutter's own hit
///          testing, with no dependency on any internal structure of flutter_math_fork and no
///          reverse lookup of character positions in the rendered output.
///
/// 中文：除表达式原文之外，本组件还接受**第二种输入**：一段已经排好的 TeX（见 [tex]）。它存在的
///       理由是引擎给出的**精确形式**本来就是 TeX，而结果行必须与表达式行走同一套排版、同一套
///       失败降级——不是因为它需要另一套能力。两种输入共用后面那一段渲染与降级。
/// English: Besides an expression source this widget takes a **second input**: pre-composed TeX (see
///          [tex]). It exists because the engine's **exact form** already *is* TeX, and the result
///          line has to share the expression line's typesetting and its failure fallback — not
///          because a second capability was needed. Both inputs share the rendering and fallback
///          below.
class MathExpressionView extends StatelessWidget {
  const MathExpressionView({
    required this.expression,
    this.naturalDisplay = true,
    this.tex = '',
    this.cursorIndex,
    this.onTapOffset,
    this.textStyle,
    super.key,
  });

  /// 中文：要显示的表达式原文。
  /// English: The expression source to display.
  final String expression;

  /// 中文：**已经排好的 TeX**——引擎给出的精确形式（`2\times \sqrt{2}`）就是这种输入。
  ///       非空时不再解析 [expression]，而是把这段 TeX 当成**一个**片段交给同一个 `Math.tex`；
  ///       它排不出来时降级为 [expression] 的纯文本，因此调用方把「排不出来时该显示什么」放在
  ///       [expression] 里即可（结果行给的是那一份十进制读数）。
  ///
  ///       精确形式走这里、而不是在结果行里另起一套 `Math.tex`：排版机制只有这一套，
  ///       [naturalDisplay] 的开关、失败降级、字号与颜色的来源三者对两行完全一致。
  ///
  ///       光标与点击定位不适用于这一段：整段是一棵子树，也没有对应的原文区间。
  /// English: **Pre-composed TeX** — the engine's exact form (`2\times \sqrt{2}`) arrives in this
  ///          shape. When non-empty, [expression] is not parsed at all: this TeX is handed to the
  ///          same `Math.tex` as **one** fragment, and when it cannot be typeset the fragment
  ///          degrades to [expression] as plain text — so a caller puts "what to show when it
  ///          cannot be typeset" in [expression] (the result line hands it the decimal reading).
  ///
  ///          The exact form travels through here rather than through a second `Math.tex` written
  ///          inside the result line: there is one typesetting mechanism, so the [naturalDisplay]
  ///          switch, the failure fallback and the source of size and colour are identical for both
  ///          lines.
  ///
  ///          The caret and tap-to-cursor do not apply to this fragment: it is one subtree and has
  ///          no corresponding source span.
  final String tex;

  /// 中文：关闭时退化为普通文本，不解析、不排版。
  /// English: When off, degrades to plain text — no parsing, no typesetting.
  final bool naturalDisplay;

  /// 中文：光标所在的原文字符偏移；为空则不画光标。这是原文字符下标，不是显示下标。
  /// English: Cursor position as a source character offset; no cursor when null. This is a source
  ///          index, not a display index.
  final int? cursorIndex;

  /// 中文：点击某个显示单元时收到该单元在原串里的起始偏移。
  /// English: Called with the tapped display unit's start offset in the source string.
  final void Function(int sourceOffset)? onTapOffset;

  /// 中文：覆盖文本样式；字号决定整条算式的大小，颜色默认继承主题。
  /// English: Overrides the text style; its size drives the whole equation's metrics and its
  ///          colour is inherited from the theme by default.
  final TextStyle? textStyle;

  /// 中文：上层样式完全没有给字号时的兜底值，只用来推算光标高度；
  ///       只要有 Material 祖先，继承来的样式总带字号，正常走不到这里。
  /// English: The fallback used only to derive the cursor height when the ambient style carries no
  ///          size at all; under a Material ancestor the inherited style always has one, so this is
  ///          not normally reached.
  static const double _fallbackFontSize = 14;

  /// 中文：这段 TeX 排得出来吗——问的是**渲染时用的那一个解析器**：`Math.tex` 在构造时就把
  ///       解析错误放在 `parseError` 上，渲染时第一个分支就是「有错误就换降级内容」，所以这个
  ///       判断与真正渲染的结果是同一句话，不是另写的一份近似预判。
  ///
  ///       调用方（结果行）用它决定「精确形式 + 近似值」这种两段式排版成不成立：排不出来时左边
  ///       那一段会退化成 [expression] 自身，再跟一个近似值就只是把同一串数字写了两遍。
  ///
  ///       引擎的 LaTeX 里确实有排不出来的写法——`\num{…}`、`\qty{…}{…}` 这两个宏
  ///       flutter_math_fork 不认，而 libqalculate 对「带千分位的长数字」正是这么印的
  ///       （`1234567` → `\num{1234567}`、`2^2000` → `\num{1.148130695274255e602}`）。
  ///       那些结果按契约退回纯文本读数，而不是显示空白的公式树。
  /// English: Whether this TeX can be typeset — asked of *the parser the renderer itself uses*:
  ///          `Math.tex` records a parse error on `parseError` as it is constructed, and the very
  ///          first branch of its build swaps in the fallback when there is one, so this is the
  ///          same statement as the render, not a separate approximation of it.
  ///
  ///          The caller (the result line) uses it to decide whether the two-part "exact form plus
  ///          approximation" layout holds at all: when it cannot be typeset the left part degrades
  ///          to [expression] itself, and appending an approximation would print the same digits
  ///          twice.
  ///
  ///          The engine's LaTeX really does contain unrenderable spellings — flutter_math_fork
  ///          knows neither `\num{…}` nor `\qty{…}{…}`, and those are exactly how libqalculate
  ///          prints a long number carrying grouping separators (`1234567` → `\num{1234567}`,
  ///          `2^2000` → `\num{1.148130695274255e602}`). Those results take the documented route
  ///          back to the plain reading rather than showing an empty formula tree.
  static bool typesetsTex(String tex) => Math.tex(tex).parseError == null;

  @override
  Widget build(BuildContext context) {
    // 中文：关闭自然排版时整行就是**一个** Text——这是该分支的对外契约，
    //       调用方（以及测试）可以用 find.text 直接命中原文。
    // English: With natural typesetting off the whole line is **one** Text — that is the plain
    //          branch's contract, so callers (and tests) can hit the raw string with find.text.
    if (!naturalDisplay) return Text(expression, style: textStyle);

    final baseStyle = DefaultTextStyle.of(context).style;
    final style = textStyle == null ? baseStyle : baseStyle.merge(textStyle);

    // 中文：给了 TeX 就是整段一棵子树，不再解析原文——但仍走同一个 `_fragment` 的降级契约：
    //       排不出来时显示的是**原文**，也就是调用方放进 [expression] 的那份纯文本读数。
    // English: Given TeX the whole fragment is one subtree and the source is never parsed — but the
    //          fallback contract is the same one `_fragment` uses: when it cannot be typeset what
    //          shows is the **source**, i.e. the plain reading the caller put in [expression].
    if (tex.trim().isNotEmpty) {
      return Math.tex(
        tex,
        textStyle: style,
        onErrorFallback: (error) => Text(expression, style: style),
      );
    }

    final units = toDisplayUnits(const ExpressionAstParser().parse(expression));
    final fragments = const TexEmitter().emitUnits(units);

    final cursorHeight =
        (style.fontSize ?? baseStyle.fontSize ?? _fallbackFontSize) * 2;
    // 中文：只有给了光标下标才插入光标；位置取"最后一个 end <= cursorIndex 的单元"之后。
    //       单元按源码顺序排列，扫一遍记住最后一个命中的位置即可；一个都没有时留在最前，
    //       也就是源码偏移 0 的位置（下标 0 属于这种情况）。
    // English: A cursor is inserted only when an index is given, after the last unit whose end is
    //          <= cursorIndex. Units are in source order, so a single scan remembering the final
    //          match is enough; with no match it stays in front, at source offset 0 — which is
    //          where an index of 0 belongs.
    final cursorAt = cursorIndex;
    var insertionIndex = 0;
    Widget? cursor;
    if (cursorAt != null) {
      for (var i = 0; i < units.length; i++) {
        if (units[i].end <= cursorAt) insertionIndex = i + 1;
      }
      cursor = _cursor(style.color ?? baseStyle.color, cursorHeight);
    }
    // 中文：`i` 从 0 走到 units.length，先在插入点放光标、再放该位置的单元，
    //       于是"末尾"这个插入点也能被覆盖到。
    // English: `i` runs from 0 through units.length: drop the cursor at the insertion point, then
    //          the unit at that position — so the "very end" insertion point is covered too.
    final children = <Widget>[];
    for (var i = 0; i <= units.length; i++) {
      if (cursor != null && i == insertionIndex) children.add(cursor);
      if (i < units.length) {
        children.add(_fragment(units[i], fragments[i], style));
      }
    }

    // 中文：横向可滚动并反向（reverse），因此默认停在算式末尾——输入光标所在的那一端。
    //       内容必须用 MainAxisSize.min：滚动方向上的约束是无界的，max 会算出无穷宽度。
    // English: Scrolls horizontally, reversed, so it rests at the end of the expression — the end
    //          the caret is at. MainAxisSize.min is required: constraints are unbounded along the
    //          scroll axis, and `max` would resolve to an infinite width.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// 中文：一个显示单元 = 一棵独立的 widget 子树，点击由 Flutter 的命中测试完成；
  ///       该片段渲染失败时降级为它覆盖的那段原文，绝不因一个片段报废整行显示。
  /// English: One display unit becomes one independent widget subtree whose tap is resolved by
  ///          Flutter's hit testing. A fragment that fails to render degrades to the source text it
  ///          covers, so one bad fragment never takes down the whole line.
  Widget _fragment(ExprNode unit, String tex, TextStyle style) {
    final source = expression.substring(unit.start, unit.end);
    return GestureDetector(
      // 中文：opaque 让整个单元矩形（含根号、分数这类留白较多的字形）都可点。
      // English: `opaque` makes the unit's whole box tappable, including the airy glyphs that
      //          radicals and fractions leave behind.
      behavior: HitTestBehavior.opaque,
      onTap: onTapOffset == null ? null : () => onTapOffset!(unit.start),
      child: Math.tex(
        tex,
        textStyle: style,
        onErrorFallback: (error) => Text(source, style: style),
      ),
    );
  }

  /// 中文：细长光标矩形，高度为两倍字号——单倍高在一行算式里几乎看不见。
  ///       用正文字色绘制，因此不引入任何自有配色；连正文字色都没有时返回 null，
  ///       宁可不画也不硬编码一个颜色。
  /// English: The thin cursor rectangle, two font sizes tall — a single size is nearly invisible in
  ///          a formula. It is drawn in the text colour, introducing no palette of its own; when not
  ///          even a text colour exists it returns null, and no colour is hardcoded.
  Widget? _cursor(Color? color, double height) {
    if (color == null) return null;
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
