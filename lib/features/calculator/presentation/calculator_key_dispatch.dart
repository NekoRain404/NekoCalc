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
    //       `hiper_keypad.dart`（含 camelCase 的 `dis:pagePrev`、`dis:xchgE` 这类），修饰态解析出的
    //       变体 id（`asin`、`ins:^3`、`cbrt`…）也走同一条通路。
    // English: Key ids are mapped to controller actions and parser expressions here, keeping display
    //          symbols out of the parser. Ids come verbatim from `hiper_keypad.dart` (camelCase ones
    //          such as `dis:pagePrev` and `dis:xchgE` included), and the variant id a modifier
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
      case 'backspace':
        _controller.backspace();
      case 'clear':
        _controller.clear();
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
      // 中文：记忆键。`x→M`（id `memoryStore`）在 HiPER 上是把当前值**写入**寄存器（替换），而控制器
      //       只有累加的 `memoryAdd`；先清空再累加，两次调用合起来就是替换。写成两次是为了不碰控制器
      //       正在进行的其它工作，也不必为它加方法——将来控制器真有了 `memoryStore()`，这个 case
      //       应该直接换成那一次调用。
      // English: Memory keys. On HiPER `x→M` (id `memoryStore`) *writes* the current value into the
      //          register (a replace), while the controller only offers the accumulating `memoryAdd`;
      //          clearing first and adding after makes the pair a replace. Doing it in two calls avoids
      //          touching the work the controller is already doing and avoids adding a method for it —
      //          if a real `memoryStore()` ever lands on the controller, this case should call that
      //          instead.
      case 'memoryRecall':
        _controller.memoryRecall();
      case 'memoryStore':
        _controller.memoryClear();
        _controller.memoryAdd();
      case 'memoryAdd':
        _controller.memoryAdd();
      case 'memorySubtract':
        _controller.memorySubtract();
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
}
