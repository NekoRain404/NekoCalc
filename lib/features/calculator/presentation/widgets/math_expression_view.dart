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
class MathExpressionView extends StatelessWidget {
  const MathExpressionView({
    required this.expression,
    this.naturalDisplay = true,
    this.cursorIndex,
    this.onTapOffset,
    this.textStyle,
    super.key,
  });

  /// 中文：要显示的表达式原文。
  /// English: The expression source to display.
  final String expression;

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

  @override
  Widget build(BuildContext context) {
    // 中文：关闭自然排版时整行就是**一个** Text——这是该分支的对外契约，
    //       调用方（以及测试）可以用 find.text 直接命中原文。
    // English: With natural typesetting off the whole line is **one** Text — that is the plain
    //          branch's contract, so callers (and tests) can hit the raw string with find.text.
    if (!naturalDisplay) return Text(expression, style: textStyle);

    final baseStyle = DefaultTextStyle.of(context).style;
    final style = textStyle == null ? baseStyle : baseStyle.merge(textStyle);
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
