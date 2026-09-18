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
///       的**基准不是同一个动作**。两格的处理因此**不同**：
///       - **`DRG` 仍是禁用的**（`dis:angleConvert`）：应用今天给不出两向的角度换算（本文件最后那一组
///         的实测表就是凭据），所以按 `∠` 那一格的先例办——**位置照挂，`enabled: false`**，SHIFT 态下
///         变暗且不响应，比「按下去却做了基准动作」诚实；
///       - **`MTRX` 本轮真的点亮了**（`openMatrixMenu`）：缺口（词表里没有菜单要插的那几个名字）
///         补上了，先例与 `dis:cplx`→`openComplex` 那三颗一样——`dis:` 前缀换成真正的动作 id。
///
///       **最后一组是那两条拒绝的「到期日」**：`MATRIX_MENU` 那一条**已经到期并已兑现**（七条调用
///       当年全过不去翻译层，本轮四条进得了、三条仍留在拒绝那一列——两个方向都写在那儿）；
///       `TO_DRG` 那一条**还没到期**，它变红的那天说明应用真的有了两向换算。
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
///          with matrix functions.") — neither is the key's **base** action. The two cells are therefore
///          handled **differently**:
///          - **`DRG` is still disabled** (`dis:angleConvert`): this app cannot provide a two-way angle
///            conversion (the measurement table in this file's last group is the evidence), so it follows
///            the `∠` cell's precedent — **the position is mounted with `enabled: false`**, dimmed and
///            inert under SHIFT, which is more honest than "presses and quietly does the base action";
///          - **`MTRX` really lights up this round** (`openMatrixMenu`): the gap (the vocabulary held
///            none of the names such a menu inserts) is closed, by the same precedent as the three keys
///            `dis:cplx`→`openComplex` — the `dis:` prefix becomes a real action id.
///
///          **The last group is the expiry date of those two refusals**: the `MATRIX_MENU` one **has
///          expired and been honoured** (all seven calls failed to translate back then; this round four
///          get through and three stay in the refused column — both directions are written there), while
///          the `TO_DRG` one **has not expired yet**: the day it goes red, the app really has a two-way
///          conversion.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('第 2 行第 1 格 `DRG`——`►DRG` 是 `DRG` 的 SHIFT，动作仍不可达', () {
    test('键位表：`DRG` 多出一个 SHIFT 变体 `dis:angleConvert`，它是禁用的；基准那一格逐字未动', () {
      final located = _locateBaseId('angleMode');
      final key = located.row.keys[located.index];

      expect(key.base.label, 'DRG', reason: '键面文字是选定的，不该被这一次改动碰到');
      expect(key.base.enabled, isTrue);
      expect(key.category, KeyCategory.function);

      final shift = key.shift;
      expect(shift, isNotNull,
          reason: '这一格在 HiPER 上是一颗真动作（`TO_DRG`）：横带写着它，键上就得有它的位置');
      expect(shift!.id, 'dis:angleConvert',
          reason: '动作本身应用给不出（见最后一组），所以按 `dis:` 前缀登记——那是本项目'
              '「有这个名字、但做不到」的写法');
      expect(shift.label, 'DRG', reason: '变体的键面文字就是横带里那条提示');
      expect(shift.enabled, isFalse,
          reason: '禁用是拒绝，不是漏做：应用今天没有两向的角度换算，点亮它只会在 RAD 档下'
              '印出一个看起来像答案的错数');

      // 中文：横带里那一格必须是**纯提示**。若它变回第二个按钮，同一个动作就有两个 id 入口，
      //       `键的 id 全局唯一` 那条不变式立刻红。
      // English: the band cell above must be a **plain hint**. Turn it back into a second button and
      //          one action has two id entrances — the id-uniqueness invariant goes red at once.
      final above = located.row.labels[located.index];
      expect(above, isA<ShiftLabel>());
      expect((above! as ShiftLabel).text, 'DRG');
    });

    testWidgets('SHIFT + `DRG` 什么都不做（禁用变体不响应）；不按 SHIFT 时 `DRG` 走的仍是基准',
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

      expect(find.text('RAD'), findsOneWidget,
          reason: 'SHIFT 态下这颗键不执行基准动作（那正是「提示在、动作不在」的可观察形态）：'
              '禁用变体让它整颗失效，档位原地不动');
      expect(find.text('DEG'), findsNothing);
      expect(_displayedExpression(tester), '',
          reason: 'fail closed：屏幕上不出现任何东西，而不是一个猜出来的换算结果');
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

  group('两条拒绝的**到期日**（实测凭据钉在这里，不是写在注释里）：一条已经兑现，一条还没到', () {
    test('应用今天给不出 `TO_DRG`：源单位说不出来，反方向（→ 度）不存在', () {
      // 中文：**这一组是 `dis:angleConvert` 为什么禁用的凭据。** 全部来自本轮跑过的探针
      //       （临时文件，跑完即删）：把这几条送进应用自己的翻译层，看它答什么。
      // English: **this group is the evidence for why `dis:angleConvert` is disabled.** Every row
      //          comes from this round's probe (a temporary file, deleted after the run): the strings
      //          were fed to the app's own translation layer and its answers recorded.
      const refused = <String>[
        '1.5707963268 to deg',
        '90 deg to rad',
        '90 to degrees',
        '1.5707963268 to radians',
      ];
      for (final source in refused) {
        expect(engineExpressionFor(source), isA<UntranslatableExpression>(),
            reason: '「$source」今天过不去翻译层；哪一天它过去了，说明应用有了两向换算，'
                '`DRG` 那一格的禁用就该撤掉');
      }

      // 中文：**反方向那一半是这条拒绝的关键。** `to rad` 过得去、`to deg` 过不去：一个方向的换算
      //       根本不是 HiPER 那颗键做的事（它要选源与目标），而硬做单向版会在 RAD 档下印出错值。
      //       这一条**只钉拒绝**，不钉「`to rad` 可用」——后者是应用现状的另一个事实，不构成本拒绝的
      //       前提，写在这里是为了说明这条不对称的形状。
      // English: **the missing direction is the heart of the refusal.** `to rad` gets through and
      //          `to deg` does not: a one-way conversion is not what HiPER's key does (it asks for a
      //          source and a target), and hand-rolling the one-way version prints a wrong value under
      //          RAD. This test pins the **refusals** only; that `to rad` works is a separate fact
      //          about the app today, noted here to describe the shape of the asymmetry.
      expect(engineExpressionFor('1.5707963268 to deg'),
          isNot(isA<TranslatedExpression>()),
          reason: '「→ 度」这一半不存在：源单位与目标单位都说不出来');
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
