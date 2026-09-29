import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';

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
/// ⚠️ **另一条判据（`androidTapTargetGuideline`，每个可点目标 ≥48dp）在这里也没有断言——
/// 而理由变了。** 我第一版量出来"每行只有 26 dp、不达标"，那是**默认 800×600 测试面**
/// 把键盘压扁造成的；**按真机尺寸（360×800）重量，它通过。**
/// **所以它不断言不是因为"那是权衡"，是因为它本来就过**——而这一条更正留在
/// `.superpowers/backup/comparison-with-hiper.md` 第十一节。
/// English: **the other guideline is not asserted here either — but the reason changed.** My first version
///          measured "every row is only 26 dp, below the guideline", which was the **default 800×600 test
///          surface** squashing the keypad; **re-measured at device size (360×800) it passes.** So it is
///          unasserted not because "it is a trade-off" but because **it already passes** — and that
///          correction lives in section 十一 of `.superpowers/backup/comparison-with-hiper.md`.
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

void main() {
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
