import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**`MTRX` 第二功能（HiPER 的 `MATRIX_MENU`）打开的矩阵与向量菜单。**
///
///       这个文件钉三件事，一件比一件要紧：
///
///       **一、菜单真的开着，四项各插一条完整调用。** `SHIFT` + 矩阵键打开面板（标题是厂商的命令名
///       `command.name.MATRIX_MENU` = "Matrix and Vector Menu"，手册第 941 行），按一项插一条。
///
///       **二、插的永远是「一条调用 + 本应用自己的矩阵写法」，不是「包住用户此刻的表达式」。**
///       这是本面板唯一的设计取舍，理由是量出来的：引擎对**标量**不报错，它给出一个看起来合理的值
///       （宿主 `qalc` 5.12.0）：`det(5)` = `5`、`inv(5)` = `0.2`、`transpose(5)` = `5`。所以
///       「包住光标前那个值」在这里是**静默错值**的入口。下面那条测试**先把一个 `5` 打在表达式里**，
///       再按 `det`，然后要求屏幕上出现的不是 `det(5)`——这就是那个取舍的可观察形态。
///
///       **三、三个危险的名字不在菜单里，而且在下面「怎么试都到不了引擎」这条断言里。**
///       `rank`/`trace`/`echelon` 是矩阵运算里最容易被想起来的三个名字，而引擎对它们的答复不是那三
///       件事。**两个成因不同，都量过**（宿主 `qalc` 5.12.0 同一串调用；`getFunction` 那一列是同一
///       台机器上的 `Calculator::getFunction`）：
///
///       | 名字 | `getFunction` | 用本应用拼法调它 | 真值 |
///       |---|---|---|---|
///       | `rank` | `Rank`（引擎里真有这个函数） | `[1  2; 3  4]`（矩阵原样回来） | 秩 = `2` |
///       | `trace` | **空** | `[(512.0295827 GGy·m·s·rad)  …]` | 迹 = `5` |
///       | `echelon` | **空** | `[(0.1486441637n B·m⁴)  …]` | 行阶梯形（真名 `rref`） |
///
///       `rank` 那一行是最坏的一种：**名字是真的、函数是真的、形状也对**（进一个矩阵、出一个矩阵），
///       而它不是秩。这类错值屏幕上没有任何线索——所以这三个**不进词表**，于是它们**根本到不了
///       引擎**（`engineExpressionFor` 对表外标识符一律拒绝），面板里那三行是**灰的**、旁边写着为什么。
///
///       **到期日**：下面最后一组钉着上面那张表。哪一天某个名字过得了翻译层（引擎把它答对了，或者
///       本应用自己实现了它），那一组会变红——那时面板里那一行灰格该点亮，而不是让一条过期的禁用
///       悄悄留着（与结果格式菜单里 `Polar coordinates` 那一项同一个做法）。
/// English: **the matrix and vector menu `MTRX`'s second function (HiPER's `MATRIX_MENU`) opens.**
///
///          This file pins three things, each more important than the last:
///
///          **1. The menu really opens and its four entries each insert one complete call.** `SHIFT` plus
///          the matrix key opens the sheet (its title is the vendor's command name
///          `command.name.MATRIX_MENU` = "Matrix and Vector Menu", manual line 941), and one press
///          inserts one call.
///
///          **2. What is inserted is always "a call around this app's own matrix spelling", never "a call
///          around whatever the user has in the expression".** That is this sheet's one design decision
///          and it is measured: the engine does not error on a **scalar**, it answers with a plausible
///          value (host `qalc` 5.12.0): `det(5)` = `5`, `inv(5)` = `0.2`, `transpose(5)` = `5`. So
///          "wrap the value before the caret" is an entrance to a **silent wrong value** here. The test
///          below **types a `5` into the expression first** and then presses `det`, requiring that what
///          appears is not `det(5)` — that is the observable form of the decision.
///
///          **3. The three dangerous names are not in the menu, and the group below makes reaching the
///          engine with them impossible.** `rank`/`trace`/`echelon` are the three names most likely to
///          come to mind for matrix work, and the engine's answers for them are not those three things.
///          **The two causes differ and both are measured** (host `qalc` 5.12.0, the same call string;
///          the `getFunction` column is `Calculator::getFunction` on the same machine) — see the table
///          above. `rank`'s row is the worst kind: **the name is real, the function is real, and the
///          shape is right** (a matrix in, a matrix out), yet it is not the rank. No screen gives that
///          away, so those three **stay out of the vocabulary** and therefore **cannot reach the engine
///          at all** (`engineExpressionFor` refuses every identifier outside the table); the sheet draws
///          them **greyed**, with the reason on their own row.
///
///          **Expiry**: the last group below pins that table. The day one of those names gets through the
///          translation layer (the engine has started answering it correctly, or this app implemented it
///          itself) that group goes red — and that grey row in the sheet should light up rather than
///          letting an expired refusal sit there quietly (the same device as the `Polar coordinates`
///          entry in the result format menu).
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('面板：`MTRX` 的第二功能打开它，四项各插一条完整调用', () {
    testWidgets('SHIFT + 矩阵键打开「Matrix and Vector Menu」；按一项关面板并插一条完整调用',
        (tester) async {
      // 中文：**键面文字在这里，id 不在**：面板里那四项按**键面文字**点（`det`/`transpose`/…），
      //       与 `CPLX`/`STAT` 那一条测试同一种做法——写死 id 的版本会在面板改名字时照样绿。
      // English: **the cell faces are here, the ids are not**: the four entries are tapped by **face**
      //          (`det`/`transpose`/…), the same device as the `CPLX`/`STAT` test — a hardcoded-id
      //          version would stay green while the sheet was re-labelled.
      const cases = <(String, String)>[
        ('det', 'det(matrix(2,2,1,2,3,4))'),
        ('transpose', 'transpose(matrix(2,2,1,2,3,4))'),
        ('inv', 'inv(matrix(2,2,1,2,3,4))'),
        ('identity', 'identity(2)'),
      ];

      for (final (face, expected) in cases) {
        await tester
            .pumpWidget(_testApp(key: ValueKey<String>('matrix-$face')));
        await tester.pumpAndSettle();

        await tester.tap(_keypadKey('SHIFT'));
        await tester.pumpAndSettle();
        await tester.tap(_matrixKey());
        await tester.pumpAndSettle();
        expect(find.text('Matrix and Vector Menu'), findsOneWidget,
            reason: '标题是厂商的命令名（`command.name.MATRIX_MENU`），逐字照抄');
        expect(_displayedExpression(tester), '', reason: '打开面板本身一个字符都不插');

        await tester.tap(find.text(face));
        await tester.pumpAndSettle();
        expect(_displayedExpression(tester), expected,
            reason: '「$face」这一格插的文本不是预期的形状');
        expect(find.text('Matrix and Vector Menu'), findsNothing,
            reason: '按一项就关面板（一次完整的动作，与 `CPLX`/`STAT` 那两颗键同一条）');
      }
    });

    testWidgets('插的是「一条调用 + 那个矩阵」，不是「包住用户此刻的表达式」', (tester) async {
      // 中文：**这是本面板唯一的设计取舍，也是这一组最要紧的一条。**
      //       表达式里先打一个 `5`，再按 `det`：屏幕上出现的**必须**是一条围着 `matrix(2,2,1,2,3,4)`
      //       的调用，**绝不能**是 `det(5)`——引擎对 `det(5)` 的答复是 `5`（宿主实测），那是一个
      //       看起来毫无问题的错答案。同一条理由也是 `Σ`/`Π`/`mean` 那一批的形状。
      // English: **this is the sheet's one design decision and the most important assertion in this
      //          group.** With a `5` already typed into the expression, pressing `det` **must** insert a
      //          call around `matrix(2,2,1,2,3,4)` and **must not** produce `det(5)` — the engine's answer
      //          for `det(5)` is `5` (host measurement), a wrong answer that looks entirely fine. The
      //          same reason gives `Σ`/`Π`/`mean` their shape.
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('matrix-no-wrap')));
      await tester.pumpAndSettle();

      await tester.tap(_keypadKey('5'));
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '5', reason: '起手：表达式里就是一个标量');

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_matrixKey());
      await tester.pumpAndSettle();
      await tester.tap(find.text('det'));
      await tester.pumpAndSettle();

      final expression = _displayedExpression(tester);
      expect(expression, isNot(contains('det(5)')),
          reason: '包住那个 `5` 就会得到 `det(5)`——引擎对它答 `5`，一个看不出错的错答案');
      expect(expression, contains('matrix(2,2,1,2,3,4)'),
          reason: '插出去的文本里永远含一个矩阵：应用不会把一个标量交给 `det`');
    });

    testWidgets('四个菜单 id 主屏都接得住（面板递 id、插入走 `_pressKey`）', (tester) async {
      // 中文：面板只递记号，插入仍走主屏——所以那四个 id 必须在 `dispatchedKeyIds` 里，否则
      //       `keypad_definition_test.dart` 那条「表里每个已启用的 id 主屏都接得住」与这里会一起红。
      // English: the sheet hands over tokens and insertion travels the screen — so those four ids must
      //          be in `dispatchedKeyIds`, or `keypad_definition_test.dart`'s "every enabled id is
      //          caught by the screen" turns red together with this.
      for (final id in <String>[
        'openMatrixMenu',
        'ins:det',
        'ins:transpose',
        'ins:inv',
        'ins:identity',
      ]) {
        expect(CalculatorPage.dispatchedKeyIds, contains(id),
            reason: '`$id` 不在主屏的显式派发集合里');
      }
    });
  });

  group('三行灰格：名字在里面、按不动、理由写在旁边', () {
    testWidgets('`rank`/`trace`/`echelon` 三行在面板里，各自灰着并带一句理由；按下去什么都不发生',
        (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('matrix-refusals')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_matrixKey());
      await tester.pumpAndSettle();

      for (final name in <String>['rank', 'trace', 'echelon']) {
        expect(find.text(name), findsOneWidget,
            reason: '「$name」应当在菜单里（灰着，不是没有）');
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isFalse,
            reason: '「$name」必须点不动：按下去得到的会是一个形状对、意思错的答案，比一句错误更坏');
        expect(tile.onTap, isNull);
        // 中文：理由那一行必须说得出**引擎的答复是什么**，而不只是一句「不支持」——前者是实测，
        //       后者会让人以为引擎算不出来。
        // English: the reason line has to say **what the engine answers**, not merely "unsupported" —
        //          the former is a measurement, the latter reads as "the engine cannot do it".
        final subtitle = tester.widget<Text>(
          find
              .descendant(of: find.byWidget(tile), matching: find.byType(Text))
              .last,
        );
        expect(subtitle.data, isNotEmpty, reason: '「$name」那一行没有理由');

        await tester.tap(find.text(name), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_displayedExpression(tester), '', reason: '灰着的行按下去什么都不插');
        expect(find.text('Matrix and Vector Menu'), findsOneWidget,
            reason: '按灰格连面板都不关（它没做任何事）');
      }
    });
  });

  group('到期日：那三个名字一条也到不了引擎（实测表钉在这里）', () {
    test('三个名字都不在词表里，所以翻译层一律拒绝——引擎永远不会被问到它们', () {
      // 中文：**这是那三行灰格的凭据，而且是可执行的那一半。** 值那一半（`rank(…)` 把矩阵原样还回来、
      //       `trace(…)` 印成 `[(512.0295827 GGy·m·s·rad)  …]`）是宿主 `qalc` 5.12.0 跑出来的，
      //       跑不进 `flutter test`；但**它们到不了引擎**这一条在这里就能钉死，而这一条正是 fail
      //       closed 的形态：不问，就没有「答错但看起来对」的机会。
      // English: **this is the evidence for those three grey rows, and it is the executable half.** The
      //          value half (`rank(…)` hands the matrix straight back, `trace(…)` prints
      //          `[(512.0295827 GGy·m·s·rad)  …]`) came out of host `qalc` 5.12.0 and cannot run inside
      //          `flutter test`; but **they cannot reach the engine** is pinned right here, and that is
      //          exactly the fail-closed form: never ask, and "wrong but plausible" never gets a chance.
      const traps = <String, String>{
        'rank': '引擎里真有这个函数（`getFunction` = `Rank`），而用本应用拼法它把矩阵原样还回来'
            '（`rank(matrix(2,2,1,2,3,4))` = `[1  2; 3  4]`，而秩是 `2`）',
        'trace': '引擎里没有这个名字（`getFunction` 返回空），它把词拆成符号，'
            '印出来带单位（`trace(matrix(2,2,1,2,3,4))` = `[(512.0295827 GGy·m·s·rad)  …]`）',
        'echelon': '引擎里没有这个名字（行阶梯形在引擎里叫 `rref`），它把词拆成符号，'
            '印出来带单位（`echelon(matrix(2,2,1,2,3,4))` = `[(0.1486441637n B·m⁴)  …]`）',
      };
      for (final entry in traps.entries) {
        expect(AppEngineVocabulary.identifiers[entry.key], isNull,
            reason: '词表里不许有 `${entry.key}`：${entry.value}。哪一天它进了表，'
                '说明引擎把那个名字答对了，面板里那一行灰格该点亮');
        expect(
          engineExpressionFor('${entry.key}(matrix(2,2,1,2,3,4))'),
          isA<UntranslatableExpression>(),
          reason: '`${entry.key}(…)` 过得了翻译层就意味着引擎会被问到它——那是错值上屏的入口',
        );
      }
    });

    test('`arg` 是安全的（它本来就在词表里）；`angle` 不是，它也不在表里', () {
      // 中文：**这两个名字长得像，一个是辐角、一个是单位。** `arg(1+i)` = `45`（DEG）/`0.7853981633974483`
      //       （RAD，跟角度模式走，与 `sin` 同一条约定），与上面那三个陷阱不同，它是**对的**，
      //       而且早就在表里（`CPLX` 面板那一批）。`angle(1+i)` 不是辐角：`getFunction('angle')`
      //       返回空，于是那个词被拆成符号——`qalc -t` 给 `(2.718281828 + 2.718281828i) L·ANG`，
      //       按桥的调用序列给 `(271.8281828459045 + 271.8281828459045i) pg*m^5`。
      //       **两次印的字符串不一样，但两次都是带单位的量、都不是角**——所以这条陷阱要按**类**记
      //       （带单位、不是角），不能按某一串字符记。
      // English: **the two names look alike; one is an argument and the other is a unit.** `arg(1+i)` =
      //          `45` (DEG) / `0.7853981633974483` (RAD, following the angle mode, the same convention
      //          `sin` uses) — unlike the three traps above it is **correct**, and it has been in the
      //          table all along (the `CPLX` batch). `angle(1+i)` is not an argument:
      //          `getFunction('angle')` returns nothing, so the word is taken apart into symbols —
      //          `qalc -t` gives `(2.718281828 + 2.718281828i) L·ANG` and the bridge's own call sequence
      //          gives `(271.8281828459045 + 271.8281828459045i) pg*m^5`. **The two strings differ, but
      //          both are unit-carrying quantities and neither is an angle** — so this trap has to be
      //          recorded as a **class** (carries units, is not an angle), never as one particular
      //          string.
      expect(AppEngineVocabulary.identifiers['arg'], isNotNull,
          reason: '`arg` 在词表里，而且它的答复是对的（`arg(1+i)` = 45 DEG）');
      expect(
          AppEngineVocabulary.identifiers['arg']!.engineKnowsThisName, isTrue);
      expect(AppEngineVocabulary.identifiers['arg']!.engineFunction, 'arg');
      expect(AppEngineVocabulary.identifiers['angle'], isNull,
          reason: '`angle` 不是辐角：引擎里没有这个名字，那个词会被拆成符号，印出来是带单位的量');
      expect(engineExpressionFor('angle(1+i)'), isA<UntranslatableExpression>(),
          reason: '`angle(…)` 过得了翻译层就意味着引擎会被问到它——那是错值上屏的入口');
    });

    test('那四个收下的名字：翻译得过去，而应用自己的求值器没有实现它们', () {
      // 中文：**两半都要**。翻译得过去（引擎会被问到）**而且**应用自己的求值器不认识它们
      //       （`canExpress` 因此为假）——后一半是「引擎那份答案留下来」的前提：应用自己答得了的输入，
      //       旧解析器仍然是权威（`namesSomethingOutsideTheAppLanguage`）。少一半都不成。
      // English: **both halves are required.** They translate (so the engine is asked) **and** this app's
      //          own evaluator does not know them (`canExpress` is therefore false) — the second half is
      //          the premise for "the engine's answer stays": for an input this app can answer itself, the
      //          legacy parser is still the authority (`namesSomethingOutsideTheAppLanguage`). Neither
      //          half alone will do.
      for (final name in <String>['det', 'transpose', 'inv', 'identity']) {
        expect(AppEngineVocabulary.identifiers[name], isNotNull,
            reason: '`$name` 应当在词表里，否则菜单里那一格按下去只会得到一条错误');
        expect(AppEngineVocabulary.identifiers[name]!.engineFunction, name,
            reason: '两边同名，所以翻译写出来的就是这个名字本身');
        expect(
          () => ExpressionParser('$name(1)', degreeMode: false).parse(),
          throwsA(isA<FormatException>().having(
              (error) => error.message, 'message', 'Unknown function $name')),
          reason: '应用自己的求值器不许实现 `$name`：实现了它，`canExpress` 就会把引擎那份答案丢掉',
        );
      }
    });
  });
}

