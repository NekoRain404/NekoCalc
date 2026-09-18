import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**`d/dx`——`∫dx` 那颗键的 SHIFT 变体（本轮接上的那颗）。**
///
///       这一组守的是四件事，缺一件这颗键就是坏的：
///       1. **键位表里真的有这个变体**，而且基准动作（`ins:integrate` / `∫dx` / 启用态 / 分类）
///          一格没动——按键的类型系统里，SHIFT 变体是加在**同一颗键**上的第二个变体；
///       2. **按下去插的是 `diff(x^2,x)`**：SHIFT + `∫dx` 走 `CalculatorKeypad._resolve` 解析出的
///          `ins:diff`，主屏把它变成这条文本。不按 SHIFT 时仍是 `integrate(x^2,0,1,x)`，逐字节不变；
///       3. **插进去的是一条立刻排得出来的调用**，不是 `\text{…}` 那样的字面文本降级；
///       4. **它是两槽，不是四槽**——四槽那一形（`diff(x^2,x,1,2)`）有一个静默的错值坑：删掉 `,1`
///          就成了 `diff(x^2,x,2)`，引擎把它读成**二阶导数**。这一条把那个决定钉在结构上。
///
///       引擎那一半（`diff` 会答、答得出符号结果、符号结果上得了屏）在 `flutter test` 里跑不到：
///       求值发生在打包进 AAR 的 libqalculate 里，它只有 arm64-v8a 的 `.so`。那一半的证据是真机
///       截图，见 `.superpowers/backup/ddx-key-report.md`。
/// English: **`d/dx` — the SHIFT variant of the `∫dx` key (the key wired this round).**
///
///          This group guards four things; with any one missing the key is broken:
///          1. **the variant really is in the key table**, and the base action (`ins:integrate` /
///             `∫dx` / enabled state / category) has not moved by a single cell — in the key type, a
///             SHIFT variant is a second variant on **the same key**;
///          2. **pressing it inserts `diff(x^2,x)`**: SHIFT + `∫dx` resolves (through
///             `CalculatorKeypad._resolve`) to `ins:diff`, and the screen turns that into this text.
///             Without SHIFT the key still inserts `integrate(x^2,0,1,x)`, byte for byte;
///          3. **what lands in the expression is a call that typesets**, not a `\text{…}` literal
///             fallback;
///          4. **it has two slots, not four** — the four-slot shape (`diff(x^2,x,1,2)`) carries a
///             silent wrong-value trap: delete `,1` and it becomes `diff(x^2,x,2)`, which the engine
///             reads as the **second derivative**. This pins that decision structurally.
///
///          The engine half (that `diff` answers, that the answer is symbolic, and that a symbolic
///          answer reaches the screen) cannot run under `flutter test`: evaluation happens inside the
///          libqalculate AAR, which ships arm64-v8a `.so` files only. That half's evidence is the
///          device screenshots in `.superpowers/backup/ddx-key-report.md`.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('`d/dx`——`∫dx` 的 SHIFT 变体', () {
    test('键位表：`∫dx` 多出一个 SHIFT 变体，基准那一格逐字未动', () {
      final located = _locateBaseId('ins:integrate');
      final key = located.row.keys[located.index];

      expect(key.base.label, '∫dx', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这颗键的全部意义就在这个变体上：没有它，`d/dx` 只是横带里一句没兑现的提示');
      expect(shift!.id, 'ins:diff');
      expect(shift.label, 'd/dx', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isTrue);

      // 中文：横带里那一格仍是**纯提示**——同一条 `d/dx` 有两处，一处不可点、一处是真动作。
      //       横带格若变成第二个按钮，同一个动作就会有两个 id 入口（键 id 全局唯一那条不变式）。
      // English: the band cell above stays a **plain hint** — the same `d/dx` appears twice, once
      //          as a non-tappable hint and once as the real variant. Turning the band cell into a
      //          second button would give one action two id entrances (the global id-uniqueness
      //          invariant).
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'd/dx');
    });

    testWidgets('SHIFT 之后按 `∫dx` 插 `diff(x^2,x)`；不按 SHIFT 时插的仍是积分',
        (tester) async {
      await tester.pumpWidget(_testApp(key: const ValueKey<String>('plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('∫dx').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'integrate(x^2,0,1,x)',
          reason: '这一次是加法：`∫dx` 的基准动作必须一个字节都没变');

      await tester.pumpWidget(_testApp(key: const ValueKey<String>('shifted')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIFT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('∫dx').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'diff(x^2,x)',
          reason: 'SHIFT + `∫dx` 插的是引擎 `diff` 的调用，两个槽，顺序是引擎自己的');
    });

    test('插进去的那一行排成 `d/dx`，不是字面文本', () {
      const expression = 'diff(x^2,x)';
      final tex = const TexEmitter()
          .emit(const ExpressionAstParser().parse(expression));

      expect(tex, r'\frac{\mathrm{d}}{\mathrm{d}x}\left(x^{2}\right)');
      expect(tex.contains(r'\text{'), isFalse,
          reason: '`\\text{…}` 只在解析器把这一段判成 ParseErrorNode 时出现——那是可见的降级');
      expect(MathExpressionView.typesetsTex(tex), isTrue,
          reason: '排版渲染器不认的话，键面上那个 `d/dx` 就成了一句空话');
    });

    test('插入物是两个实参：四槽那一形删掉 `,1` 会静默变成二阶导数', () {
      final node = const ExpressionAstParser().parse('diff(x^2,x)');
      expect(node, isA<FunctionNode>());
      final call = node as FunctionNode;
      expect(call.name, 'diff', reason: '插进去的必须是引擎那个 `diff`，不是别的名字');
      expect(call.args, hasLength(2),
          reason: '两槽是选定的：`diff(x^2,x,1,2)`（四槽）删掉 `,1` 就成了 `diff(x^2,x,2)`，'
              '引擎把它读成二阶导数——宿主实测 `= 2`，而「在点 2 的导数」是 `= 4`。'
              '两个数都像样、含义不同，屏幕上分不出哪个是哪个。'
              '两槽删掉 `,x` 得到 `diff(x^2)`，引擎自己找变量，宿主实测仍是 `= 2x`。');
    });

    test('翻译层不重排 `diff` 的实参，也不换名字', () {
      final translated = engineExpressionFor('diff(x^2,x)');
      expect(translated, isA<TranslatedExpression>(),
          reason: '翻译不了就走旧解析器，而旧解析器的名字表里没有 `diff`（它会报错）');
      expect((translated as TranslatedExpression).text, 'diff(((x)^(2)),x)',
          reason: '名字仍是 `diff`、第一个实参仍是表达式、第二个仍是求导变量——'
              '重排会让词表里 `diff` 那条 `engineKnowsThisName: true` 变成假话');
    });

    test('词表放行：`diff` 是引擎认识的名字', () {
      expect(AppEngineVocabulary.canRead('diff(x^2,x)'), isTrue,
          reason: '`canRead` 为假的话，引擎那份符号答案一律不算，屏幕上只会是一条错误');
    });
  });
}

