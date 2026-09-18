part of 'calculator_page.dart';

/// 中文：**`MTRX` 的第二功能：HiPER 的 `MATRIX_MENU`「矩阵与向量菜单」。**
///
///       自成一个 part 文件只为行数：`calculator_page_sheets.dart` 已经 736 行，而这一块是自成一体的
///       （`MTRX` 那一格与它打开的面板）。形状与 `_ComplexSheet`/`_StatisticsSheet` 逐条相同：
///       **面板只交出记号，插入仍走主屏的 `_pressKey`**——于是「面板里有什么」与「键盘能派发什么」
///       是同一套 id 词汇，没有第二份映射（`_MoreFunctionsSheet` 立的规矩）。
///
///       **一、面板里的每一项插的都是「一条调用 + 本应用自己的矩阵写法」。** `det`/`transpose`/`inv`
///       插的是围着 `matrix(2,2,1,2,3,4)`（`MTRX` 那颗键的基准动作插的就是它）的一条完整调用；
///       `identity` 是构造那一个，本身就是完整的。四个都立刻求得出值，四个的引擎答复都在
///       `app_engine_vocabulary_identifiers.dart` 那张实测表里。
///
///       **二、为什么不「包住用户此刻的表达式」——这是本面板唯一一个设计取舍，理由是量出来的。**
///       引擎对**标量**不报错，它给出一个看起来合理的值：宿主实测 `det(5)` = `5`、`inv(5)` = `0.2`、
///       `transpose(5)` = `5`。表达式里正好是一个数时，「包住它」会让屏幕上出现一个没有人会怀疑的
///       答案，而它答的不是被问的那个问题——正是本项目判为最坏的那一类静默错值。完整插入没有这个
///       状态：插出去的文本里**永远**含一个 `matrix(…)`，应用不会把一个标量交给 `det`。同一个取舍
///       也是 `Σ`/`Π`/`mean` 那一批的形状（键盘上没有逗号键，半条调用补不完）。
///
///       **三、菜单里那三行灰的是什么，以及为什么它们在里面。** `rank`/`trace`/`echelon` 是矩阵
///       运算里最容易被想起来的三个名字，而引擎对它们的答复**不是**那三件事（实测表在词表那个
///       part 文件里）：`rank` 是引擎里**真有**的函数，却把矩阵原样还回来；`trace`/`echelon` 引擎
///       根本没有这两个名字，于是词被拆成符号、印出来是带单位的量。**灰键是诚实的**（与 `STAT`
///       面板那三格、与结果格式菜单里 `Polar coordinates` 那一项同一个做法）：按不下去，而且同一行
///       里就写着为什么。真按下去会得到一个「形状对、意思错」的答案，那比一句错误更坏。
///
///       **四、到期日。** 这三行灰的凭据钉在
///       `test/features/calculator_matrix_menu_test.dart` 与
///       `test/features/calculator_drg_matrix_band_keys_test.dart` 里：哪一天引擎把那三个名字答对了
///       （或者本应用自己实现了它们），那些断言会变红——那时这三格该点亮，而不是让一条过期的禁用
///       悄悄留着。
/// English: **`MTRX`'s second function: HiPER's `MATRIX_MENU`, the "Matrix and Vector Menu".**
///
///          It has a part file of its own for line count alone: `calculator_page_sheets.dart` is at 736
///          lines and this block is self-contained (the `MTRX` cell and the sheet it opens). The shape
///          is item-for-item the one `_ComplexSheet`/`_StatisticsSheet` have: **the sheet hands over
///          tokens only, and insertion still travels the screen's `_pressKey`** — so "what is in the
///          sheet" and "what the keypad can dispatch" are one id vocabulary with no second mapping (the
///          rule `_MoreFunctionsSheet` set).
///
///          **1. Every entry inserts a call around this app's own matrix spelling.** `det`/`transpose`/
///          `inv` insert one complete call around `matrix(2,2,1,2,3,4)` (exactly what the `MTRX` key's
///          base action inserts); `identity` is the constructor and complete on its own. All four
///          evaluate at once, and all four engine answers are in the measurement table on
///          `app_engine_vocabulary_identifiers.dart`.
///
///          **2. Why not "wrap whatever the user has in the expression" — this sheet's one design
///          decision, and it is measured.** The engine does not error on a **scalar**; it answers with
///          a plausible value: host measurements `det(5)` = `5`, `inv(5)` = `0.2`, `transpose(5)` =
///          `5`. With a plain number in the expression, "wrap it" would put an answer nobody would
///          question on screen — one that answers a different question, which is the silent wrong value
///          this project treats as the worst kind. A complete insertion has no such state: the inserted
///          text **always** holds a `matrix(…)`, so this app never hands a scalar to `det`. The same
///          trade-off gives `Σ`/`Π`/`mean` their shape (the keypad has no comma key, so half a call can
///          never be completed).
///
///          **3. What those three grey rows are, and why they are there.** `rank`/`trace`/`echelon` are
///          the three names most likely to come to mind for matrix work, and the engine's answers for
///          them are **not** those three things (the measurement table is in the vocabulary part file):
///          `rank` **is** a real engine function and still returns the matrix unchanged, while `trace`
///          and `echelon` are not names the engine has at all, so the word is taken apart into symbols
///          and prints as a quantity carrying units. **A grey cell is honest** (the same device as the
///          `STAT` sheet's three cells and the result format menu's `Polar coordinates` entry): it
///          cannot be pressed, and the reason is written on its own row. Pressing it would give a
///          "right shape, wrong meaning" answer, which is worse than an error.
///
///          **4. Expiry.** The evidence for those three grey rows is pinned in
///          `test/features/calculator_matrix_menu_test.dart` and
///          `test/features/calculator_drg_matrix_band_keys_test.dart`: the day the engine answers those
///          three names correctly (or this app implements them itself) those assertions go red — and
///          those three cells should then light up rather than leaving an expired refusal quietly in
///          place.
extension _CalculatorPageMatrixSheet on _CalculatorPageState {
  /// 中文：`MTRX` 的 SHIFT 变体打开的面板。形状与 `CPLX`/`STAT` 那两个 opener 逐条相同
  ///       （`showModalBottomSheet` + 同一个高度上限常量），理由见本文件头。
  /// English: the sheet the `MTRX` SHIFT variant opens. Item-for-item the same shape as the `CPLX` and
  ///          `STAT` openers (`showModalBottomSheet` plus the same height-cap constant); the reasons are
  ///          in this file's head.
  void _openMatrixMenuSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _MatrixSheet(page: this, theme: theme),
    );
  }
}

