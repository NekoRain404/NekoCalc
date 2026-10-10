import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';

/// 中文：**主屏的语义标签：拿 Flutter 自带的判据量。**
///
///       ⚠️ **这条判据此前在整块键盘上是不通过的**，而原因很具体（实测）：
///       键面要么是文字、要么是一张图，`InkWell` **从子节点的文字推标签**——
///       所以文字键面一直读得出来，而**图形键面（`[matrix]` 那一颗）没有文字可推**，
///       于是在语义树里是一个**没有名字的可点节点**（`Rect.fromLTRB(270.2, 283.9, 398.5, 309.7)`）。
///
///       修法写在 `calculator_keypad.dart` 的 `_variantFace` 上：把**本来就有**的名字
///       （`variant.label`——键位表、横带提示、逐格快照用的都是它）接到语义树上。
///       **不是给它取名字，是把它已有的名字接上去。**
///
/// ⚠️ **另一条判据（`androidTapTargetGuideline`，每个可点目标 ≥48dp）在这里没有断言，
/// 而它在键盘上确实不通过**——但**不通过的是什么，本文件此前记错了，这一版是重测的**。
///
/// 先记结论（**结构是读源码定的，不是从祖先链推的**——见下面那条教训）：键盘是
/// `ColoredBox > Padding(6) > Column`，Column 的每个孩子是一个**行组**；行组由两片组成
/// （`calculator_keypad.dart` 的 `_row`）：`Expanded(flex: 2, _band)` 在**上**、
/// `Expanded(flex: 5, _mainStrip)` 在**下**。上面那片是**标签横带**——一行小字，`_bandCell`
/// 每格各自可点；下面那片是**主键条**——每颗键各自可点。横带标的是**它下面那行**键的功能，
/// 这正是 HiPER 的机制。360 × 800 实测：横带格 **66.6 × 15.0**、键 **66.6 × 42.1**、
/// 行组 66.6 × 57.1。**两片各自可点、各做各的事**，而**两片都矮于 48**。
///
/// ⚠️ **一条方法教训：祖先链认不出「是哪一片」。** 我最初读到的两条链**逐字相同**——
/// `Padding < Expanded < Row < Expanded < Column < Padding < ColoredBox`——于是判成「同一个格子里
/// 上下两片」，还顺手把上下**写反了**（横带在**上**，我写成了键面在上）。**那是推断，不是测量**：
/// 两片确实都长这样，差别只在**是哪一层的 `Expanded`**（行组的横带那片，还是主键那片），
/// 而链上印出来的名字一模一样。**问「结构是什么」要读源码；链只能回答「它在谁里面」。**
///
/// 旧文这里写的是「键盘每行 **48.3 × 24.2 dp**，在**测过的每一个尺寸上**都不通过」，
/// 三处都站不住（六种尺寸实测：320×640、360×640、360×800、393×851、411×731、412×915）：
/// 1. **`48.3` 是 320 宽的屏幕上的数**（键 48.3 × 29.0），不是 360 × 800 的——两个数被拼到了一起；
/// 2. **`24.2` 在测过的任何一个尺寸上都不出现**（各尺寸键高：29.0 / 29.0 / 42.1 / 46.3 / 36.4 / ≥48）；
/// 3. **「每一个尺寸都不通过」是假的**：**412 × 915 下不通过的只有 25 个节点**（全是横带格），
///    键在那里**是高过 48 的**。笼统一句「都不通过」把两种不同的成因混成了一条。
///
/// 不断言的理由仍然是**权衡**：横带是 HiPER 的机制，横带与主键条一起撑满整块键盘，
/// 把任一片单独抬到 48 就得动整块键盘的排布（键盘是照着 HiPER 排的）。
/// **一条会把权衡说成缺陷的测试，与本仓那条"判据要挂在哪一个是错的"是同一类问题。**
/// 数记在 `.superpowers/backup/comparison-with-hiper.md` 第十一节（那里也记着我一度把它误撤回）。
///
/// ⚠️ **顺带查清的另一件事：这条判据在原图上并不是"键盘一家的错"。** 显示区状态行里有两颗
/// **本应用自己的**按钮在下面：那颗 ☰ 实测语义节点 **40 × 40**、`More...` **111.7 × 34.0**——
/// 两者都不是 HiPER 的排布，是**纯缺陷**，已修（状态行 40 → 48dp，`display_status_row.dart`；
/// 连带 `CalculatorDisplay` 的固定部分 74 → 82dp、下限 176 → 182dp，推导在该组件类注释里）。
/// 下面那条「主屏的键盘之外不许有矮于 48dp 的可点目标」就是钉这件事的。
///
/// ⚠️ **还有一条方法上的坑**：`meetsGuideline` 的失败是**异步上报**的——
/// `expect(...)` 不抛异常，测试在结尾才红。**所以不能用 try/catch 去"看它过不过"。**
///          ⚠️ **One more trap**: `meetsGuideline` reports failures **asynchronously** — `expect(...)` does
///          not throw and the test goes red at the end. **So try/catch cannot be used to "see whether it
///          passes".**
/// English: **the main screen's semantic labels, measured against Flutter's own guideline.**
///
///          ⚠️ **It used to fail across the keypad**, for a specific reason (measured): a key face is either
///          text or a figure, and `InkWell` **derives** the label from descendant text — so text faces have
///          always been readable while a **figure face (the `[matrix]` key) has no text to derive from**,
///          leaving an **unnamed tappable node** in the semantics tree. The fix lives on `_variantFace` in
///          `calculator_keypad.dart`: it wires the name that **already exists** (`variant.label` — the one
///          the keypad table, the band hint and the per-cell snapshot use) into the semantics tree. **Not
///          naming it; connecting a name it already had.**
///
///          ⚠️ **The other guideline (`androidTapTargetGuideline`, ≥48dp per tappable) is not asserted
///          here, and it genuinely fails on the keypad** — but **what fails is not what this file used
///          to record, and this revision re-measured it.**
///
///          The conclusion first (**the structure was read off the source, not inferred from an
///          ancestor chain** — see the lesson below): the keypad is `ColoredBox > Padding(6) >
///          Column`, and each child of that `Column` is a **row group**; a row group has two strips
///          (`_row` in `calculator_keypad.dart`): `Expanded(flex: 2, _band)` on **top** and
///          `Expanded(flex: 5, _mainStrip)` **below**. The upper strip is the **label band** — one row
///          of small text, each `_bandCell` tappable on its own; the lower one is the **main key
///          strip** — each key tappable on its own. The band labels the key row **beneath** it, which
///          is exactly HiPER's mechanism. Measured at 360 × 800: a band cell is **66.6 × 15.0**, a key
///          **66.6 × 42.1**, the row group 66.6 × 57.1. The two strips are **independently tappable and
///          do different things**, and **both are under 48**.
///
///          ⚠️ **A methodological lesson: an ancestor chain cannot tell you *which* strip you are in.**
///          The two chains I first read were **character-for-character identical** —
///          `Padding < Expanded < Row < Expanded < Column < Padding < ColoredBox` — so I called them
///          "two strips of the same cell", and I even got the order **backwards** (the band is on
///          **top**; I had written the face on top). **That was inference, not measurement**: both
///          strips really do look like that, and the only difference is **which `Expanded`** you are
///          under (the row group's band one, or its main-strip one) — and the chain prints the same
///          name for both. **To ask what the structure is, read the source; a chain only answers
///          "what is this inside of".**
///
///          The old text here read "every keypad row is about **48.3 × 24.2 dp** and it fails at
///          **every size tested**", and all three claims fail (six sizes measured: 320×640, 360×640,
///          360×800, 393×851, 411×731, 412×915):
///          1. **`48.3` is a 320-wide screen's number** (the key there is 48.3 × 29.0), not 360 ×
///             800's — two numbers from two devices had been spliced together;
///          2. **`24.2` appears at no size measured** (key heights per size: 29.0 / 29.0 / 42.1 /
///             46.3 / 36.4 / ≥48);
///          3. **"fails at every size" is false**: at **412 × 915 only 25 nodes fail** (all band
///             cells) — the keys clear 48 there. One sweeping "all of them fail" conflated two
///             different causes.
///
///          The reason for not asserting it is still a **trade-off**: the band is HiPER's mechanism,
///          band and key strip together fill the keypad, and raising either one alone means re-laying
///          out the whole keypad (which is laid out to match HiPER). **A test that calls a trade-off a
///          defect is the same kind of problem as this repository's rule that a judgement must hang on
///          which one is wrong.** The numbers live in section 十一 of
///          `.superpowers/backup/comparison-with-hiper.md`.
///
///          ⚠️ **The other thing this cleared up: the guideline was never "the keypad's fault alone".**
///          Two buttons of **this app's own** sat below it in the display band's status row: the ☰
///          measures a **40 × 40** semantics node and `More...` **111.7 × 34.0** — neither is HiPER's
///          layout, both were plain defects, and both are fixed (the status row goes 40 → 48dp in
///          `display_status_row.dart`, taking `CalculatorDisplay`'s chrome 74 → 82dp and its floor
///          176 → 182dp; the derivation is in that widget's class comment). The test below —
///          "nothing outside the keypad may be a sub-48dp tappable" — is what pins that.
class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 中文：**工具页那一颗搜索按钮。** 它此前**没有 `tooltip`**，于是读屏里是个没有名字的按钮——
/// 实测：`labeledTapTargetGuideline` 在工具页上**只因它**不通过。同页其余几颗都有 `tooltip`。
/// English: **the tools page's search button.** It had **no `tooltip`**, so it was an unnamed button to a
///          screen reader — measured: it **alone** made `labeledTapTargetGuideline` fail on that page. Every
///          other button there has one.
class _FakeToolsDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<Set<String>> favoriteToolIds() async => const <String>{};

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const <String>[];

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  testWidgets('工具分类页：返回与搜索两颗按钮都有名字', (tester) async {
    // 中文：**这两颗此前都没有 tooltip**（与工具首页那颗搜索按钮同一类，而这一页有两颗）。
    //       它们是全仓扫描出来的——扫的是「IconButton 的参数里没有 tooltip」，
    //       而不是"我记得哪一页有问题"。
    // English: **neither had a tooltip** (the same class as the tools home's search button, and this page
    //          has two of them). They came out of a repo-wide scan for "IconButton with no tooltip in its
    //          arguments" — not from remembering which page was broken.
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: ToolCategoryScreen(
          db: _FakeToolsDatabase(),
          category: ToolCategory.math,
          favoriteIds: const <String>{},
          settings: AppSettings.fallback),
    ));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('工具页：搜索按钮有名字', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
            db: _FakeToolsDatabase(), settings: AppSettings.fallback),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('主屏：每个可点的东西都有名字（读屏读得出来）', (tester) async {
    // 中文：**按真机尺寸量**（360×800 dp）。默认的 800×600 测试面会把键盘压扁——
    //       我第一版就是这么量的，于是得出"每行只有 26 dp、不达标"这个**假的**结论。
    //       凡是量"屏幕上多大"的东西，先把测试面设成真机尺寸。
    // English: **measured at device size** (360×800 dp). The default 800×600 surface squashes the keypad —
    //          that is how my first version measured it, and it produced a **false** conclusion ("every row is
    //          only 26 dp, below the guideline"). Anything measuring "how big is it on screen" has to set the
    //          surface to a device size first.
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('主屏的键盘之外：没有矮于 48dp 的可点按钮', (tester) async {
    // 中文：**这条不是引用判据，是量出来的那条结论的钉子。**
    //
    //       整屏的 `androidTapTargetGuideline` 断言不了（键盘那两片横带是有意为之，见文件头），
    //       但**键盘不是全部**——状态行里那两颗属于本应用自己的按钮原来也不达标（☰ 40 × 40、
    //       `More...` 111.7 × 34.0）。它们不是权衡，是缺陷。这条判据把**本屏**的键盘之外切出来
    //       单独钉住：那里每一个可点按钮都必须 ≥48 × 48，键盘本身按 HiPER 的机制豁免。
    //
    //       ⚠️ **范围就是「主屏」（它 pump 的是 `CalculatorPage`），别把它读成全应用。**
    //       全应用还有一处**已知**的矮于 48dp 的可点按钮：结果卡 `DetailMetric` 角上那颗复制键
    //       **28 × 28**（工具详情页）。那一条**没有修**，理由是量出来的权衡而不是疏忽——
    //       同排的标签格实测**正好 110.00dp**，而英文最长的一条标签要 109.1dp（零余量），
    //       按钮一涨 20dp 就有 12 条英文标签被省略号吃掉。数记在 `tool_widgets.dart` 的
    //       `DetailMetric` 注释里。**这条判据不覆盖它，所以既不会误报也不会替它遮掩。**
    //
    //       ⚠️ **`checked` 那一条断言是不许省的**：这个循环如果哪天一个元素都找不到（类名改了、
    //       或 `find.byType` 换了），`offenders` 会是空的、测试照样绿——那是**空转的判据**。
    //       本仓吃过这个亏（`expect(knownOverflows, greaterThan(0))` 那一次）。
    //
    //       实测（360 × 800 dp）：☰ 与 `More...` 各一颗，都是 48 高。
    // English: **This is not a reused guideline; it is the nail for a measured conclusion.**
    //
    //          The whole-screen `androidTapTargetGuideline` cannot be asserted (the keypad's two bands
    //          are deliberate — see the file head), but **the keypad is not everything**: the status
    //          row's two buttons belong to this app and used to be under the bar too (☰ 40 × 40,
    //          `More...` 111.7 × 34.0). Those were not a trade-off, they were defects. This test cuts
    //          **this screen's** non-keypad area out and pins it on its own: every tappable button there
    //          must be ≥48 × 48, while the keypad itself is exempt under HiPER's mechanism.
    //
    //          ⚠️ **The scope is "the main screen" (it pumps `CalculatorPage`) — do not read it as the
    //          whole app.** One **known** sub-48dp tappable exists elsewhere: the copy key in the corner
    //          of the result card `DetailMetric`, **28 × 28** (the tool detail screen). That one is
    //          **not fixed**, and the reason is a measured trade-off rather than an oversight — the
    //          label box in the same row measures **exactly 110.00dp** while the longest English label
    //          needs 109.1dp (no slack at all), so a 20dp bigger button costs 12 English labels to the
    //          ellipsis. The numbers are in `DetailMetric`'s comment in `tool_widgets.dart`. **This test
    //          does not cover it, so it neither false-alarms on it nor hides it.**
    //
    //          ⚠️ **The `checked` assertion must not be dropped**: if the loop ever finds no elements at
    //          all (a renamed class, a changed `find.byType`), `offenders` stays empty and the test
    //          still goes green — a **test idling in neutral**. This repository has been bitten by that
    //          before (the `expect(knownOverflows, greaterThan(0))` episode).
    //
    //          Measured (360 × 800 dp): one ☰ and one `More...`, both 48 tall.
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pumpAndSettle();

    final Set<Element> keypad = find.byType(CalculatorKeypad).evaluate().toSet();
    bool insideKeypad(Element element) {
      var inside = false;
      element.visitAncestorElements((ancestor) {
        if (keypad.contains(ancestor)) {
          inside = true;
          return false;
        }
        return true;
      });
      return inside;
    }

    final offenders = <String>[];
    var checked = 0;
    for (final type in <Type>[IconButton, TextButton, InkWell]) {
      for (final element in find.byType(type).evaluate()) {
        if (insideKeypad(element)) continue;
        final render = element.renderObject;
        if (render is! RenderBox || !render.hasSize) continue;
        checked++;
        final size = render.size;
        if (size.width < 48 || size.height < 48) {
          offenders.add('$type ${size.width.toStringAsFixed(1)} × '
              '${size.height.toStringAsFixed(1)}');
        }
      }
    }

    expect(checked, greaterThan(0),
        reason: '主屏的键盘之外一个可点按钮都没找到——这条判据成了空转，先查 find.byType 还对不对');
    expect(offenders, isEmpty,
        reason: '主屏的键盘之外有矮于 48dp 的可点按钮：${offenders.join("，")}');
  });
}