String _displayedExpression(WidgetTester tester) => tester
    .widget<MathExpressionView>(find.byType(MathExpressionView))
    .expression;

/// 中文：键面文字所在的**可点**那一层。`SHIFT`/`MTRX` 这些字在屏幕上可能出现两次（横带里的提示与
///       下方主键的键面），所以不能直接 `find.text`——这里从文字往上找它所在的 `InkWell`：
///       提示那一句没有可点的祖先，键面那一句有。
/// English: the **tappable** layer the face text sits on. Faces such as `SHIFT`/`MTRX` can appear twice
///          on screen (the band's hint and the key face below), so a bare `find.text` will not do — this
///          walks up from the text to its `InkWell`: the hint has no tappable ancestor, the key face
///          has one.
Finder _keypadKey(String label) => find
    .ancestor(
      of: find.descendant(
        of: find.byType(CalculatorKeypad),
        matching: find.text(label),
      ),
      matching: find.byType(InkWell),
    )
    .first;

/// 中文：**矩阵键的把手，本轮换了一个。** 它的键面从 `MTRX` 四个字母换成了厂商那张图形
///       （方括号包着 2×2 四个空心方格），`find.text` 于是再也抓不到它——从图形本身
///       （`KeyFaceIconView`）往上找它所在的 `InkWell`，与上面从文字往上找是同一件事。
///       `MTRX` 这个词现在整块键盘上只剩横带那一处不可点的提示，两个测试文件都这么找它。
/// English: **the matrix key's handle, replaced this round.** Its face went from the four letters
///          `MTRX` to the vendor's figure (four hollow squares in a 2×2 grid between brackets), so
///          `find.text` can no longer reach it — this walks up from the figure itself
///          (`KeyFaceIconView`) to its `InkWell`, exactly what the helper above does from text. The
///          word `MTRX` now occurs only in the band's non-tappable hint, and both test files find the
///          key this way.
Finder _matrixKey() => find
    .ancestor(
      of: find.descendant(
        of: find.byType(CalculatorKeypad),
        matching: find.byType(KeyFaceIconView),
      ),
      matching: find.byType(InkWell),
    )
    .first;

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
