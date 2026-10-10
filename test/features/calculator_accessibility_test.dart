import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
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
/// 而它确实不通过**：键盘每行 **48.3 × 24.2 dp**，在**测过的每一个尺寸上**都不通过。
/// 不断言的理由是**那是权衡**——加高会挤动整块键盘，而键盘是照着 HiPER 排的。
/// **一条会把权衡说成缺陷的测试，与本仓那条"判据要挂在哪一个是错的"是同一类问题。**
/// 数记在 `.superpowers/backup/comparison-with-hiper.md` 第十一节（那里也记着我一度把它误撤回）。
///
/// ⚠️ **还有一条方法上的坑**：`meetsGuideline` 的失败是**异步上报**的——
/// `expect(...)` 不抛异常，测试在结尾才红。**所以不能用 try/catch 去"看它过不过"。**
/// English: **the other guideline is not asserted here, and it genuinely fails**: each keypad row is
///          **48.3 × 24.2 dp** and it fails **at every size tested**. It is unasserted because that is a
///          **trade-off** — raising the rows shoves the whole keypad around, and the keypad is laid out to
///          match HiPER. **A test that calls a trade-off a defect is the same kind of problem as this
///          repository's rule that a judgement must hang on which one is wrong.** The numbers are in
///          section 十一 of `.superpowers/backup/comparison-with-hiper.md` (which also records that I once
///          retracted them by mistake).
///
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
///          ⚠️ **The other guideline (`androidTapTargetGuideline`, ≥48dp per tappable) still fails**, and
///          that is a **layout trade-off**: every keypad row is about 26 dp tall and raising it would shove
///          the whole keypad around, which is laid out to match HiPER. **So it is not asserted here** — a
///          test that calls a trade-off a defect is the same kind of problem as this repository's rule that
///          a judgement must hang on which one is wrong. The numbers live in section 十一 of
///          `.superpowers/backup/comparison-with-hiper.md`.
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
}
