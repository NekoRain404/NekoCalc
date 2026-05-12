import 'package:flutter/material.dart';

class MathExpressionText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final spans = _buildSpans(context);
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final builder = _MathSpanBuilder(style, mathSymbols: mathSymbols);
    final index = cursorIndex?.clamp(0, expression.length);
    if (!showCursor || index == null) return builder.build(expression);
    return [
      ...builder.build(expression.substring(0, index)),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _ExpressionCursor(
            color: style.color ?? Theme.of(context).colorScheme.primary),
      ),
      ...builder.build(expression.substring(index)),
    ];
  }
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
  while (index < source.length &&
      RegExp(r'[A-Za-z0-9.]').hasMatch(source[index])) {
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