/// 中文：`MTRX` 第二功能打开的面板本体。判据一条也不在这里：**插什么**由主屏 `_pressKey` 里那几个
///       `ins:` case 决定（面板只递 id），**哪几格按不动**由下面这张 `_refused` 表决定，而那张表里的
///       名字之所以不在，凭据是词表那个 part 文件里的实测。
///
///       面板的标题用的是厂商自己的命令名 `MATRIX_MENU` = "Matrix and Vector Menu"（手册第 941 行
///       给这颗键的那句话），逐字照抄——与结果格式菜单用 `rfMenu.title` 同一个做法。
/// English: the sheet `MTRX`'s second function opens. No judgement lives here: **what gets inserted**
///          is decided by the `ins:` cases in the screen's `_pressKey` (the sheet only hands over ids),
///          and **which cells cannot be pressed** is decided by the `_refused` table below, whose names
///          are absent for the measured reasons recorded in the vocabulary part file.
///
///          The title is the vendor's own command name, `MATRIX_MENU` = "Matrix and Vector Menu" (the
///          sentence the manual gives this key on line 941), copied verbatim — the same device the
///          result format menu uses with `rfMenu.title`.
class _MatrixSheet extends StatelessWidget {
  const _MatrixSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  /// 中文：（键面文字, 派发的 id）。**键面文字就是引擎的函数名**——面板上按下去插进表达式的正是
  ///       这个名字，两者写成同一个字面量，屏幕上因此不会出现「按钮叫一个名字、插进去的是另一个」。
  ///       id 与主屏 `_pressKey` 里那几个 `ins:` case 逐字对应。
  /// English: (cell face, dispatched id). **The face is the engine's own function name** — that is the
  ///          name a press inserts into the expression, so both are the same literal and the screen can
  ///          never show "the button says one name and inserts another". The ids correspond byte for
  ///          byte to the `ins:` cases in the screen's `_pressKey`.
  static const List<(String, String)> _entries = <(String, String)>[
    ('det', 'ins:det'),
    ('transpose', 'ins:transpose'),
    ('inv', 'ins:inv'),
    ('identity', 'ins:identity'),
  ];

