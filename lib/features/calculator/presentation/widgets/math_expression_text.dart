import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MathExpressionText extends StatefulWidget {
  const MathExpressionText({
    required this.expression,
    required this.style,
    this.cursorIndex,
    this.showCursor = false,
    this.mathSymbols = true,
    this.maxLines = 1,
    super.key,
  });

  final String expression;
  final TextStyle style;
  final int? cursorIndex;
  final bool showCursor;
  final bool mathSymbols;
  final int maxLines;

  @override
  State<MathExpressionText> createState() => MathExpressionTextState();
}

class MathExpressionTextState extends State<MathExpressionText> {
  final _richTextKey = GlobalKey();
  late _MathSourceOffsetMap _sourceOffsetMap;

  /// Converts a position local to this widget's [RichText] into a source boundary.
  int sourceOffsetForLocalPosition(Offset localPosition) {
    final renderParagraph = _renderParagraph;
    if (renderParagraph == null) return 0;
    if (localPosition.dx <= 0) return 0;
    if (localPosition.dx >= renderParagraph.size.width) {
      return widget.expression.length;
    }

    final textOffset = renderParagraph
        .getPositionForOffset(localPosition)
        .offset
        .clamp(0, _sourceOffsetMap.boundaries.length - 1)
        .toInt();
    for (final span in _sourceOffsetMap.ambiguousSpansAt(textOffset)) {
      final boxes = renderParagraph.getBoxesForSelection(
        TextSelection(baseOffset: span.start, extentOffset: span.end),
      );
      for (final box in boxes) {
        final rect = box.toRect();
        if (rect.contains(localPosition)) {
          final isStartHalf = box.direction == TextDirection.ltr
              ? localPosition.dx < rect.center.dx
              : localPosition.dx >= rect.center.dx;
          return isStartHalf ? span.sourceStart : span.sourceEnd;
        }
      }
    }

    return _sourceOffsetMap.boundaries[textOffset]
        .clamp(0, widget.expression.length)
        .toInt();
  }

  /// Converts a global tap position into a valid source boundary.
  int sourceOffsetForGlobalPosition(Offset globalPosition) {
    final renderParagraph = _renderParagraph;
    if (renderParagraph == null) return 0;
    return sourceOffsetForLocalPosition(
      renderParagraph.globalToLocal(globalPosition),
    );
  }

  RenderParagraph? get _renderParagraph {
    final renderObject = _richTextKey.currentContext?.findRenderObject();
    return renderObject is RenderParagraph ? renderObject : null;
  }

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(context);
    _sourceOffsetMap = _buildSourceOffsetMap();
    return RichText(
      key: _richTextKey,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final builder =
        _MathSpanBuilder(widget.style, mathSymbols: widget.mathSymbols);
    final index = widget.cursorIndex?.clamp(0, widget.expression.length);
    if (!widget.showCursor || index == null) {
      return builder.build(widget.expression);
    }
    final map = _MathSourceOffsetMapBuilder(mathSymbols: widget.mathSymbols)
        .build(widget.expression);
    return _insertCursor(
      builder.build(widget.expression),
      map.displayOffsetForSource(index),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _ExpressionCursor(
            color: widget.style.color ?? Theme.of(context).colorScheme.primary),
      ),
    );
  }

  _MathSourceOffsetMap _buildSourceOffsetMap() {
    final builder =
        _MathSourceOffsetMapBuilder(mathSymbols: widget.mathSymbols);
    final cursorIndex = widget.cursorIndex?.clamp(0, widget.expression.length);
    if (!widget.showCursor || cursorIndex == null) {
      return builder.build(widget.expression);
    }
    final map = builder.build(widget.expression);
    return map.withWidgetAtDisplayOffset(
      map.displayOffsetForSource(cursorIndex),
      cursorIndex,
    );
  }
}

class _MathSourceOffsetMap {
  const _MathSourceOffsetMap({
    required this.boundaries,
    required this.ambiguousSpansByBoundary,
  });

