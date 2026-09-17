import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HiPER 式主屏', () {

    testWidgets('M+ 拒绝一个装不进 double 的值时，屏幕上出现一句话', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': '记忆值: 12.5'};
        return null;
      });
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await _startEditing(tester);
      await tester.tap(find.byTooltip('粘贴计算详情'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      // 中文：**先让粘贴自己那条 SnackBar 走完**（`_pasteCalculatorDetails` 会报「已恢复记忆值」）。
      //       `ScaffoldMessenger` 一次只显示一条，后来者要等前一条那 4 秒结束——那是它本来的行为，
      //       不是这一步的缺陷，但测试必须把它让开，否则断言的就成了队列而不是这句话。
      // English: **let the paste's own SnackBar finish first** (`_pasteCalculatorDetails` reports
      //          "已恢复记忆值"). A `ScaffoldMessenger` shows one at a time and a later one waits for the
      //          current one's four seconds — its own behaviour and not this step's defect, but the test
      //          has to get out of its way, or it would be asserting on the queue instead of on this
      //          sentence.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _startEditing(tester);
      await tester.enterText(find.byType(TextField), '10^400');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.text('M+').first);
      await tester.pumpAndSettle();

      expect(
        find.text('当前值放不进记忆寄存器，寄存器未改动').hitTestable(),
        findsOneWidget,
        reason: '按了 M+ 而寄存器没动，用户必须被告知；静默就是这一步要消灭的那个缺陷',
      );

      // 中文：让 SnackBar 自己走完（4 秒），测试结束时不留挂着的定时器。
      // English: let the SnackBar run out (4 seconds) so no timer is left pending at the end.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _openMore(tester);
      expect(find.text('M 12.5'), findsOneWidget,
          reason: '拒绝必须是值中性的：寄存器里还是原来的 12.5');
    });

    testWidgets('面板里的 M+ 被拒时，面板让开、那句话看得见', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await _startEditing(tester);
      await tester.enterText(find.byType(TextField), '10^400');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      await _openMore(tester);
      await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('M+'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing,
          reason: '面板盖着消息落的那一条，有话要说时它必须先让开');
      expect(
        find.text('当前值放不进记忆寄存器，寄存器未改动').hitTestable(),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('键位表里每个已启用的 id 主屏都接得住', (tester) async {
      // 逐格收集：主键、SHIFT/hyp 变体、标签横带里的实体键。
      final ids = <String>{};
      void collect(KeypadKey key) {
        if (key.category == KeyCategory.disabled) return;
        for (final variant in [key.base, key.shift, key.hyp]) {
          if (variant == null || !variant.enabled) continue;
          ids.add(variant.id);
        }
      }

      for (final row in hiperKeypad.rows) {
        for (final key in row.keys) {
          collect(key);
        }
        for (final label in row.labels) {
          if (label is InlineKey) collect(label.key);
        }
      }
      expect(ids, isNotEmpty, reason: '走表必须真的收集到 id，否则这条测试是空转的');

      for (final id in ids) {
        // 中文：每个 id 都从一块全新的主屏开始，表达式因此只可能来自这一次派发。
        // English: every id starts from a brand-new screen, so the expression can only come from this
        //          one dispatch.
        await tester.pumpWidget(_testApp(key: ValueKey<String>(id)));
        await tester.pump();
        tester
            .widget<CalculatorKeypad>(find.byType(CalculatorKeypad))
            .onKey(id);
        await tester.pump(const Duration(milliseconds: 250));

        expect(tester.takeException(), isNull, reason: '派发按键 $id 时抛异常');
        if (CalculatorPage.defaultInputKeyIds.contains(id)) continue;
        expect(_displayedExpression(tester), isNot(id),
            reason: '主屏没接住按键 id「$id」，它被当字面量写进了表达式');
      }
    });

    testWidgets('新点亮的引擎键：派发、排版、渲染三层证据', (tester) async {
      // 中文：键 id → 按下去之后表达式应有的样子。右括号是这一步的前置条件，所以它出现在
      //       每一个预期值里。
      // English: key id → what the expression should look like after the press. The closing
      //          bracket is this step's precondition, so it shows up in every expected value.
      const expected = <String, String>{
        'ins:sum': 'sum(x,1,10,x)',
        'ins:product': 'product(x,1,5,x)',
        'ins:integrate': 'integrate(x^2,0,1,x)',
        'ins:limit': 'limit(sin(x)/x,0,x)',
        'ins:logxy': 'log(8,2)',
        'ins:rand': 'rand()',
        // 中文：矩阵与虚数单位（本轮新点亮）：两条都是完整的插入物，`i` 单独一个字母。
        // English: the matrix and the imaginary unit (lit this round): both are complete insertions,
        //          `i` being a single letter.
        'ins:matrix': 'matrix(2,2,1,2,3,4)',
        'ins:i': 'i',
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(_testApp(key: ValueKey<String>(entry.key)));
        await tester.pump();
        tester
            .widget<CalculatorKeypad>(find.byType(CalculatorKeypad))
            .onKey(entry.key);
        await tester.pump(const Duration(milliseconds: 250));

        final expression = _displayedExpression(tester);
        expect(expression, entry.value,
            reason: '按键「${entry.key}」插进去的文本不是预期的形状');
        expect(_literalTextFragment(expression), isFalse,
            reason: '按键「${entry.key}」的表达式降级成了字面文本：'
                '${const TexEmitter().emit(const ExpressionAstParser().parse(expression))}');
        expect(
          MathExpressionView.typesetsTex(
              const TexEmitter().emit(const ExpressionAstParser().parse(expression))),
          isTrue,
          reason: '按键「${entry.key}」的表达式排不出来',
        );
        expect(
          find.descendant(
            of: find.byType(MathExpressionView),
            matching: find.text(expression),
          ),
          findsNothing,
          reason: '按键「${entry.key}」画成了字面文本而不是公式',
        );
      }
    });

    testWidgets('CPLX / STAT：面板、派发、排版、渲染四层证据', (tester) async {
      // 中文：**键面文字在这里，不是 id。** id 从**键位表里查**（`_cellByFace`），所以这一条钉住的
      //       是「面板上那颗键**此刻**是点亮的，它当下那个 id 打开的是那个面板」——把 `STAT` 改回
      //       `dis:stat` 或把启用态翻成 false，这一条就红，而不是「测试里写死的那个 id 仍然好用」。
      //       （先写死 id 的版本确实漏掉过这一点：那颗键退回禁用态时它照样绿。）
      // English: **the key faces are here, not the ids.** The id is looked up **in the key table**
      //          (`_cellByFace`), so what this pins is "that key on the keypad is lit *right now*, and
      //          the id it currently carries opens that sheet" — setting `STAT` back to `dis:stat` or
      //          flipping its enabled flag turns this red, rather than "the id hardcoded in the test
      //          still works". (The version with hardcoded ids did miss exactly that: it stayed green
      //          when the key went back to disabled.)
      const cases = <(String, String, String)>[
        ('CPLX', 'i', 'i'),
        ('CPLX', 'abs', 'abs()'),
        ('CPLX', 'conj', 'conj()'),
        ('CPLX', 'arg', 'arg()'),
        ('CPLX', 're', 're()'),
        ('CPLX', 'im', 'im()'),
        ('STAT', 'mean', 'mean(1,2,3,4)'),
        ('STAT', 'median', 'median(1,2,3,4)'),
        ('STAT', 'stdev', 'stdev(1,2,3,4)'),
        ('STAT', 'var', 'var(1,2,3,4)'),
      ];

      for (final (face, cell, expected) in cases) {
        final target = _cellByFace(face);
        expect(target.enabled, isTrue, reason: '「$face」这一刻还是禁用态');
        expect(target.category, isNot(KeyCategory.disabled),
            reason: '「$face」这一刻还在 disabled 分类里');

        await tester.pumpWidget(_testApp(key: ValueKey<String>('$face-$cell')));
        await tester.pump();

        // 第一层：面板真的打开，且里面有那一格。
        tester
            .widget<CalculatorKeypad>(find.byType(CalculatorKeypad))
            .onKey(target.id);
        await tester.pumpAndSettle();
        final cellFinder = find.widgetWithText(TextButton, cell);
        expect(cellFinder, findsOneWidget,
            reason: '「$face」的面板里找不到「$cell」那一格');

        // 第二层：按下去，表达式是那个形状。
        await tester.tap(cellFinder);
        await tester.pumpAndSettle();
        final expression = _displayedExpression(tester);
        expect(expression, expected,
            reason: '面板「$face」里的「$cell」插进去的文本不是预期的形状');

        // 第三层：没有降级成字面文本，而且渲染器的解析器认它。
        expect(_literalTextFragment(expression), isFalse,
            reason: '`$expression` 降级成了字面文本：'
                '${const TexEmitter().emit(const ExpressionAstParser().parse(expression))}');
        final tex =
            const TexEmitter().emit(const ExpressionAstParser().parse(expression));
        expect(MathExpressionView.typesetsTex(tex), isTrue,
            reason: '`$expression` 排不出来：$tex');

        // 第四层：屏幕上画的是公式，不是承载降级文本的那个 `Text`。
        expect(
          find.descendant(
            of: find.byType(MathExpressionView),
            matching: find.text(expression),
          ),
          findsNothing,
          reason: '`$expression` 画成了字面文本而不是公式',
        );
      }
    });

    testWidgets('复数与统计的典型调用排成 \\operatorname 形状', (tester) async {
      const calls = <String, String>{
        'conj(3+4i)': r'\operatorname{conj}{\left(3+4i\right)}',
        'arg(3+4i)': r'\operatorname{arg}{\left(3+4i\right)}',
        're(3+4i)': r'\operatorname{re}{\left(3+4i\right)}',
        'im(3+4i)': r'\operatorname{im}{\left(3+4i\right)}',
        'mean(1,2,3,4)': r'\operatorname{mean}{\left(1, 2, 3, 4\right)}',
        'median(1,2,3,4)': r'\operatorname{median}{\left(1, 2, 3, 4\right)}',
        'stdev(1,2,3,4)': r'\operatorname{stdev}{\left(1, 2, 3, 4\right)}',
        'var(1,2,3,4)': r'\operatorname{var}{\left(1, 2, 3, 4\right)}',
      };

      for (final call in calls.entries) {
        expect(
          const TexEmitter().emit(const ExpressionAstParser().parse(call.key)),
          call.value,
          reason: '${call.key} 的排版形状不对',
        );
        expect(_literalTextFragment(call.key), isFalse);
        expect(MathExpressionView.typesetsTex(call.value), isTrue,
            reason: '${call.key} 的排版渲染器不认：${call.value}');
      }
    });

    testWidgets('填满实参之后：Σ / Π / ∫ / lim / d/dx 排成专属形状', (tester) async {
      const calls = <String, String>{
        'sum(x,1,10,x)': r'\sum_{x=1}^{10}x',
        'product(k,1,5)': r'\prod_{1}^{5}k',
        'integrate(x^2,0,1,x)': r'\int_{0}^{1}x^{2}\,\mathrm{d}x',
        'limit(sin(x)/x,0,x)': r'\lim_{x\to 0}\frac{\sin\left(x\right)}{x}',
        'diff(x^3,x)': r'\frac{\mathrm{d}}{\mathrm{d}x}\left(x^{3}\right)',
        'log(8,2)': r'\log_{2}\left(8\right)',
      };

      for (final call in calls.entries) {
        expect(
          const TexEmitter().emit(const ExpressionAstParser().parse(call.key)),
          call.value,
          reason: '${call.key} 的排版形状不对',
        );
        expect(_literalTextFragment(call.key), isFalse);
        expect(MathExpressionView.typesetsTex(call.value), isTrue,
            reason: '${call.key} 的排版渲染器不认：${call.value}');
      }

      // 中文：最后真把整块显示区建出来一次，确认这几段公式都画了出来（没有降到纯文本兜底）。
      // English: finally build a whole display panel once, confirming these formulas really draw
      //          (they never take the plain-text fallback).
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      for (final call in calls.keys) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MathExpressionView(expression: call),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$call 渲染时抛异常');
        expect(find.text(call), findsNothing, reason: '$call 画成了字面文本');
        final fragments = find.descendant(
          of: find.byType(MathExpressionView),
          matching: find.byType(GestureDetector),
        );
        expect(fragments, findsOneWidget);
        expect(tester.getSize(fragments).width, greaterThan(0),
            reason: '$call 的片段宽度为 0，等于没画出来');
      }
    });
  });
}

