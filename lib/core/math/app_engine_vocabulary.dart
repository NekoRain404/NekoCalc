/// 中文：**应用自己的函数词汇 ↔ 引擎词汇。**
///
///       这个应用有一套自己的函数名（键位表与 `OTHER` 面板插进表达式的那一批）。其中有几个
///       **引擎不认识这个拼法**——而引擎不会拒绝它们，它会**把那个词拆成它认识的符号**：
///
///       | 表达式 | 引擎读到的东西 | 引擎印出来的 |
///       |---|---|---|
///       | `npr(2,1.5)` | `n · p · r`（前缀、单位、常量） | `[2n'p''r'  1.5n'p''r']` |
///       | `npr(,)` | 同上，括号里是空的 | `[0  0]` |
///       | `fact(-1)` | `f · a · c · t` | `-10 aa*t` |
///
///       这些**不报错**、有时还是「一个矩阵」——于是它们能骗过只按结果形状判断的规则。
///       所以规则要问的是**输入**：表达式里只要有一个「属于应用词汇、引擎不认识这个拼法」的名字，
///       引擎这一次的答案就**不权威**，不论它返回什么种类。
///
///       两列事实分开记，因为它们回答两个不同的问题：
///
///       - [AppFunction.engineKnowsThisName]：**引擎对这个拼法的答案能不能用**——「这个名字它认不认」
///         与「它的意思跟我们的相不相同」两件事合起来量出来的，规则用它；
///       - [AppFunction.engineFunction]：**引擎里的对应函数**（若有）——留给「让这些键走引擎」
///         那一步，今天没有消费者。
///
///       `ncr` 与 `fact` 正是两列不同的例子：引擎**不认识** `ncr`/`fact` 这两个拼法，
///       但它有语义相同的 `binomial`/`factorial`。今天它们只能由旧解析器作答；等到那一步做了映射，
///       [canRead] 就会判「引擎读得懂」——**这一处不需要再改**。
///
///       **这一列是量出来的，不是记得的**：名字那一半用引擎自己的符号表问过
///       （`Calculator::getFunction(name)`，libqalculate 5.12.0）——`ncr`/`npr`/`fact`/`deg`/`rad`
///       返回空，其余全部认得（含 `log2`）；语义那一半用同一串调用序列逐个比对（`log` 因此落网）。
///       量测程序与完整输出记在步骤 5 修复轮 3 的报告里。
/// English: **This app's own function vocabulary ↔ the engine's.**
///
///          The app has its own set of function names (what the keypad and the `OTHER` sheet insert
///          into an expression). A few of them **the engine does not know under that spelling** — and
///          the engine does not reject them, it **takes the word apart into symbols it does know**:
///
///          | expression | what the engine reads | what it prints |
///          |---|---|---|
///          | `npr(2,1.5)` | `n · p · r` (a prefix, a unit, a constant) | `[2n'p''r'  1.5n'p''r']` |
///          | `npr(,)` | the same, with an empty bracket | `[0  0]` |
///          | `fact(-1)` | `f · a · c · t` | `-10 aa*t` |
///
///          None of them errors, and some are "a matrix" — so they slip past any rule that only looks
///          at the shape of the result. The rule therefore asks about the **input**: if an expression
///          calls a name that belongs to this app's vocabulary and the engine does not know that
///          spelling, the engine's answer this time is **not authoritative**, whatever kind it returns.
///
///          The two facts are recorded separately because they answer two different questions:
///
///          - [AppFunction.engineKnowsThisName]: **may the engine's answer for this spelling be used**
///            — measured from both "does it know the name" and "does it mean the same thing"; the rule
///            uses it;
///          - [AppFunction.engineFunction]: **the engine's function for it**, if any — held for the
///            step that moves these keys onto the engine; nothing consumes it today.
///
///          `ncr` and `fact` are exactly the two-column case: the engine does **not** know the
///          spellings `ncr`/`fact`, but it has `binomial`/`factorial` with the same meaning. Today they
///          can only be answered by the legacy parser; once that mapping exists, [canRead] will judge
///          "the engine reads this" — **nothing else here needs to change**.
///
///          **This column is measured, not remembered**: the name half was asked of the engine's own
///          symbol table (`Calculator::getFunction(name)`, libqalculate 5.12.0) — `ncr`/`npr`/`fact`/
///          `deg`/`rad` return nothing and everything else is recognised (including `log2`); the
///          meaning half was compared value by value over the same call sequence (which is how `log`
///          was caught). The measuring program and its full output are in the step 5 fix-round-3
///          report.
library;

/// 中文：一个应用函数在引擎那边的两件事实。
/// English: the two facts about one app function on the engine's side.
class AppFunction {
  const AppFunction({
    required this.engineKnowsThisName,
    this.engineFunction,
  });

