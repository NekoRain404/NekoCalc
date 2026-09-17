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
///       **修复轮 7 之后：这张表是翻译表，[canRead] 那一层是第二道判断。**
///
///       - **真正消歧义的是翻译**（`engine_expression.dart`）：问引擎之前先把表达式写成引擎的
///         写法，于是 `log` 写成 `log10`、`phi` 写成它的数值、`ncr`/`fact` 写成
///         `binomial`/`factorial`，`mod`/`npr`/`deg`/`rad` **根本不问**。上面那张表就是那份映射
///         （`engineNameFor`）：从「防御性的枚举」变成**正向的翻译表**，`engineFunction` 那一列
///         因此有了消费者。修复轮 8 把它收严了两处：**表外的标识符一律拒绝**（不再原样透传），
///         **别名先折到规范名再查表**（`lg`/`c`/`p`/`arcsin` 那一批）。
///       - [canRead] 这一层的拒绝**改变屏幕上的值——这是量出来的，不是论出来的**。
///         把 [canRead] 变异成恒为 `true`（只改这一个文件），两个输入上的屏幕值就变了：
///         `log(8,2)`（`logₓy` 键插进去的正是这个式子，`hiper_keypad.dart`）从应用的 `3`
///         变成引擎对 `log10(8,2)` 的答复 `[0.9030899869919436  0.3010299956639812]`；
///         `fact(171)` 从应用自己的「阶乘只支持 0 到 170 的整数」变成引擎对 `factorial(171)` 的
///         `1.241018070217668E309`。两串引擎值都是**量出来的**（宿主上 libqalculate 5.12.0，
///         按桥的调用序列：`unlocalizeExpression` → `calculate` → `print`，精度 16、
///         `INTERVAL_DISPLAY_MIDPOINT`、`comma_as_separator=false`，同
///         `tool/qalculate_semantics_probe/probe.cc`），两条屏幕值有测试钉住
///         （`test/domain/calculator_engine_translation_test.dart`）。
///         **修复轮 7 在这里写过「这一层不再改变屏幕上任何一个值」——那句话是假的**，上面两条就是
///         反例；本节只写这两条实测，不再写任何「它一定如何」的全称句。
///       - 修复轮 6 用来证明它「不是冗余副本」的那条证据确实已经不成立：`log(1.0000000001)`。
///         当时值判据的绝对下限让引擎的 `1e-10` 上屏，而那个 `1e-10` 是**原串**的读法（引擎的
///         `log` 是自然对数，`ln(1.0000000001)` = `1e-10`）。翻译之后引擎被问的是
///         `log10(1.0000000001)`，它的答案是 `4.342944818815371e-11`，应用自己给
///         `4.342945178152236e-11`，两者**显示成同一个数**
///         （`formatNumber(…, precision: 6)` → `4.342945e-11`）。两串值同样按桥的调用序列量得；
///         原串 `log(1.0000000001)` 量出来正是 `9.9999999995e-11`，也就是那个 `1e-10` 的来源。
///         （上面那两条**不是**这条证据的替代品：`log(8,2)` 与 `fact(171)` 之所以漏过去，
///         是因为翻译写出的 `log10(8,2)` 引擎读成向量、`factorial(171)` 引擎的定义域比应用宽
///         ——两边的**含义/定义域**不同，翻译把它们写成了引擎的写法也改不掉这一点。）
///       - 它并**不省一次往返**：两条路径都是先问引擎、拿到回包之后才做这次判断，所以它拦下的
///         是**已经到手的答案**。
///
///       两列事实分开记，因为它们回答两个不同的问题：
///
///       - [AppFunction.engineKnowsThisName]：**引擎对这个拼法的答案能不能用**——「这个名字它认不认」
///         与「它的意思跟我们的相不相同」两件事合起来量出来的，[canRead] 用它；
///       - [AppFunction.engineFunction]：**引擎里的对应函数**（若有）——`engineNameFor` 用它。
///
///       `ncr` 与 `fact` 正是两列不同的例子：引擎**不认识** `ncr`/`fact` 这两个拼法，
///       但它有语义相同的 `binomial`/`factorial`。修复轮 7 把这一列接成了映射：这两个名字现在
///       由引擎作答（`binomial(5,2)` = 10），**而 [canRead] 仍旧判「不可信」**——两道判断各自
///       成立，翻译不需要它松口。
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
///          **After fix round 7 this table is the translation table, and [canRead] is a defensive
///          second judgement.**
///
///          - **The translation is what removes the ambiguity** (`engine_expression.dart`): the
///            expression is written the engine's way before the engine is asked, so `log` is written
///            `log10`, `phi` as its value and `ncr`/`fact` as `binomial`/`factorial`, while
///            `mod`/`npr`/`deg`/`rad` are **not asked at all**. The table above is that mapping
///            (`engineNameFor`): a defensive enumeration turned into a **positive translation table**,
///            which is what gives `engineFunction` a consumer.
///          - The refusal at [canRead]'s layer **changes values on screen — that is measured, not
///            argued.** Mutate [canRead] to a constant `true` (one file) and two inputs change what is
///            displayed: `log(8,2)` (the `logₓy` key inserts exactly that, `hiper_keypad.dart`) goes
///            from this app's `3` to the engine's answer for `log10(8,2)`,
///            `[0.9030899869919436  0.3010299956639812]`; `fact(171)` goes from this app's own
///            "阶乘只支持 0 到 170 的整数" to the engine's `1.241018070217668E309` for
///            `factorial(171)`. Both engine strings are **measured** (host, libqalculate 5.12.0, through
///            the bridge's call sequence: `unlocalizeExpression` → `calculate` → `print`, precision 16,
///            `INTERVAL_DISPLAY_MIDPOINT`, `comma_as_separator=false`, the sequence in
///            `tool/qalculate_semantics_probe/probe.cc`), and both screen values are pinned by tests
///            (`test/domain/calculator_engine_translation_test.dart`).
///            **Fix round 7 wrote "no longer changes any value on screen" here — that sentence is
///            false**, and the two inputs above are the counterexamples; this section now states only
///            those measurements and makes no "it always does X" claim.
///          - The evidence fix round 6 used to show it was "not a redundant copy" really is superseded:
///            `log(1.0000000001)`. The value comparison's absolute floor let the engine's `1e-10` onto
///            the screen, and that `1e-10` was the **raw string's** reading (the engine's `log` is the
///            natural logarithm, `ln(1.0000000001)` = `1e-10`). After the translation the engine is
///            asked `log10(1.0000000001)` and answers `4.342944818815371e-11` while this app gives
///            `4.342945178152236e-11` — and the two **display as the same number**
///            (`formatNumber(…, precision: 6)` → `4.342945e-11`). Both strings were measured the same
///            way; the raw `log(1.0000000001)` measures `9.9999999995e-11`, which is where that
///            `1e-10` came from. (The two inputs above are **not** a replacement for that evidence:
///            `log(8,2)` and `fact(171)` slip past the translation because the engine reads
///            `log10(8,2)` as a vector and its factorial is defined beyond this app's 0..170 — the two
///            sides' **meanings/domains** differ, and writing them the engine's way cannot change that.)
///          - It does **not** save a round trip: both paths ask the engine first and run this judgement
///            on the reply, so what it stops is an answer that has already arrived.
///
///          The two facts are recorded separately because they answer two different questions:
///
///          - [AppFunction.engineKnowsThisName]: **may the engine's answer for this spelling be used**
///            — measured from both "does it know the name" and "does it mean the same thing";
///            [canRead] uses it;
///          - [AppFunction.engineFunction]: **the engine's function for it**, if any — `engineNameFor`
///            uses it.
///
///          `ncr` and `fact` are exactly the two-column case: the engine does **not** know the
///          spellings `ncr`/`fact`, but it has `binomial`/`factorial` with the same meaning. Fix round
///          7 wired that column up as a mapping, so those two names are answered by the engine now
///          (`binomial(5,2)` = 10) — **while [canRead] still judges them untrusted**: the two
///          judgements each stand on their own, and the translation needs no permission from it.
///
///          **This column is measured, not remembered**: the name half was asked of the engine's own
///          symbol table (`Calculator::getFunction(name)`, libqalculate 5.12.0) — `ncr`/`npr`/`fact`/
///          `deg`/`rad` return nothing and everything else is recognised (including `log2`); the
///          meaning half was compared value by value over the same call sequence (which is how `log`
///          was caught). The measuring program and its full output are in the step 5 fix-round-3
///          report.
library;