  final List<int> boundaries;
  final List<List<_AmbiguousDisplaySpan>> ambiguousSpansByBoundary;

  List<_AmbiguousDisplaySpan> ambiguousSpansAt(int textOffset) {
    return ambiguousSpansByBoundary[
        textOffset.clamp(0, ambiguousSpansByBoundary.length - 1).toInt()];
  }

  int displayOffsetForSource(int sourceOffset) {
    final exact = boundaries.indexOf(sourceOffset);
    if (exact >= 0) return exact;
    for (var index = 0; index < boundaries.length; index++) {
      if (boundaries[index] > sourceOffset) return index;
    }
    return boundaries.length - 1;
  }

  _MathSourceOffsetMap withWidgetAtDisplayOffset(
    int displayOffset,
    int sourceOffset,
  ) {
    final offset = displayOffset.clamp(0, boundaries.length - 1).toInt();
    final nextBoundaries = <int>[
      ...boundaries.take(offset + 1),
      sourceOffset,
      ...boundaries.skip(offset + 1),
    ];
    final nextSpans =
        ambiguousSpansByBoundary.expand((spans) => spans).toSet().map((span) {
      if (span.end <= offset) return span;
      if (span.start >= offset) {
        return _AmbiguousDisplaySpan(
          start: span.start + 1,
          end: span.end + 1,
          sourceStart: span.sourceStart,
          sourceEnd: span.sourceEnd,
        );
      }
      return span;
    }).toList();
    final nextAmbiguousSpans = List.generate(
      nextBoundaries.length,
      (_) => <_AmbiguousDisplaySpan>[],
    );
    for (final span in nextSpans) {
      for (var position = span.start; position <= span.end; position++) {
        if (position >= 0 && position < nextAmbiguousSpans.length) {
          nextAmbiguousSpans[position].add(span);
        }
      }
    }
    return _MathSourceOffsetMap(
      boundaries: nextBoundaries,
      ambiguousSpansByBoundary: nextAmbiguousSpans,
    );
  }
}

List<InlineSpan> _insertCursor(
  List<InlineSpan> spans,
  int displayOffset,
  WidgetSpan cursor,
) {
  final result = <InlineSpan>[];
  var consumed = 0;
  var inserted = false;
  for (final span in spans) {
    final length = _displayLength(span);
    if (!inserted && displayOffset <= consumed + length) {
      result.addAll(_insertCursorIntoSpan(
        span,
        displayOffset - consumed,
        cursor,
      ));
      inserted = true;
    } else {
      result.add(span);
    }
    consumed += length;
  }
  if (!inserted) result.add(cursor);
  return result;
}

List<InlineSpan> _insertCursorIntoSpan(
  InlineSpan span,
  int offset,
  WidgetSpan cursor,
) {
  if (span is WidgetSpan) {
    return offset <= 0 ? [cursor, span] : [span, cursor];
  }
  if (span is! TextSpan) return [cursor, span];

  final text = span.text ?? '';
  if (offset <= text.length) {
    return [
      if (offset > 0)
        TextSpan(text: text.substring(0, offset), style: span.style),
      cursor,
      if (offset < text.length)
        TextSpan(text: text.substring(offset), style: span.style),
      if (span.children != null) ...span.children!,
    ];
  }

  final children = span.children ?? const <InlineSpan>[];
  final childSpans = _insertCursor(children, offset - text.length, cursor);
  return [
    if (text.isNotEmpty) TextSpan(text: text, style: span.style),
    TextSpan(style: span.style, children: childSpans),
  ];
}

int _displayLength(InlineSpan span) {
  if (span is WidgetSpan) return 1;
  if (span is TextSpan) {
    return (span.text?.length ?? 0) +
        (span.children
                ?.fold<int>(0, (sum, child) => sum + _displayLength(child)) ??
            0);
  }
  return 0;
}