  /// 中文：**引擎对这个拼法的答案能不能用**（量出来的）。为假时，引擎对这个名字的任何答案都不权威。
  ///       两件事都能让它为假：引擎**没有**这个名字（`ncr`/`npr`/`fact`/`deg`/`rad`，`getFunction`
  ///       量得），或者引擎有这个拼法但**意思不一样**（`log`：引擎是自然对数、应用是常用对数）。
  /// English: **may the engine's answer for this spelling be used** (measured). When false, no answer
  ///          the engine gives for this name is authoritative. Two things can make it false: the engine
  ///          does not have the name (`ncr`/`npr`/`fact`/`deg`/`rad`, measured with `getFunction`), or
  ///          it has the spelling but **means something else** (`log`: the engine's is the natural
  ///          logarithm, the app's the common one).
  final bool engineKnowsThisName;

  /// 中文：引擎里语义相同的函数名（若有）。**规则不用它**——它留给「让这些键走引擎」那一步。
  /// English: the engine's function with the same meaning, if any. **The rule does not use it** — it is
  ///          held for the step that moves these keys onto the engine.
  final String? engineFunction;
}

/// 中文：这个应用自己的函数词汇。**它是封闭的**：键位表与 `OTHER` 面板能插进表达式的函数名就这些。
/// English: this app's own function vocabulary. **It is closed**: these are the function names the
///          keypad and the `OTHER` sheet can insert.
class AppEngineVocabulary {
  const AppEngineVocabulary._();