import 'app_unit_catalog.dart';
import 'ast/expression_ast_parser.dart';
import 'engine_expression.dart';
import 'expression_parser.dart';

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

  /// 中文：引擎里语义相同的函数名（若有）。**翻译用它**（`engineNameFor` 把 `ncr` 写成 `binomial`）；
  ///       [canRead] 不用它——「引擎的答案能不能用」与「引擎里该写什么」是两个问题。
  /// English: the engine's function with the same meaning, if any. **The translation uses it**
  ///          (`engineNameFor` writes `ncr` as `binomial`); [canRead] does not — "may this answer be
  ///          used" and "what should be written for the engine" are two different questions.
  final String? engineFunction;
}

/// 中文：这个应用自己的函数词汇。**它是封闭的**：键位表与 `OTHER` 面板能插进表达式的函数名就这些。
/// English: this app's own function vocabulary. **It is closed**: these are the function names the
///          keypad and the `OTHER` sheet can insert.
class AppEngineVocabulary {
  const AppEngineVocabulary._();

  /// 中文：应用自己的**标识符**词汇：函数名**与常量名**。两者都能被写成调用
  ///       （`sin(1)`、`phi(2)`），所以判据必须覆盖两者——这就是「定义域」这一层。
  ///
  ///       键是**规范名**，不是拼法：`lg`/`log10` 是 `log` 的别名、`c`/`p` 是 `ncr`/`npr` 的、
  ///       `arcsin`/`arccos`/`arctan` 是 `asin`/`acos`/`atan` 的，它们的折叠在
  ///       [ExpressionParser.functionAliases] 那一张表里（**只有那一处**），本表用
  ///       [canonicalIdentifier] 折。所以这张表 + 那张别名表覆盖的是 `ExpressionParser` 接受的
  ///       **全部拼法**；覆盖测试在 `test/domain/app_engine_vocabulary_semantics_test.dart`。
  /// English: the keys are **canonical names** rather than spellings: `lg`/`log10` are `log`'s
  ///          aliases, `c`/`p` are `ncr`/`npr`'s and `arcsin`/`arccos`/`arctan` are
  ///          `asin`/`acos`/`atan`'s; the fold lives in [ExpressionParser.functionAliases]
  ///          (**only there**) and this table applies it through [canonicalIdentifier]. So this table
  ///          plus that alias table covers **every spelling** `ExpressionParser` accepts; the coverage
  ///          test is in `test/domain/app_engine_vocabulary_semantics_test.dart`.
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
    // 中文：`engineFunction` 与 `engineKnowsThisName` 这两列在这里**分开**，而且必须分开：
    //       翻译要写的是 `log10`（常用对数在引擎里的名字，量过），而 `canRead` 判的是**应用这个拼法**
    //       送到引擎去会不会被读成别的意思——会（自然对数），所以那一列是假。给它补上 `log10`
    //       是修复轮 8 的事：翻译表不再为这几个名字留特例分支，走的是**每一行同一套**
    //       「看 engineFunction」。
    // English: the `engineFunction` and `engineKnowsThisName` columns are **separate** here and have to
    //          be: the translation must write `log10` (the engine's name for the common logarithm,
    //          measured), while `canRead` judges whether **this app's spelling** reaches the engine as
    //          something else — it does (the natural logarithm), so that column is false. Filling in
    //          `log10` is fix round 8's change: the translation table no longer keeps a special-case
    //          branch for these names; every row answers through the **same** rule, "read
    //          `engineFunction`".
    'log': AppFunction(engineKnowsThisName: false, engineFunction: 'log10'),
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
    'product':
        AppFunction(engineKnowsThisName: true, engineFunction: 'product'),
    'integrate':
        AppFunction(engineKnowsThisName: true, engineFunction: 'integrate'),
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
    'infinity':
        AppFunction(engineKnowsThisName: true, engineFunction: 'infinity'),

