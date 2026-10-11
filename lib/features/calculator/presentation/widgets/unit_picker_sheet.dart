import 'package:flutter/material.dart';

import '../../../../core/math/app_unit_catalog.dart';
import '../../../../l10n/app_language.dart';
import '../calculator_strings.dart';

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

/// 中文：**一个单位在面板上显示的名字，按当前界面语言取。** 选择只在这一处发生：[AppUnit] 两种语言
///       的名字都带着（中文那个字段逐字节没动），而这里的 `switch` **必须穷尽 `AppLanguage`**——
///       加第三种语言时这里编译不过，而不是静默把中文显示给那种语言。这条保证与
///       `ToolCatalogStrings.forLanguage` 的 `switch` 是同一条，差别只在这张表的两半住在同一个条目里。
///
///       **交出去的东西与它无关**：按钮按下时交的仍然是 `unit.symbol`，显示名一个字节都到不了表达式
///       （见 `app_unit_catalog.dart` 的文件头）。
/// English: **the name one unit shows on the sheet, taken by the active interface language.** The
///          choice happens here and nowhere else: an [AppUnit] carries both names (the Chinese field
///          has not moved a byte), and the **`switch` here must exhaust `AppLanguage`** so a third
///          language breaks the build rather than silently showing it Chinese. This is the same
///          guarantee `ToolCatalogStrings.forLanguage`'s `switch` gives; the only difference is that
///          this table's two halves live inside one entry.
///
///          **What goes out is not affected**: the button still hands over `unit.symbol`, and not one
///          byte of a display name can reach an expression (see `app_unit_catalog.dart`'s file head).
String unitDisplayLabel(AppUnit unit, AppLanguage language) {
  return switch (language) {
    AppLanguage.zh => unit.label,
    AppLanguage.en => unit.labelEn,
  };
}

/// 中文：族标题的同一次选择。认不出的族**原样返回中文**——分组读的键就是那个中文字符串，所以那种
///       情况下屏幕上写的仍是它今天的样子，而不是一个空白标题。
/// English: the same choice for a family heading. An unknown family **comes back as its Chinese
///          self** — the grouping key is that Chinese string, so what shows is what is on screen today
///          rather than a blank heading.
String unitDisplayFamily(String family, AppLanguage language) {
  return switch (language) {
    AppLanguage.zh => family,
    AppLanguage.en => kAppUnitFamilyLabelsEn[family] ?? family,
  };
}

