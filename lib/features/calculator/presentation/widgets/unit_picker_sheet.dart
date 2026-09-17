import 'package:flutter/material.dart';

import '../../../../core/math/app_unit_catalog.dart';

/// 中文：**面板交出去的文本 → 真正插进表达式的那一段。** 分隔符在这一处决定，因为它是
///       「应用自己的语言读不读得懂」这件事的一部分，不是面板的排版细节。
///
///       **为什么必须有分隔符（实测，不是理论）**：键盘上没有字母键，用户按出来的是
///       `5` → `km` → `to` → `mi` 这样一串**相邻插入**。不加分隔符时它们是
///       `5` + `km` + `to` + `mi` = `5kmtomi`，而标识符是**贪婪**读的——那是**一个**名字
///       `kmtomi`，不是 `5`、`km`、`to`、`mi`。实测：`engineExpressionFor('5kmtomi')` →
///       「引擎不认识这个自由变量：`kmtomi`」（引擎根本不会被问到），旧解析器也读不懂，
///       屏幕上是一条「存在无法识别的内容」。**在这之前我用带空格的字符串做验证（测试与真机探针
///       都是 `5 km to mi`），而真实按键流产生的是没有空格的那一串**——这正是这条缺陷藏了这么久
///       的原因。
///
///       规则：
///       - **词运算符**（`to`）两侧各一个空格：` to `。空格是它**成为词**的条件——`kmtomi` 里
///         没有它，`to` 就只是 `kmtomi` 的一部分（引擎那边同理，见 `engine_expression.dart`）。
///       - **单位名**前面一个空格，除非表达式为空或已经以空格结尾（那样开头会多一个无意义的前导
///         空格）。**后面不加**：单位后面接 `to`（自带前导空格）、接运算符、接另一个单位（`m s`
///         是并置乘法，正是想要的意思）都读得动。
///       - **符号（`t`、`B`、`m`…）与字母单位一视同仁**：判据不看字符类别，所有单位名都走同一条
///         规则，免得下一个「字母开头的单位」又漏一次。
///
/// English: **the text the sheet hands over → the piece that actually goes into the expression.**
///          The separator is decided here because it is part of "can this app's own language read
///          it", not a typographic detail of the sheet.
///
///          **Why a separator is required (measured, not argued)**: the keypad has no letter keys, so
///          what the user presses is a run of **adjacent insertions** — `5` → `km` → `to` → `mi`.
///          Without separators those concatenate to `5kmtomi`, and identifiers are read **greedily**:
///          that is **one** name, `kmtomi`, not `5`, `km`, `to`, `mi`. Measured:
///          `engineExpressionFor('5kmtomi')` → "引擎不认识这个自由变量：`kmtomi`" (the engine is never
///          even asked) and the legacy parser cannot read it either, so the screen shows
///          "unrecognised content". **Before this, every verification of mine used spaced strings
///          (both the tests and the device probe used `5 km to mi`), while the real keypad flow
///          produces the unspaced one** — that is exactly why this survived.
///
///          The rules:
///          - a **word operator** (`to`) gets one space on each side: ` to `. The space is what makes
///            it a word — inside `kmtomi` there is no `to`, only a longer name (and the same is true on
///            the engine's side, see `engine_expression.dart`).
///          - a **unit name** gets one space in front, unless the expression is empty or already ends
///            in a space (which would add a meaningless leading space). **Nothing after it**: a unit
///            followed by `to` (which brings its own leading space), by an operator, or by another
///            unit (`m s` is a juxtaposition product, which is the wanted meaning) all read fine.
///          - **symbols (`t`, `B`, `m`…) and letter units get the same treatment**: the rule looks at
///            no character class, so the next "unit that starts with a letter" cannot slip through a
///            separate path.
String unitInsertionText(String token, String expression) {
  if (token == _wordOperatorToken) return ' $_wordOperatorToken ';
  if (expression.isEmpty || expression.endsWith(' ')) return token;
  return ' $token';
}

/// 中文：面板上那个「to」按钮交出来的记号（裸记号，两侧空格由 [unitInsertionText] 决定）。
/// English: the token the sheet's `to` button hands over (bare; the spaces around it are decided by
///          [unitInsertionText]).
const String _wordOperatorToken = 'to';

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
                  // 中文：交出去的是**裸记号** `to`，两侧的空格由 [unitInsertionText] 决定——
                  //       分隔符只在一处决定，见那个函数的注释。
                  // English: what goes out is the **bare token** `to`; the spaces around it are decided
                  //          by [unitInsertionText] — separators are decided in exactly one place.
                  onPressed: () => widget.onInsert(_wordOperatorToken),
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
