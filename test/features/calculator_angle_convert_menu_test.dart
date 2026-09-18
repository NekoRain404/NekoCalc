import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**`►DRG` 第二功能（HiPER 的 `TO_DRG`「换算角度单位」）打开的面板，以及它剪开的那扇窄门。**
///
///       这个文件钉四件事，一件比一件要紧：
///
///       **一、面板就是手册第 678 行那句话**：选**源单位**与**目标单位**，换算**当前显示的那个数**。
///       所以有两行、且**源单位不替用户猜**——没选源之前目标那一行是灰的（`1.5708` 既可能是弧度也
///       可能是度，猜错就是一次静默错值）。
///
///       **二、换出来的是「整条表达式」**：`<值> <源单位> to <目标单位>`。下面那条测试先把 `2+3`
///       打在表达式里（结果行上是 `5`），再换算，要求屏幕上出现的是 `5 deg to rad`——**不是**
///       `2+3 deg to rad`（`to` 比 `+` 松，那一串换算的是 `3`：屏幕上看得出来，但已经不是用户要的
///       那件事了）。
///
///       **三、翻译层那扇门只有一个形状，而这一条是本轮最要紧的证明**：`deg` 只在
///       `<值> <角度单位> to <角度单位>` 的两侧是单位，**别处一个读法都没多**——
///       - `deg(1.5707963268)` 仍旧**翻译不了**（仍旧由旧解析器答 90），
///       - `5 deg`、`deg`、`deg + 1` 仍旧翻译不了，
///       - `rad(90)` 同上（应用的 `rad` 是「度换弧度」，引擎那边的 `rad` 是单位），
///       - `90°` 也一个字没变（归一化仍旧把它写成 `rad(90)`），
///       - `isAppUnit('deg')` 仍然是假、`variableUnknownToEngine('deg')` 仍然非空。
///       **这五条合起来就是「放行一处，不等于拆墙」的可执行形式**：本轮动的只有翻译层里那一条
///       按形状判的路（`engine_expression.dart` 的 `_angleConversion`），两张表（`kAppUnits` 与
///       词表）一格未动。
///
///       **四、被拒绝的拼法写着实测值**：`grad` 不是百分度（`1 grad` = `1357.168026 s·rad`，
///       `90 grad to deg` = `81 d·°`——值对、单位坏），面板里它是一行灰的；干净的拼法是 `gon`。
///       **到期日**：哪一天引擎把 `grad` 答对了，这一组会变红，那时那一行该点亮。
/// English: **the sheet `►DRG`'s second function (HiPER's `TO_DRG`, "Convert Angular Units") opens,
///          and the narrow door it cut in the translation.**
///
///          Four things are pinned here, each more important than the last:
///
///          **1. The sheet is manual line 678's sentence**: choose a **source unit** and a **target
///          unit**, and convert **the number currently displayed**. So there are two rows, and **the
///          source unit is not guessed for the user** — before one is picked the target row is grey
///          (`1.5708` could be radians or degrees, and guessing wrong is one silent wrong value).
///
///          **2. What comes out is the "whole expression"**: `<value> <source unit> to <target unit>`.
///          The test below types `2+3` into the expression first (the result line reads `5`) and then
///          converts, requiring `5 deg to rad` on screen — **not** `2+3 deg to rad` (`to` binds looser
///          than `+`, so that string converts the `3`: visible on screen, but no longer the thing the
///          user asked for).
///
///          **3. The translation's door has exactly one shape, and this is the round's most important
///          proof**: `deg` is a unit only on the two sides of `<value> <angle unit> to <angle unit>`;
///          **nowhere else did it gain a reading** —
///          - `deg(1.5707963268)` still **cannot be translated** (the legacy parser still answers 90),
///          - `5 deg`, `deg` and `deg + 1` still cannot be translated,
///          - `rad(90)` likewise (this app's `rad` is "degrees to radians", the engine's `rad` is a
///            unit),
///          - `90°` has not moved a character either (normalisation still writes it as `rad(90)`),
///          - `isAppUnit('deg')` is still false and `variableUnknownToEngine('deg')` still non-null.
///          **Those five together are the executable form of "one admission, not a wall knocked down"**:
///          what moved this round is one shape-judged path in the translation
///          (`_angleConversion` in `engine_expression.dart`), and neither table (`kAppUnits` nor the
///          vocabulary) moved a cell.
///
///          **4. The refused spelling carries its measured numbers**: `grad` is not the gradian
///          (`1 grad` = `1357.168026 s·rad`, `90 grad to deg` = `81 d·°` — right value, corrupted unit),
///          and it is a grey row in the sheet; the clean spelling is `gon`. **Expiry**: the day the
///          engine answers `grad` correctly this group goes red, and that row should then light up.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('面板：`►DRG` 的两步，加上一行灰的 `grad`', () {
    testWidgets(
        'SHIFT + `DRG` 打开「Convert Angular Units」：两行单位、六个拼法、一行灰的 `grad`；打开本身不插任何东西',
        (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-open')));
      await tester.pumpAndSettle();

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      expect(find.text('Convert Angular Units'), findsOneWidget,
          reason: '标题是厂商的命令名（`command.name.TO_DRG`），逐字照抄');
      expect(_displayedExpression(tester), '', reason: '打开面板本身一个字符都不插');

      // 中文：六个拼法**在两行里各出现一次**——键面文字就是插进表达式的那串拼法本身（与矩阵菜单
      //       同一条规矩）。旁边那行灰的 `grad` 是第七个词，但它不是表里的单位。
      // English: the six spellings appear **once in each row** — the face is the spelling that goes
      //          into the expression (the matrix menu's own rule). The grey `grad` beside them is a
      //          seventh word, but it is not a unit in the table.
      for (final unit in kAngleUnits) {
        expect(find.text(unit), findsNWidgets(2),
            reason: '「$unit」应当在源与目标两行里各出现一次');
      }
      expect(kAngleUnits,
          <String>['deg', 'rad', 'gon', 'turn', 'arcmin', 'arcsec'],
          reason: '表里就是这六个：没有 `grad`（它不是角），也没有 `degrees`/`radians`（本应用没给'
              '它们拼法）');
    });

    testWidgets('没选源单位时目标那一行按不动——应用不替用户猜那个数是什么单位', (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-no-source')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('5'));
      await tester.pumpAndSettle();

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      expect(find.textContaining('先选源单位'), findsOneWidget,
          reason: '面板上要说出为什么目标那一行按不动');

      // 中文：**两行各六个拼法，所以「同一个词出现两次」——点目标那一行的那一个，必须点不动。**
      //       `find.text(unit)` 的第一个是源那一行（它点得动），最后一个是目标那一行。
      // English: **six spellings per row, so every word appears twice** — the one in the target row
      //          must not be pressable. The first `find.text(unit)` is the source row (pressable) and
      //          the last is the target row.
      final targetRad = find.text('rad').last;
      expect(
          tester
              .widget<TextButton>(find
                  .ancestor(
                    of: targetRad,
                    matching: find.byType(TextButton),
                  )
                  .first)
              .onPressed,
          isNull,
          reason: '没选源单位时目标那一行是灰的：`1.5708` 既可能是弧度也可能是度，猜错就是一次'
              '静默错值');

      await tester.tap(targetRad, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '5', reason: '按不动就是按不动：表达式一个字节都不该变');
      expect(find.text('Convert Angular Units'), findsOneWidget,
          reason: '什么都没发生，面板当然不该关');
    });

    testWidgets('选了源、再点目标：整条表达式换成 `<值> <源> to <目标>`，面板关掉', (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-convert')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('5'));
      await tester.pumpAndSettle();

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('deg').first);
      await tester.pumpAndSettle();
      expect(find.text('当前值 5'), findsOneWidget,
          reason: '选了源单位之后，状态那一行把要换算的那个数念出来（与结果状态卡同一句话）');

      await tester.tap(find.text('rad').last);
      await tester.pumpAndSettle();

      expect(_displayedExpression(tester), '5 deg to rad',
          reason: '插出去（这里是「换出去」）的永远是**源与目标都写出来**的完整一条');
      expect(find.text('Convert Angular Units'), findsNothing,
          reason: '按一下就关面板：表达式整条换了，用户要看的是结果行上的答案');
    });

    testWidgets('换的是**结果行上那个数**，不是往表达式里追加：`2+3` 换成 `5 deg to rad`',
        (tester) async {
      // 中文：**这是本面板唯一的设计取舍，也是最容易做错的一处。** 往光标处追加一段会得到
      //       `2+3 deg to rad`——`to` 比 `+` 松，那一步换算的是 `3` 而不是结果行上的 `5`。整条换掉
      //       没有这个状态：表达式**就是**那一次换算，值就是刚才显示的那个数。
      // English: **this is the sheet's one design decision and the easiest thing to get wrong.**
      //          Appending a piece at the caret would give `2+3 deg to rad` — `to` binds looser than
      //          `+`, so that conversion converts the `3` rather than the `5` on the result line.
      //          Replacing the whole expression has no such state: the expression **is** that one
      //          conversion, over the number that was just displayed.
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-value')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('2'));
      await tester.tap(_keypadKey('+'));
      await tester.tap(_keypadKey('3'));
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '2+3');
      expect(find.text('5'), findsWidgets, reason: '结果行上是 `5`（旧解析器算的）');

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('deg').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('rad').last);
      await tester.pumpAndSettle();

      expect(_displayedExpression(tester), '5 deg to rad',
          reason: '换的是结果行上的那个数，而表达式是整条换掉的');
      expect(_displayedExpression(tester), isNot(contains('2+3')),
          reason: '旧表达式不在新表达式里——那正是「追加一段」会做出来的形状');
    });

    testWidgets('当前没有可换算的数时：目标那一行是灰的，面板里写着为什么，按下去什么都不发生', (tester) async {
      // 中文：**没有可用的数时不替用户编一个默认值。** 表达式打一个 `(`（旧解析器当场报错，
      //       结果行上不是答案）——门槛与四个进制胶囊逐条相同：出错时换不了。
      // English: **with no usable number the sheet invents no default.** Type a `(` into the
      //          expression (the legacy parser errors at once, and the result line holds no answer) —
      //          the gates are item for item the base pills': an error state cannot be converted.
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-no-value')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('('));
      await tester.pumpAndSettle();

      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      expect(find.textContaining('当前没有可换算的数值结果'), findsOneWidget,
          reason: '面板上要说出为什么按不动');

      // 中文：源那一行仍旧点得动（选源不换算、也不写表达式），选完源目标那一行**仍然是灰的**
      //       ——灰的原因换成「没有可换算的数」，不是「没选源」。
      // English: the source row is still pressable (choosing a source converts and writes nothing),
      //          and after choosing one the target row is **still grey** — the reason has changed from
      //          "no source picked" to "nothing convertible".
      await tester.tap(find.text('deg').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('当前没有可换算的数值结果'), findsOneWidget,
          reason: '选了源单位也换不了：那个门槛管的是有没有数，与源选没选无关');
      expect(
          tester
              .widget<TextButton>(find
                  .ancestor(
                    of: find.text('rad').last,
                    matching: find.byType(TextButton),
                  )
                  .first)
              .onPressed,
          isNull);

      await tester.tap(find.text('rad').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '(', reason: '按不动就是按不动：表达式一个字节都不该变');
    });

    testWidgets('`grad` 那一行：灰着、按不动、理由里写着实测值', (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-grad')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      expect(find.text('grad'), findsOneWidget,
          reason: '「百分度」最容易被想起来的拼法应当在面板里（灰着，不是没有）');
      final tile = tester.widget<ListTile>(
        find.ancestor(of: find.text('grad'), matching: find.byType(ListTile)),
      );
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
      final note = tester
          .widget<Text>(
            find
                .descendant(
                    of: find.byWidget(tile), matching: find.byType(Text))
                .last,
          )
          .data!;
      // 中文：理由必须说得出**引擎的答复是什么**（而不是一句「不支持」），而且干净拼法是哪个。
      // English: the reason has to say **what the engine answers** (not merely "unsupported") and
      //          which spelling is clean.
      expect(note, contains('1357.168026 s·rad'));
      expect(note, contains('81 d·°'));
      expect(note, contains('gon'));

      await tester.tap(find.text('grad'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), '', reason: '灰着的行按下去什么都不插');
      expect(find.text('Convert Angular Units'), findsOneWidget,
          reason: '按灰格连面板都不关（它没做任何事）');
    });
  });

  group('那扇门的形状：只在 `<值> <角度单位> to <角度单位>` 里放行', () {
    test('六条调用、两个方向都译得出；译出来逐字是引擎读了几轮的那种串', () {
      // 中文：值那一半（引擎的答复）是宿主 `qalc` 5.12.0 量的，跑不进这个进程——表在
      //       `app_unit_catalog.dart` 的 `kAngleUnits` 上。这里钉的是**应用这一半**。
      // English: the value half (the engine's answers) was measured on host `qalc` 5.12.0 and cannot
      //          run in this process — the table is on `kAngleUnits` in `app_unit_catalog.dart`. What
      //          is pinned here is **this app's half**.
      const admitted = <(String, String)>[
        ('90 deg to rad', '((((90)*(deg))) to (rad))'),
        (
          '1.570796326794897 rad to deg',
          '((((1.570796326794897)*(rad))) to (deg))'
        ),
        ('90 deg to gon', '((((90)*(deg))) to (gon))'),
        ('0.25 turn to deg', '((((0.25)*(turn))) to (deg))'),
        ('5400 arcmin to deg', '((((5400)*(arcmin))) to (deg))'),
        ('90 arcsec to deg', '((((90)*(arcsec))) to (deg))'),
      ];
      for (final (source, expected) in admitted) {
        final translated = engineExpressionFor(source);
        expect(translated, isA<TranslatedExpression>(), reason: source);
        expect((translated as TranslatedExpression).text, expected,
            reason: source);
      }
    });

    test('**`deg`/`rad` 在别处的含义一个字节都没变**——这一条就是本轮的边界', () {
      // 中文：**这是本轮最要紧的一条断言。** 放行 `deg` 这件事只在翻译层的一个形状里发生，
      //       下面每一条都是「别处没变」的可执行形式：
      //
      //       1. **应用自己的 `deg(...)`/`rad(...)` 仍旧由旧解析器作答**（`deg(1.5707963268)` = 90，
      //          `rad(90)` = 1.5707963267948966），翻译层仍旧拒绝把它们交给引擎——引擎那边的
      //          `deg`/`rad` 是**单位**，交过去就换了意思。这一条与放行之前**逐字相同**。
      //       2. **裸的 `deg` 在换算之外仍旧到不了引擎**：`deg`、`5 deg`、`deg + 1` 一律拒绝，
      //          仍旧回落旧解析器（它对裸 `deg` 的答复是应用自己的「Function deg needs (」）。
      //       3. **`°` 的含义一个字没变**：归一化仍旧把 `90°` 写成 `rad(90)`——应用的 `°` 是
      //          「这个数是若干度」，不是单位拼法。
      //       4. **两张表一格未动**：`isAppUnit('deg')` 仍旧为假（它不在可插入单位表里），
      //          `variableUnknownToEngine('deg')` 仍旧非空（裸的 `deg` 仍旧是表外的自由变量）。
      //       5. **词表里也没有多出什么**：`AppEngineVocabulary.identifiers['deg']` 仍是那条
      //          「引擎不认识这个拼法」的行，`engineFunction` 仍旧为空。
      // English: **this is the round's most important assertion.** Admitting `deg` happens inside one
      //          shape in the translation, and every clause below is the executable form of "nothing
      //          else moved":
      //
      //          1. **this app's own `deg(...)`/`rad(...)` are still answered by the legacy parser**
      //             (`deg(1.5707963268)` = 90, `rad(90)` = 1.5707963267948966) and the translation
      //             still refuses to hand them to the engine — the engine's `deg`/`rad` are **units**,
      //             so handing them over would change the meaning. This clause is **byte for byte what
      //             it was before the admission**.
      //          2. **a bare `deg` outside a conversion still cannot reach the engine**: `deg`,
      //             `5 deg` and `deg + 1` are all refused and still fall back to the legacy parser
      //             (whose own answer for a bare `deg` is this app's "Function deg needs (").
      //          3. **`°` has not moved a character**: normalisation still writes `90°` as `rad(90)` —
      //             this app's `°` means "this number is so many degrees", not a unit spelling.
      //          4. **neither table moved a cell**: `isAppUnit('deg')` is still false (it is not an
      //             insertable unit) and `variableUnknownToEngine('deg')` is still non-null (a bare
      //             `deg` is still a free variable outside the table).
      //          5. **the vocabulary gained nothing either**: `AppEngineVocabulary.identifiers['deg']`
      //             is still that "the engine does not know this spelling" row with no
      //             `engineFunction`.
      expect(engineExpressionFor('deg(1.5707963268)'),
          isA<UntranslatableExpression>(),
          reason: '应用的 `deg(...)` 不许交给引擎：引擎的 `deg` 是单位，交过去就换了意思');
      expect(ExpressionParser('deg(1.5707963268)', degreeMode: true).parse(),
          closeTo(90, 1e-9),
          reason: '应用的 `deg(...)` 仍旧是「弧度换度」，由旧解析器作答');
      expect(engineExpressionFor('rad(90)'), isA<UntranslatableExpression>(),
          reason: '应用的 `rad(...)` 同上（那是「度换弧度」，引擎的 `rad` 是单位）');
      expect(ExpressionParser('rad(90)', degreeMode: true).parse(),
          closeTo(1.5707963267948966, 1e-15),
          reason: '应用的 `rad(...)` 一个字节都没变');

      for (final source in <String>['deg', '5 deg', 'deg + 1']) {
        expect(engineExpressionFor(source), isA<UntranslatableExpression>(),
            reason: '「$source」里的裸 `deg` 仍旧到不了引擎——本轮的放行只在一次 `to` 换算的两侧');
      }

      // 中文：**「只写目标单位」那一种形状也不许过**——它是本轮最想拦下的东西：源单位不说出来时，
      //       那一步的源单位会变成**当前角度模式**（实测 `90 to rad` 在 DEG/RAD/GRA 三档下是
      //       `1.570796327 rad` / `90 rad` / `1.413716694 rad`）。所以门的判据要求左边是
      //       「值 × 单位」两条都有，缺一条就回落旧解析器。
      // English: **the "target unit only" shape may not get through either** — it is the thing this
      //          round most wants to stop: with no source unit stated, that conversion's source unit
      //          becomes the **current angle mode** (measured: `90 to rad` is `1.570796327 rad` /
      //          `90 rad` / `1.413716694 rad` under DEG/RAD/GRA). The door's judgement therefore
      //          requires "a value × a unit" on the left, both halves, and a missing half falls back to
      //          the legacy parser.
      for (final source in <String>['90 to deg', '1.5707963268 to deg']) {
        expect(engineExpressionFor(source), isA<UntranslatableExpression>(),
            reason: '「$source」没写源单位：那一步的源单位会变成当前角度模式，而用户手里那个数'
                '未必是它的单位——这正是要拦下的静默错值形状');
      }
      expect(ExpressionParser('90°', degreeMode: true).parse(),
          closeTo(1.5707963267948966, 1e-15),
          reason: '`°` 的含义一个字没变：归一化仍旧把它写成 `rad(90)`');
      expect(engineExpressionFor('90°'), isA<UntranslatableExpression>(),
          reason: '`°` 归一化之后就是 `rad(90)`，而那条路仍旧拒绝（含义两侧不同）');

      expect(isAppUnit('deg'), isFalse,
          reason: '`deg` 仍旧不在可插入单位表里——本轮开的门不在那张表上');
      expect(AppEngineVocabulary.variableUnknownToEngine('deg'), isNotNull,
          reason: '裸的 `deg` 仍旧是表外的自由变量');
      expect(AppEngineVocabulary.identifiers['deg'], isNotNull,
          reason: '词表里那一行还在（它是应用自己的函数名）——变的只是它的 `engineFunction` 仍旧为空');
      expect(AppEngineVocabulary.identifiers['deg']!.engineFunction, isNull,
          reason: '`deg` 仍旧没有引擎写法：本轮没有给词表添过任何一行');
      expect(AppEngineVocabulary.engineNameFor('deg'),
          isA<UntranslatableExpression>(),
          reason: '词表那条路仍旧拒绝 `deg`——那扇门不走函数调用这条路');
    });

    test('表外的角度拼法一条也进不来（`degrees`/`radians`/`grad`/`gradian`）', () {
      // 中文：**`degrees`/`radians` 引擎读得懂**（宿主实测 `90 degrees to rad` = `1.570796327 rad`）
      //       ——所以它们被拒绝不是「引擎做不到」，而是**本应用没有给它们拼法**（与 `zorkmid`
      //       那一类同一条路：一个单位只留一个拼法）。
      //
      //       **`grad` 是另一类，而且更坏**：引擎确实读它，但读出来的不是一个角——
      //       `1 grad` = `1357.168026 s·rad`；用作换算的**来源**时值是对的、单位是坏的
      //       （`90 grad to deg` = `81 d·°`）。它因此不表，而是面板里那一行灰的。
      //       `gradian`/`gra` 答得对（`1 gradian to deg` = `0.9°`），但一个单位只留一个拼法，
      //       本应用用的是 `gon`（`1 gon to deg` = `0.9°`）。
      //
      //       **到期日**：这一条与矩阵菜单那三行同一个做法——哪一天某个拼法过得了翻译层
      //       （或者进了单位表），它会变红，那时面板里该多一格，而不是让一条过期的拒绝悄悄留着。
      // English: **`degrees`/`radians` the engine does read** (host measurement
      //          `90 degrees to rad` = `1.570796327 rad`) — so refusing them is not "the engine cannot",
      //          it is **this app giving them no spelling** (the same road as `zorkmid`: one unit keeps
      //          one spelling).
      //
      //          **`grad` is the other class, and the worse one**: the engine does read it, but what it
      //          reads is not an angle — `1 grad` = `1357.168026 s·rad`; as a conversion's **source** the
      //          value is right and the unit is corrupted (`90 grad to deg` = `81 d·°`). It is therefore
      //          not in the table; it is the sheet's grey row. `gradian`/`gra` do answer correctly
      //          (`1 gradian to deg` = `0.9°`), but one unit keeps one spelling, and this app's is `gon`
      //          (`1 gon to deg` = `0.9°`).
      //
      //          **Expiry**: the same device as the matrix menu's three rows — the day one of these
      //          spellings gets through the translation (or enters the unit table) this goes red, and
      //          the sheet should grow a cell rather than leaving an expired refusal quietly in place.
      for (final spelling in <String>[
        'degrees',
        'degree',
        'radians',
        'radian',
        'arcminute',
        'grad',
        'gradian',
        'gra',
      ]) {
        expect(isAngleUnit(spelling), isFalse,
            reason: '`$spelling` 不在那张闭集里（本应用只为六个角度单位各留一个拼法）');
        expect(engineExpressionFor('90 $spelling to deg'),
            isA<UntranslatableExpression>(),
            reason: '「90 $spelling to deg」不许过翻译层：名字不在表里就等于让引擎去猜');
        expect(isAppUnit(spelling), isFalse,
            reason: '`$spelling` 也不在可插入单位表里——两张表都不认它');
      }
      expect(isAngleUnit('grad'), isFalse,
          reason: '`grad` 那条灰行的凭据：引擎读它，但读出来的不是一个角');
      expect(engineExpressionFor('90 grad to deg'),
          isA<UntranslatableExpression>(),
          reason: '`grad` 的来源形状一个也到不了引擎（值对、单位坏：实测 `81 d·°`）');
      expect(AppEngineVocabulary.variableUnknownToEngine('grad'), isNotNull,
          reason: '`grad` 是表外的自由变量——它没有第二条路');
    });
  });

  group('那扇门的下游：送进引擎的是译出来的那一串；撤销拿得回来', () {
    test('`convertAngle` 之后引擎被问到的就是 `((((5)*(deg))) to (rad))`', () async {
      // 中文：**从按键到引擎的这一整条路在这里钉住**：`convertAngle` 把当前值写成表达式，求值路径
      //       照常把它译出来（走的正是上面那扇门），引擎收到的是那一串。回执的字段是宿主实测的
      //       （`qalc` 5.12.0，`-t -set "precision 16"`——桥自己用的就是 16 位有效数字：
      //       `5 deg to rad` = `0.08726646259971648 rad`）。
      // English: **the whole road from the press to the engine is pinned here**: `convertAngle` writes
      //          the current value into the expression, the evaluation path translates it as usual
      //          (through the door above) and the engine receives that string. The receipt's fields are
      //          measured on the host (`qalc` 5.12.0, `-t -set "precision 16"` — 16 significant digits
      //          is what the bridge itself asks for: `5 deg to rad` = `0.08726646259971648 rad`).
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '0.08726646259971648 rad',
          displayTex: r'\qty{0.08726646259971648}{rad}',
          kind: EngineResultKind.conversion,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5');
      // 中文：先让边打边算落地（旧解析器给 `5`），再换算——`angleConvertValue` 读的是**结果行**。
      // English: let the as-you-type evaluation land first (the legacy parser gives `5`), then convert —
      //          `angleConvertValue` reads the **result line**.
      controller.evaluate();
      expect(controller.angleConvertValue, '5',
          reason: '要换算的就是当前结果的那个数（十进制形态）');
      expect(controller.convertAngle('deg', 'rad'), isTrue);
      expect(controller.expression, '5 deg to rad', reason: '表达式就是那一次换算，逐字的形状');

      await controller.submit();
      expect(engine.calls.last.expression, '((((5)*(deg))) to (rad))',
          reason: '源与目标都写出来了，译出来的就是引擎那串老形状');
      controller.dispose();
    });

    test('一次撤销把原来的表达式拿回来；角度模式一个字节都没动', () async {
      final controller =
          _controller(_FakeDatabase(), engine: _FakeMathEngine(null));
      controller.setExpression('2+3');
      await controller.submit();
      final angleModeBefore = controller.angleMode;

      expect(controller.convertAngle('deg', 'gon'), isTrue);
      expect(controller.expression, '5 deg to gon');
      expect(controller.canUndo, isTrue, reason: '换算记了一次撤销快照——与「继续使用」同一条路');

      controller.undo();
      expect(controller.expression, '2+3',
          reason: '一次撤销就能拿回原来的表达式（那个代价与「继续使用」一样）');
      expect(controller.angleMode, angleModeBefore,
          reason: '`►DRG` 是一次换算，不是 `DRG` 那颗模式键：DEG/RAD 状态不许被动到');
      controller.dispose();
    });

    test('结果是一个量（`5 km`）时换不了，而且什么都没改', () async {
      // 中文：**没有有限十进制形态的结果不是「一个数」。** 判据与四个进制胶囊逐条相同
      //       （`hasError || !hasFiniteDecimal`），所以量与符号式都换不了——把 `5 km` 当成一个数
      //       去换算是把两件事混在一起。
      // English: **a result with no finite decimal form is not "a number".** The gates are item for
      //          item the base pills' (`hasError || !hasFiniteDecimal`), so a quantity and a symbolic
      //          form are both unconvertible — treating `5 km` as a number to convert would mix two
      //          different things.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km',
          displayTex: r'\qty{5}{\km}',
          kind: EngineResultKind.quantity,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);
      controller.setExpression('5 km');
      await controller.submit();

      expect(controller.angleConvertValue, isNull,
          reason: '量没有十进制形态，所以面板上那两行是灰的');
      expect(controller.convertAngle('deg', 'rad'), isFalse,
          reason: '换不了就说换不了——返回 false，调用方据此给用户一句解释');
      expect(controller.expression, '5 km', reason: '什么都没改：表达式一个字节都不动');
      controller.dispose();
    });

    test('拼法不在表里时一样拒绝（边界上的守卫）', () async {
      final controller =
          _controller(_FakeDatabase(), engine: _FakeMathEngine(null));
      controller.setExpression('5');
      await controller.submit();
      expect(controller.convertAngle('grad', 'deg'), isFalse,
          reason: '`grad` 不在那张闭集里——就算面板哪天递错了，这里也过不去');
      expect(controller.convertAngle('deg', 'degrees'), isFalse);
      expect(controller.expression, '5', reason: '两次拒绝都没有动过表达式');
      controller.dispose();
    });

    test('表达式为空时结果是屏幕上的那个 `0`：`0 deg to rad` 是一句真话', () async {
      // 中文：**「没有可用的数」不等于「表达式是空的」。** 空表达式时结果行上是 `MathResult.zero`
      //       （状态卡就写着「当前值 0」），所以它换算得了——0 度就是 0 弧度，那是一个真答案，
      //       不是替用户编出来的默认值。真正换不了的是**没有十进制形态**的那些（量、符号式、出错）。
      // English: **"no usable number" is not "the expression is empty".** With an empty expression the
      //          result line holds `MathResult.zero` (the status card literally reads "当前值 0"), so it
      //          is convertible — zero degrees is zero radians, a true answer rather than a default
      //          invented for the user. What really cannot be converted is anything with **no decimal
      //          form** (a quantity, a symbolic form, an error).
      final controller =
          _controller(_FakeDatabase(), engine: _FakeMathEngine(null));
      expect(controller.expression, '');
      expect(controller.angleConvertValue, '0');
      expect(controller.convertAngle('deg', 'rad'), isTrue);
      expect(controller.expression, '0 deg to rad');
      controller.dispose();
    });
  });
}

