import 'package:flutter/material.dart';

import '../../../../core/math/app_unit_catalog.dart';

/// 中文：`CONV` 打开的单位面板。它只做一件事：**把单位名插进表达式**（以及把 ` to ` 插进去），
///       自己不换算——换算由引擎做，见 `QalculateEngine`。
///
///       **为什么是搜索 + 分族，而不是一个 982 项的下拉**：libqalculate 的 units.xml 里有 982 个
///       `<unit>`（737 个非别名），一次列出来是没法用的。这里用的是应用自己那张**封闭的**
///       可插入单位表（[kAppUnits]，117 个，逐个量过引擎读得懂），按族分组，顶上带一个过滤框。
///       选择面因此是「用户认识的那几十个」×「按族找」，而不是「在 982 项里翻」。
///
///       **面板不自动关闭**，这是刻意的：一次换算要插两样东西（源单位、目标单位，中间一个 `to`），
///       每插一次就关掉的话用户要开两次面板。用户插完点面板外或按返回键即可关闭。
///
///       **插入用键盘光标的位置**（`CalculatorController.input`），所以面板与键盘是同一个入口，
///       没有第二条写表达式的路。
///
/// English: The unit sheet `CONV` opens. It does exactly one thing: **insert a unit name into the
///          expression** (and insert ` to `), it does not convert anything itself — the engine does
///          that, see `QalculateEngine`.
///
///          **Why search plus families rather than a 982-item dropdown**: units.xml in libqalculate
///          holds 982 `<unit>` elements (737 non-alias) and listing them all is unusable. What this
///          uses is the app's own **closed** table of insertable units ([kAppUnits], 117, each measured
///          to be readable by the engine), grouped by family with a filter box on top. The choice is
///          therefore "the few dozen names a user knows" × "find them by family" rather than "scroll
///          982 entries".
///
///          **The sheet does not close itself**, deliberately: one conversion inserts two things (the
///          source unit, the target unit and a `to` between them), and closing after each insert would
///          make the user open the sheet twice. Tapping outside or the back button closes it.
///
///          **Insertion goes through the keypad's cursor position** (`CalculatorController.input`), so
///          the sheet and the keypad are one entrance and there is no second way to write the
///          expression.
class UnitPickerSheet extends StatefulWidget {
  const UnitPickerSheet({required this.onInsert, super.key});

  /// 中文：插入一段文本到当前光标处（页面接到控制器的 `input` 上）。
  /// English: inserts a piece of text at the current cursor (the page wires this to the controller's
  ///          `input`).
  final ValueChanged<String> onInsert;

  @override
  State<UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<UnitPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppUnit> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return kAppUnits;
    return kAppUnits
        .where((unit) =>
            unit.symbol.toLowerCase().contains(query) ||
            unit.label.toLowerCase().contains(query) ||
            unit.family.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _matches;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: '搜索单位（米、km、mile…）',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '点一个单位插进表达式；两个单位之间点「to」',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonal(
                  // 中文：` to ` 两侧的空格是**必须**的：引擎把 `)to(` 读成 `t`·`o` 的乘积，
                  //       而且不报错（宿主实测）。见 `engine_expression.dart` 的 `_wordOperator`。
                  // English: the spaces around ` to ` are **required**: the engine reads `)to(` as the
                  //          product `t`·`o`, without erroring (measured on the host). See
                  //          `_wordOperator` in `engine_expression.dart`.
                  onPressed: () => widget.onInsert(' to '),
                  child: const Text('to'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('没有匹配的单位', style: theme.textTheme.bodyMedium),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final family in kAppUnitFamilies)
                          if (matches.any((unit) => unit.family == family)) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(family, style: theme.textTheme.labelLarge),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final unit in matches)
                                  if (unit.family == family)
                                    TextButton(
                                      onPressed: () => widget.onInsert(unit.symbol),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        '${unit.symbol}  ${unit.label}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                              ],
                            ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
