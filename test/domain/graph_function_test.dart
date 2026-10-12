import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/graph/models/graph_strings.dart';
import 'package:nekocalc/features/graph/presentation/graph_page.dart';

void main() {
  final zh = GraphStrings.graphZh;
  test('normalizes y-prefixed expressions', () {
    expect(
        GraphFunction.normalizeExpression('y = x^2 - 3x + 2'), 'x^2 - 3x + 2');
    expect(GraphFunction.normalizeExpression('y: x^2 + 1'), 'x^2 + 1');
    expect(GraphFunction.normalizeExpression('y(x) -> 2x + 1'), '2x + 1');
    expect(GraphFunction.normalizeExpression('f(x): sin(x)'), 'sin(x)');
    expect(GraphFunction.normalizeExpression('g(x) => x^2'), 'x^2');
    expect(GraphFunction.normalizeExpression('Y＝２x＋１'), '2x+1');
    expect(GraphFunction.labelFor('y = 2x + 1'), 'y = 2x + 1');
    expect(GraphFunction.labelFor('sqrt(x)+pi^2'), 'y = √(x)+π²');
    expect(GraphFunction.labelFor('1.2e3*x'), 'y = 1.2×10³*x');
    expect(GraphFunction.labelFor('tau*x+phi'), 'y = τ*x+φ');
    expect(
      GraphFunction.normalizeExpression(r'y=\frac{1}{2}x+\sqrt{9}'),
      '((1)/(2))x+sqrt(9)',
    );
    expect(
      GraphFunction.normalizeExpression('y = x^2 - 1, x ∈ [-2, 2]'),
      'x^2 - 1',
    );
    expect(
      GraphFunction.normalizeExpression('f(x)=sin(x)，定义域 x∈[0,2π]'),
      'sin(x)',
    );
    expect(
      GraphFunction.normalizeExpression('g(x): sqrt(x); domain x >= 0'),
      'sqrt(x)',
    );
    expect(
      GraphFunction.normalizeExpression('h(x) = x^3 for x in R'),
      'x^3',
    );
    expect(GraphFunction.normalizeExpression('x^2 = 4'), '((x^2)-(4))');
    expect(
      GraphFunction.normalizeExpression('sin(x) = 0.5'),
      '((sin(x))-(0.5))',
    );
  });

  test('evaluates common graph shorthand', () {
    const linear = GraphFunction(
      expression: '2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
    );
    const factored = GraphFunction(
      expression: '(x + 1)(x - 1)',
      label: 'y = (x + 1)(x - 1)',
      color: Color(0xFF1677FF),
    );
    const trig = GraphFunction(
      expression: '2sin(x) + pi',
      label: 'y = 2sin(x) + pi',
      color: Color(0xFF1677FF),
    );
    const fullWidth = GraphFunction(
      expression: '２（x＋１）',
      label: 'y = ２（x＋１）',
      color: Color(0xFF1677FF),
    );
    const latex = GraphFunction(
      expression: r'\frac{1}{2}x+\sqrt{9}',
      label: r'y = \frac{1}{2}x+\sqrt{9}',
      color: Color(0xFF1677FF),
    );
    const constants = GraphFunction(
      expression: 'tau*x+phi',
      label: 'y = tau*x+phi',
      color: Color(0xFF1677FF),
    );
    const implicitConstants = GraphFunction(
      expression: '2tau*x+3phi',
      label: 'y = 2tau*x+3phi',
      color: Color(0xFF1677FF),
    );
    const constantFunction = GraphFunction(
      expression: 'taucos(x)+phi',
      label: 'y = taucos(x)+phi',
      color: Color(0xFF1677FF),
    );
    const radix = GraphFunction(
      expression: '0x10 + 0b10 + 0o10 + 10x',
      label: 'y = 0x10 + 0b10 + 0o10 + 10x',
      color: Color(0xFF1677FF),
    );
    const prefixed = GraphFunction(
      expression: 'f(x): x^2 + 2x + 1',
      label: 'f(x): x^2 + 2x + 1',
      color: Color(0xFF1677FF),
    );
    const domainSuffix = GraphFunction(
      expression: 'y = x^2 - 1, x ∈ [-2, 2]',
      label: 'y = x^2 - 1, x ∈ [-2, 2]',
      color: Color(0xFF1677FF),
    );
    const equation = GraphFunction(
      expression: 'x^2 = 4',
      label: 'x^2 = 4',
      color: Color(0xFF1677FF),
    );

    expect(linear.evaluate(3), closeTo(7, 1e-9));
    expect(factored.evaluate(3), closeTo(8, 1e-9));
    expect(trig.evaluate(0), closeTo(3.141592653589793, 1e-9));
    expect(fullWidth.evaluate(3), closeTo(8, 1e-9));
    expect(latex.evaluate(4), closeTo(5, 1e-9));
    expect(constants.evaluate(0.5),
        closeTo(3.141592653589793 + 1.618033988749895, 1e-9));
    expect(implicitConstants.evaluate(0.5),
        closeTo(2 * 3.141592653589793 + 3 * 1.618033988749895, 1e-9));
    expect(constantFunction.evaluate(0),
        closeTo(2 * 3.141592653589793 + 1.618033988749895, 1e-9));
    expect(radix.evaluate(3), closeTo(56, 1e-9));
    expect(prefixed.evaluate(3), closeTo(16, 1e-9));
    expect(domainSuffix.evaluate(3), closeTo(8, 1e-9));
    expect(equation.evaluate(2), closeTo(0, 1e-9));
    expect(equation.evaluate(3), closeTo(5, 1e-9));
  });

  // 中文：**角度单位是函数自己的一个字段，evaluate 认它。** `sin(90)` 是一眼分得开的那一对：
  //       角度制 `1`、弧度制 `0.8939966636005579`——计算器在同样的设置下给的就是这两个数。
  // English: **the angle unit is a field on the function and `evaluate` honours it.** `sin(90)` is the
  //          pair that separates at a glance: `1` under degrees, `0.8939966636005579` under radians —
  //          the very two numbers the calculator returns under the same setting.
  test('evaluates angles in the function\'s own unit: sin(90) is 1 in DEG', () {
    const radians = GraphFunction(
      expression: 'sin(x)',
      label: 'y = sin(x)',
      color: Color(0xFF1677FF),
    );
    const degrees = GraphFunction(
      expression: 'sin(x)',
      label: 'y = sin(x)',
      color: Color(0xFF1677FF),
      degreeMode: true,
    );

    expect(radians.evaluate(90), closeTo(0.8939966636005579, 1e-12));
    expect(degrees.evaluate(90), closeTo(1, 1e-12));
  });

  test('previews graph function input normalization and validation', () {
    final prefixed = previewGraphFunctionInput(
      'f(x)=sin(x)，定义域 x∈[0,2π]',
      color: const Color(0xFF1677FF),
      strings: zh,
    );
    final equation = previewGraphFunctionInput(
      'x^2 = 4',
      color: const Color(0xFF1677FF),
      strings: zh,
    );
    final invalid = previewGraphFunctionInput(
      'unknown(x)',
      color: const Color(0xFF1677FF),
      strings: zh,
    );
    final empty = previewGraphFunctionInput(
      '  ',
      color: const Color(0xFF1677FF),
      strings: zh,
    );

    expect(prefixed.isValid, isTrue);
    expect(prefixed.normalizedExpression, 'sin(x)');
    expect(prefixed.label, 'y = sin(x)');
    expect(prefixed.validSampleCount, greaterThan(0));
    expect(prefixed.message, contains('有效采样'));

    expect(equation.isValid, isTrue);
    expect(equation.normalizedExpression, '((x^2)-(4))');
    expect(equation.label, 'y = ((x²)-(4))');

    expect(invalid.isValid, isFalse);
    expect(invalid.errorMessage, contains('表达式无法计算'));
    expect(empty.isValid, isFalse);
    expect(empty.errorMessage, '请输入函数表达式');
  });

  test('builds graph sample markers for visible in-range functions', () {
    const first = GraphFunction(
      expression: '2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
    );
    const second = GraphFunction(
      expression: 'x^2',
      label: 'y = x^2',
      color: Color(0xFF7C3AED),
    );
    const hidden = GraphFunction(
      expression: '100',
      label: 'y = 100',
      color: Color(0xFFFF8A00),
      visible: false,
    );
    const outOfRange = GraphFunction(
      expression: '50',
      label: 'y = 50',
      color: Color(0xFF23B45D),
    );

    final markers = buildSampleMarkers(
      functions: const [first, second, hidden, outOfRange],
      x: 2,
      yMin: -10,
      yMax: 10,
      strings: zh,
    );

    expect(markers.length, 2);
    expect(markers.first.x, 2);
    expect(markers.first.y, closeTo(5, 1e-9));
    expect(markers.last.y, closeTo(4, 1e-9));
    expect(markers.first.info, contains('y = 2x + 1'));
    expect(markers.first.info, contains('y = x^2'));
    expect(markers.first.info, isNot(contains('y = 100')));
    expect(markers.first.kind, '取样');
  });

  test('builds graph copy text with viewport functions and markers', () {
    const first = GraphFunction(
      expression: 'sin(x)',
      label: 'y = sin(x)',
      color: Color(0xFF1677FF),
    );
    const second = GraphFunction(
      expression: 'x^2',
      label: 'y = x^2',
      color: Color(0xFF7C3AED),
      visible: false,
    );
    const viewport = GraphViewport(centerX: 1, centerY: 2, spanX: 6, spanY: 8);
    const markers = [
      GraphMarker(
        x: 0,
        y: 0,
        color: Color(0xFF1677FF),
        kind: '零点',
        info: 'y = sin(x) 零点\nx = 0.000000\ny = 0',
      ),
      GraphMarker(
        x: 1.5,
        y: 2.25,
        color: Color(0xFF7C3AED),
        kind: '取样',
        info: 'x = 1.500000',
      ),
    ];

    final text = buildGraphCopyText(
      functions: const [first, second],
      viewport: viewport,
      markers: markers,
      selectedMarker: 1,
      strings: zh,
    );

    expect(text, contains('图形数据'));
    expect(text, contains('1. y = sin(x) (显示)'));
    expect(text, contains('表达式: sin(x)'));
    expect(text, contains('2. y = x^2 (隐藏)'));
    expect(text, contains('表达式: x^2'));
    expect(text, contains('x: -2 ~ 4'));
    expect(text, contains('y: -2 ~ 6'));
    expect(text, contains('当前标记'));
    expect(text, contains('取样: x = 1.5, y = 2.25'));
    expect(text, contains('1. 零点: x = 0, y = 0'));
    expect(text, contains('2. 取样: x = 1.5, y = 2.25'));

    final markerText = buildMarkerCopyText(markers.last);
    expect(markerText, startsWith('取样: x = 1.5, y = 2.25'));
    expect(markerText, contains('x = 1.500000'));
  });

  test('serializes and restores graph workspace safely', () {
    const first = GraphFunction(
      expression: 'y = 2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
      visible: false,
    );
    const second = GraphFunction(
      expression: 'sqrt(x)',
      label: 'y = sqrt(x)',
      color: Color(0xFFFF8A00),
    );
    const viewport = GraphViewport(centerX: 3, centerY: -2, spanX: 8, spanY: 5);

    final encoded = encodeGraphWorkspace(
      functions: const [first, second],
      viewport: viewport,
    );
    final restored = decodeGraphWorkspace(encoded, strings: zh);

    expect(restored, isNotNull);
    expect(restored!.viewport.centerX, 3);
    expect(restored.viewport.centerY, -2);
    expect(restored.viewport.spanX, 8);
    expect(restored.viewport.spanY, 5);
    expect(restored.functions, hasLength(2));
    expect(restored.functions.first.expression, '2x + 1');
    expect(restored.functions.first.label, 'y = 2x + 1');
    expect(restored.functions.first.visible, isFalse);
    expect(restored.functions.first.color.toARGB32(), 0xFF1677FF);
    expect(restored.functions.last.expression, 'sqrt(x)');
    expect(restored.functions.last.color.toARGB32(), 0xFFFF8A00);
  });

  test('parses copied graph data back into a workspace', () {
    const first = GraphFunction(
      expression: '2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
      visible: false,
    );
    const second = GraphFunction(
      expression: 'sqrt(x)',
      label: 'y = sqrt(x)',
      color: Color(0xFFFF8A00),
    );
    const viewport = GraphViewport(centerX: 1, centerY: 2, spanX: 6, spanY: 8);
    final text = buildGraphCopyText(
      functions: const [first, second],
      viewport: viewport,
      markers: const [],
      strings: zh,
    );

    final paste = parseGraphWorkspacePasteText(text, strings: zh);

    expect(paste.hasWorkspace, isTrue);
    expect(paste.fromCopyText, isTrue);
    expect(paste.summary, contains('已从图形数据恢复工作区'));
    expect(paste.workspace!.functions, hasLength(2));
    expect(paste.workspace!.functions.first.expression, '2x + 1');
    expect(paste.workspace!.functions.first.visible, isFalse);
    expect(paste.workspace!.functions.last.expression, 'sqrt(x)');
    expect(paste.workspace!.viewport.centerX, 1);
    expect(paste.workspace!.viewport.centerY, 2);
    expect(paste.workspace!.viewport.spanX, 6);
    expect(paste.workspace!.viewport.spanY, 8);

    final jsonPaste = parseGraphWorkspacePasteText(
      encodeGraphWorkspace(
        functions: const [first],
        viewport: viewport,
      ),
      strings: zh,
    );
    expect(jsonPaste.hasWorkspace, isTrue);
    expect(jsonPaste.fromCopyText, isFalse);
    expect(
        parseGraphWorkspacePasteText('not a graph', strings: zh).hasWorkspace,
        isFalse);
  });

  test('parses English graph copy text back into a workspace', () {
    // 中文：**英文界面的粘贴回路。** `buildGraphCopyText` 今天仍只出中文，但解析器已经接受
    //       英文小节名（`graph data` / `functions` / `viewport` / `markers` / `hidden`）；本轮
    //       补上 `current marker`，这一条钉住"英文数据能粘回来"。
    //       `Current marker` 小节里那一行 `x: 100 ~ 200` 是**故意放的探针**：`Current marker`
    //       若不被认成小节边界，`inViewport` 就还是 true，这一行会被当成视窗数据，把上面
    //       `Viewport` 那两行读出来的范围整个覆盖掉。所以断言视窗仍是 `-2 ~ 4 / -2 ~ 6`。
    // English: **the English paste loop.** `buildGraphCopyText` still emits Chinese only, but the
    //          parser already accepts the English section names (`graph data` / `functions` /
    //          `viewport` / `markers` / `hidden`); this round adds `current marker`, and this test
    //          pins "English data pastes back". The `x: 100 ~ 200` line under `Current marker` is a
    //          **deliberate probe**: if `Current marker` were not recognised as a section boundary,
    //          `inViewport` would still be true, that line would be read as viewport data and would
    //          overwrite the range parsed from the `Viewport` lines above. Hence the assertion that
    //          the viewport is still `-2 ~ 4 / -2 ~ 6`.
    final paste = parseGraphWorkspacePasteText('''
Graph data

Functions
1. y = 2x + 1 (visible)
   expression: 2x + 1
2. y = x^2 (hidden)
   expression: x^2

Viewport
x: -2 ~ 4
y: -2 ~ 6

Current marker
Zero: x = 0, y = 0
x: 100 ~ 200

Markers
1. Zero: x = 0, y = 0
''', strings: zh);

    expect(paste.hasWorkspace, isTrue);
    expect(paste.fromCopyText, isTrue);
    expect(paste.workspace!.functions, hasLength(2));
    expect(paste.workspace!.functions.first.expression, '2x + 1');
    expect(paste.workspace!.functions.first.visible, isTrue);
    expect(paste.workspace!.functions.last.expression, 'x^2');
    expect(paste.workspace!.functions.last.visible, isFalse);
    expect(paste.workspace!.viewport.centerX, 1);
    expect(paste.workspace!.viewport.centerY, 2);
    expect(paste.workspace!.viewport.spanX, 6);
    expect(paste.workspace!.viewport.spanY, 8);
  });

  test(
      'English copy text round-trips through the parser (bilingual wire format)',
      () {
    const first = GraphFunction(
      expression: '2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
      visible: false,
    );
    const second = GraphFunction(
      expression: 'sqrt(x)',
      label: 'y = sqrt(x)',
      color: Color(0xFFFF8A00),
    );
    const viewport = GraphViewport(centerX: 1, centerY: 2, spanX: 6, spanY: 8);
    final en = GraphStrings.graphEn;
    final text = buildGraphCopyText(
      functions: const [first, second],
      viewport: viewport,
      markers: const [],
      strings: en,
    );

    // 中文：**英文界面复制出去的数据，英文界面自己粘得回来。** 这一条钉的是"线格式两种语言都收"：
    //       小节名一旦出英文，解析器必须认（`current marker` 是本轮之前补的），否则英文界面的
    //       复制/粘贴回路是断的。
    // English: **data copied out of the English interface pastes back into it.** This pins "the wire
    //          format accepts both languages": once the section names go English the parser must
    //          recognise them (`current marker` was added just before this round), or the English
    //          interface's copy/paste loop is broken.
    expect(text, contains('Graph data'));
    expect(text, contains('Viewport'));
    // 中文：**英文侧写的是 `(Hide)` / `(Show)`，不是 `(hidden)`。** 这一条顺带钉住解析器认得出
    //       它——之前解析器只认 `hidden`，英文数据粘回来会把隐藏的函数变回显示。
    // English: **the English side writes `(Hide)` / `(Show)`, not `(hidden)`.** This also pins that
    //          the parser recognises it — it used to know only `hidden`, so English data pasted back
    //          turned hidden functions visible again.
    expect(text, contains('(Hide)'));
    expect(text, contains('(Show)'));
    expect(_containsCjk(text), isFalse, reason: '英文界面复制出去的数据不该有汉字：\n$text');

    final paste = parseGraphWorkspacePasteText(text, strings: en);
    expect(paste.hasWorkspace, isTrue);
    expect(paste.fromCopyText, isTrue);
    expect(paste.summary, contains('Workspace restored from graph data'));
    expect(paste.workspace!.functions, hasLength(2));
    expect(paste.workspace!.functions.first.visible, isFalse);
    expect(paste.workspace!.viewport.centerX, 1);
    expect(paste.workspace!.viewport.spanY, 8);

    // 中文：反向也钉一下——中文数据用英文表解析，summary 是英文，工作区照样读出来。
    // English: pin the other direction too — Chinese data parsed with the English table yields an
    //          English summary and still reads the workspace.
    final zhText = buildGraphCopyText(
      functions: const [second],
      viewport: viewport,
      markers: const [],
      strings: zh,
    );
    final zhPaste = parseGraphWorkspacePasteText(zhText, strings: en);
    expect(zhPaste.hasWorkspace, isTrue);
    expect(zhPaste.summary, contains('Workspace restored from graph data'));
  });

  test('parses plain pasted graph functions into a workspace', () {
    final paste = parseGraphWorkspacePasteText('''
y = x^2 - 1
sin(x)
表达式: 2x + 1
sin(x)
not a graph
''', strings: zh);

    expect(paste.hasWorkspace, isTrue);
    expect(paste.fromCopyText, isFalse);
    expect(paste.fromFunctionText, isTrue);
    expect(paste.summary, contains('已从函数文本创建工作区'));
    expect(paste.workspace!.viewport, defaultGraphViewport);
    expect(paste.workspace!.functions.map((item) => item.expression), [
      'x^2 - 1',
      'sin(x)',
      '2x + 1',
    ]);
    expect(
      paste.workspace!.functions.map((item) => item.visible),
      everyElement(isTrue),
    );

    final invalid = parseGraphWorkspacePasteText('''
shopping list
todo tomorrow
plain words only
''', strings: zh);
    expect(invalid.hasWorkspace, isFalse);
  });

  test('graph workspace decoder ignores malformed content and clamps viewport',
      () {
    final restored = decodeGraphWorkspace('''
      {
        "version": 1,
        "viewport": {"centerX": "1.5", "centerY": -2, "spanX": 9999, "spanY": 0.1},
        "functions": [
          {"expression": "unknown(x)", "visible": true, "color": "#FF0000"},
          {"expression": "sin(x)", "visible": false, "color": "#23B45D"},
          {"expression": "x^2 = 4", "color": "0xFF7C3AED"},
          {"expression": "", "color": 123}
        ]
      }
    ''', strings: zh);

    expect(restored, isNotNull);
    expect(restored!.viewport.centerX, 1.5);
    expect(restored.viewport.centerY, -2);
    expect(restored.viewport.spanX, 200);
    expect(restored.viewport.spanY, 0.5);
    expect(restored.functions, hasLength(2));
    expect(restored.functions.first.expression, 'sin(x)');
    expect(restored.functions.first.visible, isFalse);
    expect(restored.functions.first.color.toARGB32(), 0xFF23B45D);
    expect(restored.functions.last.expression, '((x^2)-(4))');
    expect(restored.functions.last.color.toARGB32(), 0xFF7C3AED);

    expect(decodeGraphWorkspace(null, strings: zh), isNull);
    expect(decodeGraphWorkspace('not json', strings: zh), isNull);
    expect(decodeGraphWorkspace('{"functions": []}', strings: zh), isNull);
  });

  test('graph viewport zoom keeps focal graph coordinate anchored', () {
    const viewport =
        GraphViewport(centerX: 2, centerY: -1, spanX: 12, spanY: 8);
    const size = Size(300, 200);
    const focal = Offset(75, 50);

    final beforeX = viewport.toGraphX(focal.dx, size);
    final beforeY = viewport.toGraphY(focal.dy, size);
    final zoomed = viewport.zoomAt(0.5, focal, size);

    expect(zoomed.spanX, 6);
    expect(zoomed.spanY, 4);
    expect(zoomed.toGraphX(focal.dx, size), closeTo(beforeX, 1e-10));
    expect(zoomed.toGraphY(focal.dy, size), closeTo(beforeY, 1e-10));
    expect(zoomed.centerX, isNot(viewport.centerX));
    expect(zoomed.centerY, isNot(viewport.centerY));
  });

  test('graph viewport center zoom and invalid sizes stay stable', () {
    const viewport =
        GraphViewport(centerX: 2, centerY: -1, spanX: 12, spanY: 8);

    final centered = viewport.zoom(0.5);
    final invalidZoom = viewport.zoomAt(0.5, const Offset(80, 40), Size.zero);
    final invalidPan = viewport.pan(const Offset(20, 10), Size.zero);

    expect(centered.centerX, 2);
    expect(centered.centerY, -1);
    expect(centered.spanX, 6);
    expect(centered.spanY, 4);
    expect(invalidZoom.centerX, 2);
    expect(invalidZoom.centerY, -1);
    expect(invalidZoom.spanX, 6);
    expect(invalidZoom.spanY, 4);
    expect(invalidPan, same(viewport));
  });

  test('graph viewport centers on finite marker while keeping zoom', () {
    const viewport =
        GraphViewport(centerX: 2, centerY: -1, spanX: 12, spanY: 8);

    final centered = viewport.centerOn(-3, 4.5);
    final invalidX = viewport.centerOn(double.nan, 4.5);
    final invalidY = viewport.centerOn(-3, double.infinity);

    expect(centered.centerX, -3);
    expect(centered.centerY, 4.5);
    expect(centered.spanX, viewport.spanX);
    expect(centered.spanY, viewport.spanY);
    expect(invalidX, same(viewport));
    expect(invalidY, same(viewport));
  });

  test('builds zero markers without false positives at asymptotes', () {
    const viewport = GraphViewport(centerX: 0, centerY: 0, spanX: 4, spanY: 4);
    const reciprocal = GraphFunction(
      expression: '1/x',
      label: 'y = 1/x',
      color: Color(0xFF1677FF),
    );
    const tangent = GraphFunction(
      expression: '(x - 0.333)^2',
      label: 'y = (x - 0.333)^2',
      color: Color(0xFF7C3AED),
    );
    const zero = GraphFunction(
      expression: '0',
      label: 'y = 0',
      color: Color(0xFFFF8A00),
    );
    const equation = GraphFunction(
      expression: 'x^2 = 4',
      label: 'x^2 = 4',
      color: Color(0xFF23B45D),
    );

    expect(
      buildGraphZeroMarkers(
          functions: const [reciprocal], viewport: viewport, strings: zh),
      isEmpty,
    );

    final tangentMarkers = buildGraphZeroMarkers(
        functions: const [tangent], viewport: viewport, strings: zh);
    expect(tangentMarkers, hasLength(1));
    expect(tangentMarkers.single.x, closeTo(0.333, 1e-4));
    expect(tangentMarkers.single.kind, '零点');

    final zeroMarkers = buildGraphZeroMarkers(
        functions: const [zero], viewport: viewport, strings: zh);
    expect(zeroMarkers, hasLength(1));
    expect(zeroMarkers.single.info, contains('所有 x 都是零点'));

    final equationMarkers = buildGraphZeroMarkers(
        functions: const [equation], viewport: viewport, strings: zh);
    expect(equationMarkers.map((marker) => marker.x),
        containsAll([closeTo(-2, 1e-4), closeTo(2, 1e-4)]));
  });

  test('builds intersection markers without asymptote false positives', () {
    const viewport = GraphViewport(centerX: 0, centerY: 0, spanX: 4, spanY: 4);
    const reciprocal = GraphFunction(
      expression: '1/x',
      label: 'y = 1/x',
      color: Color(0xFF1677FF),
    );
    const zero = GraphFunction(
      expression: '0',
      label: 'y = 0',
      color: Color(0xFF7C3AED),
    );
    const tangent = GraphFunction(
      expression: '(x - 0.333)^2',
      label: 'y = (x - 0.333)^2',
      color: Color(0xFFFF8A00),
    );
    const sameTangent = GraphFunction(
      expression: '(x - 0.333)^2',
      label: 'y = (x - 0.333)^2',
      color: Color(0xFF23B45D),
    );

    expect(
      buildGraphIntersectionMarkers(
        functions: const [reciprocal, zero],
        viewport: viewport,
        strings: zh,
      ),
      isEmpty,
    );

    final tangentMarkers = buildGraphIntersectionMarkers(
      functions: const [tangent, zero],
      viewport: viewport,
      strings: zh,
    );
    expect(tangentMarkers, hasLength(1));
    expect(tangentMarkers.single.x, closeTo(0.333, 1e-4));
    expect(tangentMarkers.single.y, closeTo(0, 1e-7));
    expect(tangentMarkers.single.kind, '交点');

    final overlapMarkers = buildGraphIntersectionMarkers(
      functions: const [tangent, sameTangent],
      viewport: viewport,
      strings: zh,
    );
    expect(overlapMarkers, hasLength(1));
    expect(overlapMarkers.single.kind, '重合');
  });

  test('builds extreme markers only for visible in viewport extrema', () {
    const viewport = GraphViewport(centerX: 0, centerY: 0, spanX: 6, spanY: 8);
    const minimum = GraphFunction(
      expression: '(x - 1)^2 - 2',
      label: 'y = (x - 1)^2 - 2',
      color: Color(0xFF1677FF),
    );
    const maximum = GraphFunction(
      expression: '-(x + 0.5)^2 + 3',
      label: 'y = -(x + 0.5)^2 + 3',
      color: Color(0xFF7C3AED),
    );
    const hidden = GraphFunction(
      expression: 'x^2',
      label: 'y = x^2',
      color: Color(0xFFFF8A00),
      visible: false,
    );
    const outOfView = GraphFunction(
      expression: 'x^2 + 20',
      label: 'y = x^2 + 20',
      color: Color(0xFF23B45D),
    );

    final markers = buildGraphExtremeMarkers(
      functions: const [minimum, maximum, hidden, outOfView],
      viewport: viewport,
      strings: zh,
    );

    expect(markers, hasLength(2));
    expect(markers.map((marker) => marker.kind), containsAll(['极小值', '极大值']));

    final minMarker = markers.singleWhere((marker) => marker.kind == '极小值');
    expect(minMarker.x, closeTo(1, 1e-4));
    expect(minMarker.y, closeTo(-2, 1e-4));
    expect(minMarker.info, contains('y = (x - 1)^2 - 2'));

    final maxMarker = markers.singleWhere((marker) => marker.kind == '极大值');
    expect(maxMarker.x, closeTo(-0.5, 1e-4));
    expect(maxMarker.y, closeTo(3, 1e-4));
    expect(maxMarker.info, contains('y = -(x + 0.5)^2 + 3'));
  });

  test('builds plot segments that break around discontinuities', () {
    const viewport = GraphViewport(centerX: 0, centerY: 0, spanX: 4, spanY: 4);
    const linear = GraphFunction(
      expression: 'x',
      label: 'y = x',
      color: Color(0xFF1677FF),
    );
    const reciprocal = GraphFunction(
      expression: '1/x',
      label: 'y = 1/x',
      color: Color(0xFF7C3AED),
    );

    final lineSegments = buildGraphPlotSegments(
      function: linear,
      viewport: viewport,
      width: 80,
      height: 80,
    );
    final reciprocalSegments = buildGraphPlotSegments(
      function: reciprocal,
      viewport: viewport,
      width: 80,
      height: 80,
    );

    expect(lineSegments, hasLength(1));
    expect(lineSegments.single.length, greaterThan(60));
    expect(reciprocalSegments.length, greaterThanOrEqualTo(2));
    expect(
      reciprocalSegments.expand((segment) => segment),
      everyElement(
        predicate<Offset>((point) => point.dx.isFinite && point.dy.isFinite),
      ),
    );
  });
}

/// 中文：CJK 统一表意文字区（含扩展 A）。
/// English: The CJK Unified Ideographs block (plus Extension A).
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