  /// 中文：应用自己的**标识符**词汇：函数名**与常量名**。两者都能被写成调用
  ///       （`sin(1)`、`phi(2)`），所以判据必须覆盖两者——这就是「定义域」这一层。
  /// English: this app's own **identifier** vocabulary: function names **and** constant names. Both
  ///          can be written as calls (`sin(1)`, `phi(2)`), so the judgement has to cover both — that
  ///          is what this domain is.
  static const Map<String, AppFunction> identifiers = <String, AppFunction>{
    // 两边同名，引擎认得这个拼法，语义相同。
    'sin': AppFunction(engineKnowsThisName: true, engineFunction: 'sin'),
    'cos': AppFunction(engineKnowsThisName: true, engineFunction: 'cos'),
    'tan': AppFunction(engineKnowsThisName: true, engineFunction: 'tan'),
    'asin': AppFunction(engineKnowsThisName: true, engineFunction: 'asin'),
    'acos': AppFunction(engineKnowsThisName: true, engineFunction: 'acos'),
    'atan': AppFunction(engineKnowsThisName: true, engineFunction: 'atan'),
    'sinh': AppFunction(engineKnowsThisName: true, engineFunction: 'sinh'),
    'cosh': AppFunction(engineKnowsThisName: true, engineFunction: 'cosh'),
    'tanh': AppFunction(engineKnowsThisName: true, engineFunction: 'tanh'),
    'cot': AppFunction(engineKnowsThisName: true, engineFunction: 'cot'),
    'sec': AppFunction(engineKnowsThisName: true, engineFunction: 'sec'),
    'csc': AppFunction(engineKnowsThisName: true, engineFunction: 'csc'),
    // 中文：`log` **两边意思不同**：应用的是常用对数（log₁₀，`expression_parser.dart:129`），
    //       引擎的 `log(x)` 是**自然**对数（`LognFunction` 的第二个实参默认 `e`）。
    //       实测（libqalculate 5.12.0，同一个调用序列）：`log(100)` 引擎给
    //       `4.605170185988091`，应用自己给 `2`。所以引擎这个名字认，**意思不认**——
    //       它的答案不权威。（这条在文字表里是「引擎认识吗」为假的一个**语义**例子：
    //       这一列问的是「引擎对这个拼法的答案能不能用」，不是「引擎有没有这个名字」。）
    // English: `log` **means different things on the two sides**: the app's is the common logarithm
    //          (log₁₀, `expression_parser.dart:129`) while the engine's `log(x)` is the **natural**
    //          one (`LognFunction`'s second argument defaults to `e`). Measured (libqalculate 5.12.0,
    //          the same call sequence): `log(100)` gives the engine `4.605170185988091` and the app
    //          `2`. So the engine knows the name but not the meaning — its answer is not
    //          authoritative. (This is the **semantic** case of the column below: the column asks "may
    //          the engine's answer for this spelling be used", not "does the engine have this name".)
    'log': AppFunction(engineKnowsThisName: false),
    'log2': AppFunction(engineKnowsThisName: true, engineFunction: 'log2'),
    'ln': AppFunction(engineKnowsThisName: true, engineFunction: 'ln'),
    'exp': AppFunction(engineKnowsThisName: true, engineFunction: 'exp'),
    'abs': AppFunction(engineKnowsThisName: true, engineFunction: 'abs'),
    'sqrt': AppFunction(engineKnowsThisName: true, engineFunction: 'sqrt'),
    'cbrt': AppFunction(engineKnowsThisName: true, engineFunction: 'cbrt'),
    'floor': AppFunction(engineKnowsThisName: true, engineFunction: 'floor'),
    'ceil': AppFunction(engineKnowsThisName: true, engineFunction: 'ceil'),
    'round': AppFunction(engineKnowsThisName: true, engineFunction: 'round'),
    'min': AppFunction(engineKnowsThisName: true, engineFunction: 'min'),
    'max': AppFunction(engineKnowsThisName: true, engineFunction: 'max'),
    // 中文：`mod` 是第二个 `log`：引擎的 `mod(7,-3)` 给 `-2`，应用自己的解析器给 `1`
    //       （Dart 的 `%` 是欧几里得余数）。**键盘可达**（`7` → `mod` → `+/-` → `3`），
    //       而且种类是 `number` + 有限十进制 → 走 tier 1 直接采用引擎的答案 ✗。
    //       复审的 629 个表达式扫描里，它是除 `log` 外唯一剩下的同名数值分歧。
    //       处理方式与 `log` 相同：引擎对这个名字的答案不可用，由旧解析器作答。
    // English: `mod` is a second `log`: the engine's `mod(7,-3)` gives `-2` while this app's own
    //          parser gives `1` (Dart's `%` is the Euclidean remainder). It is **keypad-reachable**
    //          (`7` → `mod` → `+/-` → `3`) and its kind is `number` with a finite decimal, so tier 1
    //          adopted the engine's answer outright. In the review's 629-expression sweep it was the
    //          only remaining same-name numeric divergence besides `log`. Handled the same way: the
    //          engine's answer for this name may not be used; the legacy parser answers.
    'mod': AppFunction(engineKnowsThisName: false),
    'gcd': AppFunction(engineKnowsThisName: true, engineFunction: 'gcd'),
    'lcm': AppFunction(engineKnowsThisName: true, engineFunction: 'lcm'),
    'root': AppFunction(engineKnowsThisName: true, engineFunction: 'root'),
    'atan2': AppFunction(engineKnowsThisName: true, engineFunction: 'atan2'),
    'matrix': AppFunction(engineKnowsThisName: true, engineFunction: 'matrix'),
    'sum': AppFunction(engineKnowsThisName: true, engineFunction: 'sum'),
    'product': AppFunction(engineKnowsThisName: true, engineFunction: 'product'),
    'integrate': AppFunction(engineKnowsThisName: true, engineFunction: 'integrate'),
    'diff': AppFunction(engineKnowsThisName: true, engineFunction: 'diff'),
    'limit': AppFunction(engineKnowsThisName: true, engineFunction: 'limit'),
    'rand': AppFunction(engineKnowsThisName: true, engineFunction: 'rand'),

    // 中文：**常量也在这张表里。** 这一列的判据是「引擎对这个**标识符**的答案能不能用」，
    //       而应用的常量同样可以被写成调用（`phi(2)`、`tau(2)`、`pi(2)`）——只覆盖「函数名」
    //       会让这一类整个漏过去。修复轮 5 的 `phi` 就是这么漏的：引擎里有一个**同名的函数**
    //       （欧拉 φ 函数），于是 `phi(2)` 走 tier 1 显示 `1`，而应用自己的读法是
    //       `phi × 2` = `3.236068`。
    // English: **constants live in this table too.** The column asks "may the engine's answer for this
    //          **identifier** be used", and this app's constants can be written as calls just as well
    //          (`phi(2)`, `tau(2)`, `pi(2)`) — covering only "function names" would miss that whole
    //          class, which is how fix round 5's `phi` slipped: the engine has a **function of the
    //          same name** (Euler's totient), so `phi(2)` took tier 1 and displayed `1`, where this
    //          app's own reading is `phi × 2` = `3.236068`.
    //
    // 中文：`phi`：引擎里**既有函数也有变量**（量过：`function=1 variable=1`），而被调用时赢的是
    //       那个**函数**（欧拉 φ）——名字认、意思不认。`tau`/`pi`/`e` 引擎都认识且同义。
    //       `inf` 引擎里三者皆无（量过），所以 `inf(2)` 由原生侧那条检查挡下。
    // English: `phi`: the engine has **both a function and a variable** under that name (measured:
    //          `function=1 variable=1`), and when it is *called* the **function** (the totient) wins —
    //          the name is known, the meaning is not. `tau`/`pi`/`e` are known and mean the same. `inf`
    //          is none of the three in the engine (measured), so `inf(2)` is stopped by the native
    //          check instead.
    'pi': AppFunction(engineKnowsThisName: true, engineFunction: 'pi'),
    'e': AppFunction(engineKnowsThisName: true, engineFunction: 'e'),
    'tau': AppFunction(engineKnowsThisName: true, engineFunction: 'tau'),
    'phi': AppFunction(engineKnowsThisName: false),
    'inf': AppFunction(engineKnowsThisName: false),
    'infinity': AppFunction(engineKnowsThisName: true, engineFunction: 'infinity'),

    // 中文：**引擎不认识这几个拼法**——它会把它们拆成符号，于是答案描述的是另一件事。
    //       `ncr`/`fact` 的 `engineFunction` 就是「让它们走引擎」那一步要用的映射；今天没有消费者。
    // English: **the engine does not know these spellings** — it takes them apart into symbols, so its
    //          answer is about something else. The `engineFunction` of `ncr`/`fact` is the mapping that
    //          step will use; nothing consumes it today.
    'ncr': AppFunction(engineKnowsThisName: false, engineFunction: 'binomial'),
    'npr': AppFunction(engineKnowsThisName: false),
    'fact': AppFunction(engineKnowsThisName: false, engineFunction: 'factorial'),
    'deg': AppFunction(engineKnowsThisName: false),
    'rad': AppFunction(engineKnowsThisName: false),
  };

