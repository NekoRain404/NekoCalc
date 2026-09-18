import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**横带偏差的最后一类：反向的不对称——横带上有提示，而对应的键没有那个动作。**
///       本文件守本轮核实出来的那两格：第 2 行第 1 格 `DRG`（HiPER 的 `►DRG`）与第 3 格 `MTRX`。
///
///       **核实结论（本轮量的）**：两格都是**下方主键的第二功能记号**，不是独立的键——
///       1. 位置：第 2 行横带六格的字形列中心与下方六键的列中心**一一对齐**，最大差 1.0 px
///          （`►DRG` vs `DRG` 差 0.5 px，`MTRX` vs 矩阵键差 1.0 px；列宽 238 px）；
///       2. HiPER 自己给这个位置下了定义（`quickTour.page.SECOND_FUNCTION.text2`：「键的第二功能
///          印在它上方的标签里」，手册 §SHIFT 同义）；
///       3. **画法**：横带里每一颗真按钮都戴浅色胶囊底（四个进制胶囊，亮像素占比 0.21–0.61），
///          每一格第二功能记号都是平排文字（0.02–0.09），字形核心 **(159,161,168)**——`►DRG` 与
///          `MTRX` 与 `FSE`/`Π`/`d/dx`/`hyp`/`sin⁻¹` 逐个像素同值；
///       4. `▸` **不是**「这是一颗按钮」的记号：厂商自己的更新日志把这一族写成一个函数名
///          `▸BASE`（U+25B8），而同一族在**展开布局**里是三颗键——展开布局没有 SHIFT 键、也没有
///          第二功能。它属于换算命令的名字。
///
///       **动作是什么，以及今天各自是什么状态**：`►DRG` = `TO_DRG`「换算角度单位」（手册第 678 行：
///       "►DRG key in compact layout opens the menu to choose source and target angular units and
///       converts the current display number."），`MTRX` = `MATRIX_MENU`「矩阵与向量菜单」（手册
///       第 941 行："Press the MTRX key to open a menu with matrix functions."）——两个都与下方那颗键
///       的**基准不是同一个动作**，而且**现在两格都点亮了**，各自走同一条先例（`dis:` 前缀换成真正的
///       动作 id）：
///       - **`DRG` 走 `openAngleConvert`**：SHIFT 态下打开「换算角度单位」面板（`►DRG`，
///         `calculator_page_angle_sheet.dart`）；
///       - **`MTRX` 走 `openMatrixMenu`**：SHIFT 态下打开「矩阵与向量菜单」（上一轮点亮的，
///         `calculator_page_matrix_sheet.dart`）。
///
///       **最后一组是那两条拒绝的「到期日」，两条都已经兑现**：
///       - `MATRIX_MENU` 那一条**上一轮就兑现了**（七条调用当年全过不去翻译层，上一轮四条进得了、
///         三条仍留在拒绝那一列——两个方向都写在那儿）；
///       - `TO_DRG` 那一条**本轮兑现**。它当年钉的是「源单位说不出来」与「反方向（→ 度）不存在」，
///         而本轮实测**两句都要改**：反方向在引擎里一直存在（`90 rad to deg` = `5156.620156°`），
///         过去过不去的是应用这一侧；「说不出来」是因为翻译层当时不给 `deg` 任何位置——本轮给它开了
///         **一个形状**（`<值> <角度单位> to <角度单位>`），于是那几条**如期变红**。这一组换成正反
///         两面写：开了的那几条仍然只在那一个形状里、没开的那些一条也不许进来。
/// English: **The last class of band deviation: the reverse asymmetry — a hint sits in the band while
///          the key below it has no such action.** This file guards the two cells verified in that
///          round: row 2's first cell `DRG` (HiPER's `►DRG`) and its third cell `MTRX`.
///
///          **What the check found (measured)**: both cells are **second-function symbols of the key
///          below**, not keys of their own — (1) position: the six glyph column centres of row 2's band
///          line up one-to-one with the six key centres below, largest gap 1.0 px (`►DRG` vs `DRG`:
///          0.5 px; `MTRX` vs the matrix key: 1.0 px; column width 238 px); (2) HiPER defines that
///          position itself (`quickTour.page.SECOND_FUNCTION.text2`: "The key's second function is
///          displayed in the label above.", the manual's SHIFT section says the same); (3) **the
///          drawing**: every real band button wears a light capsule (the four base pills, light-pixel
///          fraction 0.21–0.61) while every second-function symbol is plain text (0.02–0.09) with glyph
///          core **(159,161,168)** — `►DRG` and `MTRX` match `FSE`/`Π`/`d/dx`/`hyp`/`sin⁻¹` pixel for
///          pixel; (4) `▸` is **not** a "this is a button" marker: the vendor's own release notes write
///          the family's name as the function `▸BASE` (U+25B8), and the same family is three keys in the
///          **expanded** layout, which has no SHIFT key and no second functions at all. It belongs to
///          the names of the conversion commands.
///
///          **What the actions are, and where each stands today**: `►DRG` = `TO_DRG`, "Convert Angular
///          Units" (manual line 678: "►DRG key in compact layout opens the menu to choose source and
///          target angular units and converts the current display number."), and `MTRX` =
///          `MATRIX_MENU`, "Matrix and Vector Menu" (manual line 941: "Press the MTRX key to open a menu
///          with matrix functions.") — neither is the key's **base** action, and **both cells have lit
///          up now**, each on the same precedent (a `dis:` prefix becoming a real action id):
///          - **`DRG` goes through `openAngleConvert`**: under SHIFT it opens the "Convert Angular
///            Units" sheet (`►DRG`, `calculator_page_angle_sheet.dart`);
///          - **`MTRX` goes through `openMatrixMenu`**: under SHIFT it opens the "Matrix and Vector
///            Menu" (lit last round, `calculator_page_matrix_sheet.dart`).
///
///          **The last group is the expiry date of those two refusals, and both have been honoured**:
///          - the `MATRIX_MENU` one **expired last round** (all seven calls failed to translate back
///            then; last round four got through and three stayed in the refused column — both
///            directions are written there);
///          - the `TO_DRG` one **expires this round**. It used to pin "the source unit cannot be
///            stated" and "the other direction (→ degrees) does not exist", and this round's
///            measurements **changed both sentences**: the other direction has always existed in the
///            engine (`90 rad to deg` = `5156.620156°`) and what did not exist was the spelling on this
///            app's side; "cannot be stated" held because the translation gave `deg` no position at
///            all — this round gives it **one shape** (`<value> <angle unit> to <angle unit>`), so
///            those assertions **went red as scheduled**. The group is rewritten with both directions:
///            what was opened holds only inside that one shape, and what stayed shut may not come in at
///            all.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('第 2 行第 1 格 `DRG`——`►DRG` 是 `DRG` 的 SHIFT，本轮真的点亮了', () {
    test('键位表：`DRG` 多出一个 SHIFT 变体 `openAngleConvert`，它是可用的；基准那一格逐字未动', () {
      final located = _locateBaseId('angleMode');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'DRG', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这一格在 HiPER 上是一颗真动作（`TO_DRG`）：横带写着它，键上就得有它的位置');
      expect(shift!.id, 'openAngleConvert',
          reason: '本轮起它是一个**真动作 id**——与上一轮 `dis:matrixMenu`→`openMatrixMenu`、'
              '以及更早 `dis:cplx`→`openComplex` 同一条先例：`dis:` 前缀是「有这个名字、但做不到」，'
              '点亮时换成真正的动作 id');
      expect(shift.label, 'DRG', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isTrue,
          reason: '缺口补上了（翻译层给 `deg` 开了一个形状：`<值> <角度单位> to <角度单位>`，'
              '见本文件最后一组），所以它不再禁用——禁用是拒绝，而这一格今天不再需要拒绝');

      // 中文：横带里那一格必须是**纯提示**。若它变回第二个按钮，同一个动作就有两个 id 入口，
      //       `键的 id 全局唯一` 那条不变式立刻红。
      // English: the band cell above must be a **plain hint**. Turn it back into a second button and
      //          one action has two id entrances — the id-uniqueness invariant goes red at once.
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'DRG');
    });

    testWidgets('SHIFT + `DRG` 打开「换算角度单位」面板，面板自己一个字节都不插；不按 SHIFT 时 `DRG` 走的仍是基准',
        (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-plain')));
      await tester.pumpAndSettle();
      expect(find.text('RAD'), findsOneWidget, reason: '起始档位来自设置（RAD）');

      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();
      expect(find.text('DEG'), findsOneWidget,
          reason: '`DRG` 的基准动作（DEG↔RAD 循环）这一次一个字节都没动');
      expect(_displayedExpression(tester), '', reason: '它是模式键，不往表达式里插东西');

      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('drg-shifted')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('DRG'));
      await tester.pumpAndSettle();

      expect(find.text('Convert Angular Units'), findsOneWidget,
          reason: 'SHIFT 态下这颗键打开面板（厂商的命令名，`command.name.TO_DRG`）——'
              '**不再走基准动作**：档位一个字节都不该动');
      expect(find.text('RAD'), findsOneWidget,
          reason: '面板打开时角度模式仍是 RAD：那颗键的基准是模式开关，而 SHIFT 变体是一次换算');
      expect(find.text('DEG'), findsNothing);
      expect(_displayedExpression(tester), '',
          reason: '打开面板本身不往表达式里插任何东西——换算是面板里再按一下才发生的');
    });
  });

  group('第 2 行第 3 格 `MTRX`——矩阵键的 SHIFT，本轮真的点亮了', () {
    test('键位表：矩阵键多出一个 SHIFT 变体 `openMatrixMenu`，它是可用的；基准那一格逐字未动', () {
      final located = _locateBaseId('ins:matrix');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'MTRX');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这一格在 HiPER 上是一颗真动作（`MATRIX_MENU`）：横带写着它，键上就得有它的位置');
      expect(shift!.id, 'openMatrixMenu',
          reason: '本轮起它是一个**真动作 id**——与 `dis:cplx`→`openComplex`、`dis:stat`→'
              '`openStatistics`、`dis:x`→`openVariables` 同一条先例：`dis:` 前缀是「有这个名字、'
              '但做不到」，点亮时换成真正的动作 id');
      expect(shift.label, 'MTRX', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isTrue,
          reason: '缺口补上了（词表添了 `det`/`transpose`/`inv`/`identity`，见最后一组），'
              '所以它不再禁用——禁用是拒绝，而这一格今天不再需要拒绝');

      // 中文：横带里那一格必须是**纯提示**。若它变回第二个按钮，同一个动作就有两个 id 入口，
      //       `键的 id 全局唯一` 那条不变式立刻红。
      // English: the band cell above must be a **plain hint**. Turn it back into a second button and
      //          one action has two id entrances — the id-uniqueness invariant goes red at once.
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'MTRX',
          reason: '横带那一格与它的 `shift` 变体同名');
    });

    testWidgets(
        'SHIFT + 矩阵键打开矩阵与向量菜单，按一项插一条完整调用；不按 SHIFT 时插的仍是 '
        '`matrix(2,2,1,2,3,4)`', (tester) async {
      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('mtrx-plain')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('MTRX'));
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'matrix(2,2,1,2,3,4)',
          reason: '矩阵键的基准动作必须一个字节都没变');

      await tester
          .pumpWidget(_testApp(key: const ValueKey<String>('mtrx-shifted')));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(_keypadKey('MTRX'));
      await tester.pumpAndSettle();

      expect(find.text('Matrix and Vector Menu'), findsOneWidget,
          reason: 'SHIFT 态下这颗键打开面板（厂商的命令名，`command.name.MATRIX_MENU`）');
      expect(_displayedExpression(tester), '',
          reason: '打开面板本身不往表达式里插任何东西——插入只发生在面板里按一下的时候');

      await tester.tap(find.text('det'));
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), 'det(matrix(2,2,1,2,3,4))',
          reason: '面板那四项插的是「一条调用围着基准动作那条矩阵」');
    });
  });

  group('第 2 行横带——本轮的改动没有把别的格子卷进来', () {
    test('第 2 行横带六格仍是提示，六格文字逐格未动', () {
      final located = _locateBaseId('angleMode');
      final labels = located.row.labels;

      expect(labels.length, 6);
      for (var i = 0; i < labels.length; i++) {
        final label = labels[i];
        // 中文：第 6 格是空位——HiPER 那里是 `CNST`（`CONV` 的 SHIFT），而本应用那一格是相机键，
        //       相机键上方**没有**标签（理由在键位表第 2 行的注释里）。这条断言把「空位」也钉住。
        // English: cell 6 is empty — HiPER has `CNST` there (`CONV`'s SHIFT), while this app's cell
        //          holds the camera key, which has **no** band label (the reason is in the key table's
        //          row-2 note). This assertion pins the empty slot too.
        if (i == 5) {
          expect(label, isNull);
          continue;
        }
        expect(label, isA<ShiftLabel>(),
            reason: '第 2 行横带第 ${i + 1} 格应当是不可点的提示');
      }
      expect(
          labels.whereType<ShiftLabel>().map((ShiftLabel l) => l.text).toList(),
          <String>['DRG', 'FSE', 'MTRX', 'Π', 'd/dx'],
          reason: '本轮只给第 1、3 格挂上了 `shift` 变体，五格文字一个都没改');
    });
  });

  group('两条拒绝的**到期日**（实测凭据钉在这里，不是写在注释里）：两条都已经兑现', () {
    test('`TO_DRG` 那条到期了：本应用现在给得出两向换算——只在那一个形状里，别的形状一条也没松', () {
      // 中文：**这一条是上一轮那条「到期日」断言的继承者，而且它真的到期了。**
      //       上一轮这里钉的是四条调用**全都过不去翻译层**、以及一句「反方向（→ 度）不存在」。
      //
      //       **那句话是假的，本轮实测把它改掉**（无论这个功能做没做成，这一条都要改）：
      //       - **反方向在引擎里一直存在**：`90 rad to deg` 实测 = `5156.620156°`（宿主 `qalc`
      //         5.12.0）。过去过不去的是**应用这一侧**——`deg` 当时根本不是一个可写的单位拼法。
      //       - 上一轮那段「`90 to deg` 只是贴了个记号、值一个字节没变」**只在 DEG 下成立**：
      //         同一个输入在 RAD 下实测是 `5156.620156°`（引擎把 90 读成弧度）。正确的说法是
      //         「不写源单位时，源单位就是**当前角度模式**」——`90 to rad` 三档分别是
      //         `1.570796327 rad` / `90 rad` / `1.413716694 rad`。
      //       **本轮因此没有做「只写目标单位」那一种**（它正是被上面那两条推翻的东西）：翻译层开的
      //       是**一个形状**，两侧的单位都要写出来。下面两个方向都钉住。
      // English: **this is the successor of last round's "expiry date" assertion, and it really did
      //          expire.** Last round it pinned four calls that **could not get through the translation
      //          layer** plus the sentence "the other direction (→ degrees) does not exist".
      //
      //          **That sentence was false, and this round's measurements replace it** (this has to
      //          change whether or not the feature ships):
      //          - **the other direction has always existed in the engine**: `90 rad to deg` measures
      //            `5156.620156°` (host `qalc` 5.12.0). What did not exist was the spelling on **this
      //            app's** side — `deg` was not a writable unit spelling at all back then.
      //          - last round's "`90 to deg` merely attaches a symbol and the value does not move a
      //            byte" **holds under DEG only**: the same input under RAD measures `5156.620156°`
      //            (the engine reads 90 as radians). The right sentence is "with no source unit written,
      //            the source unit **is the current angle mode**" — `90 to rad` is
      //            `1.570796327 rad` / `90 rad` / `1.413716694 rad` in the three modes.
      //          **So this round did not build the "target unit only" form** (it is exactly what those
      //          two measurements refuted): what the translation opened is **one shape**, with both
      //          units written out. Both directions are pinned below.

      // 中文：**开了的那一半：六条调用，两个方向，每条都译得出**，而且译出来的就是引擎读了几轮的
      //       那种串（`((值)*(单位)) to (目标单位)`）。值那一半不在 `flutter test` 里——引擎的答复
      //       （`1.570796327 rad`、`90.00000000°`、`100 gra`…）在 `app_unit_catalog.dart` 的
      //       `kAngleUnits` 实测表上；这里钉的是**应用这一半**。
      // English: **the half that opened: six calls, both directions, every one translatable**, and what
      //          comes out is the shape the engine has read for rounds
      //          (`((value)*(unit)) to (target unit)`). The value half cannot run inside `flutter test` —
      //          the engine's answers (`1.570796327 rad`, `90.00000000°`, `100 gra`…) are in the
      //          measurement table on `kAngleUnits` in `app_unit_catalog.dart`; this pins **this app's
      //          half**.
      const admitted = <(String, String)>[
        ('90 deg to rad', '((((90)*(deg))) to (rad))'),
        ('1.570796326794897 rad to deg', '((((1.570796326794897)*(rad))) to (deg))'),
        ('90 deg to gon', '((((90)*(deg))) to (gon))'),
        ('0.25 turn to deg', '((((0.25)*(turn))) to (deg))'),
        ('5400 arcmin to deg', '((((5400)*(arcmin))) to (deg))'),
        ('90 arcsec to deg', '((((90)*(arcsec))) to (deg))'),
      ];
      for (final (source, expected) in admitted) {
        final translated = engineExpressionFor(source);
        expect(translated, isA<TranslatedExpression>(),
            reason: '「$source」本轮起过得了翻译层——`►DRG` 那一格能点亮，凭的就是这一条');
        expect((translated as TranslatedExpression).text, expected,
            reason: '「$source」译出来的是引擎那串老形状，逐字钉住');
      }

      // 中文：**没开的那一半一条也没松。** 这些形状里 `deg` 仍旧到不了引擎——本轮开的门只有一个
      //       形状（`<值> <角度单位> to <角度单位>`，两侧都是**裸的单位词**），而下面每一条都缺了
      //       其中一半：只有单位没有值、值后面没有单位、单位被括号包着、右边不是一个单位、或者那个
      //       拼法根本不在表里（`degrees`/`radians` 引擎读得懂，但本应用没给它们拼法）。
      //       **这一组是「开一个窄门」与「拆墙」的分界线**：哪一天某一条过去了，说明有人的改动比本轮
      //       写下的形状宽——那时该停下来问一句，而不是让表达式语言里多出一个 `deg` 的读法。
      // English: **the half that stayed shut has not loosened at all.** `deg` still cannot reach the
      //          engine in these shapes — the door this round opened has exactly one shape
      //          (`<value> <angle unit> to <angle unit>`, both sides **bare unit words**), and every row
      //          below is missing one half of it: a unit with no value, a value with no unit after it, a
      //          unit inside brackets, a right side that is not a unit, or a spelling that is not in the
      //          table at all (`degrees`/`radians` the engine does read, but this app gives them no
      //          spelling). **This group is the line between "one narrow door" and "knocking the wall
      //          down"**: the day one of them gets through, someone's change is wider than the shape
      //          written down here — that is the moment to stop and ask, not to let the expression
      //          language grow another reading for `deg`.
      const stillRefused = <String>[
        '90 deg',
        'deg',
        'deg + 1',
        'deg(90)',
        '90 to deg',
        '1.5707963268 to deg',
        '5 km to deg',
        '90 (deg) to rad',
        '90 deg to (rad)',
        '90 deg to rad + 5',
        '90 to degrees',
        '1.5707963268 to radians',
      ];
      for (final source in stillRefused) {
        expect(engineExpressionFor(source), isA<UntranslatableExpression>(),
            reason: '「$source」今天仍旧过不去翻译层（这是有意的）：那个形状不在本轮开的那一个里');
      }

      // 中文：**`deg` 在表外那两处仍旧一个字都没变。** 它不是应用的可插入单位（`kAppUnits` 里没有
      //       它，`isAppUnit('deg')` 为假），也不是应用词汇里可以交给引擎的调用名
      //       （`deg(1.5707963268)` 仍旧由**旧解析器**作答：90）。本轮的放行**只发生在翻译层那一个
      //       形状里**，这两张表一格未动。
      // English: **the two tables outside it have not moved a character.** `deg` is still not one of
      //          this app's insertable units (it is absent from `kAppUnits`, `isAppUnit('deg')` is
      //          false) and still not a call name the app may hand to the engine
      //          (`deg(1.5707963268)` is still answered by the **legacy parser**: 90). This round's
      //          admission **happens inside that one translation shape only**; neither table moved.
      expect(isAppUnit('deg'), isFalse,
          reason: '`deg` 仍旧不在可插入单位表里——本轮开的门不在那张表上');
      expect(AppEngineVocabulary.variableUnknownToEngine('deg'), isNotNull,
          reason: '裸的 `deg` 仍旧是「表外的自由变量」：翻译层里那一个形状之外的 `deg` 一律拒绝');
      expect(ExpressionParser('deg(1.5707963268)', degreeMode: true).parse(),
          closeTo(90, 1e-9),
          reason: '应用自己的 `deg(...)` 一个字节都没变：它仍旧是「弧度换度」（旧解析器答，'
              '引擎不参与）');
    });

    test('`MATRIX_MENU` 那条路本轮通了——而被拒绝的三个名字仍过不去', () {
      // 中文：**这一条是上一轮那条「到期日」断言的继承者，而且它真的到期了。**
      //       上一轮这里钉的是七条调用**全都过不去翻译层**（词表里没有那些名字 "缺口就在这里"），
      //       外加 `AppEngineVocabulary.identifiers['det']` 为 null。本轮把
      //       `det`/`transpose`/`inv`/`identity` 添进词表之后，那几条**如期变红**——这正是到期日
      //       断言该有的样子（与结果格式菜单里 `Polar coordinates` 那一条同一个做法），所以这里把它
      //       换成正反两面，而不是把它删掉。
      //
      //       收下的四条：翻译得过去，而且写出来的就是引擎的同一个拼法（这四个名字两边同名）。
      //       **值那一半不在 `flutter test` 里**：`det(matrix(2,2,1,2,3,4))` = `−2`、
      //       `transpose(…)` = `[1  3; 2  4]`、`inv(…)` = `[−2  1; 1.5  −0.5]`、`identity(2)` =
      //       `[1  0; 0  1]` 是宿主 `qalc` 5.12.0 跑出来的，跑不进这个测试进程——所以那四个名字的
      //       「引擎答得对」由词表文件里那两张实测表与 `calculator_matrix_menu_test.dart` 承担，
      //       这里只钉应用这一半。
      // English: **this is the successor of last round's "expiry date" assertion, and it really did
      //          expire.** Last round it pinned that all seven calls **could not get through the
      //          translation layer** (the vocabulary had none of those names — "the gap is right here"),
      //          plus that `AppEngineVocabulary.identifiers['det']` was null. This round, after
      //          `det`/`transpose`/`inv`/`identity` entered the vocabulary, those assertions **went red
      //          as scheduled** — which is exactly what an expiry assertion is for (the same device as
      //          the `Polar coordinates` one in the result format menu), so they are replaced with both
      //          directions rather than deleted.
      //
      //          The four admitted ones translate, and what comes out is the engine's own spelling (all
      //          four share the name on both sides). **The value half cannot run inside `flutter test`**:
      //          `det(matrix(2,2,1,2,3,4))` = `−2`, `transpose(…)` = `[1  3; 2  4]`, `inv(…)` =
      //          `[−2  1; 1.5  −0.5]`, `identity(2)` = `[1  0; 0  1]` came out of host `qalc` 5.12.0 —
      //          so "the engine answers those four correctly" is carried by the two measurement tables in
      //          the vocabulary file and by `calculator_matrix_menu_test.dart`, and only this half is
      //          pinned here.
      const admitted = <String>[
        'det(matrix(2,2,1,2,3,4))',
        'transpose(matrix(2,2,1,2,3,4))',
        'inv(matrix(2,2,1,2,3,4))',
        'identity(2)',
      ];
      for (final call in admitted) {
        expect(engineExpressionFor(call), isA<TranslatedExpression>(),
            reason: '「$call」本轮起过得了翻译层（词表里有这个名字）——`MTRX` 那一格的 SHIFT '
                '能点亮，凭的就是这一条');
      }
      expect(AppEngineVocabulary.identifiers['det'], isNotNull,
          reason: '词表里有 `det`——上一轮这条断言写的是 isNull，它到期了');

      // 中文：**拒绝的那三条一条也不能进来。** 它们才是矩阵运算里最容易被想起来的名字，而引擎对
      //       它们的答复不是那件事（`rank`：引擎里真有的函数却把矩阵原样还回来；`trace`/`echelon`：
      //       引擎里根本没有，词被拆成符号、印出来带单位）——**老老实实留在「过不去」这一列**，
      //       所以它们永远到不了引擎，也就永远不会有「形状对、意思错」的答案上屏。
      //       **哪一天某一条过去了，说明引擎把那个名字答对了**（或者应用自己实现了它），那时面板上
      //       那一行灰格该点亮，而不是让一条过期的禁用悄悄留着。
      // English: **not one of the three refused names may come in.** They are exactly the names most
      //          likely to come to mind for matrix work, and the engine's answers for them are not those
      //          things (`rank`: a real engine function that hands the matrix straight back;
      //          `trace`/`echelon`: not names the engine has at all, so the word is taken apart into
      //          symbols and prints with units) — **they stay in the "cannot get through" column**, so
      //          they never reach the engine and a "right shape, wrong meaning" answer can never reach
      //          the screen. **The day one of them gets through**, the engine has started answering that
      //          name correctly (or this app implemented it itself), and that grey row in the sheet
      //          should light up rather than letting an expired refusal sit there quietly.
      const refused = <String>[
        'rank(matrix(2,2,1,2,3,4))',
        'trace(matrix(2,2,1,2,3,4))',
        'echelon(matrix(2,2,1,2,3,4))',
      ];
      for (final call in refused) {
        expect(engineExpressionFor(call), isA<UntranslatableExpression>(),
            reason: '「$call」今天过不去翻译层（词表里没有这个名字，这是有意的）；哪一天它过去了，'
                '说明引擎把那个名字答对了，面板里那一行灰格该点亮');
      }
      for (final name in <String>['rank', 'trace', 'echelon']) {
        expect(AppEngineVocabulary.identifiers[name], isNull,
            reason: '词表里不许有 `$name`：引擎对它的答复不是那件事（实测表在 '
                'app_engine_vocabulary_identifiers.dart 上），进表就等于让它上屏');
      }
      expect(AppEngineVocabulary.identifiers['matrix'], isNotNull,
          reason: '词表里有 `matrix`（矩阵键的基准就插它），所以缺口专指菜单里那几个函数名');

      // 中文：旧解析器读不了 `matrix(...)`——它只认 `matrix(` 里那一个子矩阵实参。这一条**没有变**，
      //       而且它今天仍然是要紧的：矩阵菜单那四条调用旧解析器一条也读不了，所以它们由**引擎**
      //       作答（而不是回落到旧解析器给一个猜出来的数）。
      // English: the legacy parser cannot read `matrix(...)` — it knows only the single sub-matrix
      //          argument. This has **not changed**, and it still matters today: the legacy parser
      //          cannot read any of the matrix menu's four calls either, which is why the **engine**
      //          answers them (rather than a fallback to a guessed number from the legacy parser).
      expect(
        () => ExpressionParser('matrix(2,2,1,2,3,4)', degreeMode: true).parse(),
        throwsFormatException,
      );
    });
  });
}

