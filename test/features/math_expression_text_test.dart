import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_text.dart';

void main() {
  const style = TextStyle(fontSize: 24);

  Future<MathExpressionTextState> pumpExpression(
    WidgetTester tester,
    String expression, {
    bool mathSymbols = true,
    int? cursorIndex,
    bool showCursor = false,
    EdgeInsets padding = EdgeInsets.zero,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final key = GlobalKey<MathExpressionTextState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: textDirection,
            child: Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topLeft,
                child: MathExpressionText(
                  key: key,
                  expression: expression,
                  style: style,
                  mathSymbols: mathSymbols,
                  cursorIndex: cursorIndex,
                  showCursor: showCursor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return key.currentState!;
  }

  RenderParagraph paragraph(WidgetTester tester) {
    return tester.renderObject<RenderParagraph>(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.maxLines == 1,
      ),
    );
  }

  testWidgets('maps a displayed pi to a source boundary', (tester) async {
    final state = await pumpExpression(tester, '2*pi+3');
    final renderParagraph = paragraph(tester);
    final literalBox = renderParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single;
    final piBox = renderParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 2, extentOffset: 3),
        )
        .single;

    expect(
      state.sourceOffsetForLocalPosition(literalBox.toRect().center),
      anyOf(0, 1),
    );
    expect(
      state.sourceOffsetForLocalPosition(piBox.toRect().center),
      anyOf(2, 4),
    );
  });

  testWidgets('clamps positions before and after the rendered expression',
      (tester) async {
    final state = await pumpExpression(tester, '2*pi+3');
    final size = paragraph(tester).size;

    expect(state.sourceOffsetForLocalPosition(const Offset(-100, 0)), 0);
    expect(
      state.sourceOffsetForLocalPosition(Offset(size.width + 100, 0)),
      6,
    );
  });

  testWidgets('maps a transformed exponent to one of its source boundaries',
      (tester) async {
    final state = await pumpExpression(tester, '2^12');
    final renderParagraph = paragraph(tester);
    final exponentBox = renderParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single;

    expect(
      state.sourceOffsetForLocalPosition(exponentBox.toRect().center),
      anyOf(1, 4),
    );
  });

  testWidgets('maps each exponent placeholder half to its source boundary',
      (tester) async {
    final state = await pumpExpression(tester, '2^12');
    final exponentBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single;
    final rect = exponentBox.toRect();

    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.left + rect.width * .25, rect.center.dy),
      ),
      1,
    );
    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.left + rect.width * .75, rect.center.dy),
      ),
      4,
    );
  });

  testWidgets('maps a transformed function symbol to its source boundaries',
      (tester) async {
    final state = await pumpExpression(tester, 'sqrt(9)');
    final rootBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single;
    final rect = rootBox.toRect();

    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.left + rect.width * .25, rect.center.dy),
      ),
      0,
    );
    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.left + rect.width * .75, rect.center.dy),
      ),
      4,
    );
  });

  testWidgets('maps a function subscript placeholder to source boundaries',
      (tester) async {
    final state = await pumpExpression(tester, 'log2(8)');
    final subscriptBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 3, extentOffset: 4),
        )
        .single;

    expect(
      state.sourceOffsetForLocalPosition(subscriptBox.toRect().center),
      anyOf(3, 4),
    );
  });

  testWidgets('keeps cursor mapping legal with math symbols disabled',
      (tester) async {
    final state = await pumpExpression(
      tester,
      'pi+2',
      mathSymbols: false,
      cursorIndex: 1,
      showCursor: true,
    );
    final renderParagraph = paragraph(tester);
    final cursorBox = renderParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single;
    final size = renderParagraph.size;

    expect(state.sourceOffsetForLocalPosition(cursorBox.toRect().center), 1);
    for (final position in [
      const Offset(-20, 0),
      Offset(size.width * .5, size.height * .5),
      Offset(size.width + 20, 0),
    ]) {
      expect(
        state.sourceOffsetForLocalPosition(position),
        inInclusiveRange(0, 4),
      );
    }
  });

  testWidgets('maps the virtual close in an unclosed root call to source end',
      (tester) async {
    final state = await pumpExpression(tester, 'root(9,2');
    final closingBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 4, extentOffset: 5),
        )
        .single;

    expect(
      state.sourceOffsetForLocalPosition(closingBox.toRect().center),
      8,
    );
  });

  testWidgets('maps a global position after an ancestor offset',
      (tester) async {
    final state = await pumpExpression(
      tester,
      '2*pi+3',
      padding: const EdgeInsets.only(left: 80, top: 40),
    );
    final renderParagraph = paragraph(tester);
    final piBox = renderParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 2, extentOffset: 3),
        )
        .single;

    expect(
      state.sourceOffsetForGlobalPosition(
        renderParagraph.localToGlobal(piBox.toRect().center),
      ),
      anyOf(2, 4),
    );
  });

  testWidgets('uses RTL direction to resolve widget span halves',
      (tester) async {
    final state = await pumpExpression(
      tester,
      '2^12',
      textDirection: TextDirection.rtl,
    );
    final exponentBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single;
    final rect = exponentBox.toRect();

    expect(exponentBox.direction, TextDirection.rtl);
    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.right - rect.width * .25, rect.center.dy),
      ),
      1,
    );
    expect(
      state.sourceOffsetForLocalPosition(
        Offset(rect.left + rect.width * .25, rect.center.dy),
      ),
      4,
    );
  });

  testWidgets(
      'cursor within transformed source syntax preserves formatted spans',
      (tester) async {
    final cases =
        <({String expression, int cursorIndex, String formatted, String raw})>[
      (expression: 'sqrt(9)', cursorIndex: 4, formatted: '√(9)', raw: 'sqrt'),
      (expression: 'pi+2', cursorIndex: 1, formatted: 'π+2', raw: 'pi'),
      (expression: '2^12', cursorIndex: 2, formatted: '2', raw: '^'),
      (expression: 'log2(8)', cursorIndex: 3, formatted: 'log(8)', raw: 'log2'),
    ];

    for (final testCase in cases) {
      await pumpExpression(
        tester,
        testCase.expression,
        cursorIndex: testCase.cursorIndex,
        showCursor: true,
      );

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.maxLines == 1,
        ),
      );
      final rendered = richText.text.toPlainText(
        includeSemanticsLabels: false,
        includePlaceholders: true,
      );

      final withoutPlaceholders = rendered.replaceAll('\uFFFC', '');
      expect(withoutPlaceholders, contains(testCase.formatted));
      expect(withoutPlaceholders, isNot(contains(testCase.raw)));
    }
  });

  testWidgets('cursor insertion preserves transformed root hit testing',
      (tester) async {
    final state = await pumpExpression(
      tester,
      'sqrt(9)',
      cursorIndex: 4,
      showCursor: true,
    );
    final rootBox = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single;

    expect(
      state.sourceOffsetForLocalPosition(rootBox.toRect().center),
      anyOf(0, 4),
    );
  });

  testWidgets('cursor insertion preserves pi exponent and log2 hit testing',
      (tester) async {
    var state = await pumpExpression(
      tester,
      'pi+2',
      cursorIndex: 1,
      showCursor: true,
    );
    var box = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single;
    expect(
      state.sourceOffsetForLocalPosition(box.toRect().center),
      anyOf(0, 2),
    );

    state = await pumpExpression(
      tester,
      '2^12',
      cursorIndex: 2,
      showCursor: true,
    );
    box = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single;
    expect(
      state.sourceOffsetForLocalPosition(box.toRect().center),
      anyOf(1, 4),
    );

    state = await pumpExpression(
      tester,
      'log2(8)',
      cursorIndex: 3,
      showCursor: true,
    );
    box = paragraph(tester)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 4, extentOffset: 5),
        )
        .single;
    expect(
      state.sourceOffsetForLocalPosition(box.toRect().center),
      anyOf(3, 4),
    );
  });
}