  /// 中文：应用词汇里**引擎不认识这个拼法**的那些名字——引擎对它们的答案一律不权威。
  /// English: the names in this app's vocabulary that **the engine does not know under that
  ///          spelling** — its answers for them are never authoritative.
  static final Set<String> unknownToEngine = <String>{
    for (final entry in identifiers.entries)
      if (!entry.value.engineKnowsThisName) entry.key,
  };

  /// 中文：表达式里出现的函数调用名（`名字(`）。应用自己的语法里，调用就是「标识符紧跟左括号」。
  /// English: the call names in an expression (a name immediately followed by `(`). In this app's
  ///          syntax a call is exactly that.
  static final RegExp _callName = RegExp(r'([A-Za-z][A-Za-z0-9]*)\s*\(');

  /// 中文：这个表达式里的全部函数调用名。
  /// English: every function-call name in this expression.
  static Set<String> callNamesIn(String expression) => <String>{
        for (final match in _callName.allMatches(expression)) match.group(1)!,
      };

  /// 中文：**引擎读得懂这个表达式吗**——表达式里只要有一个「属于应用词汇、引擎不认识这个拼法」的
  ///       调用，答案就是「读不懂」，于是引擎这一次的答案（不论形状）都不许用。
  ///
  ///       判据是**结构性的**，而且两条输入都封闭：
  ///
  ///       - **应用词汇表**是这个应用自己能插进表达式的函数名，有限且可枚举（`hiper_keypad.dart`
  ///         与 `_MoreFunctionsSheet._entries` 的全部函数键）；
  ///       - **「引擎不认识」那一列**由引擎自己的符号表量得（`Calculator::getFunction`），
  ///         不是谁记得的清单。
  ///
  ///       于是它没有「还有哪种写法没覆盖」这个失效方式：判据问的不是"结果像什么"，
  ///       而是"这个输入里的调用名，引擎的符号表里有吗"。任何**不在**词表里的调用名（用户自己
  ///       敲进来的）也不受影响——那由原生侧的同一条规则（`getFunction` 直接问引擎）兜住。
  /// English: **can the engine read this expression** — if it calls a name that belongs to this app's
  ///          vocabulary and the engine does not know that spelling, the answer is no, and the engine's
  ///          answer this time may not be used, whatever shape it has.
  ///
  ///          The test is **structural**, and both inputs are closed:
  ///
  ///          - the **app vocabulary** is the set of function names this app itself can insert — finite
  ///            and enumerable (every function key in `hiper_keypad.dart` and in
  ///            `_MoreFunctionsSheet._entries`);
  ///          - the **"the engine does not know it" column** was measured from the engine's own symbol
  ///            table (`Calculator::getFunction`), not written down from anyone's memory.
  ///
  ///          So "which other spelling did I miss" is not a failure mode: the test does not ask what the
  ///          result looks like, it asks whether the engine's symbol table has the call names in the
  ///          input. A call name **outside** the vocabulary (typed by the user) is unaffected here — the
  ///          native side covers that with the same rule, asking the engine directly (`getFunction`).
  static bool canRead(String expression) =>
      !callNamesIn(expression).any(unknownToEngine.contains);
}