class _AmbiguousDisplaySpan {
  const _AmbiguousDisplaySpan({
    required this.start,
    required this.end,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final int start;
  final int end;
  final int sourceStart;
  final int sourceEnd;
}

class _MathSourceOffsetMapBuilder {
  _MathSourceOffsetMapBuilder({required this.mathSymbols});

  final bool mathSymbols;
  final _boundaries = <int>[];
  final _ambiguousSpans = <_AmbiguousDisplaySpan>[];

  _MathSourceOffsetMap build(String source, {int sourceOffset = 0}) {
    if (!mathSymbols) {
      _appendLiteral(source, sourceOffset);
      return toMap();
    }

    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (char == '^') {
        final parsed = _readExponent(source, index + 1);
        if (parsed != null) {
          appendWidget(sourceOffset + index, sourceOffset + parsed.end);
          index = parsed.end;
          continue;
        }
      }
      if (_isIdentifierStart(char)) {
        final tokenStart = index;
        index++;
        while (index < source.length && _isIdentifierPart(source[index])) {
          index++;
        }
        final token = source.substring(tokenStart, index);
        if (index < source.length && source[index] == '(') {
          final close = _matchingClose(source, index);
          final bodyEnd = close ?? source.length;
          _appendFunction(
            name: token,
            tokenStart: sourceOffset + tokenStart,
            open: sourceOffset + index,
            body: source.substring(index + 1, bodyEnd),
            closed: close != null,
          );
          if (close == null) break;
          index = close + 1;
          continue;
        }
        if (token == 'pi') {
          _appendTransformed(
              'π', sourceOffset + tokenStart, sourceOffset + index);
        } else {
          _appendLiteral(token, sourceOffset + tokenStart);
        }
        continue;
      }
      _appendLiteral(char, sourceOffset + index);
      index++;
    }
    return toMap();
  }

  void _appendFunction({
    required String name,
    required int tokenStart,
    required int open,
    required String body,
    required bool closed,
  }) {
    final bodyStart = open + 1;
    final close = bodyStart + body.length;
    switch (name) {
      case 'sqrt':
        _appendTransformed('√', tokenStart, open);
        _appendGroup(body, bodyStart, close, closed);
      case 'cbrt':
        _appendTransformed('∛', tokenStart, open);
        _appendGroup(body, bodyStart, close, closed);
      case 'log':
        _appendLiteral(name, tokenStart);
        appendWidget(open, open);
        _appendGroup(body, bodyStart, close, closed);
      case 'log2':
        _appendLiteral('log', tokenStart);
        appendWidget(tokenStart + 3, open);
        _appendGroup(body, bodyStart, close, closed);
      case 'ln':
        _appendLiteral(name, tokenStart);
        _appendGroup(body, bodyStart, close, closed);
      case 'exp':
        _appendTransformed('e', tokenStart, open);
        appendWidget(open, closed ? close + 1 : close);
      case 'abs':
        _appendTransformed('|', tokenStart, bodyStart);
        build(body, sourceOffset: bodyStart);
        _appendTransformed('|', close, closed ? close + 1 : close);
      case 'fact':
        _appendGroup(body, bodyStart, close, closed);
        _appendTransformed(
            '!', closed ? close + 1 : close, closed ? close + 1 : close);
      case 'root':
        _appendRoot(tokenStart, open, body, bodyStart, close, closed);
      case 'ncr':
      case 'npr':
        _appendTransformed(name == 'ncr' ? 'C' : 'P', tokenStart, open);
        _appendGroup(body, bodyStart, close, closed);
      case 'deg':
        build(body, sourceOffset: bodyStart);
        _appendTransformed('°', close, closed ? close + 1 : close);
      default:
        _appendLiteral(name, tokenStart);
        _appendGroup(body, bodyStart, close, closed);
    }
  }

  void _appendRoot(int tokenStart, int open, String body, int bodyStart,
      int close, bool closed) {
    final args = _splitTopLevelArgs(body);
    if (args.length != 2) {
      appendWidget(tokenStart, open);
      _appendTransformed('√', open, open);
      _appendGroup(body, bodyStart, close, closed);
      return;
    }
    final comma = _topLevelComma(body);
    final indexStart = bodyStart + comma + 1;
    appendWidget(tokenStart, indexStart + args[1].length);
    _appendTransformed(
        '√', indexStart + args[1].length, indexStart + args[1].length);
    _appendLiteral('(', open);
    build(args[0].trim(),
        sourceOffset: bodyStart + _leadingWhitespace(args[0]));
    if (closed) {
      _appendLiteral(')', close);
    } else {
      _appendTransformed(')', close, close);
    }
  }

  void _appendGroup(String body, int bodyStart, int close, bool closed) {
    _appendLiteral('(', bodyStart - 1);
    build(body, sourceOffset: bodyStart);
    if (closed) _appendLiteral(')', close);
  }

  void _appendLiteral(String text, int sourceStart) {
    _begin(sourceStart);
    for (var index = 1; index <= text.length; index++) {
      _boundaries.add(sourceStart + index);
    }
  }

  void _appendTransformed(String display, int sourceStart, int sourceEnd) {
    final start = _boundaries.isEmpty ? 0 : _boundaries.length - 1;
    _begin(sourceStart);
    for (var index = 1; index <= display.length; index++) {
      _boundaries.add(index == display.length ? sourceEnd : sourceStart);
    }
    _ambiguousSpans.add(_AmbiguousDisplaySpan(
      start: start,
      end: _boundaries.length - 1,
      sourceStart: sourceStart,
      sourceEnd: sourceEnd,
    ));
  }

  void appendWidget(int sourceStart, int sourceEnd) {
    _appendTransformed('\uFFFC', sourceStart, sourceEnd);
  }

  void _begin(int sourceOffset) {
    if (_boundaries.isEmpty) {
      _boundaries.add(sourceOffset);
    } else {
      _boundaries[_boundaries.length - 1] = sourceOffset;
    }
  }

  _MathSourceOffsetMap toMap() {
    final boundaries = _boundaries.isEmpty ? <int>[0] : _boundaries;
    final ambiguousSpansByBoundary = List.generate(
      boundaries.length,
      (_) => <_AmbiguousDisplaySpan>[],
    );
    for (final span in _ambiguousSpans) {
      for (var offset = span.start; offset <= span.end; offset++) {
        if (offset >= 0 && offset < ambiguousSpansByBoundary.length) {
          ambiguousSpansByBoundary[offset].add(span);
        }
      }
    }
    return _MathSourceOffsetMap(
      boundaries: boundaries,
      ambiguousSpansByBoundary: ambiguousSpansByBoundary,
    );
  }
}

int _topLevelComma(String source) {
  var depth = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (char == ',' && depth == 0) return index;
  }
  return source.length;
}