/// 中文：打开显示面板右上角的 `More...` 动作面板（旧工具条与记忆条上的操作现在都住在这里）。
/// English: Opens the `More...` action sheet at the right of the display panel — where the operations
///          from the old toolbar and memory bar now live.
Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
}

/// 中文：从面板里显式打开内联编辑器（旧工具条上那颗带焦点的编辑按钮）。
/// English: Opens the inline editor explicitly from the sheet (the old toolbar's focusing edit
///          button).
Future<void> _startEditing(WidgetTester tester) async {
  await _openMore(tester);
  await tester.tap(find.text('编辑表达式'));
  await tester.pumpAndSettle();
}

/// 中文：在**键位表**里按键面文字查那一格这一刻的 id、启用态与分类。主键条与标签横带都走。
///       查询失败直接抛错——「表里没有这个键面」本身就是要被听见的事。
/// English: Look a cell up **in the key table** by its face text and return the id, enabled state and
///          category it carries right now. Both the main strips and the label bands are walked. A
///          failed lookup throws — "the table has no such face" is itself something to hear about.
({String id, bool enabled, KeyCategory category}) _cellByFace(String face) {
  for (final row in hiperKeypad.rows) {
    for (final key in row.keys) {
      if (key.base.label == face) {
        return (
          id: key.base.id,
          enabled: key.base.enabled,
          category: key.category,
        );
      }
    }
    for (final label in row.labels) {
      if (label is InlineKey && label.key.base.label == face) {
        return (
          id: label.key.base.id,
          enabled: label.key.base.enabled,
          category: label.key.category,
        );
      }
    }
  }
  throw StateError('键位表里没有「$face」这一格');
}

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

