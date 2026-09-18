import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**`logₓy` 与 `∠`——`e` 与 `i` 的 SHIFT 变体（本轮重挂的两格）。**
///
///       这两格上一轮是横带里可点的 `InlineKey`，与 `FSE` 完全同型；本轮按同一条通则退回纯提示，
///       动作挂到下方那颗键的 `shift` 上。本组守的是五件事：
///
///       1. **键位表里变体真的在**，而且两颗键的基准动作（`ins:e` / `ins:i` / 键面文字 / 分类 /
///          启用态）一格未动；
///       2. **横带那两格是不可点的 `ShiftLabel`** —— 同一个动作不能有两个 id 入口
///          （`键的 id 全局唯一`那条不变式，见 `keypad_definition_test.dart`）；
///       3. **按下去的行为**：SHIFT + `e` 插 `log(8,2)`；不按 SHIFT 时 `e` 仍是 `e`。
///       4. **`∠` 是 fail closed，不是没做**：SHIFT + `i` **什么都不插**——`i` 的 SHIFT 变体是
///          禁用态，键位表里挂着它（位置与 HiPER 一致），但本应用给不出这个动作的值，所以按下去
///          没有反应，而不是插一段读不懂的文本；不按 SHIFT 时 `i` 仍是 `i`；
///       5. **那条拒绝是有据的**：`∠` 挂禁用的理由是「应用自己的两个解析器都读不了它」。
///          这一条把那句话变成可失败的断言——哪一天有人教会了解析器读 `∠`，这里会红，而不是让
///          一个过期的禁用悄悄留着。
///
///       **引擎那一半跑不到**（`flutter test` 用的是假引擎；求值发生在只有 arm64-v8a 的
///       libqalculate AAR 里）。所以「引擎读得了 `∠`」这一句在本文件里**只是记录**，不是断言：
///       宿主 libqalculate 5.12.0 实测 `5∠45` = `3.535533906 + 3.535533906i`、`1∠90` = `i`、
///       `2∠0` = `2`，而 `log(8,2)` = `3`。真机证据见
///       `.superpowers/backup/logxy-angle-report.md`。
/// English: **`logₓy` and `∠` — the SHIFT variants of `e` and `i` (the two cells re-mounted this
///          round).**
///
///          Both were tappable `InlineKey`s in the band last round, exactly the shape `FSE` had; this
///          round they go back to plain hints per the same rule and their actions move onto the
///          `shift` of the key below. This group guards five things:
///
///          1. **the variants really are in the table**, and both keys' base actions (`ins:e` / `ins:i`
///             / face label / category / enabled state) have not moved a cell;
///          2. **those two band cells are non-tappable `ShiftLabel`s** — one action must not have two
///             id entrances (the `key ids are globally unique` invariant, see
///             `keypad_definition_test.dart`);
///          3. **what a press does**: SHIFT + `e` inserts `log(8,2)`; without SHIFT `e` is still `e`;
///          4. **`∠` fails closed rather than being skipped**: SHIFT + `i` inserts **nothing** — `i`'s
///             SHIFT variant is the disabled one, and it is in the table (so the position matches
///             HiPER) while this app cannot produce a value for that action, so the press does nothing
///             instead of inserting text nothing can read. Without SHIFT `i` is still `i`;
///          5. **that refusal is grounded**: the reason `∠` is disabled is "this app's own two parsers
///             cannot read it". This turns that sentence into an assertion that can fail — the day
///             someone teaches a parser to read `∠` it goes red, instead of leaving a stale refusal
///             behind.
///
///          **The engine half cannot run here** (`flutter test` uses a fake engine; evaluation happens
///          inside the arm64-v8a-only libqalculate AAR). So "the engine can read `∠`" is **recorded,
///          not asserted**, in this file: host libqalculate 5.12.0 measures `5∠45` =
///          `3.535533906 + 3.535533906i`, `1∠90` = `i`, `2∠0` = `2`, and `log(8,2)` = `3`. Device
///          evidence is in `.superpowers/backup/logxy-angle-report.md`.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('`logₓy` 与 `∠`——`e` 与 `i` 的 SHIFT 变体', () {
    test('键位表：`e` 多出一个 SHIFT 变体 `logₓy`，基准那一格逐字未动', () {
      final located = _locateBaseId('ins:e');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'e', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这颗键的意义就在这个变体上：没有它，`logₓy` 只是横带里一句没兑现的提示');
      expect(shift!.id, 'ins:logxy');
      expect(shift.label, 'logₓy', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isTrue,
          reason: '`logₓy` 插的 `log(8,2)` 两个解析器都读得了，没有理由禁用');

      // 中文：横带里那一格必须是**纯提示**。若它变回第二个按钮，同一个动作就有两个 id 入口，
      //       `键的 id 全局唯一` 那条不变式立刻红。
      // English: the band cell above must be a **plain hint**. Turn it back into a second button and
      //          one action has two id entrances — the id-uniqueness invariant goes red at once.
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'logₓy');
    });

    test('键位表：`i` 的 SHIFT 是 `∠`，且它仍是禁用的；基准那一格逐字未动', () {
      final located = _locateBaseId('ins:i');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'i', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue,
          reason: '`i` 本身是可用的：复数一直开着，`i` 插的就是引擎认识的虚数单位');
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: 'HiPER 上 `∠` 是 `i` 的第二功能（厂商 FAQ：press SHIFT and the i key to insert '
              'the angle symbol ∠）——位置照挂，动作本身仍是禁用');
      expect(shift!.id, 'dis:angle');
      expect(shift.label, '∠');
      expect(shift.enabled, isFalse,
          reason: '**这是拒绝，不是没做**：引擎读得了 `∠`，应用的两个解析器都读不了它——'
              '插进去只会得到一条错误和一个 `\\text{…}` 字面降级，永远得不到值。'
              '屏幕上出现错值比报错更糟，所以这一格保持禁用');

      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, '∠');
    });

    testWidgets('SHIFT + `e` 插 `log(8,2)`；不按 SHIFT 时 `e` 插的仍是 `e`', (tester) async {
      await tester.pumpWidget(_testApp(key: const ValueKey<String>('plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('e').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'e',
          reason: '这一次是加法：`e` 的基准动作必须一个字节都没变');

      await tester.pumpWidget(_testApp(key: const ValueKey<String>('shifted')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIFT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('e').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'log(8,2)',
          reason: 'SHIFT + `e` 插的是 `logₓy` 那一格上一轮插的**同一条文本**——'
              '本轮换的是它挂在哪儿，不是它做什么');
    });

    testWidgets('SHIFT + `i` 什么都不插（禁用变体不响应）；不按 SHIFT 时 `i` 插的仍是 `i`',
        (tester) async {
      await tester.pumpWidget(_testApp(key: const ValueKey<String>('plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('i').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'i',
          reason: '`i` 的基准动作必须一个字节都没变——复数一直开着，它插的是引擎认识的虚数单位');

      await tester.pumpWidget(_testApp(key: const ValueKey<String>('shifted')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIFT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('i').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '',
          reason: '**fail closed**：`i` 的 SHIFT 是禁用的 `∠`，禁用键不挂 `onTap`——'
              '按下去一个字符都不该进表达式。若这里出现了 `∠`，那就是把一段两个解析器都读不懂的'
              '文本放上了表达式行');
    });

    test('插进去的 `log(8,2)` 排得出来，应用自己读成 3——底是第二个实参', () {
      const expression = 'log(8,2)';
      final tex = const TexEmitter()
          .emit(const ExpressionAstParser().parse(expression));

      expect(tex, r'\log_{2}\left(8\right)',
          reason: '下标印的是**第二个**实参，与应用的取值一致；两者不一致就是屏幕上印着一个底、'
              '算着另一个底');
      expect(tex.contains(r'\text{'), isFalse,
          reason: '`\\text{…}` 只在解析器把这一段判成 ParseErrorNode 时出现——那是可见的降级');
      expect(MathExpressionView.typesetsTex(tex), isTrue,
          reason: '排版渲染器不认的话，键面上那个 `logₓy` 就成了一句空话');
      expect(ExpressionParser(expression, degreeMode: true).parse(), 3.0,
          reason: '宿主 libqalculate 5.12.0 实测 `log(8,2)` = `3`、`log(2,8)` = `0.3333333333`：'
              '引擎与应用两边都把**第二个实参**当底');
    });

    test('`∠` 的禁用是拒绝而非未做：应用的两个解析器都读不了它', () {
      final node = const ExpressionAstParser().parse('5∠45');
      expect(node, isA<ParseErrorNode>(),
          reason: '语法树读不了 `∠`，所以翻译器拿不到可以翻译的树（它只吃 AST）');
      expect(
        const TexEmitter().emit(node),
        r'\text{5∠45}',
        reason: '读不了就降级成字面文本——那是本项目认定的可见降级，不是一条可以上屏的表达式',
      );
      expect(
        () => ExpressionParser('5∠45', degreeMode: true).parse(),
        throwsFormatException,
        reason: '旧解析器同样读不了，所以引擎缺席时的回落路径也给不出值——'
            '`∠` 因此是 fail closed，而不是「等引擎接上就可用」',
      );
    });
  });
}

/// 中文：在键位表里按**基准 id** 找那一格，返回它所在的行与列。只在主键条里找——本轮的两次重挂
///       都是主键（横带那两格已经是提示了）。找不到直接抛错：「表里没有这个 id」本身就是要被听见的事。
/// English: Find a cell **by its base id** and return its row and column. Only the main strips are
///          walked — this round's two re-mounts are both main keys (the band cells are hints now). A
///          failed lookup throws: "the table has no such id" is itself something to hear about.
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