  /// 中文：**三行按不动的格子**，以及它们各自那一行小字。表里的名字**一条也不在词表里**——这正是
  ///       它们按不动的原因（判据在词表那一侧，不是这里）。
  ///
  ///       为什么把按不动的格子也画出来（而不是干脆不列）：它们是矩阵运算里最容易被想起来的三个
  ///       名字，不列出来用户只会以为面板缺了一块；而列出来、灰着、旁边写着为什么，是**一句真话**。
  ///       与结果格式菜单里 `Polar coordinates` 那一项、`STAT` 面板里那三格同一个做法。
  ///
  ///       写成函数而不是 `const` 表：**每一行的小字必须跟着那一行走**，而字住在 `CalculatorStrings`
  ///       里。于是「加一个被拒绝的名字」只有一种写法——把名字与它那句话一起写出来；没有 `switch`
  ///       需要兜底（写 `switch` 就得有一个 `_`，而 `_` 正好是「加了名字却忘了写话」能溜过去的地方）。
  /// English: **the three unpressable rows** with their own small line each. Not one of those names is
  ///          in the vocabulary — which is exactly why they cannot be pressed (the judgement is on the
  ///          vocabulary's side, not here).
  ///
  ///          Why draw them at all rather than leave them out: they are the three names most likely to
  ///          come to mind for matrix work, and leaving them out only makes the user think the sheet is
  ///          missing a piece, while listing them, greyed, with the reason beside them, **is a true
  ///          sentence**. The same device as the result format menu's `Polar coordinates` entry and the
  ///          `STAT` sheet's three cells.
  ///
  ///          Written as a function rather than a `const` table: **each row's sentence has to travel with
  ///          that row**, and the sentences live in `CalculatorStrings`. So "add a refused name" has one
  ///          spelling — write the name and its sentence out together — and no `switch` needs a
  ///          catch-all (and a `switch` would need one, which is exactly where "added a name, forgot the
  ///          sentence" gets through).
  List<(String, String)> _refusedRows(CalculatorStrings strings) =>
      <(String, String)>[
        ('rank', strings.matrixMenuRankNote),
        ('trace', strings.matrixMenuTraceNote),
        ('echelon', strings.matrixMenuEchelonNote),
      ];

  @override
  Widget build(BuildContext context) {
    final strings = CalculatorStrings.of(context);
    final material = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 中文：标题逐字用厂商的命令名——菜单的名字也是那一格定义的一部分（与 `rfMenu.title`
            //       同一个做法）。它不含汉字，所以不走文案表。
            // English: the title is the vendor's command name verbatim — the menu's name is part of what
            //          that cell is (the same device as `rfMenu.title`). It holds no CJK, so it does not
            //          go through the string table.
            Text(
              'Matrix and Vector Menu',
              style: material.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (label, id) in _entries)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      page._pressKey(id);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.display.indicatorFg,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 中文：那一行小字不是装饰（与 `statisticsHint` 同一条理由）：不说「插的是完整调用」，
            //       屏幕上就会凭空出现一个 `matrix(2,2,1,2,3,4)`；不说「标量不包」，用户会以为
            //       「先打一个数再按 det」也成——那正是本面板唯一拒绝掉的形状。
            // English: this line is not decoration (the same reason as `statisticsHint`): without "a
            //          complete call is inserted" a `matrix(2,2,1,2,3,4)` appears from nowhere, and
            //          without "scalars are not wrapped" the user would expect "type a number, press
            //          det" to work — the one shape this sheet refuses.
            Text(
              strings.matrixMenuHint,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // 中文：**不是 `ListView`**：三行全部当场建出来，理由与结果格式菜单那一列相同
            //       （窗口矮一点时 `ListView` 里最后几行根本不在树里，而「菜单里有没有 `rank`
            //       这一行」正是要被问的断言）。
            // English: **not a `ListView`**: all three rows are built at once, for the same reason as
            //          the result format menu's column (in a short window a `ListView` would leave the
            //          last rows out of the tree entirely, while "is `rank` in the menu" is exactly one
            //          of the assertions to ask).
            for (final (label, note) in _refusedRows(strings))
              ListTile(
                dense: true,
                enabled: false,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: material.disabledColor,
                  ),
                ),
                subtitle: Text(note),
              ),
          ],
        ),
      ),
    );
  }
}
