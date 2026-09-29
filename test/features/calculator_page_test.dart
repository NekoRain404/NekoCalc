import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

  testWidgets('复制为 LaTeX：入口在 More 面板里，没有 LaTeX 时如实说而不是复制空串', (tester) async {
    // 中文：**这条钉的是接线那一半。** 「复制的是屏幕上那一份」由 `texFor(resolve(形态))` 决定，
    //       而 `texFor` 本身已经在三处测试里钉住了（含 `decimal` 形态回空串）。这里缺的只有：
    //       **入口在不在**，以及**取不到时必须说话**。
    //
    //       ⚠️ **「复制到一段真 LaTeX」这一支单测证不了**：单测里引擎从不被 mock（整仓一致，
    //       因为 `flutter test` 用的是假引擎——见 `HANDOFF` 里那条铁律），所以这里的每个结果都是
    //       旧解析器给的、`displayTex` 都是空的。那一支**只能在真机上验**，本轮的记录里如实写明。
    //
    //       HiPER 的官方 v12 手册里 `latex` 命中为 **0**，所以这一格是它没有的能力。
    // English: **what this pins is the wiring half.** "It copies what the screen shows" is decided by
    //          `texFor(resolve(form))`, and `texFor` itself is already pinned in three tests (including
    //          `decimal` coming back empty). What is missing here is only: **is there an entry point**,
    //          and **does it speak up when there is nothing to copy**.
    //
    //          ⚠️ **the "a real LaTeX string was copied" branch cannot be proven here**: the engine is
    //          never mocked in unit tests (true across the repository, because `flutter test` runs a fake
    //          engine — see the rule in `HANDOVER.md`), so every result here comes from the legacy parser
    //          and every `displayTex` is empty. That branch **is device-only**, and the round's record
    //          says so.
    //
    //          HiPER's official v12 manual scores **zero** for `latex`, so this is a capability it lacks.
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _openMore(tester);

    expect(find.text('复制为 LaTeX'), findsOneWidget,
        reason: 'More 面板里没有这一格——能力在、入口不在');

    await tester.tap(find.text('复制为 LaTeX'));
    await tester.pumpAndSettle();

    expect(find.text('这一份结果没有 LaTeX'), findsOneWidget,
        reason: '取不到 LaTeX 时应当如实说，而不是弹一句"已复制"');
    expect(copied, isNull,
        reason: '取不到时不该往剪贴板里放任何东西——空串会让用户以为复制成功了');
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
