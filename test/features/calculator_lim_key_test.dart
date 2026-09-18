import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**`lim`——`x⁻¹` 的 SHIFT 变体（本轮重挂的那一格）**，以及**`hyp` 为什么这一轮没有跟着挂**。
///
///       前四组守 `lim`：
///
///       1. **键位表里变体真的在**，而且 `x⁻¹` 的基准动作（`ins:^-1` / 键面文字 / 分类 / 启用态）
///          一格未动；
///       2. **横带那一格是不可点的 `ShiftLabel('lim')`** —— 同一个动作不能有两个 id 入口
///          （`键的 id 全局唯一`那条不变式，见 `keypad_definition_test.dart`）。这一改让第 4 行横带
///          六格**全部**成了提示，而其中五格本来就已经是 `shift` 变体；
///       3. **按下去的行为**：SHIFT + `x⁻¹` 插 `limit(sin(x)/x,0,x)`；不按 SHIFT 时 `x⁻¹` 仍是 `^-1`；
///       4. **它插的那条调用真的到得了引擎**：排版印成 `\lim_{x\to 0}…`（不是 `\text{…}` 降级），
///          翻译层把它原样透传成 `limit(((sin(x))/(x)),0,x)`（词表里 `limit` 是
///          `engineKnowsThisName: true`），而应用自己的旧解析器读不了它、抛 `FormatException`——
///          所以引擎缺席时**报错而不是猜一个值**。
///
///       最后一组守 **`hyp`**：它是这一类偏差里**唯一没有被改**的一格，而这是**有据的留手**，不是漏看。
///       HiPER 那一侧的证据齐（`hyp` 量到 `π` 正上方；本项目规格书第 17 行写着 `π`→SHIFT→`hyp`，
///       计划书第 95 行写着「HiPER 把 `hyp` 放在 `π` 的 SHIFT 位上」），所以它是**立项时就写下的刻意
///       偏离**，而不是一次没被发现的偏差。不改的实测理由是本应用修饰态**单值**
///       （`KeypadModifier { none, shift, hyp }`）：挂上去之后同一个手势能进 hyp 却退不出来
///       （实测 `SHIFT,π` 进 hyp，`SHIFT,π,SHIFT,π` **仍在 hyp**），而计划书对它的要求恰是
///       「需再点一次退出」；且横带那颗键一撤，`_isActiveModifier` 就再没有键可亮。两条都要改
///       `CalculatorPage` 的修饰态状态机，也就是改一颗**已经在工作**的键。
///
///       **这一组断言是那条拒绝的「到期日」**：修饰态模型哪一天能表达嵌套，它们就会变红，而不是留下
///       一条过期的拒绝。（与 `∠` 那条把「应用解析器读不了它」变成断言的做法同型。）
/// English: **`lim` — the SHIFT variant of `x⁻¹` (this round's re-mount)**, plus **why `hyp` does not
///          follow it this round**.
///
///          The first four groups guard `lim`:
///
///          1. **the variant really is in the table**, and `x⁻¹`'s base action (`ins:^-1` / face label /
///             category / enabled state) has not moved a cell;
///          2. **that band cell is a non-tappable `ShiftLabel('lim')`** — one action must not have two
///             id entrances (the id-uniqueness invariant in `keypad_definition_test.dart`). The change
///             makes all six cells of row 4's band hints, five of which already were `shift` variants;
///          3. **what a press does**: SHIFT + `x⁻¹` inserts `limit(sin(x)/x,0,x)`; without SHIFT `x⁻¹`
///             is still `^-1`;
///          4. **the call it inserts really reaches the engine**: it typesets as `\lim_{x\to 0}…`
///             (not a `\text{…}` degradation), the translator passes it through verbatim as
///             `limit(((sin(x))/(x)),0,x)` (the vocabulary has `limit` as `engineKnowsThisName: true`),
///             and this app's own legacy parser cannot read it — it throws `FormatException` — so with
///             no engine answer the result is **an error rather than a guessed value**.
///
///          The last group guards **`hyp`**: the one cell of this class that is **not** moved, and that
///          is **a grounded refusal, not an oversight**. The HiPER side is well evidenced (`hyp`
///          measures directly above `π`; this project's spec writes `π`→SHIFT→`hyp` on line 17 and its
///          plan says on line 95 that HiPER puts `hyp` at `π`'s SHIFT position), so it is a **deviation
///          written down when the keypad was designed** rather than an undiscovered one. The measured
///          reason it stays is that this app's modifier state is **single-valued**
///          (`KeypadModifier { none, shift, hyp }`): with `hyp` on `π`'s `shift` the same gesture can
///          enter hyp but not leave it (measured: `SHIFT,π` enters hyp, `SHIFT,π,SHIFT,π` **stays in
///          hyp**), while the plan requires exactly that ("left by pressing it once more"); and once
///          the band key is gone, `_isActiveModifier` has no key left to light. Both fixes mean
///          changing `CalculatorPage`'s modifier state machine — changing a key that **already works**.
///
///          **That group is the refusal's expiry date**: a modifier model that gains nesting turns it
///          red instead of leaving a stale refusal behind (the shape the `∠` refusal already took).
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('`lim`——`x⁻¹` 的 SHIFT 变体', () {
    test('键位表：`x⁻¹` 多出一个 SHIFT 变体 `lim`，基准那一格逐字未动', () {
      final located = _locateBaseId('ins:^-1');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'x⁻¹', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这颗键的意义就在这个变体上：没有它，`lim` 只是横带里一句没兑现的提示');
      expect(shift!.id, 'ins:limit');
      expect(shift.label, 'lim', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isTrue,
          reason: '`lim` 插的 `limit(sin(x)/x,0,x)` 引擎认（宿主 5.12.0 实测 RAD 下 = 1），没有理由禁用');

      // 中文：横带里那一格必须是**纯提示**。若它变回第二个按钮，同一个动作就有两个 id 入口，
      //       `键的 id 全局唯一` 那条不变式立刻红。
      // English: the band cell above must be a **plain hint**. Turn it back into a second button and
      //          one action has two id entrances — the id-uniqueness invariant goes red at once.
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'lim');
    });

    test('键位表：第 4 行横带六格全是提示——另外五格本来就已经是 `shift` 变体', () {
      final located = _locateBaseId('ins:^-1');
      final labels = located.row.labels;

      expect(labels.length, 6);
      for (var i = 0; i < labels.length; i++) {
        expect(labels[i], isA<ShiftLabel>(),
            reason: '第 4 行横带第 ${i + 1} 格应当是不可点的提示');
      }
      expect(labels.map((l) => (l! as ShiftLabel).text).toList(),
          <String>['lim', 'x³', '∛x', 'ˣ√y', '10ˣ', 'eˣ'],
          reason: '六格的文字与 HiPER 截图逐格一致；`lim` 只是从实体键退回提示，文字一个字没变');

      // 中文：同一条横带的其它五格在本应用里早就挂在下方主键的 `shift` 上——「这条横带是 SHIFT 带」
      //       不是外来的推断，本应用自己已经这么认了五格，`lim` 是第六格。
      // English: the other five cells of this same band have long hung on the `shift` of the key
      //          below — "this band is the SHIFT band" is not an outside inference; this app already
      //          agrees about five of the six, and `lim` was the sixth.
      const belowToVariant = <String, String>{
        'x³': 'ins:^3',
        '∛x': 'cbrt',
        'ˣ√y': 'root',
        '10ˣ': 'ins:10^',
        'eˣ': 'ins:e^',
      };
      for (final entry in belowToVariant.entries) {
        final index = labels.indexWhere((l) => (l! as ShiftLabel).text == entry.key);
        expect(index, isNot(-1));
        expect(located.row.keys[index].shift?.id, entry.value,
            reason: '横带第 ${index + 1} 格的提示 ${entry.key} 是下方主键的 SHIFT 变体');
      }
    });

    testWidgets('SHIFT + `x⁻¹` 插 `limit(sin(x)/x,0,x)`；不按 SHIFT 时 `x⁻¹` 插的仍是 `^-1`',
        (tester) async {
      await tester.pumpWidget(_testApp(key: const ValueKey<String>('plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('x⁻¹').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '^-1',
          reason: '这一次是重挂：`x⁻¹` 的基准动作必须一个字节都没变');

      await tester.pumpWidget(_testApp(key: const ValueKey<String>('shifted')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIFT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('x⁻¹').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'limit(sin(x)/x,0,x)',
          reason: 'SHIFT + `x⁻¹` 插的是横带那一格上一轮插的**同一条文本**——'
              '本轮换的是它挂在哪儿，不是它做什么');
    });

    test('`limit(sin(x)/x,0,x)` 排得出来，翻译层原样透传，应用自己的解析器读不了它', () {
      const expression = 'limit(sin(x)/x,0,x)';
      final node = const ExpressionAstParser().parse(expression);
      final tex = const TexEmitter().emit(node);

      expect(tex, r'\lim_{x\to 0}\frac{\sin\left(x\right)}{x}',
          reason: '横带那一格写着 `lim`，表达式行就得真的印出一个极限——印不出来它就是一句空话');
      expect(tex.contains(r'\text{'), isFalse,
          reason: '`\\text{…}` 只在解析器把这一段判成 ParseErrorNode 时出现——那是可见的降级');
      expect(MathExpressionView.typesetsTex(tex), isTrue,
          reason: '排版渲染器不认的话，这一格就没有兑现');

      // 中文：**这条调用真的到得了引擎。**词表里 `limit` 是 `engineKnowsThisName: true`，
      //       翻译层因此把它原样写出去（只是把实参按应用的优先级补上括号）。
      // English: **the call really reaches the engine.** The vocabulary marks `limit` as
      //          `engineKnowsThisName: true`, so the translator writes it out verbatim (only adding
      //          brackets around arguments per this app's precedence).
      final limitEntry = AppEngineVocabulary.identifiers['limit'];
      expect(limitEntry, isNotNull, reason: '词表里没有 `limit` 的话，引擎那一份答复根本不权威');
      expect(limitEntry!.engineKnowsThisName, isTrue);
      expect(limitEntry.engineFunction, 'limit');

      final translated = engineExpressionFor(expression);
      expect(translated, isA<TranslatedExpression>(),
          reason: '翻译不了就只会回落旧解析器——而旧解析器读不了 `limit`（见下一条断言）');
      expect((translated as TranslatedExpression).text, 'limit(((sin(x))/(x)),0,x)');

      // 中文：**回落路径给不出值**，所以引擎缺席时是**报错**而不是猜一个值。宿主 libqalculate 5.12.0
      //       上 `limit(sin(x)/x,0,x)` = `1`（RAD）/ `0.01745329252`（DEG，π/180，度制下正确）——
      //       引擎那一半跑不到 `flutter test` 里（假引擎），所以这里只钉应用这一半。
      // English: **the fallback yields no value**, so with no engine answer the outcome is an
      //          **error**, never a guess. On host libqalculate 5.12.0 `limit(sin(x)/x,0,x)` = `1`
      //          (RAD) / `0.01745329252` (DEG, i.e. π/180, correct in degree mode) — the engine half
      //          cannot run under `flutter test` (fake engine), so only this half is asserted.
      expect(
        () => ExpressionParser(expression, degreeMode: true).parse(),
        throwsFormatException,
        reason: '旧解析器把 `x` 当成一个缺左括号的函数名——它给不出这个极限，只会抛',
      );
    });
  });

  group('`hyp`——这一类偏差里唯一没有改的一格（有据的留手）', () {
    test('`π` 仍没有 SHIFT 变体，横带那一格仍是可点的 `hyp` 修饰键', () {
      final located = _locateBaseId('ins:pi');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'π');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);
      expect(key.shift, isNull,
          reason: '**这一条是那条拒绝的可测形式。** HiPER 上 `hyp` 是 `π` 的第二功能（本项目规格书'
              '第 17 行：`π`→SHIFT→`hyp`），而这里没有挂上去——理由是修饰态单值，挂上去就退不出来'
              '（见本文件最后一组）。哪一天模型支持嵌套，这里应当先变红，再被改成非 null');

      final above = located.row.labels[located.index];
      expect(above, isA<InlineKey>(),
          reason: '本应用把 `hyp` 放在同一格，但做成可直接点按的修饰键——立项时写下的刻意偏离');
      final bandKey = (above! as InlineKey).key;
      expect(bandKey.base.id, 'hyp');
      expect(bandKey.base.label, 'hyp');
      expect(bandKey.category, KeyCategory.modifier);
      expect(bandKey.base.enabled, isTrue);
    });

    test('第 3 行横带里只剩 `hyp` 一个实体键——另外五格都已经是提示', () {
      final located = _locateBaseId('ins:pi');
      final labels = located.row.labels;

      expect(labels.whereType<InlineKey>().length, 1);
      expect(labels.first, isA<InlineKey>());
      expect(labels.skip(1).every((l) => l is ShiftLabel), isTrue);
      expect(labels.skip(1).map((l) => (l! as ShiftLabel).text).toList(),
          <String>['sin⁻¹', 'cos⁻¹', 'tan⁻¹', '∠', 'logₓy']);
    });

    testWidgets('修饰态是单值的：`SHIFT` 会顶掉 `hyp`——嵌套因此没有退出手势', (tester) async {
      await tester.pumpWidget(_testApp(key: const ValueKey<String>('hyp-probe')));
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      // 中文：先确认 `hyp` 真的锁得上：锁上之后 `sin` 走的是 `sinh`。
      await tap('hyp');
      await tap('sin');
      expect(_displayedExpression(tester), 'sinh()',
          reason: '`hyp` 是持续态修饰键，这一按必须走它的变体');

      // 中文：**这就是那条拒绝的机制。** 从 hyp 态点 `SHIFT`，修饰态被换成 shift——「刚才在 hyp」
      //       这件事**丢掉了**，`sin` 于是走 `sin⁻¹` 而不是 `sinh`。
      //       把 `hyp` 挂到 `π` 的 `shift` 上时，派发 `hyp` 的唯一入口就是「修饰态为 shift 时按 π」，
      //       而进了 hyp 态之后再也回不到 shift 态——同一个手势（SHIFT,π,SHIFT,π）**一直停在 hyp**
      //       （本轮实测：`SHIFT,π` → `sinh()`；`SHIFT,π,SHIFT,π` → `sinh()`；`SHIFT,π,SHIFT,SHIFT` → `sin()`）。
      //       计划书对 `hyp` 的要求恰是「它是持续态，**需再点一次退出**」——那条要求因此无法满足。
      // English: **This is the mechanism behind the refusal.** From the hyp state a `SHIFT` tap swaps
      //          the modifier to shift — the fact that hyp *was* on is **discarded**, so `sin` runs
      //          `sin⁻¹` rather than `sinh`. With `hyp` mounted on `π`'s `shift`, the only entrance that
      //          dispatches `hyp` is "press π while the modifier is shift", and the hyp state cannot get
      //          back to shift — the same gesture (`SHIFT,π,SHIFT,π`) **stays in hyp** (measured this
      //          round: `SHIFT,π` → `sinh(`, `SHIFT,π,SHIFT,π` → `sinh(`, `SHIFT,π,SHIFT,SHIFT` →
      //          `sin(`). The plan requires `hyp` to be exactly a persistent state **left by pressing
      //          it once more**, which therefore cannot hold.
      await tap('SHIFT');
      await tap('sin');
      expect(_displayedExpression(tester), 'sinh(asin())',
          reason: '第一个 `sinh(` 是 hyp 态按下的，第二个 `asin(` 是 SHIFT 顶掉 hyp 之后按下的——'
              '同一个 `sin` 键两次走出两个不同的变体，说明修饰态被换掉了。若哪一天修饰态能叠起来'
              '（SHIFT 保留 hyp），第二个会仍是 `sinh(`，这里就成了 `sinh(sinh())`——那时本条拒绝'
              '就过期了，`hyp` 该挂到 `π` 的 SHIFT 上');
    });
  });
}

/// 中文：在键位表里按**基准 id** 找那一格，返回它所在的行与列。只在主键条里找——本轮的重挂对象是
///       主键（横带那一格已经是提示了）。找不到直接抛错：「表里没有这个 id」本身就是要被听见的事。
/// English: Find a cell **by its base id** and return its row and column. Only the main strips are
///          walked — this round's re-mount target is a main key (the band cell is a hint now). A
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