    // 中文：**引擎不认识这几个拼法**——它会把它们拆成符号，于是答案描述的是另一件事。
    //       `ncr`/`fact` 的 `engineFunction` 就是翻译要用的映射（`engineNameFor`）：这两个名字现在
    //       由引擎作答，而 [canRead] 仍旧把它们挡在「不可信」那一列——两道判断互不放宽。
    // English: **the engine does not know these spellings** — it takes them apart into symbols, so its
    //          answer is about something else. The `engineFunction` of `ncr`/`fact` is the mapping the
    //          translation uses (`engineNameFor`): those two names are answered by the engine now,
    //          while [canRead] still keeps them in the untrusted column — neither judgement relaxes the
    //          other.
    'ncr': AppFunction(engineKnowsThisName: false, engineFunction: 'binomial'),
    'npr': AppFunction(engineKnowsThisName: false),
    'fact':
        AppFunction(engineKnowsThisName: false, engineFunction: 'factorial'),
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

  /// 中文：这个表达式里的全部函数调用名，**折成表里的规范名**（别名与大小写都折，用的是
  ///       `ExpressionParser` 那一张 [ExpressionParser.functionAliases]，没有第二份）。
  ///       折这一下是必须的：词表的键是规范名，而 `lg`/`log10` 与 `lg`/`LG` 指的是同一行——
  ///       不折它们会**穿过**这张表。实测：不折时 `canRead('lg(8,2)')` 是真，引擎对 `log10(8,2)`
  ///       的二元素向量因此上屏，而 `log(8,2)`（同一个式子）被拦下。
  ///
  ///       **这条判据读的是 ASCII 拼法**（正则就是 `[A-Za-z][A-Za-z0-9]*`），所以非 ASCII 的拼法
  ///       它看不见。修复轮 9 实测的**两类**：`φ`/`ϕ`（归一化写成 `phi`，而 `phi` 在「不可用」
  ///       那一列；应用自己的 `phi(2)` 与引擎对 `(1.618033988749895)*(2)` 的答复是同一个数，
  ///       两侧都量过——这一类**不是错值**），以及**全角拉丁字母**（`U+FF21`–`U+FF5A`，归一化
  ///       写成同名的 ASCII）——**这一类有两个实例是错值**：`ｌｇ(8,2)`、`ｆａｃｔ(171)`。
  ///       修复轮 9 起 [canRead] 先把输入归一化再交给这里，所以这两类都到不了名字层；
  ///       本函数自己看不见它们这条边界仍在（它的参数是什么字符串，它就读什么字符串），
  ///       别再拿它当 `canRead` 的边界用。
  /// English: every function-call name in this expression, **folded to the table's canonical spelling**
  ///          (aliases and case, through `ExpressionParser`'s own [ExpressionParser.functionAliases] —
  ///          there is no second copy). The fold is required: the table's keys are canonical names, and
  ///          `lg`/`log10`, or `lg`/`LG`, name the same row — unfolded they **pass through** this table.
  ///          Measured: unfolded, `canRead('lg(8,2)')` is true and the engine's two-element vector for
  ///          `log10(8,2)` goes on screen, while `log(8,2)` (the same expression) is stopped.
  ///
  ///          **This judgement reads ASCII spellings** (the regex is `[A-Za-z][A-Za-z0-9]*`), so a
  ///          non-ASCII spelling is invisible to it. Fix round 9 measured **two classes**: `φ`/`ϕ` (which
  ///          normalise to `phi`, a name in the unusable column; this app's own `phi(2)` and the engine's
  ///          answer for `(1.618033988749895)*(2)` are the same number, both measured — this class is
  ///          **not a wrong value**), and **full-width Latin** (`U+FF21`–`U+FF5A`, which normalise to the
  ///          same names in ASCII) — **two of its instances are wrong values**: `ｌｇ(8,2)` and
  ///          `ｆａｃｔ(171)`. Since fix round 9 [canRead] normalises its input before handing it here, so
  ///          neither class reaches the name layer; this function still cannot see them (it reads exactly
  ///          the string it is handed), and that boundary is no longer `canRead`'s.
  static Set<String> callNamesIn(String expression) => <String>{
        for (final match in _callName.allMatches(expression))
          ExpressionParser.canonicalFunctionName(match.group(1)!),
      };