/// 中文：在键位表里按**基准 id** 找那一格，返回它所在的行与列。只在主键条里找——本轮的挂载对象是
///       主键（横带那两格本来就是提示）。找不到直接抛错：「表里没有这个 id」本身就是要被听见的事。
/// English: Find a cell **by its base id** and return its row and column. Only the main strips are
///          walked — this round's mount targets are main keys (both band cells were already hints). A
///          failed lookup throws: "the table has no such id" is itself something to hear about.
({KeypadRow row, int index}) _locateBaseId(String baseId) {
  for (final row in hiperKeypad.rows) {
    for (var index = 0; index < row.keys.length; index++) {
      if (row.keys[index].base.id == baseId) return (row: row, index: index);
    }
  }
  throw StateError('键位表里没有基准 id 为「$baseId」的主键');
}

String _displayedExpression(WidgetTester tester) => tester
    .widget<MathExpressionView>(find.byType(MathExpressionView))
    .expression;

/// 中文：键面文字所在的**可点**那一层。`DRG` 与 `MTRX` 两个字在屏幕上各出现两次——横带里那句
///       不可点的提示，与下方主键的键面（这正是本轮的主题：提示与键同名）——所以不能直接
///       `find.text`。这里从文字往上找它所在的 `InkWell`：提示那一句没有可点的祖先，键面那一句有。
/// English: the **tappable** layer the face text sits on. `DRG` and `MTRX` each appear twice on
///          screen — the non-tappable hint in the band and the key face below (which is this round's
///          very subject: hint and key sharing a name) — so a bare `find.text` will not do. This
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