/// 中文：在键位表里按**基准 id** 找那一格，返回它所在的行与列。主键条与横带里的实体键都走，
///       因为这两处的键都可能在别的用例里被问起。找不到直接抛错——「表里没有这个 id」本身
///       就是要被听见的事。
/// English: Find a cell **by its base id** and return its row and column. Both the main strips and
///          the band's real keys are walked, since other cases may ask about either. A failed lookup
///          throws — "the table has no such id" is itself something to hear about.
({KeypadRow row, int index}) _locateBaseId(String baseId) {
  for (final row in hiperKeypad.rows) {
    for (var index = 0; index < row.keys.length; index++) {
      if (row.keys[index].base.id == baseId) return (row: row, index: index);
    }
  }
  throw StateError('键位表里没有基准 id 为「$baseId」的主键');
}

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

/// 中文：被测主屏。`key` 用于强制重建一块全新的主屏（`pumpWidget` 同型组件会复用 State，
///       不换 key 的话上一次输入还留在控制器里）。
/// English: The screen under test. `key` forces a brand-new screen (`pumpWidget` reuses the State for
///          an identical widget type, so without a new key the previous input would still be in the
///          controller).
Widget _testApp({Key? key}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CalculatorPage(
        key: key,
        db: _FakeDatabase(),
        onOpenSettings: () {},
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
          groupThousands: false,
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