  /// 中文：**一个标识符（可以是别名拼法）→ 引擎里该写什么；表里没有的一律拒绝。**
  ///
  ///       三步，每一步都是修复轮 8 明确下来的：
  ///
  ///       1. **先折别名**（[ExpressionParser.canonicalFunctionName]，与 `ExpressionParser` 归一化用的是
  ///          同一张 [ExpressionParser.functionAliases] 表）：`lg`/`log10` → `log`、`c` → `ncr`、
  ///          `p` → `npr`、`arcsin`/`arccos`/`arctan` → `asin`/`acos`/`atan`。表里写的是**规范名**，
  ///          别名拼法是同一个标识符的另一种写法，必须落到同一行上。
  ///       2. **表里没有 ⇒ 拒绝**，不再原样透传（修复轮 7 的 low）：未知标识符是 `npr` 那一类
  ///          ——引擎不报错，它把那个词拆成符号，于是答案描述的是另一件事。**这是这一层的封闭性所在：
  ///          表外的拼法到不了引擎，而不是「到了引擎再说」。**
  ///       3. 表里有 `engineFunction` ⇒ 写它（这就是翻译）；**没有** ⇒ 拒绝。
  ///
  ///       **第 3 步判的是 `engineFunction`，不是 `engineKnowsThisName`**——两列回答两个问题
  ///       （「该写什么」/「引擎对这个拼法的答案能不能用」），`log`/`ncr`/`fact` 正是两列给出不同
  ///       答案的三行：翻译能把它们写成引擎的写法（`log10`/`binomial`/`factorial`），而 `canRead`
  ///       仍旧判「应用这个拼法的答案不可用」。修复轮 7 用三个 `if (name == …)` 特例表达同一件事，
  ///       修复轮 8 收成一条规则：**每一行都从它自己的那一列取值**。
  ///
  ///       剩下的 `npr`/`mod`/`deg`/`rad`/`phi`/`inf` 两列都是「不可用」，所以一律拒绝。
  ///       这个集合由 `test/domain/app_engine_vocabulary_semantics_test.dart` 钉住。
  /// English: **one identifier (alias spellings included) → what to write for the engine; anything not
  ///          in the table is refused.**
  ///
  ///          Three steps, each of them fix round 8's:
  ///
  ///          1. **fold aliases first** ([ExpressionParser.canonicalFunctionName], the same
  ///             [ExpressionParser.functionAliases] table `ExpressionParser`'s normalisation uses):
  ///             `lg`/`log10` → `log`, `c` → `ncr`, `p` → `npr`, `arcsin`/`arccos`/`arctan` →
  ///             `asin`/`acos`/`atan`. The table holds **canonical names**, and an alias is another
  ///             spelling of the same identifier, so it has to land on the same row.
  ///          2. **absent from the table ⇒ refuse**, no more pass-through (fix round 7's low): an
  ///             unknown identifier is the `npr` class — the engine does not error, it takes the word
  ///             apart into symbols, so its answer is about something else. **This is where this layer's
  ///             closure lives: a spelling outside the table cannot reach the engine at all**, rather
  ///             than "reaching it and then being judged".
  ///          3. the row has an `engineFunction` ⇒ write it (that is the translation); it has none ⇒
  ///             refuse.
  ///
  ///          **Step 3 reads `engineFunction`, not `engineKnowsThisName`** — the two columns answer two
  ///          questions ("what should be written" / "may the engine's answer for this spelling be
  ///          used"), and `log`/`ncr`/`fact` are exactly the rows where they differ: the translation can
  ///          write them the engine's way (`log10`/`binomial`/`factorial`) while `canRead` still judges
  ///          the app's spelling unusable. Fix round 7 expressed the same thing with three
  ///          `if (name == …)` special cases; fix round 8 collapses it to one rule: **every row is read
  ///          from its own column**.
  ///
  ///          The remaining `npr`/`mod`/`deg`/`rad`/`phi`/`inf` are unusable in both columns, so they are
  ///          refused. This set is pinned by `test/domain/app_engine_vocabulary_semantics_test.dart`.
  static EngineExpression engineNameFor(String name) {
    final canonical = canonicalIdentifier(name);
    if (canonical == null) {
      return UntranslatableExpression(
        '标识符不在应用词汇表里，不送去让引擎猜：`$name`',
      );
    }
    final engineFunction = identifiers[canonical]!.engineFunction;
    if (engineFunction == null) {
      return UntranslatableExpression(
        '词表里这个名字没有引擎写法，引擎的答案也不可用：`$canonical`',
      );
    }
    return TranslatedExpression(engineFunction);
  }

