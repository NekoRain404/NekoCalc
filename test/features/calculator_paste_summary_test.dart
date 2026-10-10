import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_strings.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：粘贴回执（`CalculatorPasteResult.summaryIn`）的两条护栏，外加屏幕那一条。
///
///       ### 它修的是什么
///
///       `summary` 原先是一个 getter，里面直接写着七句中文，而它**真的会上屏**：
///       `calculator_page_sheets.dart` 把它塞进 `SnackBar`。于是英文界面下用户读到的还是中文——
///       这一族里最后一处上屏的中文。
///
///       ### 三条断言各自钉什么
///
///       1. **中文逐字节没变**：七句话与拆分前 getter 里那七条一个字不差，两截附加部分
///          （`'角度模式 DEG'` / `'记忆值 12.5'`）连同中间那个 `' · '` 也逐字节相同。
///          默认语言是中文，所以这一条就是"屏幕上每一个字都和从前一样"的证据本身。
///       2. **判据与文案分家**：七种情形各自落在 [CalculatorPasteSummaryHead] 的哪一格上，
///          是**从 `status`/`hasExpression`/`fromCurrentValue` 判出来的**，不是从任何一句话里
///          比出来的；两种语言下每一格都必须有自己的那句话（两格共用一句 = 两格实际上是一格）。
///       3. **英文界面下屏幕上真的是英文**：真跑一次主屏的「粘贴计算详情」，看那条 `SnackBar`。
///          这条是"用户看得见"的那一半——前两条只保证表本身对。
///
/// English: two guard rails for the paste receipt (`CalculatorPasteResult.summaryIn`) plus the one on
///          screen.
///
///          ### What it fixes
///
///          `summary` used to be a getter holding seven Chinese sentences, and it **really does reach
///          the screen**: `calculator_page_sheets.dart` puts it in a `SnackBar`. So an English
///          interface still showed the user Chinese — the last on-screen Chinese of its family.
///
///          ### What each of the three assertions pins
///
///          1. **The Chinese did not move by one byte**: the seven sentences are character-for-character
///             the seven in the getter before the split, and so are the two appended parts
///             (`'角度模式 DEG'` / `'记忆值 12.5'`) together with the `' · '` between them. The default
///             language is Chinese, so this is the evidence itself that "every character on screen
///             reads as before".
///          2. **Verdict and wording are separate**: which of [CalculatorPasteSummaryHead]'s cells each
///             of the seven cases lands in is judged **from `status`/`hasExpression`/`fromCurrentValue`**,
///             never compared out of a sentence; and under each language every cell needs its own
///             sentence (two cells sharing one = they are really one cell).
///          3. **Under the English interface the screen really is English**: the main screen's "paste
///             calculation details" is actually run and that `SnackBar` is read. This is the
///             user-visible half — the first two only prove the table itself is right.
void main() {
  final han = RegExp(r'[一-鿿㐀-䶿]');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('粘贴回执那张表', () {
    /// 中文：一种情形：怎么造出来、判据落在哪一格、两种语言下那句话各是什么。
    ///       **中文那一栏逐字节照抄拆分前的七条**，不从这里反过来生成。
    /// English: one case: how it is produced, which cell the verdict lands in, and what the sentence
    ///          is under each language. **The Chinese column copies the seven from before the split
    ///          byte for byte** rather than being generated from anything.
    final cases = <({
      String title,
      String clipboard,
      CalculatorPasteSummaryHead head,
      String zh,
      String en,
    })>[
      (
        title: '空剪贴板',
        clipboard: '',
        head: CalculatorPasteSummaryHead.nothingRecognised,
        zh: '剪贴板里没有识别到表达式',
        en: 'No expression recognised in the clipboard',
      ),
      (
        title: '普通表达式',
        clipboard: 'sqrt(81) + 1',
        head: CalculatorPasteSummaryHead.pastedExpression,
        zh: '已粘贴表达式',
        en: 'Expression pasted',
      ),
      (
        title: '报告里的表达式',
        clipboard: '表达式: sin(90)\n结果: 1',
        head: CalculatorPasteSummaryHead.extractedExpression,
        zh: '已从计算详情提取表达式',
        en: 'Expression extracted from the calculation details',
      ),
      (
        title: '报告里的当前值',
        clipboard: '当前值: 1,234.5\n状态: 当前值可继续使用',
        head: CalculatorPasteSummaryHead.restoredCurrentValue,
        zh: '已从计算详情恢复当前值',
        en: 'Current value restored from the calculation details',
      ),
      (
        title: '只有角度模式',
        clipboard: '角度模式: 角度 DEG',
        head: CalculatorPasteSummaryHead.restoredAngle,
        zh: '已恢复角度模式 · 角度模式 DEG',
        en: 'Angle mode restored · Angle mode DEG',
      ),
      (
        title: '只有记忆值',
        clipboard: '记忆值: 12.5',
        head: CalculatorPasteSummaryHead.restoredMemory,
        zh: '已恢复记忆值 · 记忆值 12.5',
        en: 'Memory value restored · Memory 12.5',
      ),
      (
        title: '角度模式与记忆值都有',
        clipboard: '角度模式: 弧度 RAD\n记忆值: 12.5',
        head: CalculatorPasteSummaryHead.restoredAngleAndMemory,
        zh: '已恢复角度模式和记忆值 · 角度模式 RAD · 记忆值 12.5',
        en: 'Angle mode and memory value restored · Angle mode RAD · Memory 12.5',
      ),
    ];

    test('中文逐字节没变：七句话与两截附加部分都和拆分前一样', () {
      for (final item in cases) {
        final paste = CalculatorPasteResult.fromText(item.clipboard);
        expect(paste.summaryHead, item.head, reason: item.title);
        expect(paste.summaryIn(CalculatorPasteStrings.zh), item.zh,
            reason: item.title);
      }
      // 中文：**无参那个 getter 走的就是中文那一份**——它的唯一读者是用户未提交的那条测试，
      //       这里把它与表钉在一起，免得两条路各自漂。
      // English: **the no-argument getter goes through the Chinese entry** — its only reader is the
      //          user's uncommitted test; pinning it to the table here keeps the two roads from
      //          drifting apart.
      for (final item in cases) {
        expect(CalculatorPasteResult.fromText(item.clipboard).summary, item.zh,
            reason: item.title);
      }
    });

    test('英文那一份：与中文一一对应，且一个汉字都没有', () {
      for (final item in cases) {
        final paste = CalculatorPasteResult.fromText(item.clipboard);
        final rendered = paste.summaryIn(CalculatorPasteStrings.en);
        expect(rendered, item.en, reason: item.title);
        expect(han.hasMatch(rendered), isFalse,
            reason: '英文界面上还有汉字：$rendered');
      }
      // 中文：**两格不能共用一句话**：第二种语言里两格撞成一句，说明其中一格是抄错的那一格。
      // English: **two cells may not share one sentence**: if two cells collide in either language,
      //          one of them is the copy that got it wrong.
      for (final strings in <CalculatorPasteStrings>[
        CalculatorPasteStrings.zh,
        CalculatorPasteStrings.en,
      ]) {
        final rendered = <String>{
          for (final item in cases)
            CalculatorPasteResult.fromText(item.clipboard).summaryIn(strings),
        };
        expect(rendered.length, cases.length,
            reason: '有格子共用同一句话：$rendered');
      }
    });

    test('界面那侧的一格指着同一种语言的那一份', () {
      expect(CalculatorStrings.forLanguage(AppLanguage.zh).pasteSummary,
          same(CalculatorPasteStrings.zh));
      expect(CalculatorStrings.forLanguage(AppLanguage.en).pasteSummary,
          same(CalculatorPasteStrings.en));
    });
  });

  group('屏幕上那一条', () {
    testWidgets('英文界面：粘贴详情的回执是英文', (tester) async {
      _mockClipboard('sqrt(81) + 1');
      await tester.pumpWidget(_testApp(language: AppLanguage.en));
      await tester.pumpAndSettle();

      await _startEditing(tester, editLabel: 'Edit expression');
      await tester.tap(find.byTooltip('Paste calculation details'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('Expression pasted'), findsOneWidget);
      expect(find.text('已粘贴表达式'), findsNothing,
          reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

      // 中文：让 SnackBar 自己走完（4 秒），测试结束时不留挂着的定时器。
      // English: let the SnackBar run out (4 seconds) so no timer is left pending at the end.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('默认（中文）界面：同一个动作报的还是原来那句话', (tester) async {
      _mockClipboard('sqrt(81) + 1');
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await _startEditing(tester, editLabel: '编辑表达式');
      await tester.tap(find.byTooltip('粘贴计算详情'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('已粘贴表达式'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}

void _mockClipboard(String text) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    return null;
  });
}

/// 中文：从 `More...` 面板里打开内联编辑器（与 `calculator_page_hiper_engine_test.dart` 里那条
///       同名助手同形；那边的两个面板入口文案是中文，这里要按语言选）。
/// English: opens the inline editor from the `More...` sheet (the same shape as the helper of that name
///          in `calculator_page_hiper_engine_test.dart`; the sheet's entries are Chinese over there and
///          here the language decides).
Future<void> _startEditing(WidgetTester tester, {required String editLabel}) async {
  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(editLabel));
  await tester.pumpAndSettle();
}

Widget _testApp({AppLanguage? language}) {
  final page = Scaffold(
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
        groupThousands: false,
      ),
    ),
  );
  return MaterialApp(
    theme: ThemeData.light(),
    // 中文：**作用域装在 `builder:` 上，与 `app.dart` 逐字同形**——不是包在 `home:` 上。
    //       差别是实测出来的：「More...」面板是 `showModalBottomSheet` 开出来的一条新路由，
    //       它的 context 挂在 **Navigator 之上**，包在 `home:` 里的作用域它看不见，
    //       于是英文界面下那张面板还是中文（第一版就是这么红的）。
    // English: **the scope sits on `builder:`, character for character the way `app.dart` mounts
    //          it**, not wrapped around `home:`. The difference is measured: the `More...` sheet is a
    //          new route opened by `showModalBottomSheet`, whose context hangs **above the Navigator**,
    //          so a scope wrapped around `home:` is invisible to it and that sheet stayed Chinese in
    //          the English interface (how the first version went red).
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: page,
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
