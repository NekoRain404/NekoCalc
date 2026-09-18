import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/platform/app_haptics.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';
import 'package:nekocalc/features/settings/presentation/settings_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：滚到目标再点。设置页长于测试视口（800×600），直接 `tap` 会点在屏幕外。
/// English: Scroll to the target, then tap. The settings page is taller than the test viewport
///          (800×600) and a bare `tap` would land off-screen.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 中文：滚到目标并**让它真的落在视口里**。`scrollUntilVisible` 末尾虽然会调
///       `Scrollable.ensureVisible`，但它不 pump：紧随其后的 `tap()` 会拿着滚动前的坐标。
/// English: Scroll to the target and **actually land it in the viewport**.
///          `scrollUntilVisible` ends by calling `Scrollable.ensureVisible` but never pumps, so an
///          immediately following `tap()` would use the pre-scroll position.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300,
      scrollable: find.byType(Scrollable));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required AppDatabase db,
  required AppLanguage language,
  ValueChanged<String>? onThemeChanged,
  ValueChanged<String>? onLanguageChanged,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: AppLanguageScope(
      language: language,
      child: SettingsPage(
        db: db,
        onThemeChanged: onThemeChanged,
        onLanguageChanged: onLanguageChanged,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('主题配色在 CalcTheme.all 里循环，落库的是 id 而不是名字', (tester) async {
    final db = _FakeDatabase();
    final notified = <String>[];
    await _pumpSettings(tester,
        db: db, language: AppLanguage.zh, onThemeChanged: notified.add);

    expect(find.text('玫瑰奶霜'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('主题配色'));
    expect(db.savedSettings['theme_id'], CalcTheme.lavenderMist.id);
    expect(db.savedSettings['theme_id'], 'lavenderMist');
    expect(find.text('薰衣草雾'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('主题配色'));
    expect(db.savedSettings['theme_id'], 'peachSugar');
    expect(find.text('蜜桃砂糖'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('主题配色'));
    expect(db.savedSettings['theme_id'], 'roseCream', reason: '三套转完回到第一套');

    expect(notified, ['lavenderMist', 'peachSugar', 'roseCream']);

    // 中文：落库的是 id，**不是** `CalcTheme.name`（那是给人看的、可翻译的标签）。
    //       两者混用会让主题改名就等于改存储格式。
    // English: What is stored is the id, **not** `CalcTheme.name`, which is a human-facing,
    //          translatable label. Conflating them would make renaming a theme a storage-format
    //          change.
    expect(db.savedSettings.values, isNot(contains('薰衣草雾')));
  });

  testWidgets('语言在 zh / en 之间循环，落库的是 code 而不是自称', (tester) async {
    final db = _FakeDatabase();
    final notified = <String>[];
    await _pumpSettings(tester,
        db: db, language: AppLanguage.zh, onLanguageChanged: notified.add);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('语言'));
    expect(db.savedSettings['language'], 'en');
    // 中文：语言的名字用**自称**（endonym）：`en` 在屏幕上写 `English` 而不是 `英语`。点名
    //       "不是 英语"——只断言 `English` 存在的话，一个"把 endonym 换成译文"的实现照样会过。
    //       这一格显示的是当前选中项，所以切到 en 之后它就该是 `English`。
    // English: A language names itself with its **endonym**: `en` reads `English`, not `英语`. The
    //          negative half is spelled out on purpose — asserting only that `English` exists would
    //          still pass for an implementation that translated the endonym. This cell shows the
    //          current selection, so after switching to `en` it must read `English`.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('英语'), findsNothing);
    // 中文：界面语言由作用域决定，而本测试的作用域固定是 zh，所以标题仍是 `语言`——这一条同时
    //       证明了"落库"与"生效"是两件事：写进库不改变这一帧的界面语言。
    // English: The UI language comes from the scope, which this test pins to zh, so the row title is
    //          still `语言`. That also shows persistence and effect are two separate things: writing
    //          to storage does not change this frame's UI language.
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await _scrollToAndTap(tester, find.text('语言'));
    expect(db.savedSettings['language'], 'zh');
    expect(find.text('中文'), findsOneWidget);
    expect(notified, ['en', 'zh']);
  });

  testWidgets('切到英文后界面文案跟着变', (tester) async {
    final db = _FakeDatabase();
    await _pumpSettings(tester, db: db, language: AppLanguage.en);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme mode'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Back'), findsNothing, reason: 'tooltip 不是可见文本');

    // 中文：**这一条从前钉的是那个缺口**：`CalcTheme.name` 只有中文，英文界面下这一格仍写着
    //       「玫瑰奶霜」（旧注释原话是"本轮已知的可见缺口"）。本轮把三个名字 × 两种语言补进了
    //       `SettingsStrings`，于是这一条翻转成缺口关闭的证据，并在中文侧要求仍是 `CalcTheme.name`
    //       （`settings_strings_test.dart` 里那条逐套主题的断言钉着这件事）。
    // English: **this used to pin the gap**: `CalcTheme.name` was Chinese-only, so the cell still read
    //          「玫瑰奶霜」 in an English interface (the old note called it a known, visible gap). This
    //          round put the three names × two languages into `SettingsStrings`, so this flips into the
    //          evidence that the gap is closed; the Chinese side is still required to equal
    //          `CalcTheme.name` (pinned theme by theme in `settings_strings_test.dart`).
    expect(find.text('Rose Cream'), findsOneWidget);
    expect(find.text('玫瑰奶霜'), findsNothing);
  });

  /// 中文：**本轮最关键的一条**。设置里有一批字段的值本身就是中文，它们被持久化、被 `==` 比较、
  ///       被 `fromMap` 按字面值迁移。翻译界面时把它们一起翻了，用户库里的 `'跟随系统'` 立刻
  ///       对不上，而且不会有任何报错。
  ///       这条测试对每种语言各跑一遍同样的操作序列，要求落库的每一个字节都相同；同时又要求
  ///       屏幕上显示的话**确实不同**——否则测试是空的（语言根本没切）。
  /// English: **The single most important test of this round.** Several settings fields have Chinese
  ///          *values* that are persisted, compared with `==`, and migrated by `fromMap` on their
  ///          literal text. Translating them along with the UI would immediately desynchronise the
  ///          `'跟随系统'` already in a user's database, with no error anywhere.
  ///          This runs the same sequence of taps once per language and requires every persisted byte
  ///          to match, while also requiring the on-screen labels to **actually differ** — otherwise
  ///          the test would be vacuous (the language never switched).
  testWidgets('切换语言前后，所有持久化值逐字节不变', (tester) async {
    final persisted = <AppLanguage, Map<String, String>>{};
    final shownTitles = <AppLanguage, String>{};

    for (final language in AppLanguage.values) {
      final db = _FakeDatabase();
      await _pumpSettings(tester, db: db, language: language);
      final s = SettingsStrings.forLanguage(language);

      // 中文：**先**证明这一轮的语言真的生效了，再动任何东西。页面标题在列表第一行，此刻必然
      //       在树里；等下面那轮把列表滚到底，它会连同其它滚出缓存区的行一起被 `ListView` 销毁，
      //       而 `scrollUntilVisible` 只朝一个方向滚，回不去。
      // English: Prove the language for this pass really took effect **first**, before touching
      //          anything. The page title is the list's first row and is certainly in the tree now;
      //          once the loop below scrolls to the bottom it is disposed along with every other row
      //          leaving the cache extent, and `scrollUntilVisible` only scrolls one way — there is no
      //          way back.
      expect(find.text(s.pageTitle), findsOneWidget,
          reason: '${language.code} 下页面标题应是「${s.pageTitle}」');
      if (language == AppLanguage.zh) {
        expect(find.text('设置'), findsOneWidget);
      } else {
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('设置'), findsNothing, reason: '英文界面里不该还留着中文标题');
      }
      shownTitles[language] = s.pageTitle;

      // 中文：令牌 → 标签的映射也必须随语言变——否则"界面换了"可能只是标题换了，底下那些
      //       开关显示的其实还是令牌本身。这里逐语言点名期望值：中文下标签**恰好等于**令牌
      //       （`'浅色'`），英文下必须换成 `Light`。前一条不是笔误，是本项目最容易踩的那个巧合，
      //       测试把它显式写出来，读者一眼就能看见"这里相等是故意的"。
      // English: The token → label mapping must move with the language too; otherwise "the UI
      //          switched" could mean only the title switched while the rows below still showed
      //          tokens. Each language names its expected value: in Chinese the label **happens to
      //          equal** the token (`'浅色'`), in English it must become `Light`. The first is not a
      //          typo — it is the coincidence this project is most likely to trip over, written out so
      //          a reader sees at a glance that the equality is deliberate.
      final captionForToken = s.themeModeLabel(SettingsTokens.themeModeLight);
      expect(
        captionForToken,
        switch (language) {
          AppLanguage.zh => '浅色',
          AppLanguage.en => 'Light',
        },
      );

      // 中文：顺序和次数对每种语言都一样，走完六个会落库的循环项。
      // English: Same order and count for every language, over the six cycling rows that persist.
      for (final title in [
        s.themeModeTileTitle,
        s.themeTileTitle,
        s.angleModeTileTitle,
        s.decimalPlacesTileTitle,
        s.expressionDisplayTileTitle,
        s.hapticStrengthTileTitle,
      ]) {
        await _scrollToAndTap(tester, find.text(title));
      }

      persisted[language] = Map<String, String>.from(db.savedSettings);
      // 中文：每种语言都从零开始，避免上一种语言的写入串到这一种。
      // English: Each language starts from scratch so the previous one's writes cannot bleed in.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    final zh = persisted[AppLanguage.zh]!;
    final en = persisted[AppLanguage.en]!;

    // —— 逐字节不变 ——
    expect(en.keys.toSet(), zh.keys.toSet(),
        reason: '两个语言写下的键集合必须一致，多一个少一个都是分叉');
    for (final key in zh.keys) {
      expect(en[key], zh[key], reason: '键 `$key` 的持久化值在切换语言后必须逐字节相同');
    }

    // —— 落库的就是那几个令牌，不是任何标签 ——
    expect(zh, {
      'theme_mode': SettingsTokens.themeModeLight,
      'theme_id': CalcTheme.lavenderMist.id,
      'angle_mode': SettingsTokens.angleModeDegrees,
      'digits': SettingsTokens.digits8,
      'expression_display': SettingsTokens.expressionDisplayMath,
      'haptic_strength': AppHaptics.strong,
    });
    // 中文：再钉一次**字面量本身**，而不是常量名——常量哪天被改掉，上面那张表跟着一起改，
    //       这两行不会：它们要的就是"库里躺着的汉字节".
    //       每个循环项各走一格：跟随系统→浅色 / 弧度→角度 / 6 位→8 位 / 数学符号→数学表达式 /
    //       标准→强。
    // English: Pins the **literals themselves**, not the constant names: were a constant changed, the
    //          map above would change with it while these lines would not — and these are the Chinese
    //          bytes that must sit in storage. Each cycling row advances one step: 跟随系统→浅色,
    //          弧度→角度, 6 位→8 位, 数学符号→数学表达式, 标准→强.
    expect(zh['theme_mode'], '浅色');
    expect(zh['theme_id'], 'lavenderMist');
    expect(zh['angle_mode'], '角度');
    expect(zh['digits'], '8 位');
    expect(zh['expression_display'], '数学表达式');
    expect(zh['haptic_strength'], '强');

    // —— 但屏幕上那句话确实换了，否则上面那些比较是空的 ——
    expect(shownTitles[AppLanguage.zh], '设置');
    expect(shownTitles[AppLanguage.en], 'Settings');
    expect(shownTitles[AppLanguage.zh], isNot(shownTitles[AppLanguage.en]));
  });

  testWidgets('百分比计算在 direct / relative 之间循环，落库的是 ASCII 令牌', (tester) async {
    // 中文：这一项的两个令牌是 ASCII（`'direct'` / `'relative'`），与主题 `id`、语言 `code`
    //       同一类。屏幕上写的是「直接」/「相对」，库里的两个字节必须是令牌——翻译界面时
    //       跟着翻掉，用户库里已经存好的值会静默变成默认值，没有任何报错。
    // English: this one's two tokens are ASCII (`'direct'` / `'relative'`), the same kind of thing as a
    //          theme `id` or a language `code`. The screen says 「直接」/「相对」 while the bytes in the
    //          database must be the token — translated along with the interface, a stored value silently
    //          becomes the default with no error anywhere.
    final db = _FakeDatabase();
    await _pumpSettings(tester, db: db, language: AppLanguage.zh);

    expect(find.text('百分比计算'), findsOneWidget);
    expect(find.text('直接'), findsOneWidget, reason: '默认是 direct');
    expect(db.savedSettings, isEmpty, reason: '没点就不写');

    await _scrollToAndTap(tester, find.text('百分比计算'));
    expect(db.savedSettings['percentage_mode'], 'relative');
    expect(db.savedSettings['percentage_mode'],
        SettingsTokens.percentageRelative);
    expect(find.text('相对'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('百分比计算'));
    expect(db.savedSettings['percentage_mode'], 'direct');
    expect(db.savedSettings['percentage_mode'], SettingsTokens.percentageDirect);
    expect(find.text('直接'), findsOneWidget);
  });

  testWidgets('换语言只换屏幕上那句话，`percentage_mode` 的字节不动', (tester) async {
    // 中文：round-trip 的另一半——先把 relative 落库，再用**同一份库**以英文重开设置页：
    //       屏幕上应当是 `Relative`，而库里（以及再次写出去的）仍然是 `'relative'`。
    // English: the other half of the round trip — store relative, then reopen the settings page in
    //          English **against the same database**: the screen should read `Relative` while what is
    //          in storage (and what any further write produces) stays `'relative'`.
    final db = _FakeDatabase(settings: const {
      'percentage_mode': SettingsTokens.percentageRelative,
    });
    await _pumpSettings(tester, db: db, language: AppLanguage.zh);
    expect(find.text('相对'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpSettings(tester, db: db, language: AppLanguage.en);

    expect(find.text('Percentage calculation'), findsOneWidget);
    expect(find.text('Relative'), findsOneWidget);
    expect(find.text('相对'), findsNothing, reason: '英文界面上不许留下中文标签');
    expect(db.savedSettings, isEmpty, reason: '只是打开页面，没有点任何东西');
  });

  testWidgets('默认态与接入前逐字节相同：不碰新选择时仍是中文 + 玫瑰奶霜', (tester) async {
    final db = _FakeDatabase();
    await _pumpSettings(tester, db: db, language: AppLanguage.zh);

    // 中文：默认语言是中文，所以设置页的每一个字都与"接入多语言之前"一模一样。
    // English: The default language is Chinese, so every word on the page is exactly what it was
    //          before i18n existed.
    for (final text in [
      '设置',
      '外观设置',
      '主题模式',
      '主题配色',
      '语言',
      '角度模式',
      '数字格式',
      '小数位数',
      '表达式显示',
      '使用体验',
      '触感反馈',
      '触感强度',
      '记住上次状态',
      '自动保存计算历史',
      '跟随系统',
      '弧度',
      '6 位',
      '数学符号',
      '玫瑰奶霜',
      '中文',
    ]) {
      expect(find.text(text), findsOneWidget, reason: '默认态必须还能找到「$text」');
    }
    expect(db.savedSettings, isEmpty, reason: '没点任何东西就不该有任何写入');
  });
}

class _FakeDatabase implements AppDatabase {
  /// 中文：可选地给一份不同的**已有设置**——默认那份与接入本轮之前逐字节相同，
  ///       所以老测试走的是同一条路。
  /// English: optionally hand in a different set of **stored settings**; the default one is
  ///          byte-for-byte what it was before this round, so older tests take the same road.
  _FakeDatabase({Map<String, String>? settings})
      : _storedSettings = settings ??
            const {
              'haptics': 'true',
              'haptic_strength': '标准',
              'restore_state': 'true',
              'auto_save': 'true',
              'theme_mode': '跟随系统',
              'angle_mode': '弧度',
              'digits': '6 位',
              'expression_display': '数学符号',
            };

  final Map<String, String> _storedSettings;
  final savedSettings = <String, String>{};

  @override
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(_storedSettings);

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<Map<String, int>> backupTableCounts() async => const {
        'calculation_history': 0,
        'notes': 0,
        'favorite_tools': 0,
        'recent_tools': 0,
        'app_settings': 0,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