  /// 中文：**一个拼法（别名、大小写都算）→ 表里的规范名；不在表里返回 null。**
  ///       别名折叠用的就是 `ExpressionParser` 那一张表（[ExpressionParser.canonicalFunctionName]），
  ///       所以「`lg` 是什么」在整个应用里只有一处答案。
  /// English: **one spelling (aliases and case included) → its canonical name in the table, or null when
  ///          it is not there.** The fold is `ExpressionParser`'s own table
  ///          ([ExpressionParser.canonicalFunctionName]), so "what `lg` is" has exactly one answer in
  ///          this app.
  static String? canonicalIdentifier(String name) {
    final folded = ExpressionParser.canonicalFunctionName(name);
    return identifiers.containsKey(folded) ? folded : null;
  }

  /// 中文：变量名 → 能不能原样交给引擎。应用自己的常量名（`phi` 除外，它在翻译里被写成数值）
  ///       与 `x`/`y`/`i` 都能；其余（引擎不认识的自由变量）不能。
  /// English: a variable name → whether it may be handed to the engine as-is. This app's constant
  ///          names (except `phi`, which the translation writes as a value) and `x`/`y`/`i` may;
  ///          anything else (a free variable the engine does not know) may not.
  static String? variableUnknownToEngine(String name) {
    // 中文：**单位名走同一张封闭表。** `km` 与 `zorkmid` 在这里是同一类输入的两种结果：能插进
    //       表达式的单位名（[kAppUnits]）放行，表外的一切照旧拒绝。这张表是量出来的（117 个符号
    //       逐个在宿主上问过），而拒绝的那一半正是「不存在的单位得到一个看似合理的值」那条
    //       静默错值的入口——实测 `5 zorkmid` 给 `5E-21 B`，没有任何提示。
    //
    //       **大小写敏感**：查表用的是原样的名字，不是小写形式。单位名分大小写（`m` 是米），
    //       折成小写就等于把两个不同的单位当成一个；`KM` 因此留在「表外的自由变量」那一列。
    //
    //       注意它与上面那一行的分工：常量名与 `x`/`y`/`i` 折大小写，单位名不折。两者混在一个
    //       函数里是因为它们回答的是同一个问题——「这个名字能不能原样交给引擎」。
    // English: **unit names go through the same closed table.** `km` and `zorkmid` are two outcomes of
    //          one kind of input here: a unit name that can be inserted into an expression
    //          ([kAppUnits]) passes, everything outside the table is refused as before. That table is
    //          measured (117 symbols, each asked of the host), and the refused half is exactly the
    //          entrance to the "a unit that does not exist returns a plausible value" silent wrong
    //          value — measured, `5 zorkmid` gives `5E-21 B` with nothing to show for it.
    //
    //          **Case-sensitive**: the lookup uses the name verbatim rather than its lowercase form.
    //          Unit names distinguish case (`m` is metre), so folding to lowercase would treat two
    //          different units as one; `KM` therefore stays in the "free variable outside the table"
    //          column.
    //
    //          Note the division of labour with the line above: constant names and `x`/`y`/`i` fold
    //          case, unit names do not. Both live in one function because they answer one question —
    //          "may this name be handed to the engine as it stands".
    if (isAppUnit(name)) return null;
    final lower = name.toLowerCase();
    const known = <String>{'pi', 'e', 'tau', 'infinity', 'x', 'y', 'i'};
    if (known.contains(lower)) return null;
    return '引擎不认识这个自由变量：`$name`';
  }

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
  ///
  ///          中文：**它是第二道判断，不是第一道**，而且**不省一次往返**：两条路径都是先问引擎
  ///          （问的是翻译后的表达式）、拿到回包之后才走到这里，所以这里拦下的是**已经到手的答案**。
  ///          它**改变屏幕上的值**，而这是量出来的：把它变异成恒为 `true`（一个文件），
  ///          `log(8,2)` 与 `fact(171)` 上屏的就是引擎的答案而不是应用的（两条实测见文件头）。
  ///          所以它是必要的一道，不是翻译那一层的副本。
  ///
  /// English: **this is the second judgement, not the first**, and it **saves no round trip**: both
  ///          paths ask the engine first (with the translated expression) and reach this only once the
  ///          reply is in hand, so what it stops is an answer that has already arrived. It **does change
  ///          values on screen**, and that is measured: mutate it to a constant `true` (one file) and
  ///          `log(8,2)` and `fact(171)` display the engine's answers instead of this app's (both
  ///          measurements are in the file header). So it is a necessary judgement, not a copy of the
  ///          translation layer.
  ///
  ///          读的调用名先折成规范名（[callNamesIn]）——否则别名拼法穿过这张表：`lg(8,2)` 与
  ///          `log(8,2)` 会得到两个不同的答案，而它们是同一个调用（实测见 [callNamesIn]）。
  ///
  ///          中文：**输入在这里先归一化**（修复轮 9）：[ExpressionParser.normalizeExpressionInput]
  ///          ——与翻译器（`engineExpressionFor`）、与 `ExpressionParser` 构造函数是**同一个静态
  ///          方法**。修复轮 8 让翻译器读了归一化之后的形态，名字层却还在读原文，于是「归一化之后
  ///          才成为词汇表名字」的拼法整个绕过这一层。两个实测（都在提交路径上，引擎只回答它真会被
  ///          问到的那些字符串）：`fact 171` 归一化成 `fact(171)`、全角 `ｌｇ(8,2)` 归一化成
  ///          `lg(8,2)`（别名再折成 `log`），这两条在修复轮 9 之前 `canRead` 都判真，引擎的答案
  ///          因此上屏——分别是 `1.241018070217668E309` 与 `[0.9030899869919436  0.3010299956639812]`，
  ///          而应用自己的答案是「阶乘只支持 0 到 170 的整数」与 `3`。两条都由
  ///          `test/domain/calculator_engine_translation_test.dart` 钉住。
  /// English: the call names it reads are folded to their canonical spelling first ([callNamesIn]) — or
  ///          alias spellings would pass through this table and `lg(8,2)` and `log(8,2)` would get two
  ///          different answers for one and the same call (the measurement is on [callNamesIn]).
  ///
  ///          **The input is normalised here first** (fix round 9):
  ///          [ExpressionParser.normalizeExpressionInput] — the **same static method** the translator
  ///          (`engineExpressionFor`) and `ExpressionParser`'s constructor use. Fix round 8 gave the
  ///          translator the normalised form and left the name layer reading the raw source, so a
  ///          spelling that only becomes a vocabulary name after normalisation bypassed this layer
  ///          entirely. Two measurements (both on the submit path, with the engine answering only the
  ///          strings it would really be asked): `fact 171` normalises to `fact(171)` and the full-width
  ///          `ｌｇ(8,2)` to `lg(8,2)` (aliased on to `log`); before fix round 9 both passed `canRead`
  ///          and the engine's answer reached the screen — `1.241018070217668E309` and
  ///          `[0.9030899869919436  0.3010299956639812]` — where this app's own answers are
  ///          "阶乘只支持 0 到 170 的整数" and `3`. Both are pinned in
  ///          `test/domain/calculator_engine_translation_test.dart`.
  static bool canRead(String source) => !callNamesIn(
        ExpressionParser.normalizeExpressionInput(source),
      ).any(unknownToEngine.contains);

