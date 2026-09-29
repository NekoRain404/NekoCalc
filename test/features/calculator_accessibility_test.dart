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
/// ⚠️ **另一条判据（`androidTapTargetGuideline`，每个可点目标 ≥48dp）仍然不通过**，
/// 而那是**布局权衡**：键盘每一行只有约 26 dp 高，加高会挤动整块键盘，
/// 而键盘是照着 HiPER 排的。**所以这里没有断言它**——
/// 一条会把"权衡"说成"缺陷"的测试，与本仓那条"判据要挂在哪一个是错的"是同一类问题。
/// 数（每行约 26 dp、抽屉按钮 40×40、`More...` 112×34）记在
/// `.superpowers/backup/comparison-with-hiper.md` 第十一节。
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
