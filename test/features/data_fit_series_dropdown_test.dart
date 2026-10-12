import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/data_fit_tool_screen.dart';

/// 中文：**拟合页那个数据组下拉框，真的被按一下，屏幕上的方程与 R² 跟着换。**
///
///       **它补的是哪一格。** 解析与「选中组的序号」由 `data_fit_test.dart` 在领域层钉住，
///       保存流程又在同一屏上量过——但**下拉框本身从来没有被点过**：`data_fit_cards.dart` 里那个
///       `DropdownButtonFormField<int>`（驱动在 `data_fit_tool_screen.dart` 的
///       `_selectSeriesIndex`）在整仓库里没有一条测试碰过它。数据表下面那排胶囊是**同一个动作的
///       第二个入口**，点它会走同一条路——也正因为如此，只点胶囊的那类测试证明不了这个下拉框接上了。
///
///       **判据不是「标签换了」。** 换组之后屏幕上的**方程**与 **R²** 都必须是**第二组自己的那几个
///       数**（起手数据是 `x,y1,y2` 三列，两组各 6 点）：
///       - 数据 1（线性）：`y = 2.051429x - 0.046667`，R² `0.999362`；
///       - 数据 2（线性）：`y = 1.92x - 1.786667`，R² `0.942148`。
///       两个方程在斜率与截距上都不同、R² 也不同，所以「换了一组」与「只是标题换了字」在这里分得开。
///       第一组的那个方程在换组之后**不许还在屏幕上**——只看新值出现，一个「两组都印出来」的实现
///       也能绿。
/// English: **the series dropdown on the fit screen is really pressed once, and the equation and R²
///          on screen follow it.**
///
///          **The cell this fills.** Parsing and "which index is selected" are pinned in the domain
///          layer by `data_fit_test.dart`, and the save flow was measured on this same screen — but
///          **the dropdown itself has never been tapped**: the `DropdownButtonFormField<int>` in
///          `data_fit_cards.dart` (driven by `_selectSeriesIndex` in `data_fit_tool_screen.dart`) is
///          touched by no test in the repository. The chips under the data table are a **second
///          entrance** to the same action and take the same road — which is exactly why tests that
///          only tap the chips cannot show that this dropdown is wired.
///
///          **The criterion is not "a label changed".** After switching, the **equation** and the
///          **R²** on screen must both be **the second series' own numbers** (the starting data is
///          three columns `x,y1,y2`, six points each):
///          - series 1 (linear): `y = 2.051429x - 0.046667`, R² `0.999362`;
///          - series 2 (linear): `y = 1.92x - 1.786667`, R² `0.942148`.
///          The two equations differ in both slope and intercept and the R²s differ too, so "another
///          series was fitted" and "only the caption changed" are told apart here. Series 1's equation
///          **may not still be on screen** after the switch — seeing only the new value appear would
///          leave an implementation that prints both green.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('换到数据 2：方程与 R² 都换成第二组自己的数，第一组的不在屏幕上', (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: _FakeDatabase(),
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    // 中文：起手数据是三列——两组都在，下拉框才画得出来（`if (_series.length > 1)`）。
    // English: the starting data is three columns — two series exist, which is the only condition
    //          under which the dropdown is drawn (`if (_series.length > 1)`).
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget,
        reason: '两组数据都在时，下拉框必须画出来');
    expect(find.text('数据 1 · 6 点'), findsWidgets,
        reason: '下拉框此刻显示的是第一组');
    _expectFitted(tester, equation: 'y = 2.051429x - 0.046667', rSquared: '0.999362');

    // 中文：**按的是那个控件本身**——不是它旁边那排胶囊，也不是任何别的入口。
    // English: **the widget itself is pressed** — not the chips beside it, not any other entrance.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据 2 · 6 点').last);
    await tester.pumpAndSettle();

    _expectFitted(tester, equation: 'y = 1.92x - 1.786667', rSquared: '0.942148');
    expect(find.text('y = 2.051429x - 0.046667'), findsNothing,
        reason: '换了组之后，前一组的方程不许还留在屏幕上');
    expect(find.text('R²  0.999362'), findsNothing,
        reason: 'R² 是第一组那个，说明换的只是标题、拟合没跟着换');
    expect(find.textContaining('当前 数据 2'), findsOneWidget,
        reason: '读数那一行也要说清楚现在是哪一组');
  });
}

/// 中文：屏幕上此刻的拟合结果——**方程与 R² 一起**，两者都取自渲染树里真实存在的节点。
/// English: the fit result on screen right now — **equation and R² together**, both taken from nodes
///          that really exist in the render tree.
void _expectFitted(
  WidgetTester tester, {
  required String equation,
  required String rSquared,
}) {
  expect(
    tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data),
    contains(equation),
    reason: '结果卡上的方程必须是 `$equation`',
  );
  expect(find.text('R²  $rSquared'), findsOneWidget,
      reason: '结果卡上的 R² 必须是 `$rSquared`');
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