  /// 中文：**应用自己的求值器答得了这个表达式吗**——表达式里有没有一个「应用自己的语言没有
  ///       绑定的名字」（`x`、`y`、`i`，以及 `km` 这类单位名）。
  ///
  ///       判据在**应用自己的语法树**上，而且是**节点类型**：`VariableNode` 就是
  ///       [namesSomethingOutsideTheAppLanguage] 那一条判据本身（见那里的注释），不是名字表、
  ///       也不是正则。输入先过 [ExpressionParser.normalizeExpressionInput]——与翻译器
  ///       （`engineExpressionFor`）、[canRead]、`ExpressionParser` 构造函数用的是**同一个静态
  ///       方法**，所以这里与它们看的是同一个字符串。
  ///
  ///       **它只服务一处**：`_selectEngineResult` 用它决定一个 [EngineResultKind.symbolic] 结果
  ///       配不配显示。**它不是 [canRead] 的放宽或收紧**，两者回答两个问题：
  ///       - [canRead]：**引擎**读得懂这个表达式吗（读不懂时引擎这一次的答案一律不算）；
  ///       - 本方法：**应用自己**答得了这个表达式吗（答得了时，旧解析器依旧是权威——这一条把
  ///         引擎的符号结果判回 [EngineResultKind.arithmetic]，与放宽之前一字不差）。
  ///
  ///       实测的实例是 `pi!`：引擎把它读成 `factorial(pi)`（`pi` 在引擎里是一个**变量**，量过），
  ///       这一次的回执种类因此是 [EngineResultKind.symbolic]；而这个表达式里只有一个常量与一个
  ///       后缀，**没有** [VariableNode]，所以这一条为真、引擎那份文本不算，屏幕上是旧解析器
  ///       那句「阶乘只支持 0 到 170 的整数」——放宽前后一字未变。
  ///       （`pi` 单独一个**不**走这一路：它的十进制形态是有限的 `3.141592653589793`，tier 2
  ///       直接采用，压根到不了这道判据。）
  ///       含 `x` 的输入（`2x`、`x^2 + 1`、`sqrt(x)`）这里为假，于是引擎的符号结果留下来。
  ///
  ///       解析不了（`ParseErrorNode`）时为**假**：那样一个输入应用自己的求值器也答不了，
  ///       引擎（或回落）给出的就是这一行的答案——与这条判据要问的问题一致。
  /// English: **can this app's own evaluator answer this expression** — does it hold a name this
  ///          app's own language has no binding for (`x`, `y`, `i`, and unit names such as `km`).
  ///
  ///          The test is on **this app's own syntax tree**, and it is the **node type**: a
  ///          [VariableNode] is that judgement itself ([namesSomethingOutsideTheAppLanguage] — see
  ///          the note there), not a table of names and not a regex. The input goes through
  ///          [ExpressionParser.normalizeExpressionInput] first — the **same static method** the
  ///          translator (`engineExpressionFor`), [canRead] and `ExpressionParser`'s constructor use,
  ///          so all of them look at one string.
  ///
  ///          **It serves exactly one place**: `_selectEngineResult` uses it to decide whether an
  ///          [EngineResultKind.symbolic] result belongs on screen. **It is neither a relaxation nor a
  ///          tightening of [canRead]** — the two answer two questions:
  ///          - [canRead]: can the **engine** read this expression (when it cannot, no answer of its
  ///            counts this time);
  ///          - this: can **this app itself** answer this expression (when it can, the legacy parser
  ///            is still the authority — this judges the engine's symbolic result back to
  ///            [EngineResultKind.arithmetic], byte-for-byte what it was before the relaxation).
  ///
  ///          The measured instance is `pi!`: the engine reads it as `factorial(pi)` (`pi` is one of
  ///          its **variables**, measured), so that receipt carries [EngineResultKind.symbolic]; the
  ///          expression holds one constant and one postfix and therefore **no** [VariableNode], so
  ///          this is true, the engine's text does not count, and the screen shows the legacy parser's
  ///          "阶乘只支持 0 到 170 的整数" — unchanged by the relaxation. (`pi` on its own never
  ///          reaches this judgement: its decimal form is the finite `3.141592653589793`, which tier 2
  ///          takes directly.) An input holding `x` (`2x`, `x^2 + 1`, `sqrt(x)`) is false here, so the
  ///          engine's symbolic result stays.
  ///
  ///          An unparseable input (`ParseErrorNode`) is **false**: this app's own evaluator cannot
  ///          answer such an input either, so what the engine (or the fallback) gives is this line's
  ///          answer — which is what this judgement is asking about.
  static bool canExpress(String source) => !namesSomethingOutsideTheAppLanguage(
        const ExpressionAstParser().parse(
          ExpressionParser.normalizeExpressionInput(source),
        ),
      );
}