String _displayedExpression(WidgetTester tester) => tester
    .widget<MathExpressionView>(find.byType(MathExpressionView))
    .expression;

/// 中文：键面文字所在的**可点**那一层。`SHIFT`/`DRG` 这些字在屏幕上出现两次（横带里的提示与下方
///       主键的键面），所以不能直接 `find.text`——这里从文字往上找它所在的 `InkWell`：提示那一句
///       没有可点的祖先，键面那一句有。
///       **横带那一格本轮起写 `▸DRG`**（带 U+25B8，见行 7 的注释），而键面永远画基准标签 `DRG`——
///       两个字符串从此不同，这个查找器仍然按**键面**（可点的那一层）取，不受影响。
/// English: the **tappable** layer the face text sits on. Faces such as `SHIFT`/`DRG` appear twice on
///          screen (the band's hint and the key face below), so a bare `find.text` will not do — this
///          walks up from the text to its `InkWell`: the hint has no tappable ancestor, the key face
///          has one. **The band cell reads `▸DRG` from this round on** (U+25B8; see row 7's note) while
///          the face always draws the base `DRG` — the two strings differ now, and this finder still
///          takes the **face**, the tappable one.
Finder _keypadKey(String label) => find
    .ancestor(
      of: find.descendant(
        of: find.byType(CalculatorKeypad),
        matching: find.text(label),
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

/// 中文：控制器级测试用的那套替身，与 `test/domain/unit_conversion_expression_test.dart` 逐条相同
///       ——引擎换成可编程的假引擎（`null` 表示「这一次不需要引擎回话」），设置与真实默认值一致。
/// English: the stand-ins the controller-level tests use, item for item the ones in
///          `test/domain/unit_conversion_expression_test.dart` — the engine becomes a programmable
///          fake (`null` means "no engine reply is needed this time") and the settings match the real
///          defaults.
CalculatorController _controller(
  _FakeDatabase db, {
  required _FakeMathEngine engine,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: false,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
  );
}

class EngineReplyFixture {
  const EngineReplyFixture({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.arithmetic,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        decimalText:
            decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  /// 中文：`null` 表示这个测试不需要引擎回话（回执一路为空，结果行由旧解析器决定）。
  /// English: `null` means this test needs no engine reply (the receipt stays empty and the result
  ///          line is decided by the legacy parser).
  final EngineReply? reply;

  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply ?? EngineReply.failure('no engine in this test');
  }
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
