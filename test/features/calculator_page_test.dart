import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

void main() {
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
      // English: the expression line is rich text via MathExpressionView, so read the widget's
      //          expression instead of asserting with find.text.
      expect(_displayedExpression(tester), 'gcd(');
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

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

Widget _testApp() {
  return MaterialApp(
    home: Scaffold(
      body: CalculatorPage(
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