/// 中文：这段表达式转成 TeX 之后是不是**降级成了字面文本**。判据只有一个：产物里有没有
///       `\text{…}`——`TexEmitter` 只在一种情况下写它，即解析器把这一段判成 `ParseErrorNode`
///       （未闭合的调用、认不出的字符都走这里）。真机上 `sqrt(8` 显示成灰色字母就是这个产物。
/// English: Whether this expression **degrades to literal text** once turned into TeX. There is one
///          criterion: whether the output contains `\text{…}` — `TexEmitter` writes that in exactly
///          one situation, when the parser judged the fragment a `ParseErrorNode` (unclosed calls
///          and unrecognised characters both land there). The grey `sqrt(8` seen on a device is
///          this output.
bool _literalTextFragment(String expression) =>
    const TexEmitter()
        .emit(const ExpressionAstParser().parse(expression))
        .contains(r'\text{');

/// 中文：被测主屏。`themeMode` 用来区分「应用自己的明暗」与「平台亮度」——`app.dart` 正是用
///       `themeMode` 把设置里的浅色/深色/跟随系统落地的；`key` 用于强制重建一块全新的主屏
///       （`pumpWidget` 同型组件会复用 State，不换 key 的话上一次输入还留在控制器里）。
/// English: The screen under test. `themeMode` separates the app's own light/dark from the platform's
///          brightness — it is what `app.dart` uses to apply the 浅色/深色/跟随系统 setting; `key`
///          forces a brand-new screen (`pumpWidget` reuses the State for an identical widget type, so
///          without a new key the previous input would still be in the controller).
Widget _testApp({
  bool groupThousands = false,
  ThemeMode? themeMode,
  Key? key,
}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: themeMode == null ? null : ThemeData.dark(),
    themeMode: themeMode ?? ThemeMode.system,
    home: Scaffold(
      body: CalculatorPage(
        key: key,
        db: _FakeDatabase(),
        onOpenSettings: () {},
        settings: AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
          groupThousands: groupThousands,
        ),
      ),
    ),
  );
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
