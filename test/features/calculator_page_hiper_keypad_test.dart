import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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

    testWidgets('应用选深色、平台是浅色时主屏用深色主题', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_testApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      final keypad = tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad));
      expect(keypad.background, CalcTheme.roseCream.dark.keypadBackground,
          reason: '应用处于深色模式，主屏必须取深色主题，即使平台报的是浅色');
    });

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