int _leadingWhitespace(String value) {
  var index = 0;
  while (index < value.length && value[index].trim().isEmpty) {
    index++;
  }
  return index;
}

class _ExpressionCursor extends StatelessWidget {
  const _ExpressionCursor({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _MathSpanBuilder {
  const _MathSpanBuilder(this.style, {required this.mathSymbols});

  final TextStyle style;
  final bool mathSymbols;

  List<InlineSpan> build(String source) {
    if (!mathSymbols) return [_normal(source)];
    final spans = <InlineSpan>[];
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (char == '^') {
        final parsed = _readExponent(source, index + 1);
        if (parsed != null) {
          spans.add(_sup(parsed.value));
          index = parsed.end;
          continue;
        }
      }
      if (_isIdentifierStart(char)) {
        final tokenStart = index;
        index++;
        while (index < source.length && _isIdentifierPart(source[index])) {
          index++;
        }
        final token = source.substring(tokenStart, index);
        if (index < source.length && source[index] == '(') {
          final close = _matchingClose(source, index);
          if (close != null) {
            final body = source.substring(index + 1, close);
            spans.addAll(_functionCall(token, body));
            index = close + 1;
            continue;
          }
          final body = source.substring(index + 1);
          spans.addAll(_functionCall(token, body, closed: false));
          break;
        }
        spans.add(_normal(_constant(token)));
        continue;
      }
      spans.add(_normal(char));
      index++;
    }
    return spans;
  }

  List<InlineSpan> _functionCall(String name, String body,
      {bool closed = true}) {
    final bodySpans = build(body);
    final group = closed ? _group(bodySpans) : _openGroup(bodySpans);
    return switch (name) {
      'sqrt' => [_normal('√'), group],
      'cbrt' => [_normal('∛'), group],
      'log' => [_normal('log'), _sub('10'), group],
      'log2' => [_normal('log'), _sub('2'), group],
      'ln' => [_normal('ln'), group],
      'exp' => [_normal('e'), _supGroup(bodySpans, closed: closed)],
      'abs' => [_normal('|'), ...bodySpans, _normal('|')],
      'fact' => [group, _normal('!')],
      'root' => _root(body),
      'ncr' => [_normal('C'), group],
      'npr' => [_normal('P'), group],
      'deg' => [...bodySpans, _normal('°')],
      _ => [_normal(name), group],
    };
  }

  List<InlineSpan> _root(String body) {
    final args = _splitTopLevelArgs(body);
    if (args.length != 2) {
      return [_sup('n'), _normal('√'), _group(build(body))];
    }
    final radicand = args[0].trim();
    final index = args[1].trim();
    return [_sup(index), _normal('√'), _group(build(radicand))];
  }

  InlineSpan _group(List<InlineSpan> children) {
    return TextSpan(children: [_normal('('), ...children, _normal(')')]);
  }

  InlineSpan _openGroup(List<InlineSpan> children) {
    return TextSpan(children: [_normal('('), ...children]);
  }

  InlineSpan _supGroup(List<InlineSpan> children, {required bool closed}) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Transform.translate(
        offset: const Offset(0, -5),
        child: RichText(
          text: TextSpan(
            style: style.copyWith(
                fontSize:
                    style.fontSize == null ? null : style.fontSize! * 0.68),
            children: [
              _normal('('),
              ...children,
              if (closed) _normal(')'),
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _normal(String text) => TextSpan(text: text, style: style);

  InlineSpan _sup(String text) => WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Transform.translate(
          offset: const Offset(0, -5),
          child: Text(text, style: _scriptStyle),
        ),
      );

  InlineSpan _sub(String text) => WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: Transform.translate(
          offset: const Offset(0, 3),
          child: Text(text, style: _scriptStyle),
        ),
      );

  TextStyle get _scriptStyle {
    final fontSize = style.fontSize;
    return style.copyWith(fontSize: fontSize == null ? null : fontSize * 0.64);
  }
}

({String value, int end})? _readExponent(String source, int start) {
  if (start >= source.length) return null;
  if (source[start] == '(') {
    final close = _matchingClose(source, start);
    if (close == null) return null;
    return (value: source.substring(start + 1, close), end: close + 1);
  }
  var index = start;
  if (source[index] == '-') index++;
  while (index < source.length && _isExponentPart(source[index])) {
    index++;
  }
  if (index == start || (index == start + 1 && source[start] == '-')) {
    return null;
  }
  return (value: source.substring(start, index), end: index);
}

String _constant(String token) {
  return switch (token) {
    'pi' => 'π',
    _ => token,
  };
}

List<String> _splitTopLevelArgs(String body) {
  final args = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (char == ',' && depth == 0) {
      args.add(body.substring(start, i));
      start = i + 1;
    }
  }
  args.add(body.substring(start));
  return args;
}

int? _matchingClose(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

bool _isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

bool _isIdentifierPart(String char) {
  final code = char.codeUnitAt(0);
  return _isIdentifierStart(char) || (code >= 48 && code <= 57);
}

bool _isExponentPart(String char) {
  final code = char.codeUnitAt(0);
  return _isIdentifierStart(char) || (code >= 48 && code <= 57) || char == '.';
}
