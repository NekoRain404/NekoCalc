part of 'calculator_page.dart';

extension _CalculatorKeyDispatch on _CalculatorPageState {
  /// 中文：抽屉按钮。外壳的 Scaffold 有 Drawer 就打开它；本页单独使用时（组件测试就是这种）
  ///       Scaffold 里没有 drawer，于是是空操作。
  /// English: The drawer button: opens the shell Scaffold's drawer when it has one. Standalone —
  ///          which is what the widget tests do — the Scaffold has no drawer, so it is a no-op.
  void _openDrawer() {
    Scaffold.maybeOf(context)?.openDrawer();
  }

  /// 中文：页面级导航。`onNavigate` 为空时惰性——不虚构目标页。
  /// English: Page-level navigation; inert while `onNavigate` is null — no destination is invented.
  void _navigate(String destination) {
    widget.onNavigate?.call(destination);
  }

  Future<void> _pressKey(String key) async {
    _feedback();
    // 中文：SHIFT 是一次性修饰态，按键后自动复位；hyp 是持续态，不在这里复位。两个修饰键自身例外：
    //       它们由下面的 case 切换，若先在这里复位，再点一次 SHIFT 会「复位又立刻锁上」，永远退不出
    //       SHIFT 态。
    // English: SHIFT is one-shot and clears after a press; hyp latches and is not cleared here. The two
    //          modifier keys themselves are the exception: the cases below flip them, and clearing first
    //          would turn a second SHIFT tap into "unlatch then immediately relatch", never leaving the
    //          SHIFT state.
    if (key != 'shift' && key != 'hyp') _clearOneShotShift();
    // 中文：按键 id 在这里统一映射为控制器动作与解析器表达式，避免 parser 混入展示层符号。id 逐字来自
    //       `hiper_keypad.dart`（含 camelCase 的 `openVariables`、`cursorLeft` 这类），修饰态解析出的
    //       变体 id（`asin`、`ins:^3`、`cbrt`…）也走同一条通路。
    // English: Key ids are mapped to controller actions and parser expressions here, keeping display
    //          symbols out of the parser. Ids come verbatim from `hiper_keypad.dart` (camelCase ones
    //          such as `openVariables` and `cursorLeft` included), and the variant id a modifier
    //          resolves to (`asin`, `ins:^3`, `cbrt`, …) travels the same path.
    switch (key) {
      // 中文：修饰键。`CalculatorKeypad` 不认识任何 id，`SHIFT`/`hyp` 两个键的 id 就像别的键一样交到
      //       这里，由这两个 case 切换修饰态——这是它们唯一的处理处。
      // English: The modifier keys. `CalculatorKeypad` knows no ids; the `SHIFT`/`hyp` keys hand their
      //          ids here like every other key and these two cases flip the state — the only place that
      //          handles them.
      case 'shift':
        _toggleShift();
      case 'hyp':
        _toggleHyp();
      // 中文：导航键。`drawer` 打开外壳抽屉，其余交给页面的 `onNavigate`；为空时惰性——独立使用本页
      //       （组件测试）不虚构目标页。四个进制胶囊是进制换算入口，与 CNST/CONV 同归工具箱。
      // English: Navigation. `drawer` opens the shell's drawer and the rest go to the page's
      //          `onNavigate`, which is inert when null — standalone use (widget tests) invents no
      //          destination. The four base pills are base-conversion entry points and belong with
      //          CNST/CONV under the toolbox.
      case 'drawer':
        _openDrawer();
      case 'openHistory':
        _navigate('history');
      // 中文：`OTHER` 在 HiPER 里就是「键盘放不下的那些函数」的入口（它的手册原话），所以它打开
      //       更多函数面板，而不是工具箱；工具箱仍由 `CNST`/`CONV` 与四个进制胶囊经 `onNavigate`
      //       抵达（`MENU` 打开抽屉）。
      // English: in HiPER `OTHER` is the entry point for the functions the keypad cannot fit (its
      //          manual says so), so it opens the more-functions sheet rather than the toolbox. The
      //          toolbox stays reachable through `CNST`/`CONV` and the four base pills via
      //          `onNavigate` (`MENU` opens the drawer).
      case 'openTools':
        _openMoreFunctionsSheet();
      // 中文：**`CONV` 从此打开单位面板，不再切到工具箱。** 这是本步唯一一处「改了已经工作的键」，
      //       理由与代价写在这里：
      //
      //       - 键盘上**没有字母键**，所以单位名只能由面板送进表达式；而 `CONV` 这个名字本身就是
      //         「换算」，单位入口放它下面最容易被找到（步骤 6 的 brief 也是这么要求的）。
      //       - 工具箱那 21 个换算器**没有因此进不去**：抽屉里有独立的「工具箱」入口，
      //         `CNST` 与四个进制胶囊（DEC/HEX/BIN/OCT）也都仍然切到 `tools`。`CONV` 是**唯一**
      //         改掉的那一个键，它原来也只是切到同一个页面。
      //       - 测试钉住的只有这颗键的 id/标签/可用态（`keypad_definition_test.dart`）与
      //         `onNavigate('tools')` 本身（`app_shell_test.dart`），两者都不受影响。
      // English: **`CONV` now opens the unit sheet instead of switching to the toolbox.** This is the
      //          one place this step changes a key that already worked, so the reason and the price are
      //          written here:
      //
      //          - the keypad has **no letter keys**, so a unit name can only reach the expression
      //            through a sheet; and `CONV` is literally named "conversion", which makes it the most
      //            discoverable home for the unit entry (the step 6 brief asks for exactly this).
      //          - the toolbox's 21 converters are **not** cut off: the drawer has its own 工具箱 entry,
      //            and `CNST` plus the four base pills (DEC/HEX/BIN/OCT) all still navigate to `tools`.
      //            `CONV` is the **only** key that changed, and it merely switched to that same page
      //            before.
      //          - the tests pin only this key's id/label/enabled state (`keypad_definition_test.dart`)
      //            and `onNavigate('tools')` itself (`app_shell_test.dart`); neither is affected.
      case 'openUnits':
        _openUnitSheet();
      // 中文：**`X` 打开变量面板**（`Y` 走 `ins:y`，见键位表里那两颗键的注释）。这是加法：`dis:x`
      //       原来是一颗灰键，`X`/`Y` 两个 id 都不在 `dispatchedKeyIds` 里，也没有任何测试钉过它们
      //       的行为（`keypad_definition_test.dart` 钉的是「逐格快照」与「每个**已启用** id 主屏都
      //       接得住」，两条都随这一次改动一起更新）。
      // English: **`X` opens the variable sheet** (`Y` goes through `ins:y`; see the notes on those two
      //          cells in the key table). This is an addition: `dis:x` was a grey key, neither `X` nor
      //          `Y` had an id in `dispatchedKeyIds`, and no test pinned their behaviour
      //          (`keypad_definition_test.dart` pins the per-cell snapshot and "every **enabled** id is
      //          caught by the screen", both of which are updated with this change).
      case 'openVariables':
        _openVariableSheet();
      // 中文：**`CPLX` 与 `STAT` 打开各自的入口面板**（本轮点亮的两颗灰键）。这是加法：两个 `dis:`
      //       id 此前从不在 `dispatchedKeyIds` 里，也没有任何测试钉过它们的行为；键位表那两条契约
      //       （逐格快照、每个已启用 id 主屏接得住）随这一次改动一起更新。
      //
      //       两颗键做的事**不是同一类**，这一点值得写下来：
      //       - `CPLX` 是**入口**——复数能力早就在（引擎的 `allow_complex` 一直开着），缺的只是
      //         共轭/辐角/实部/虚部这四个没有键的函数；
      //       - `STAT` 是**入口**，但它背后那个「统计编辑器」这一轮**没有做**（数据集、回归、
      //         散点图都不在），面板只把完整的统计调用送进表达式。这一点在报告里明写了。
      //       两颗都**不改任何已经在工作的键**，也都不往结果行上放任何东西。
      // English: **`CPLX` and `STAT` open their own entrance sheets** (the two grey keys lit this
      //          round). This is an addition: neither `dis:` id was ever in `dispatchedKeyIds`, and no
      //          test pinned their behaviour; the key table's two contracts (the per-cell snapshot and
      //          "every enabled id is caught by the screen") are updated with this change.
      //
      //          What the two keys do is **not the same kind of thing**, and that is worth writing
      //          down:
      //          - `CPLX` is an **entrance** — the complex capability was already there (the engine's
      //            `allow_complex` is on), and only the four keyless functions conjugate / argument /
      //            real part / imaginary part were missing;
      //          - `STAT` is an **entrance** too, but the "statistics editor" behind it is **not built**
      //            this round (no dataset, no regression, no scatter plot); the sheet only delivers
      //            complete statistics calls into the expression. The report says so plainly.
      //          Neither changes any key that already worked, and neither puts anything on the result
      //          line.
      case 'openComplex':
        _openComplexSheet();
      case 'openStatistics':
        _openStatisticsSheet();
      case 'openConstants':
        _navigate('tools');
      // 中文：**四个进制胶囊从这一步起真的做进制换算**（它们此前只是切到工具箱）。理由与代价：
      //
      //       - 它们是键盘上**唯一**与进制有关的入口，而它们本来就长成「▸HEX」——按下去却只是
      //         换一页，那颗键的名字与它做的事是两回事。
      //       - 换算是**显示**：结果行、`Ans`/`last`、记忆寄存器、历史都不动，所以这一改碰不到
      //         任何既有数值行为（`CalculatorController.showBaseReadout` 上有完整论证，含两个
      //         被否掉的方案）。
      //       - 工具箱**没有因此进不去**：`CNST` 仍切 `tools`，抽屉里也有独立的「工具箱」入口。
      //         这四颗键是唯一改掉的键，而且它们原来也只是切到同一个页面。
      //       - 测试钉住的只有它们的 id/标签/可用态（`keypad_definition_test.dart`）与
      //         「每个已启用的 id 主屏都接得住」（`calculator_page_test.dart`），两者都仍然成立
      //         ——它们的 id 仍在 `dispatchedKeyIds` 里。
      // English: **the four base pills really do base conversion from this step on** (until now they
      //          merely switched to the toolbox). Why, and what it costs:
      //
      //          - they are the keypad's **only** base-related entrance and they are literally shaped
      //            like `▸HEX`; pressing one used to change page, so the key's name and its act were
      //            two different things;
      //          - the conversion is a **display**: the result line, `Ans`/`last`, the memory register
      //            and the history stay untouched, so this change reaches no numeric behaviour that
      //            exists today (the full argument, both rejected designs included, is on
      //            `CalculatorController.showBaseReadout`);
      //          - the toolbox is **not** cut off: `CNST` still switches to `tools` and the drawer has
      //            its own 工具箱 entry. These four are the only keys that changed, and they used to
      //            switch to that same page anyway;
      //          - what the tests pin is their id/label/enabled state
      //            (`keypad_definition_test.dart`) and "every enabled id is caught by the screen"
      //            (`calculator_page_test.dart`) — both still hold, since their ids stay in
      //            `dispatchedKeyIds`.
      case 'baseBin':
        await _showBaseReadout(CalculatorBase.bin);
      case 'baseOct':
        await _showBaseReadout(CalculatorBase.oct);
      case 'baseDec':
        await _showBaseReadout(CalculatorBase.dec);
      case 'baseHex':
        await _showBaseReadout(CalculatorBase.hex);
      case 'notationCycle':
        await _cycleNotation();
      case 'backspace':
        _controller.backspace();
      case 'clear':
        _controller.clear();
      // 中文：`◀` `▶`——**光标键，不是翻页键**（来源见 `hiper_keypad.dart` 第 1 行那一段：HiPER 的
      //       命令表里只有 `CHAR_LEFT`/`CHAR_RIGHT`「移动一个字符」，没有翻页这一个动作）。它们走
      //       控制器已有的两个方法，与 `More...` 面板里那两颗光标键**同一个入口**——所以「键盘上按一下
      //       移一格」与「面板里长按连发」动的是同一份光标状态，不存在第二套移动逻辑。
      //       光标已经在两端时那两个方法是空操作（`cursorIndex == 0` / `>= expression.length` 直接
      //       返回），这正是要的：那里没有可去的位置，屏幕上的光标本来就停在那儿。
      // English: `◀` `▶` — **cursor keys, not page keys** (the sources are in `hiper_keypad.dart`'s
      //          row-1 note: HiPER's command catalogue has only `CHAR_LEFT`/`CHAR_RIGHT`, "move one
      //          character", and no paging action at all). They take the controller's two existing
      //          methods — **the same entrance** the two cursor keys inside the `More...` sheet use — so
      //          "one tap on the keypad" and "hold-to-repeat in the sheet" move one and the same caret
      //          state, with no second movement logic anywhere.
      //          At either end those methods are no-ops (`cursorIndex == 0` / `>= expression.length`
      //          returns early), which is exactly right: there is nowhere to go, and the caret is
      //          visibly already there.
      case 'cursorLeft':
        _controller.moveCursorLeft();
      case 'cursorRight':
        _controller.moveCursorRight();
      case 'equals':
        final submitResult = await _controller.submit();
        if (mounted && submitResult.needsAttention) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(submitResult.message)));
        }
      // 中文：DRG 是循环键（HiPER 一个键在 DEG 与 RAD 之间切换），不是两个键。
      // English: DRG cycles (HiPER has one key switching between DEG and RAD, not two).
      case 'angleMode':
        _controller
            .setAngleMode(_controller.angleMode == 'DEG' ? 'RAD' : 'DEG');
      // 中文：`+/−` 用控制器已有的符号切换 token，不新造动作。
      // English: `+/−` uses the controller's existing sign-toggle token.
      case 'negate':
        _controller.input('+/-');
      case 'ans':
        _controller.append(_controller.reusableResult);
      // 中文：记忆键。`x→M`（id `memoryStore`）在 HiPER 上是把当前值**写入**寄存器（替换）——这个
      //       语义现在住在控制器里（`memoryStore()`）。它以前是主屏上写死的「先清空再累加」，而那个
      //       写法有一个破坏性缺陷：值放不进 double 时清空照常发生、累加被拒，**用户原来的记忆值
      //       被一次拒绝静默抹掉**（详见那个方法的注释）。判定必须在清空之前发生，主屏拿不到那个
      //       判定，所以这一对调用搬进了控制器，这个 case 只剩下一次调用。
      //
      //       被拒时控制器回一句话（`String?`），[_reportMemory] 把它交给用户；成功时它回 `null`
      //       （无话可说）。**这是这三个 case 与从前唯一的行为差别**：放不进 double 的值仍然一律
      //       被拒、寄存器仍然一动不动，只是这一次拒绝不再静默。`MR`/`MC` 不会拒绝——寄存器里那个
      //       值总是写得回表达式，而清零在寄存器已经是 0 时是空操作，且那是屏幕上看得见的
      //       （`M` 徽标本来就不在）。
      // English: Memory keys. On HiPER `x→M` (id `memoryStore`) *writes* the current value into the
      //          register (a replace), and that semantics now lives on the controller
      //          (`memoryStore()`). It used to be a hardcoded "clear, then add" on the screen, and
      //          that shape had a destructive defect: when the value does not fit a double the clear
      //          happened anyway and the add was refused, so **one refusal silently wiped the user's
      //          previous memory value** (see that method's own note). The judgement has to run
      //          before the clear and the screen cannot make it, so the pair moved into the
      //          controller and this case is one call again.
      //
      //          A refusal comes back as a sentence (`String?`) which [_reportMemory] hands to the
      //          user; success comes back as `null` (nothing to say). **That is the only behavioural
      //          difference these three cases have**: a value that does not fit a double is still
      //          refused and the register still does not move — the refusal is simply no longer
      //          silent. `MR`/`MC` cannot refuse: the register's value always writes back into the
      //          expression, and clearing an already-zero register is a no-op that the screen already
      //          shows (the `M` badge is absent).
      case 'memoryRecall':
        _controller.memoryRecall();
      case 'memoryStore':
        _reportMemory(_controller.memoryStore());
      case 'memoryAdd':
        _reportMemory(_controller.memoryAdd());
      case 'memorySubtract':
        _reportMemory(_controller.memorySubtract());
      // 中文：**结果行的形态**——`x⇔E` 打开菜单、`d/c` 在标准写法与十进制之间来回。HiPER 的手册把
      //       「结果格式」与「数字记法」分成两维（`x⇔E` 是前者、`FSE` 是后者），而 `d/c` 的 SHIFT
      //       标签 `a b/c` 正是同一格里分数那一格，所以这两颗键管的是同**一维**里的两件事。
      //
      //       **两者都只改显示，一个值都不碰**：`Ans`/`last`、记忆寄存器、继续使用、历史与提交路径
      //       读的都还是 `MathResult.decimalText`，这两颗键连控制器的状态都不进——形态记在这一页的
      //       `_resultForm` 上。这不是四个进制胶囊那条「显示读数」的路，而是**结果行自己的画法**。
      //
      //       按下去有没有变化由 [ResultPresentation] 回答（它按「画出来是不是同一行」合并形态）：
      //       `2+2` 只有一种画法，于是菜单里那些格都是灰的——不做任何假装（不弹提示、不写状态行）。
      // English: **the result line's form** — `x⇔E` opens the menu, `d/c` toggles between the standard
      //          spelling and the decimal. HiPER's manual splits "result format" from "number notation"
      //          (`x⇔E` the first, `FSE` the second), and `d/c`'s SHIFT label `a b/c` is the fraction
      //          cell of that same dimension — so both keys work inside **one** dimension.
      //
      //          **Both change the display only; neither touches a value**: `Ans`/`last`, the memory
      //          register, continue-with, history and the submit path all still read
      //          `MathResult.decimalText`, and these keys do not even enter the controller's state —
      //          the form lives in this page's `_resultForm`. This is not the four base pills'
      //          "read-out" route but **the result line's own drawing**.
      //
      //          Whether a press changes anything is [ResultPresentation]'s answer (it merges forms by
      //          "does it draw the same line"): `2+2` has one drawing, so those menu cells are grey —
      //          nothing is faked here (no toast, no status-row text).
      // 中文：**自本轮起它打开菜单，不再走一圈**——来源、形状与代价写在 `_openResultFormatSheet` 上。
      // English: **from this round on it opens the menu, no longer a cycle** — sources, shape and cost
      //          are on `_openResultFormatSheet`.
      case 'resultForm':
        _openResultFormatSheet();
      case 'fractionForm':
        _setResultForm(_resultPresentation.toggleStandard(_resultForm));
      // 中文：`D°M'S`——**度分秒写法 ⇄ 原来那一行**，与 `d/c` 同一个形状（也是只改显示、值一个
      //       都不碰），只是走 `toggleDms` 而不经过菜单。没有度分秒写法时（没引擎、RAD 模式、
      //       形状认不出）是同样的空操作。
      // English: `D°M'S` — **the DMS spelling ⇄ the line it had**, the same shape as `d/c` (display
      //          only, not one value touched), except that it goes through `toggleDms` and never
      //          through the menu. With no DMS spelling (no engine, RAD mode, an unrecognised shape)
      //          it is the same honest no-op.
      case 'dmsForm':
        _setResultForm(_resultPresentation.toggleDms(_resultForm));
      // 中文：`ins:` 前缀 = 插入这段文本。三处落点比裸插入更贴切：`%` 走控制器的百分号运算（`50+10%`
      //       会被折算），`exp` 走一元函数（它插入 `exp(`，裸插的 `exp` 会被解析器拒绝），`inf` 是
      //       解析器承认的常数。
      // English: The `ins:` prefix means "insert this text". Three ids land on something better than a
      //          raw insert: `%` uses the controller's percent arithmetic (so `50+10%` is resolved),
      //          `exp` uses the unary function (it inserts `exp(`; a bare `exp` is rejected by the
      //          parser) and `inf` is a constant the parser knows.
      case 'ins:pi':
        _controller.append('pi');
      case 'ins:e':
        _controller.append('e');
      case 'ins:^-1':
        _controller.append('^-1');
      case 'ins:^2':
        _controller.append('^2');
      case 'ins:^3':
        _controller.append('^3');
      case 'ins:^':
        _controller.append('^');
      case 'ins:10^':
        _controller.append('10^');
      case 'ins:e^':
        _controller.append('e^');
      case 'ins:inf':
        _controller.append('inf');
      // 中文：微积分与复现调用那几颗键插的是**完整**的引擎调用，不是 `名字(`：
      //
      //       - 它们全都要两个以上实参，而**键盘上没有逗号键**（`defaultInputKeyIds` 里有数字、
      //         小数点、括号与加减，没有 `,`），所以 `sum(` 这种前缀在键盘上永远补不完；
      //       - 而没填满的槽位会让整段调用降级成字面文本——`ExpressionAstParser` 把空的实参判成
      //         `ParseErrorNode`，`_parseCall` 因此让整个调用 `_failure`（实测：`log(,)` 的产物是
      //         `\text{log(,)}`）。这正是这一步要消灭的那种「只产出坏表达式的键」。
      //
      //       插入的实参取自 `qalc` 5.12.0 的实测结果（见步骤 5 报告），按下去就是一个立刻算得出来
      //       的数：`sum(x,1,10,x)`=55、`product(x,1,5,x)`=120、`integrate(x^2,0,1,x)`=1/3、
      //       `limit(sin(x)/x,0,x)`=1、`log(8,2)`=3。它们同时把引擎的实参顺序写在屏幕上，用户
      //       可以照着自己改（内联编辑器里逗号是打得出的）。`OTHER` 面板里的 `√2`→`sqrt(2)` 是
      //       同一形状，不是新发明的做法。
      // English: the calculus/randomness keys insert a **complete** engine call rather than a bare
      //          `name(`:
      //
      //          - every one of them takes two or more arguments, and **the keypad has no comma
      //            key** (`defaultInputKeyIds` holds digits, the decimal point, brackets and the
      //            two signs — no `,`), so a `sum(` prefix can never be completed from the keypad;
      //          - an unfilled slot makes the whole call degrade to literal text — the
      //            `ExpressionAstParser` reads an empty argument as a `ParseErrorNode` and
      //            `_parseCall` then `_failure`s the entire call (measured: `log(,)` emits
      //            `\text{log(,)}`). That is exactly the "key that only produces broken
      //            expressions" this step exists to remove.
      //
      //          The arguments come from measurements with `qalc` 5.12.0 (see the step 5 report), so
      //          a press yields an immediately evaluable number: `sum(x,1,10,x)`=55,
      //          `product(x,1,5,x)`=120, `integrate(x^2,0,1,x)`=1/3, `limit(sin(x)/x,0,x)`=1,
      //          `log(8,2)`=3. They also put the engine's argument order on screen, and the user can
      //          edit from there (the inline editor does accept commas). `√2` → `sqrt(2)` in the
      //          `OTHER` sheet has the same shape; this is not a new invention.
      case 'ins:sum':
        _controller.append('sum(x,1,10,x)');
      case 'ins:product':
        _controller.append('product(x,1,5,x)');
      case 'ins:integrate':
        _controller.append('integrate(x^2,0,1,x)');
      // 中文：**`d/dx`（`∫dx` 的 SHIFT 变体）插 `diff(x^2,x)`——两个槽，引擎自己的实参顺序。**
      //       引擎的签名是 `diff(表达式, 对谁求导=undefined, 阶数=1, 点的值=undefined)`
      //       （`BuiltinFunctions-calculus.cc` 的 `MathFunction("diff", 1, 4)`：第 4 个才是**点的值**）。
      //       HiPER 手册那套「表达式 / 点 / 变量」是**反的**：宿主实测 `diff(x^2,2,x)` 被原样退回，
      //       而把点填进第 3 格是**错值**（见下）。
      //
      //       **为什么不摆四槽的 `diff(x^2,x,1,2)`**：删掉 `,1` 就成了 `diff(x^2,x,2)`，引擎读成
      //       **二阶导数**（宿主实测 `= 2`），而四槽都在时那是「在点 2 的导数」（`= 4`）——两个数
      //       都像样，含义不同，屏幕上分不出来。两槽没有这道坎：删掉 `,x` 得到 `diff(x^2)`，引擎
      //       自己找变量，宿主实测仍是 `= 2x`。**屏幕上的错值比报错更糟**，所以取两槽。
      //       附带一条：`TexEmitter._derivative` 的专属模板只在 2/3 个实参时启用，四槽退回
      //       `\operatorname{diff}{…}`，连 `d/dx` 的形状都排不出来。
      //
      //       宿主实测（`qalc` 5.12.0）：`diff(x^2,x)`=`2x`、`diff(x^2)`=`2x`、`diff(x^2,x,1,2)`=`4`、
      //       `diff(x^2,x,2)`=`2`。用户改起来与上面几颗一样方便（内联编辑器里逗号是打得出的）。
      // English: **`d/dx` (the SHIFT variant of `∫dx`) inserts `diff(x^2,x)` — two slots, in the
      //          engine's own argument order.** The signature is
      //          `diff(expression, with respect to=undefined, order=1, variable value=undefined)`
      //          (`MathFunction("diff", 1, 4)` in `BuiltinFunctions-calculus.cc`: slot 4 is the
      //          **point**). The manual's "expression / point / variable" order is the **reverse**:
      //          `diff(x^2,2,x)` comes back unevaluated on the host, and a point in slot 3 is a
      //          **wrong value** (below).
      //
      //          **Why not the four-slot `diff(x^2,x,1,2)`**: delete `,1` and `diff(x^2,x,2)` is read
      //          as the **second derivative** (`= 2` on the host) where all four slots said "the
      //          derivative at the point 2" (`= 4`) — both values look reasonable, they mean different
      //          things, and the screen cannot tell you which you have. The two-slot shape has no such
      //          cliff: delete `,x` and `diff(x^2)` lets the engine find the variable itself, still
      //          `= 2x`. **A wrong value on screen is worse than an error**, so two slots win.
      //          `TexEmitter._derivative`'s template only fires at 2 or 3 arguments; four fall back to
      //          `\operatorname{diff}{…}` and cannot even typeset as `d/dx`.
      //
      //          Host measurements (`qalc` 5.12.0): `diff(x^2,x)`=`2x`, `diff(x^2)`=`2x`,
      //          `diff(x^2,x,1,2)`=`4`, `diff(x^2,x,2)`=`2`. As easy to edit as the keys above (the
      //          inline editor does accept commas).
      case 'ins:diff':
        _controller.append('diff(x^2,x)');
      case 'ins:limit':
        _controller.append('limit(sin(x)/x,0,x)');
      case 'ins:logxy':
        _controller.append('log(8,2)');
      // 中文：`MTRX` 与 `i` 同样是**完整**的插入物，理由与上面那几颗一样（多实参 + 没有逗号键）。
      //       矩阵的实参顺序取自引擎自己的 `MathFunction("matrix", 3)`：行、列、元素；插入的
      //       2×2 在 `qalc` 5.12.0 与真机上都印成 `[1  2; 3  4]`。
      //       `i` 插在数值后面不做任何加工——`2` 之后按 `i` 得到 `2i`，两个解析器都读成隐式乘法。
      // English: `MTRX` and `i` are **complete** insertions for the same reason as the ids above
      //          (several arguments, and no comma key). The matrix arguments follow the engine's own
      //          `MathFunction("matrix", 3)` — rows, columns, elements — and the 2×2 inserted here
      //          prints as `[1  2; 3  4]` on both `qalc` 5.12.0 and the device. `i` is inserted
      //          unmodified: after a number it gives `2i`, which both parsers read as an implicit
      //          product.
      case 'ins:matrix':
        _controller.append('matrix(2,2,1,2,3,4)');
      case 'ins:i':
        _controller.append('i');
      // 中文：`Y`（横带那格）一下把 `y` 插进表达式——与 `i` 逐字同样的做法。`x` 的字母从 `X` 打开的
      //       面板里插入（那颗键在那儿是「插入 x」按钮），两个变量因此都进得来。
      // English: `Y` (the band cell) inserts `y` in one tap — byte for byte what `i` does. The letter
      //          `x` is inserted from the sheet `X` opens (where it is the "insert x" button), so both
      //          variables are reachable.
      case 'ins:y':
        _controller.append('y');
      // 中文：`ran#` 插的是完整的 `rand()`。`rand` 是引擎的零实参函数
      //       （`BuiltinFunctions-statistics.cc` 的 `MathFunction("rand", 0, 2)`），带括号按下去
      //       就是一个立刻可求值的随机数。
      // English: `ran#` inserts a complete `rand()`. `rand` is the engine's zero-argument function
      //          (`MathFunction("rand", 0, 2)` in `BuiltinFunctions-statistics.cc`), so the
      //          parenthesised spelling is immediately evaluable.
      case 'ins:rand':
        _controller.append('rand()');
      // 中文：**`STAT` 面板插的四个统计调用**，与上面那几颗同一个形状：完整、立刻求得出一个数、
      //       把引擎的实参顺序摆在屏幕上。那四个名字都要一串实参，而**键盘上没有逗号键**，所以
      //       `mean(` 这种前缀在键盘上永远补不完——理由与 `ins:sum` 那一段逐字相同。
      //
      //       实参 `(1,2,3,4)` 是一份**起手数据**，不是算出来的值：宿主实测（`qalc` 5.12.0）
      //       `mean(1,2,3,4)` = `2.5`、`median(1,2,3,4)` = `2.5`、`stdev(1,2,3,4)` = `1.290994449`、
      //       `var(1,2,3,4)` = `1.666666667`（后两个是**样本**口径，分母 n−1）。四个用同一串数，
      //       是为了让它们互相可比，也短到看得完。
      // English: **the four statistics calls the `STAT` sheet inserts**, the same shape as the keys
      //          above: complete, immediately evaluable, and it puts the engine's argument order on
      //          screen. Those four names each take a run of arguments and **the keypad has no comma
      //          key**, so a prefix like `mean(` can never be completed from the keypad — byte for byte
      //          the reason in the `ins:sum` note.
      //
      //          The argument list `(1,2,3,4)` is a **starting sample**, not a computed value: measured
      //          on the host (`qalc` 5.12.0), `mean(1,2,3,4)` = `2.5`, `median(1,2,3,4)` = `2.5`,
      //          `stdev(1,2,3,4)` = `1.290994449` and `var(1,2,3,4)` = `1.666666667` (the last two are
      //          the **sample** convention, divisor n−1). All four share one run of numbers so they are
      //          comparable with each other, and short enough to read at a glance.
      //
      // 中文：**实参从这一轮起由数据集给出**（`statisticsCall` 是唯一那一处判断）。数据集非空时插的
      //       是它那几个值（`mean(5,12,13)`），**为空时插的仍然是上面那串起手数据**——所以「没有
      //       数据集」这条路上，本轮的行为与上一轮逐字节相同。形状一点没变（完整调用、立刻可求值），
      //       变的只是那几个数从哪里来。
      //
      //       用户在表达式里手改过的那条调用**不受任何影响**：面板只往光标处插一条新的，从不回头去
      //       改已经写下的文本。数据集与那条调用从插入那一刻起就是两样东西（理由写在
      //       `_CalculatorDataset` 与 `statisticsCall` 的注释里）。
      // English: **the arguments come from the dataset from this round on** (`statisticsCall` is the
      //          one place that decides). With a non-empty dataset it inserts those values
      //          (`mean(5,12,13)`); **with an empty one it still inserts the starting sample above** —
      //          so on the "no dataset" path this round's behaviour is byte for byte the last round's.
      //          The shape is untouched (a complete, immediately evaluable call); all that moved is
      //          where the numbers come from.
      //
      //          A call the user has hand-edited in the expression is **not affected at all**: the
      //          sheet only inserts a new one at the cursor and never reaches back into text already
      //          written. Dataset and call are two different objects from the moment of insertion (the
      //          reasons are on `_CalculatorDataset` and on `statisticsCall`).
      case 'ins:mean':
        _controller.append(_controller.statisticsCall('mean'));
      case 'ins:median':
        _controller.append(_controller.statisticsCall('median'));
      case 'ins:stdev':
        _controller.append(_controller.statisticsCall('stdev'));
      case 'ins:var':
        _controller.append(_controller.statisticsCall('var'));
      // 中文：**双变量那三格。** 它们与上面四格的分别只有一处：**实参的形状**。上面四格吃
      //       **一个行矩阵**（`mean(5,12,13)`），这三格吃**一个两行矩阵**
      //       （`pearson(matrix(2,3,1,2,3,4,5,6))`）——第一行 X、第二行 Y，正是 HiPER 自己那句话
      //       （`error.regression_parameter_error`：「two rows: the first one with X values, the
      //       second one with Y values」）。切法与理由都在 `regressionCall` 上。
      //
      //       **读不成两行时插不进去任何东西**：`regressionCall` 那一条为 `null` 时这里是空操作。
      //       这不是「静默失灵」——`STAT` 面板上那三格在这种状态下**是禁用的**（同一个判据，
      //       见 `_StatisticsSheet`），所以这条 `null` 分支在界面上到不了；把它写成空操作是为了
      //       让「判据说不行」与「屏幕上不动作」是同一句话，而不是让某个 id 绕过面板去插一条
      //       引擎答不出来的调用。**宁可什么都不发生，也不要一个错值。**
      // English: **the three two-variable cells.** They differ from the four above in exactly one
      //          place: **the shape of the argument**. Those four take **a one-row matrix**
      //          (`mean(5,12,13)`); these three take **a two-row matrix**
      //          (`pearson(matrix(2,3,1,2,3,4,5,6))`) — first row X, second row Y, which is HiPER's own
      //          sentence (`error.regression_parameter_error`: "two rows: the first one with X values,
      //          the second one with Y values"). The cut and its reasons are on `regressionCall`.
      //
      //          **When the dataset cannot be read as two rows nothing is inserted**: while
      //          `regressionCall` is `null` this is a no-op. That is not a silent failure — in that
      //          state those three cells are **disabled** on the `STAT` sheet (the same judgement; see
      //          `_StatisticsSheet`), so the `null` branch is unreachable from the screen. It is
      //          written as a no-op so that "the judgement says no" and "the screen does nothing" are
      //          the same sentence, rather than letting some id bypass the sheet and insert a call the
      //          engine cannot answer. **Better that nothing happens than a wrong value.**
      case 'ins:pearson':
        _appendRegressionCall('pearson');
      case 'ins:covar':
        _appendRegressionCall('covar');
      case 'ins:spearman':
        _appendRegressionCall('spearman');
      // 中文：**三个拟合格。** 与上面三格共用 `_appendRegressionCall` 那一条规矩（判据说 `null`
      //       就什么都不做），但**判据与形状都不是同一个**：下限按函数取（2/3/4），插的是两个
      //       行矩阵而不是一个两行矩阵——理由与实测表在 `CalculatorController.fitCall` 上。
      //       面板上那三格各自的禁用态用的是同一条判据。
      // English: **the three fit cells.** They share the rule `_appendRegressionCall` follows ("the
      //          judgement says `null` ⇒ do nothing") but neither the judgement nor the shape is the
      //          same: the floor is per function (2/3/4) and what lands is two row matrices rather than
      //          one two-row matrix — the reasons and the measurement table are on
      //          `CalculatorController.fitCall`. Each cell's disabled state on the sheet uses that same
      //          judgement.
      case 'ins:linearfit':
        _appendFitCall('linearfit');
      case 'ins:quadraticfit':
        _appendFitCall('quadraticfit');
      case 'ins:cubicfit':
        _appendFitCall('cubicfit');
      case 'ins:%':
        _controller.input('%');
      case 'ins:exp':
        _controller.applyUnaryFunction('exp');
      case 'sin':
      case 'cos':
      case 'tan':
      case 'asin':
      case 'acos':
      case 'atan':
      case 'sinh':
      case 'cosh':
      case 'tanh':
      // 中文：以下几项在 HiPER 网格上没有专属键位，只能从 `OTHER` 的「更多函数」面板进来
      //       （`cot`/`sec`/`csc`/`log₂`/`exp`、取整族与角度辅助族）；id 逐字沿用重写前
      //       `_functionSections` 的写法。
      // English: the ids below have no HiPER grid cell and are reachable only from `OTHER`'s
      //          "more functions" sheet (`cot`/`sec`/`csc`/`log₂`/`exp`, the rounding family and the
      //          angle helpers); the ids are kept verbatim from the pre-rewrite `_functionSections`.
      case 'cot':
      case 'sec':
      case 'csc':
      case 'log₂':
      case 'exp':
      case 'floor':
      case 'ceil':
      case 'round':
      case 'deg':
      case 'rad':
      case 'log':
      case 'ln':
      case 'abs':
      case 'sqrt':
      case 'cbrt':
      case 'fact':
      // 中文：复数面板插的那四个（`CPLX`）。与 `abs` 一样是**一元函数**，走同一条 `applyUnaryFunction`
      //       ——它包住光标前那一个值（`3+4i` 上按 `conj` 得到 `conj(3+4i)`），与 `sin`/`sqrt` 逐字
      //       同一条路，所以光标位置、撤销栈与边打边算都不需要新代码。
      //       它们的 id 与解析器函数名逐字相同，`_functionNameForKey` 因此原样返回。
      // English: the four the complex sheet inserts (`CPLX`). Unary like `abs`, travelling the same
      //          `applyUnaryFunction` — which wraps the value before the cursor (`conj` on `3+4i` gives
      //          `conj(3+4i)`), byte for byte the path `sin`/`sqrt` take, so cursor position, the undo
      //          stack and as-you-type evaluation need no new code. Their ids are the parser's own
      //          function names, so `_functionNameForKey` returns them unchanged.
      case 'conj':
      case 'arg':
      case 're':
      case 'im':
        _controller.applyUnaryFunction(_functionNameForKey(key));
      case 'mod':
      case 'nCr':
      case 'nPr':
      case 'root':
      // 中文：同上——`gcd`/`lcm`/`atan2` 与 `min`/`max` 也只在「更多函数」面板里。
      // English: as above — `gcd`/`lcm`/`atan2` and `min`/`max` live only in the sheet too.
      case 'min':
      case 'max':
      case 'gcd':
      case 'lcm':
      case 'atan2':
        _controller.applyBinaryFunction(_functionNameForKey(key));
      // 中文：常数与角度快捷值，同样只在「更多函数」面板里——插入的文本逐字沿用旧函数面板，
      //       所以行为与重写前一致。
      // English: the constants and angle shortcuts, likewise sheet-only — the inserted text is kept
      //          from the old function panel, so the behaviour matches the pre-rewrite screen.
      case '2ˣ':
        _controller.append('2^');
      case '90°':
        _controller.append('90');
      case '180°':
        _controller.append('180');
      case '360°':
        _controller.append('360');
      case 'φ':
        _controller.append('1.61803398875');
      case '√2':
        _controller.append('sqrt(2)');
      case 'τ':
        _controller.append('(2*pi)');
      case 'ln2':
        _controller.append('0.69314718056');
      case 'ln10':
        _controller.append('2.30258509299');
      case 'g':
        _controller.append('9.80665');
      case 'c':
        _controller.append('299792458');
      case '2π':
        _controller.append('2*pi');
      case 'π/2':
        _controller.append('pi/2');
      // 中文：`×`/`÷` 的键面符号正是控制器认的运算符（`_isOperator` 只认 `+ - × ÷ ^`），而键位表的
      //       id 是给解析器用的 ASCII `*`/`/`。这里把 id 翻回符号，才会走 `_appendOperator`
      //       （它折叠尾随的运算符、忽略开头的运算符），而不是当成普通字符插入：`5` `+` `×` `3`
      //       得到 `5×3` 而不是 `5+*3`，空显示时按 `×` 什么也不发生。
      // English: the faces' `×`/`÷` are the tokens the controller recognises (`_isOperator` knows only
      //          `+ - × ÷ ^`) while the key table's ids are the parser-friendly ASCII `*` and `/`.
      //          Translating the id back to the symbol routes it through `_appendOperator` (which
      //          collapses a trailing operator and ignores a leading one) instead of a plain insert:
      //          `5` `+` `×` `3` gives `5×3`, not `5+*3`, and `×` on an empty display does nothing.
      //          `-` needs no such case: its id is ASCII and so is the controller's token.
      case '*':
        _controller.input('×');
      case '/':
        _controller.input('÷');
      default:
        // 中文：禁用键（`dis:` 前缀）键盘永不触发，万一到达就安静忽略，绝不当成文本写进表达式；
        //       数字、小数点、运算符与括号则直接输入——但**只有** `defaultInputKeyIds` 里那些 id 该
        //       走这条路。别的 id 落到这里说明 `_pressKey` 没接住它，而 `default` 会把它原样插进
        //       表达式（`×`/`÷` 的事故就是这个形状），所以开发期直接断言把那个 id 喊出来。
        //       `dispatchedKeyIds`/`defaultInputKeyIds` 与键位表的覆盖关系由
        //       `test/features/keypad_definition_test.dart` 逐格守着，本断言是那条守卫在运行期的回声：
        //       集合漏写、case 漏加，第一次按到那颗键就会响，而不是静默写错表达式。
        // English: A disabled key (`dis:`) is never fired by the keypad — if one arrives it is ignored
        //          quietly rather than typed into the expression; digits, the decimal point, operators
        //          and brackets go straight in — but **only** the ids in `defaultInputKeyIds` may travel
        //          this path. Any other id reaching here means `_pressKey` does not handle it, and
        //          `default` would insert it verbatim (the shape of the `×`/`÷` accident), so
        //          development fails an assertion that names it. The coverage of the key table by
        //          `dispatchedKeyIds`/`defaultInputKeyIds` is guarded cell by cell in
        //          `test/features/keypad_definition_test.dart`; this assertion is that guard's echo at
        //          run time — a missing set entry or a missing `case` rings on the first tap instead of
        //          silently writing the wrong expression.
        if (key.startsWith('dis:')) return;
        assert(
          CalculatorPage.defaultInputKeyIds.contains(key),
          '未派发的按键 id / undispatched key id: $key',
        );
        _controller.input(key);
    }
  }

  /// 中文：双变量那三格（`pearson`/`covar`/`spearman`）共用的一条：**控制器说读不成两行就不插**。
  ///
  ///       为什么不让 `case` 里直接 `append(regressionCall(...)!)`：`regressionCall` 在数据集读不成
  ///       两行时返回 `null`，而 `!` 会把它变成一个只在设备上崩的异常——那正是 `MathEngine` 契约里
  ///       明说不许出现的形状（「实现不抛异常，调用方不能把守约当本钱」）。这里把 `null` 与「什么
  ///       都不做」对上，判据仍然是 `regressionCall` 那一处，这里不写第二份。
  ///
  ///       面板上同一条判据把这三格变成禁用态，所以从界面上到不了这个 `null`；这条分支的存在是为了
  ///       **让 id 本身不会绕过面板**去插一条引擎答不出来的调用。
  ///
  /// English: the one path the three two-variable cells (`pearson`/`covar`/`spearman`) share: **when
  ///          the controller says the dataset cannot be read as two rows, nothing is inserted.**
  ///
  ///          Why not `append(regressionCall(...)!)` in the `case`: `regressionCall` returns `null`
  ///          while the dataset cannot be read as two rows, and `!` would turn that into an exception
  ///          that only ever fires on a device — exactly the shape the `MathEngine` contract forbids
  ///          ("implementations do not throw, and the caller may not bank on that"). Here `null` maps
  ///          to "do nothing", and the judgement still lives in `regressionCall` alone; no second copy
  ///          is written.
  ///
  ///          The sheet turns these three cells into disabled ones on the same judgement, so the
  ///          `null` is unreachable from the screen; this branch exists so that **an id cannot bypass
  ///          the sheet** and insert a call the engine cannot answer.
  void _appendRegressionCall(String function) {
    final call = _controller.regressionCall(function);
    if (call == null) return;
    _controller.append(call);
  }

  /// 中文：三个拟合格共用的一条，与 [_appendRegressionCall] 逐字同形（判据说 `null` 就什么都不做，
  ///       判据仍然只有 `fitCall` 一处）。**它是分开的一个方法，因为判据不同**：三个拟合各有各的
  ///       下限，所以「哪几格亮」不是整行一个布尔。
  /// English: the one path the three fit cells share, word for word the shape
  ///          [_appendRegressionCall] has (the judgement says `null` ⇒ do nothing, and that judgement
  ///          is still written once, on `fitCall`). **It is a separate method because the judgement
  ///          differs**: each fit has its own floor, so "which cells are lit" is not one boolean for the
  ///          whole row.
  void _appendFitCall(String function) {
    final call = _controller.fitCall(function);
    if (call == null) return;
    _controller.append(call);
  }

  /// 中文：四个进制胶囊共用的那一条：让控制器去换算，**有事要说时**把它说的话交给用户。
  ///       用的是提交路径同一种做法（`SnackBar`），因为两者是同一类事情——用户按了一个键，
  ///       而这一次没成，必须有人告诉他，而不是屏幕上什么都没有、看起来像按键失灵。
  ///
  ///       控制器自己会在成功时点亮读数、失败时不点亮（见 `showBaseReadout`），这里只负责把
  ///       那句话显示出来，不判断成功与否——第二个判断点迟早会与控制器那一处漂开。
  /// English: the one path the four base pills share: let the controller convert and, **when it has
  ///          something to say**, hand that sentence to the user. It uses the submit path's own
  ///          device (a `SnackBar`) because the two are the same kind of event — the user pressed a
  ///          key and this time it did not work, which someone has to say, or the screen shows
  ///          nothing and reads as a dead key.
  ///
  ///          The controller lights the read-out on success and leaves it dark on failure (see
  ///          `showBaseReadout`); this only displays the sentence and does not judge success — a
  ///          second judgement point would sooner or later drift away from the controller's.
  Future<void> _showBaseReadout(CalculatorBase base) async {
    final message = await _controller.showBaseReadout(base);
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 中文：记忆键被拒时，把控制器那句话交给用户。通道与 [_showBaseReadout]、以及提交路径的
  ///       `needsAttention` 是同一条（`SnackBar`），因为它们是同一类事情：用户按了一个键，而这一次
  ///       没成——不说，屏幕上就什么都没有，看起来像按键失灵。控制器回 `null` 时这里什么都不做
  ///       （成功是常态，不该有提示）。
  /// English: hand the controller's sentence to the user when a memory key is refused. Same channel as
  ///          [_showBaseReadout] and the submit path's `needsAttention` (a `SnackBar`), because they
  ///          are the same kind of event: the user pressed a key and this time it did not work —
  ///          unsaid, the screen shows nothing and reads as a dead key. A `null` from the controller
  ///          does nothing here (success is the normal case and deserves no prompt).
  void _reportMemory(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 中文：`More...` 面板里的那两个记忆键走这一条（`MR`/`MC` 不会拒绝，走的是同一条但永远无声）。
  ///       有话要说时**先把面板收掉**：面板盖着屏幕底部那一条，而消息落在右下角那条 `SnackBar`
  ///       上——量过（800×600 的测试面）：面板占 y=418..600、`SnackBar` 占 y=552..600，两者重叠，
  ///       被盖住的消息 `hitTestable()` 是 0。顶着面板说，用户根本看不见，那正是这一步要消灭的
  ///       「按了没反应」；这与同文件 `_action` 的理由是同一个形状（面板盖着键盘，所以动作先关面板）。
  ///       成功时面板原地留着——那正是面板自己的注释承诺的行为（读数原地更新）。
  /// English: the path the `More...` sheet's two refusing memory keys take (`MR`/`MC` cannot refuse;
  ///          they take it too and are simply never heard from). When there is something to say the
  ///          sheet is **dismissed first**: it covers the bottom strip of the screen while the message
  ///          lands on the `SnackBar` in that same strip — measured on the 800×600 test surface: the
  ///          sheet spans y=418..600 and the `SnackBar` y=552..600, they overlap, and a covered
  ///          message has `hitTestable()` 0. Speaking from behind the sheet means the user never sees
  ///          it, which is exactly the "pressed it, nothing happened" this step exists to delete; it
  ///          is the same shape as `_action`'s reason in this file (the sheet covers the keypad, so
  ///          the action closes it first). On success the sheet stays where it is — which is what the
  ///          sheet's own comment promises (the reading updates in place).
  void _reportMemoryFromSheet(String? message) {
    if (message == null) return;
    Navigator.of(context).pop();
    _reportMemory(message);
  }

  /// 中文：键面标签与解析器函数名不一致的少数几个在这里换算（`nCr` → `ncr`、`nPr` → `npr`、
  ///       `log₂` → `log2`）；其余 id 本身就是解析器词汇。
  /// English: The few places where a key face and the parser's function name differ are translated
  ///          here (`nCr` → `ncr`, `nPr` → `npr`, `log₂` → `log2`); every other id already is parser
  ///          vocabulary.
  String _functionNameForKey(String key) {
    return switch (key) {
      'nCr' => 'ncr',
      'nPr' => 'npr',
      'log₂' => 'log2',
      _ => key,
    };
  }

  /// 中文：**当前结果有哪几种画法**——`x⇔E` / `d/c` 两颗键问的就是这一个问题，而算它的地方只有一处
  ///       （[ResultPresentation]，结果行画的也是同一份）。`naturalDisplay` 与结果行取的是同一个
  ///       表达式（`expressionDisplayMode == '数学符号'`）：自然排版关掉时结果行整行是纯文本，
  ///       没有任何一种形态排得出来，于是两颗键都是空操作——这正是那条设置本来就有的含义。
  /// English: **which ways the current result can be drawn** — the one question `x⇔E` / `d/c` ask,
  ///          computed in exactly one place ([ResultPresentation], the same one the result line
  ///          draws from). `naturalDisplay` is the same expression the result line uses
  ///          (`expressionDisplayMode == '数学符号'`): with natural typesetting off the result line is
  ///          plain text throughout, no form can typeset, and both keys are no-ops — which is what
  ///          that setting already meant.
  ResultPresentation get _resultPresentation => ResultPresentation.of(
        resultTex: _controller.resultTex,
        fractionTex: _controller.resultFractionTex,
        // 中文：带分数那一格——与上面两份同一条路，空串 = 这一次没有这一格（菜单里那一项点不动）。
        // English: the mixed-number cell — the same road as the two above; empty means there is none
        //          this time (and that menu entry cannot be pressed).
        mixedTex: _controller.resultMixedTex,
        resultDecimal: _controller.resultDecimal,
        naturalDisplay: _naturalDisplay,
        // 中文：度分秒那一格的另外两个入参：引擎给的那串写法（形状由 `ResultPresentation` 判），
        //       以及**这一份结果是在哪种角度模式下算出来的**——用的是控制器里那个活着的
        //       `angleMode`（不是设置里那一份）：粘贴可以带来另一种模式，而「这个数是若干度」
        //       这句断言只对**算出它的那一次**成立。
        // English: the DMS cell's other two inputs: the string the engine handed over (its shape is
        //          judged by `ResultPresentation`), and **which angle mode this result was produced
        //          under** — the live `angleMode` on the controller rather than the one in settings,
        //          because a paste can bring another mode along and the claim "this number is so many
        //          degrees" only holds for **the evaluation that produced it**.
        dmsText: _controller.resultDmsText,
        degreesMode: _controller.angleMode == 'DEG',
        // 中文：这一份结果**是不是引擎算的**——菜单里那几格灰着时写哪一句话由它挑（`gapFor`；
        //       理由在 `resultCameFromEngine` 上：它取自结果自己的形状字段，不是上面那个设置）。
        // English: whether this result **came from the engine** — it picks which sentence the menu
        //          writes for those grey cells (`gapFor`; the reasoning is on `resultCameFromEngine`:
        //          it reads the result's own shape field, not the setting above).
        engineTookPart: _controller.resultCameFromEngine,
      );
}