/// 中文：`CONV` 打开的单位面板。它只做一件事：**把单位名插进表达式**（以及把 ` to ` 插进去），
///       自己不换算——换算由引擎做，见 `QalculateEngine`。
///
///       **为什么是搜索 + 分族，而不是一个 982 项的下拉**：libqalculate 的 units.xml 里有 982 个
///       `<unit>`（737 个非别名），一次列出来是没法用的。这里用的是应用自己那张**封闭的**
///       可插入单位表（[kAppUnits]，今天 120 个，逐个量过引擎读得懂），按族分组，顶上带一个过滤框。
///       选择面因此是「用户认识的那几十个」×「按族来找」，而不是「在 982 项里翻」。
///
///       **显示名按界面语言取，交出去的记号不变。** 每个单位带着中文名与英文名（[AppUnit]），每条
///       族名带着一张英文对照表（[kAppUnitFamilyLabelsEn]）；面板用当前 `AppLanguage` 选出写哪一侧
///       （[unitDisplayLabel] / [unitDisplayFamily]，两处 `switch` 都必须穷尽），而按钮交出去的永远
///       是 `unit.symbol`。**这是英文界面此前列出汉字的那条缺陷的修法**——面板是那张表唯一的显示处，
///       所以选择就放在这里，数据表自己不 import Flutter，也不认识界面语言。
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
///          uses is the app's own **closed** table of insertable units ([kAppUnits], 120 today, each
///          measured to be readable by the engine), grouped by family with a filter box on top. The
///          choice is therefore "the few dozen names a user knows" × "find them by family" rather than
///          "scroll 982 entries".
///
///          **The display name follows the interface language; the token handed over does not.** Every
///          unit carries a Chinese and an English name ([AppUnit]) and every family has an English
///          counterpart ([kAppUnitFamilyLabelsEn]); the sheet picks which side to write with the active
///          `AppLanguage` ([unitDisplayLabel] / [unitDisplayFamily], both `switch`es exhaustive), while
///          what the button hands over is always `unit.symbol`. **This fixes the defect where an
///          English interface listed Han characters** — the sheet is that table's one display site, so
///          the choice lives here; the data table itself imports no Flutter and does not know the
///          interface language.
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

  /// 中文：搜索同时匹配**两种语言的名字**（外加拼法与族名），不按当前界面语言分叉。两条理由：
  ///       中文的提示语今天就在承诺 `mile` 搜得到（`CalculatorStrings.unitSearchHint`：「搜索单位
  ///       （米、km、mile…）」），而英文用户拿中文名来搜也该找得到。**两边都匹配只会让结果变多**：
  ///       `where` 多一个条件，集合只会变大，所以没有哪条中文查询会少掉它今天找得到的单位。
  /// English: the search matches **both languages' names** (plus the spelling and the family name) and
  ///          does not branch on the active language. Two reasons: the Chinese hint already promises
  ///          that `mile` finds the mile (`CalculatorStrings.unitSearchHint`: "搜索单位（米、km、
  ///          mile…）"), and an English user searching by a Chinese name should find the entry too.
  ///          **Matching both only ever adds results**: one more clause in the `where` can only grow
  ///          the set, so no Chinese query loses a unit it finds today.
  List<AppUnit> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return kAppUnits;
    return kAppUnits
        .where((unit) =>
            unit.symbol.toLowerCase().contains(query) ||
            unit.label.toLowerCase().contains(query) ||
            unit.labelEn.toLowerCase().contains(query) ||
            unit.family.contains(query) ||
            (kAppUnitFamilyLabelsEn[unit.family] ?? '')
                .toLowerCase()
                .contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = CalculatorStrings.of(context);
    // 中文：**语言在这一行取一次**，下面所有显示名都从它来——面板是这张表唯一的显示处。
    // English: **the language is taken once, here**, and every display name below comes from it — the
    //          sheet is this table's one display site.
    final language = AppLanguage.of(context);
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
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: strings.unitSearchHint,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.unitSheetHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonal(
                  // 中文：交出去的是**裸记号** `to`，两侧的空格由 [unitInsertionText] 决定——
                  //       分隔符只在一处决定，见那个函数的注释。
                  // English: what goes out is the **bare token** `to`; the spaces around it are decided
                  //          by [unitInsertionText] — separators are decided in exactly one place.
                  onPressed: () => widget.onInsert(_wordOperatorToken),
                  // 中文：**面字走文案表，交出去的记号不变。** 中文界面上这个按钮此前写着英文 `to`
                  //       （两处语言里都是英文），现在按语言取字；`onPressed` 交的还是裸记号 `to`。
                  // English: **the face goes through the table; what it hands over does not change.** This
                  //          button used to read the English `to` in both languages; the label now follows
                  //          the language, while `onPressed` still hands over the bare token `to`.
                  child: Text(strings.unitWordOperatorLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(strings.noMatchingUnits,
                            style: theme.textTheme.bodyMedium),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final family in kAppUnitFamilies)
                          // 中文：分组比的是 `unit.family`（中文键），屏幕上写的是它按语言取的
                          //       显示名——**比较与显示是两件事**，见 [unitDisplayFamily]。
                          // English: grouping compares `unit.family` (the Chinese key) while the screen
                          //          writes its language-selected name — **comparing and showing are
                          //          two different things**, see [unitDisplayFamily].
                          if (matches.any((unit) => unit.family == family)) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(unitDisplayFamily(family, language),
                                  style: theme.textTheme.labelLarge),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final unit in matches)
                                  if (unit.family == family)
                                    TextButton(
                                      onPressed: () =>
                                          widget.onInsert(unit.symbol),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      // 中文：**面字是显示名（随语言），交出去的是 `unit.symbol`
                                      //       （永远不变）**——与旁边那个「to」按钮同一条规矩。
                                      // English: **the face is a display name (language-dependent);
                                      //          what goes out is `unit.symbol` (never changes)** — the
                                      //          same rule the `to` button next to it follows.
                                      child: Text(
                                        '${unit.symbol}  ${unitDisplayLabel(unit, language)}',
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
