import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

void main() {
  testWidgets('CONV 打开单位面板，插进去的单位真的进了表达式', (tester) async {
    // 中文：**键盘上没有字母键，所以这是单位名唯一的入口。** 这条走完整条交互：`CONV` → 面板 →
    //       单位 → `to` → 目标单位 → 关面板 → 表达式行上是那三段文本。断言读的是显示面板自己的
    //       `expression`（表达式行的真源），不是某个渲染片段。
    // English: **the keypad has no letter keys, so this is the only way a unit name gets in.** This runs
    //          the whole interaction: `CONV` → sheet → unit → `to` → target unit → close → the three
    //          pieces are on the expression line. The assertion reads the display's own `expression`
    //          (the source of truth for that line) rather than some rendered fragment.
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    // 中文：**先按 `5`，再开面板** —— 这一步与本仓库的其余测试一样，模拟的是真实按键流。
    //       上一轮漏掉的正是这条：四处验证用的都是手写的带空格字符串，而按键产生的是
    //       `5` + `km` + `to` + `mi` 这样一串相邻插入，不加分隔符会粘成 `5kmtomi`（一个标识符）。
    // English: **press `5` first, then open the sheet** — like the rest of this repository's tests,
    //          this simulates the real keypad flow. That is exactly what the last round missed: every
    //          verification used a hand-written spaced string, while key presses produce a run of
    //          adjacent insertions (`5` + `km` + `to` + `mi`) that glues into `5kmtomi` (one
    //          identifier) without separators.
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONV'));
    await tester.pumpAndSettle();
    expect(find.byType(UnitPickerSheet), findsOneWidget);

    await tester.tap(find.text('km  千米'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mi  英里'));
    await tester.pumpAndSettle();

    // 中文：面板**刻意不自动关**（一次换算要插三样东西），所以这里手动点面板外关掉它。
    // English: the sheet deliberately does **not** close itself (one conversion inserts three pieces),
    //          so it is dismissed here by tapping outside.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MathExpressionView>(find.byType(MathExpressionView).first).expression,
      '5 km to mi',
      reason: '按出来的那一串必须是应用自己的语法读得懂的',
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('tapping the display opens the inline editor at the tapped unit',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '12+34');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    // 中文：显示单元是 '12'、'+'、'34'，第三个单元在原文里的偏移是 3。
    // English: the display units are '12', '+' and '34'; the third one starts at source offset 3.
    final units = find.descendant(
      of: find.byType(MathExpressionView),
      matching: find.byType(GestureDetector),
    );
    expect(units, findsNWidgets(3));
    await tester.tap(units.at(2));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    final editor = tester.widget<TextField>(find.byType(TextField));
    // 中文：点出来的编辑器不抢焦点——用户先定位，再用键盘区或输入法继续输入。
    // English: the editor opened by a tap does not steal focus: the user picks a place first, then
    //          types with the keypad or the IME.
    expect(editor.focusNode?.hasFocus, isFalse);
    expect(
        editor.controller!.selection, const TextSelection.collapsed(offset: 3));
  });

  testWidgets('native editor value and selection synchronize to keypad input',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '12+34',
        selection: TextSelection(baseOffset: 2, extentOffset: 4),
      ),
    );
    await tester.pump();

    // 中文：编辑期间键盘区照常可点，按键写进编辑器里的选区。
    // English: the keypad stays tappable while editing, and its keys write into the editor's
    //          selection.
    await tester.tap(find.text('9', findRichText: true).first);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1294',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.selection,
      const TextSelection.collapsed(offset: 3),
    );
  });

  testWidgets('explicit edit action focuses the inline text editor',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _startEditing(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue);
  });

  testWidgets('losing inline editor focus restores the display panel',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '12+34');

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(MathExpressionView), findsOneWidget);
    expect(_displayedExpression(tester), '12+34');
  });

  testWidgets('cancelling calculator details paste leaves focus loss enabled',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);

    final paste = find.byTooltip('粘贴计算详情');
    final gesture = await tester.startGesture(tester.getCenter(paste));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    FocusManager.instance.primaryFocus!.unfocus();
    // 中文：用 pumpAndSettle 而不是数帧——焦点变更由 FocusManager 延后应用，粘贴手势的抑制/恢复
    //       让这条路径比别的用例多花一帧；要断言的是「失焦后编辑器关闭」，不是帧数。
    // English: settle rather than counting frames — FocusManager applies focus changes a frame late and
    //          the paste gesture's suppress/restore adds one more. What is asserted is that focus loss
    //          closes the editor, not how many frames it takes.
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(MathExpressionView), findsOneWidget);
  });

  testWidgets('block navigation is reachable from the display controls',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _openMore(tester);

    expect(
      find.byTooltip('光标左移（长按按表达式块左移后连续移动）'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('光标右移（长按按表达式块右移后连续移动）'),
      findsOneWidget,
    );
  });

  testWidgets('explicit calculator details paste restores expression state',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {
          'text': '''
表达式: sin(90)
结果: 1
状态: 结果可继续使用
角度模式: 角度 DEG
记忆值: 12.5
''',
        };
      }
      return null;
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);

    await tester.tap(find.byTooltip('粘贴计算详情'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'sin(90)',
    );

    // 中文：先退出编辑再看元数据——角度模式 chip 现在由显示面板唯一提供（旧标题行与旧工具条都已删除），
    //       记忆读数住在 More... 面板里。
    // English: leave the editor before checking the restored metadata — the angle-mode chip now has a
    //          single source (the display panel; the old title row and toolbar are gone) and the
    //          memory reading lives in the `More...` sheet.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('DEG'), findsOneWidget);

    await _openMore(tester);
    expect(find.textContaining('M 12.5'), findsOneWidget);
  });

  testWidgets('current value calculator report pastes a valid expression',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {
          'text': '''
当前值: 42
状态: 当前值可继续使用
角度模式: 角度 DEG
记忆值: 7.5
''',
        };
      }
      return null;
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);

    await tester.tap(find.byTooltip('粘贴计算详情'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '42',
    );

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('DEG'), findsOneWidget);

    await _openMore(tester);
    expect(find.textContaining('M 7.5'), findsOneWidget);
  });

  testWidgets('memory-only report confirms restored metadata', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': '记忆值: 7.5'};
      return null;
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);

    await tester.tap(find.byTooltip('粘贴计算详情'));
    await tester.pumpAndSettle();

    expect(find.text('已恢复记忆值 · 记忆值 7.5'), findsOneWidget);

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    await _openMore(tester);
    expect(find.textContaining('M 7.5'), findsOneWidget);
  });

  testWidgets('copy result reports clipboard write errors', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') throw StateError('unavailable');
      return null;
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _openMore(tester);
    await tester.tap(find.text('复制结果'));
    await tester.pumpAndSettle();

    expect(find.text('无法复制计算详情'), findsOneWidget);
    expect(find.byType(MathExpressionView), findsOneWidget);
  });

  testWidgets('calculator details paste reports clipboard errors unchanged',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') throw StateError('unavailable');
      return null;
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '12+34');

    await tester.tap(find.byTooltip('粘贴计算详情'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '12+34',
    );
    expect(find.text('无法读取剪贴板'), findsOneWidget);
  });

  testWidgets('display actions move the cursor to expression start and end',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '12');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    await _openMore(tester);
    await tester.tap(find.text('移到开头'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9', findRichText: true).first);
    await tester.pump();

    await _openMore(tester);
    await tester.tap(find.text('移到末尾'));
    await tester.pumpAndSettle();
    await _startEditing(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '912',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.selection,
      const TextSelection.collapsed(offset: 3),
    );
  });

  testWidgets('held character arrow repeats and stops on pointer up',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '12+34');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    await _openMore(tester);
    final arrow = find.byTooltip('光标左移（长按按表达式块左移后连续移动）');
    final gesture = await tester.startGesture(tester.getCenter(arrow));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 350));
    await gesture.up();
    await tester.pump();

    // 中文：长按结束后关掉面板（点面板外的遮罩），再用键盘区输入，验证光标停在被长按移到的位置。
    // English: dismiss the sheet by tapping its barrier, then type on the keypad to check where the
    //          held arrow left the cursor.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('9', findRichText: true).first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('8', findRichText: true).first);
    await tester.pump();

    expect(_displayedExpression(tester), '9812+34');
  });

  testWidgets('320dp main screen keeps every editing action reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _openMore(tester);
    expect(tester.takeException(), isNull);

    for (final label in [
      '编辑表达式',
      '退格',
      '撤销',
      '重做',
      '复制结果',
      '保存笔记',
      '移到开头',
      '移到末尾',
      'MR',
      'MC',
      'M−',
      'M+',
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
    expect(
      find.byTooltip('光标左移（长按按表达式块左移后连续移动）').hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byTooltip('光标右移（长按按表达式块右移后连续移动）').hitTestable(),
      findsOneWidget,
    );
  });

  group('HiPER 式主屏', () {
    testWidgets('数字键与函数键同时可见，无需切页', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      expect(find.text('7'), findsWidgets);
      expect(find.text('sin'), findsWidgets);
    });

    testWidgets('主屏没有纵向滚动容器', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
        ),
        findsNothing,
        reason: '主屏不得出现纵向滚动（当前有 211dp 溢出）',
      );
    });

    testWidgets('点数字键把数字写进表达式', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('7').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), contains('7'));
    });

    testWidgets('按 SHIFT 后 sin 执行 sin⁻¹', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIFT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('sin').first);
      await tester.pumpAndSettle();
      expect(_displayedExpression(tester), contains('asin'));
    });

    testWidgets('SHIFT 按一次就复位，hyp 需要再点一次才退出', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      // 中文：SHIFT 是一次性修饰态——按过一个键（7）之后就复位，sin 执行基准的 sin 而不是 sin⁻¹。
      // English: SHIFT is one-shot — after one key (7) it clears, so sin runs the base sin, not sin⁻¹.
      await tap('SHIFT');
      await tap('7');
      await tap('sin');
      expect(_displayedExpression(tester), 'sin(7)');

      // 中文：hyp 是持续态——连按两次 sin 都执行 sinh，中间没有退出修饰态。
      // English: hyp latches — two sin presses both run sinh, with no exit in between.
      await tap('AC');
      await tap('7');
      await tap('hyp');
      await tap('sin');
      expect(_displayedExpression(tester), 'sinh(7)');
      await tap('sin');
      expect(_displayedExpression(tester), 'sinh(sinh(7))');

      // 中文：再点一次 hyp 才退出，sin 回到基准行为。
      // English: only a second hyp tap leaves it, after which sin is plain again.
      await tap('hyp');
      await tap('sin');
      expect(_displayedExpression(tester), 'sin(sinh(sinh(7)))');

      // 中文：SHIFT 与 hyp 互斥——点了 SHIFT 之后 hyp 态必须消失，这一按走 sin⁻¹。
      // English: SHIFT and hyp are mutually exclusive — a SHIFT tap clears hyp, and this press runs
      //          sin⁻¹.
      await tap('hyp');
      await tap('SHIFT');
      await tap('sin');
      expect(_displayedExpression(tester), 'asin(sin(sinh(sinh(7))))');
    });

    testWidgets('OTHER 打开更多函数，选中项写进表达式', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // 中文：OTHER 是 HiPER 给「键盘放不下的函数」留的入口，打开的是更多函数面板。
      // English: OTHER is HiPER's entry point for the functions the keypad cannot fit, so it opens the
      //          more-functions sheet.
      await tester.tap(find.text('OTHER').first);
      await tester.pumpAndSettle();
      expect(find.text('gcd'), findsOneWidget);
      expect(find.text('log₂'), findsOneWidget);

      await tester.tap(find.text('gcd'));
      await tester.pumpAndSettle();

      // 中文：表达式行由 MathExpressionView 渲染成富文本，所以读组件的 expression，不用 find.text。
      //       `gcd(,)` 而不是 `gcd(`：二元调用现在把右括号一起补上（不补的话表达式永远停在
      //       未闭合状态，解析器把它降级成字面文本），光标落在第一个空槽里，也就是 `(` 之后。
      // English: the expression line is rich text via MathExpressionView, so read the widget's
      //          expression instead of asserting with find.text. It is `gcd(,)` rather than `gcd(`:
      //          a binary call now writes its closing bracket too (without it the expression stays
      //          unclosed and the parser degrades it to literal text), and the caret goes into the
      //          first empty slot, i.e. just after the `(`.
      expect(_displayedExpression(tester), 'gcd(,)');
    });

    testWidgets('× 与 ÷ 走控制器的运算符，而不是 ASCII 插入', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      // 中文：键位表的 id 是 ASCII `*`/`/`，而控制器只把 `×`/`÷` 当运算符。若少了这层换算，
      //       `+` 之后的 `×` 会被当成普通字符插入，得到 `5+*3` 并解析失败——这里钉住的是折叠行为。
      // English: the key table's ids are ASCII `*`/`/` while the controller treats only `×`/`÷` as
      //          operators. Without that translation a `×` after `+` is inserted as a plain character,
      //          giving `5+*3` and a parse error — this pins the collapsing behaviour instead.
      await tap('5');
      await tap('+');
      await tap('×');
      await tap('3');
      expect(_displayedExpression(tester), '5×3');

      // 中文：开头的运算符被忽略——空显示时按 `×` 什么也不写进去。
      // English: a leading operator is ignored — `×` on an empty display writes nothing.
      await tap('AC');
      await tap('×');
      expect(_displayedExpression(tester), '');

      // 中文：除法同理。
      // English: division behaves the same way.
      await tap('8');
      await tap('÷');
      await tap('2');
      expect(_displayedExpression(tester), '8÷2');
    });

    testWidgets('继续使用把结果替换成表达式，不可用时置灰', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      // 中文：显示区与「复制结果」的报告文本都会写着「结果可继续使用」，所以面板里必须有对应入口；
      //       它替换而不是追加表达式（追加是 `ans` 的行为），两者不等价。
      // English: the display's report text says the result can be reused, so the sheet must offer it.
      //          It replaces the expression rather than appending (`ans` appends); the two are not
      //          equivalent.
      await tap('1');
      await tap('2');
      await tap('+');
      await tap('3');
      await tap('4');
      await tap('✓');

      await _openMore(tester);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '继续使用'))
            .onPressed,
        isNotNull,
      );
      await tap('继续使用');
      expect(_displayedExpression(tester), '46');

      // 中文：出错时结果不可继续使用，入口置灰（与撤销/重做同一套 enabled 门控）。
      // English: with an error the entry is greyed out, the same enabled-gating undo/redo use.
      await tap('AC');
      await tap('1');
      await tap('+');
      await tap('✓');
      await _openMore(tester);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '继续使用'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('记忆读数按设置的千分位格式化', (tester) async {
      // 中文：控制器显示结果（:530）与导出文本（:544）都按 settings.groupThousands 格式化，记忆读数
      //       也照办——重写前的记忆条唯独漏了它。12345 正是能区分两种格式的值。
      // English: the controller formats the result (:530) and the exported report (:544) per
      //          settings.groupThousands, and the memory reading follows suit — the pre-rewrite bar was
      //          the one place that ignored it. 12345 is what separates the two formats.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': '记忆值: 12345'};
        return null;
      });
      await tester.pumpWidget(_testApp(groupThousands: true));
      await tester.pumpAndSettle();
      await _startEditing(tester);
      await tester.tap(find.byTooltip('粘贴计算详情'));
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      await _openMore(tester);

      expect(find.text('M 12,345'), findsOneWidget);
    });

    // 中文：明暗必须跟着**应用自己的**主题模式走。`app.dart` 用设置里的浅色/深色/跟随系统驱动
    //       `MaterialApp.themeMode`，所以生效的明暗在 `Theme.of(context).brightness` 里；平台亮度
    //       （`MediaQuery.platformBrightness`）是另一件事。用户选了浅色、手机却是深色模式时两者相反，
    //       按平台亮度取色会让本页与其它页面各穿一套皮。
    // English: light/dark must follow the **app's own** theme mode. `app.dart` drives
    //          `MaterialApp.themeMode` from the 浅色/深色/跟随系统 setting, so the effective brightness
    //          lives in `Theme.of(context).brightness`; the platform's
    //          (`MediaQuery.platformBrightness`) is a different thing. With 浅色 chosen on a dark-mode
    //          phone the two disagree, and resolving from the platform dresses this page in a different
    //          skin from every other page.
    testWidgets('应用选浅色、平台是深色时主屏用浅色主题', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_testApp(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      final keypad = tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad));
      expect(keypad.background, CalcTheme.roseCream.keypadBackground,
          reason: '应用处于浅色模式，主屏必须取浅色主题，即使平台报的是深色');
      expect(keypad.background, isNot(CalcTheme.roseCream.dark.keypadBackground));
    });

    // 中文：反向也要成立——平台报浅色而应用选了深色时，主屏必须是深色主题。两条一起才说明取的是
    //       应用生效的明暗，而不是「永远用浅色」。
    // English: the reverse has to hold too — platform light while the app is in dark mode must give the
    //          dark theme. Only both directions together show the resolution reads the app's effective
    //          brightness rather than always answering light.
    testWidgets('应用选深色、平台是浅色时主屏用深色主题', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_testApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      final keypad = tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad));
      expect(keypad.background, CalcTheme.roseCream.dark.keypadBackground,
          reason: '应用处于深色模式，主屏必须取深色主题，即使平台报的是浅色');
    });

    // 中文：HiPER 的 `x→M` 是把当前值**写进**记忆寄存器（替换），不是累加。控制器只有累加的
    //       `memoryAdd`，所以 `_pressKey` 先清空再累加。这条钉住用户看得见的结果：记忆里先有 12.5，
    //       再对当前值 7 按 `x→M`，读数必须是 7，而不是 19.5。
    // English: HiPER's `x→M` *writes* the current value into the memory register (replacing it), it does
    //          not accumulate. The controller only offers the accumulating `memoryAdd`, so `_pressKey`
    //          clears first. This pins what the user sees: with 12.5 already in the register, `x→M` on a
    //          current value of 7 must read 7, not 19.5.
    testWidgets('x→M 替换记忆值而不是累加', (tester) async {
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

      await tester.tap(find.text('7').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('x→M').first);
      await tester.pumpAndSettle();

      await _openMore(tester);
      expect(find.text('M 7'), findsOneWidget,
          reason: 'x→M 必须把记忆值替换成当前值 7，而不是累加成 19.5');
      expect(find.text('M 19.5'), findsNothing);
    });

    // 中文：**这一步的红证据**（不修就红）。`M+`/`M−` 拒绝一个装不进 double 的值时，用户必须被告知：
    //       以前这里是彻底的静默——寄存器没动、屏幕上也没有任何提示，看起来像按键失灵。
    //
    //       这条走真实按键流：先粘贴一份只带「记忆值: 12.5」的报告（寄存器里有东西，拒绝才不会与
    //       「本来就没反应」混为一谈），再把表达式换成 `10^400`（旧求值器连有限值都给不出，于是
    //       `_currentNumericValue()` 给 null；引擎在 `flutter test` 里没有原生侧，走的正是回落那条路），
    //       然后按 `M+`。断言是**看得见**（`hitTestable`）而不是「树上存在」——被面板盖住的消息也在树上。
    //
    //       最后一条断言（寄存器仍是 12.5）是这句话的另一半：拒绝必须是值中性的。
    // English: **the red proof for this step** (red without the fix). When `M+`/`M−` refuse a value that
    //          does not fit a double the user has to be told: this used to be total silence — the
    //          register did not move and the screen said nothing, which reads as a dead key.
    //
    //          The real key flow: paste a report carrying only 「记忆值: 12.5」 (the register holds
    //          something, so a refusal cannot be confused with "nothing to do anyway"), put `10^400` in
    //          the expression (the legacy evaluator cannot produce a finite value from it, so
    //          `_currentNumericValue()` gives null; there is no native side under `flutter test`, which
    //          is exactly the fallback route), then press `M+`. The assertion is **visibility**
    //          (`hitTestable`), not "present in the tree" — a message hidden behind the sheet is still
    //          in the tree.
    //
    //          The last assertion (the register still holds 12.5) is the other half of that sentence:
    //          a refusal has to be value-neutral.
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

    // 中文：同一次拒绝，从 `More...` 面板里按 `M+` 也要看得见。面板盖着屏幕底部那一条，而消息落在
    //       那一条上的 `SnackBar` 里——面板不让开，这句话就是隐形的（量过：面板 y=418..600、
    //       `SnackBar` y=552..600，被盖住的消息 `hitTestable()` 为 0）。所以这条同时断言两件事：
    //       **面板收掉了**、**那句话看得见**。成功时不收面板由上面那条「面板里的记忆读数原地更新」
    //       的行为守着（`x→M 替换记忆值而不是累加` 走的正是面板里的读数）。
    // English: the same refusal reached from the `More...` sheet has to be visible too. The sheet
    //          covers the bottom strip of the screen and the message lands on the `SnackBar` in that
    //          same strip — with the sheet in place the sentence is invisible (measured: sheet
    //          y=418..600, `SnackBar` y=552..600, and a covered message has `hitTestable()` 0). So this
    //          asserts both halves: **the sheet is gone** and **the sentence is visible**. That the
    //          sheet stays put on success is guarded by the test above (its memory reading updates in
    //          place, which is the sheet's own promise).
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

    // 中文：本计划的核心承诺是「改键位表，别的地方不用动」，而这条承诺此前没有任何测试守着——
    //       `×`/`÷` 的 id 与主屏分派对不上，就是这么上的真机。这里逐格走整张表，把每个已启用的 id
    //       真的派发给主屏，并断言它**没有**被当成字面量写进表达式：没接住的 id 会落到 `default`，
    //       由 `_insert` 原样插进去，表达式就等于那个 id 本身。
    // English: the plan's central promise is "edit the table, change nothing else", and nothing guarded
    //          it — which is how the `×`/`÷` id mismatch reached the device. This walks the whole table
    //          cell by cell, dispatching every enabled id to the screen, and asserts it was **not** typed
    //          in as literal text: an unwired id falls to `default`, `_insert` writes it verbatim, and
    //          the expression becomes that id itself.
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

    // 中文：新点亮的那七颗引擎键（Σ / Π / ∫dx / d/dx / lim / logₓy / ran#）各自要交出的证据，
    //       分三层，缺一层都不算数：
    //
    //       1. **派发**——按键落进表达式，且文本是预期的样子（含补出来的右括号）；
    //       2. **排版**——这段表达式经 `ExpressionAstParser` + `TexEmitter` 之后，产物里没有
    //          `\text{…}`，也就是**没有**降级成字面文本（真机上 `sqrt(8` 显示成灰色字母，就是
    //          这条路走出来的），而且渲染器自己的解析器（`MathExpressionView.typesetsTex`，
    //          与结果行同一个判断）认它；
    //       3. **渲染**——真把组件树建出来：表达式那一行的 `MathExpressionView` 底下找不到那个
    //          承载降级文本的 `Text`，也就是屏幕上画的是公式而不是字母。
    //
    //       第二、三层都要：`typesetsTex` 只问解析器，画不画得出来是渲染阶段的事（`Math.tex` 的
    //       `onErrorFallback` 是那一道兜底）；反过来只看组件树则分不清"排出来了"和"恰好没抛"。
    // English: The evidence each of the seven newly lit engine keys (Σ / Π / ∫dx / d/dx / lim /
    //          logₓy / ran#) has to produce, in three layers — none of them alone is enough:
    //
    //          1. **dispatch** — the press reaches the expression and the text is what it should be
    //             (closing bracket included);
    //          2. **typesetting** — run through `ExpressionAstParser` + `TexEmitter`, the output
    //             holds no `\text{…}`, i.e. it did **not** degrade to literal text (the grey
    //             `sqrt(8` seen on a device comes out of exactly that path), and the renderer's own
    //             parser accepts it (`MathExpressionView.typesetsTex`, the same judgement the result
    //             line makes);
    //          3. **rendering** — the widget tree is really built: no `Text` carrying the fallback
    //             text exists under the expression line's `MathExpressionView`, so what is drawn is
    //             a formula rather than letters.
    //
    //          Layers two and three are both needed: `typesetsTex` asks the parser only, while
    //          whether it draws is a render-stage question (`Math.tex`'s `onErrorFallback` is that
    //          safety net); and the widget tree alone cannot tell "it typeset" from "it merely did
    //          not throw".
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

    // 中文：**`CPLX` / `STAT`（本轮点亮的两颗键）的证据，比上一条多一层：面板。**
    //       这两颗键的动作是「打开一个面板，从面板里取一个记号」，所以只有三层是不够的——
    //       「按了面板里那一格之后表达式是什么」必须真的走一遍组件树，而不是靠读代码推断。
    //       四层：**开面板**（面板真的出现在树里）→ **派发**（按完之后表达式是那个形状）→
    //       **排版**（没有降级成 `\text{…}`，且渲染器的解析器认它）→ **渲染**（屏幕上画的是公式
    //       而不是字母）。
    //
    //       预期值里的 `()` 与 `(1,2,3,4)` 都是**实测**的：复数那四颗是**一元函数**，走
    //       `applyUnaryFunction`，表达式为空时它给出的是 `name()`（空槽留给用户填，与 `sin`/`abs`
    //       逐字同一条路）；统计那四颗插的是**完整**调用，理由写在主屏那份派发注释里。
    // English: **the evidence for `CPLX` / `STAT` (the two keys lit this round) has one layer more than
    //          the test above: the sheet.** These two keys act by "open a sheet, take a token from
    //          it", so three layers are not enough — "what the expression is after the press" has to
    //          really travel the widget tree rather than be inferred from reading the code. Four
    //          layers: **open the sheet** (it really appears in the tree) → **dispatch** (the
    //          expression afterwards is that shape) → **typesetting** (not degraded to `\text{…}`, and
    //          the renderer's own parser accepts it) → **rendering** (what is drawn is a formula, not
    //          letters).
    //
    //          The `()` and `(1,2,3,4)` in the expectations are **measured**: the four complex ones are
    //          **unary functions** going through `applyUnaryFunction`, which yields `name()` on an empty
    //          expression (the empty slot is left for the user, byte for byte the path `sin`/`abs`
    //          take), while the four statistics ones insert a **complete** call, for the reason written
    //          in the screen's dispatch note.
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

    // 中文：**填满实参之后的形状**——上面那条钉的是「按下去得到一个空槽」，这一条钉的是那几颗键
    //       各自的典型用法，也就是面板那句「实参是一份起手数据，改成你自己的」所指向的东西。
    //       期望的 TeX 是**实测**的（`TexEmitter` 对未知函数名一律回退到 `\operatorname`，
    //       名字保持正体、绝不与实参粘连，见 `tex_emitter.dart` 的 `_call`），在这里写死是为了
    //       让「形状变了」这件事有人接着——只断言 `typesetsTex` 的话，`\operatorname{mean}` 换成
    //       别的写法也照样绿。
    // English: **the shape once the arguments are filled in** — the test above pins "a press yields an
    //          empty slot", this one pins each key's typical use, which is what the sheet's "the
    //          arguments are a starting sample, edit them" sentence points at. The expected TeX is
    //          **measured** (`TexEmitter` falls back to `\operatorname` for every unknown function
    //          name, upright and never glued to the arguments — see `_call` in `tex_emitter.dart`);
    //          spelling it out here means somebody is told when the shape changes — asserting
    //          `typesetsTex` alone would stay green if `\operatorname{mean}` became something else.
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

    // 中文：上面那条证明的是"按下去之后的东西排得出来"，这一条证明**填满实参之后**同样排得出来，
    //       而且形状是那个符号专属的形状（积分号、求和号、上下限）而不是前置函数名。这些表达式
    //       正是五个键各自的典型用法，`qalc` 5.12.0 上逐条实测过求值结果（见步骤 5 报告）。
    // English: the test above shows what a press produces typesets; this one shows that the same
    //          holds **once the arguments are filled in**, and that the shape is the symbol's own
    //          (an integral sign, a summation sign, bounds) rather than a prefix function name.
    //          These expressions are each key's typical use and were evaluated one by one with
    //          `qalc` 5.12.0 (see the step 5 report).
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
