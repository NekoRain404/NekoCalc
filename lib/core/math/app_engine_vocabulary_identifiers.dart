part of 'app_engine_vocabulary.dart';

// 中文：**词表本身（`identifiers`）住在这个 part 文件里**，不是它下面的那些判断。
//       搬到这里只为行数：搬之前主文件 799 行，已经贴着 800 行的硬性上限，而矩阵那一批名字（本轮）
//       还要往表里加行。分开之后两边都远在限下，而且**加名字再也不用动主文件**——这正是这次拆分的
//       目的：表是会长的那一半，判断不是。
//       **行为一个字符都没有改**：表的每一行、每一段注释逐字来自主文件，值也逐字相同。代码上只有
//       两处不同，两处都不改变任何取值：
//       1. `identifiers` 从类里的 `static const` 变成了这个文件里的顶层 `const`，主文件用一行转发
//          （`static const identifiers = _engineIdentifiers;`），所以
//          `AppEngineVocabulary.identifiers` 这个名字对外一字未变；
//       2. 缩进少两格（类成员 → 顶层），`dart format` 因此把几条**能排进 80 列**的换行收了回去
//          （`'product':`、`'fact':` 那几行）——纯排版，值不变。
//
//       **私有（`_` 前缀）是有意的**：公开面仍是那个类，顶层名字不外泄。
// English: **the table itself (`identifiers`) lives in this part file**, not the judgements below it.
//          It moved here for line count alone: the main file was 799 lines, against the hard 800-line
//          cap, and the matrix batch (this round) needed more rows. Both halves now sit far below the
//          cap, and **adding a name never touches the main file again** — which is the point of the
//          split: the table is the half that grows, the judgements are not.
//          **Not one character of behaviour changed**: every row and every comment came over verbatim
//          and every value is byte-for-byte the same. Two things differ in the code, and neither
//          changes a value:
//          1. `identifiers` went from a `static const` inside the class to a top-level `const` here,
//             with a one-line forwarder in the main file
//             (`static const identifiers = _engineIdentifiers;`), so
//             `AppEngineVocabulary.identifiers` reads exactly as it did before;
//          2. two spaces less indentation (class member → top level), so `dart format` pulled back the
//             few line breaks that **now fit in 80 columns** (the `'product':` and `'fact':` rows) —
//             pure layout, values unchanged.
//
//          **Private (the `_` prefix) is deliberate**: the public face is still that class, and no
//          top-level name escapes.

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
const Map<String, AppFunction> _engineIdentifiers = <String, AppFunction>{
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
  // 中文：**复数与统计这两批，与 `matrix`/`sum`/… 同属「只在引擎那边成立」的那一类。**
  //       应用自己的解析器没有实现它们（`conj(1)` 抛 `Unknown function conj`，实测），所以
  //       它们只能由引擎作答；键盘上也没有它们的键，入口是 `CPLX` 与 `STAT` 两颗键各自打开的
  //       面板（`calculator_page_sheets.dart`），面板把**完整的调用**插进表达式——理由与
  //       `Σ`/`Π`/`∫dx`/`logₓy` 那几颗一样：这些函数都要两个以上实参，而**键盘上没有逗号键**。
  //
  //       **这些名字是量出来的，不是想出来的。** 判据与这张表其它行相同：引擎既认这个拼法、
  //       意思也是我们要的那个。宿主实测（`qalc` 5.12.0，与本 AAR 同版本，`-p 16`，
  //       与桥同一条调用序列）：
  //
  //       | 输入 | 引擎印出来的 | 说明 |
  //       |---|---|---|
  //       | `conj(3+4i)` | `3 − 4i` | 共轭复数 |
  //       | `re(3+4i)` | `3` | 实部 |
  //       | `im(3+4i)` | `4` | 虚部 |
  //       | `arg(3+4i)` | `53.13010235`（DEG）／`0.9272952180`（RAD） | 辐角，**随角度模式变**，与 `sin` 同一条约定 |
  //       | `mean(1,2,3,4)` | `2.5` | 算术平均 |
  //       | `median(1,2,3,4)` | `2.5` | 中位数 |
  //       | `stdev(1,2,3,4)` | `1.290994449` | **样本**标准差（分母 n−1：√(5/3)） |
  //       | `var(1,2,3,4)` | `1.666666667` | **样本**方差（分母 n−1：5/3） |
  //
  //       最后两行的分母是**量出来的**、也是要写下来的：引擎给的是 n−1 那一支，不是总体方差。
  //       应用这一侧从来没有过这两个名字，所以两边不存在「同名不同义」——这正是这两列都填真的
  //       理由。反过来，一个**被拆成符号**的名字长什么样也量过（`zorkmid(1,2)` → `1E−21 B`、
  //       `gg(3)` → `3 g²`），上面八行没有一行是那个形状。
  //
  //       `arg` 随角度模式变，这不是缺陷而是它该有的样子：应用把角度模式交给引擎
  //       （`MathEngine.evaluate` 的 `angleMode`），`arg` 与 `sin` 走同一条约定。
  // English: **the complex and statistics batches belong to the same "holds only on the engine's
  //          side" class as `matrix`/`sum`/…** This app's own parser does not implement them
  //          (`conj(1)` throws `Unknown function conj`, measured), so only the engine can answer
  //          them; and the keypad has no key for them, so the entrance is the sheet the `CPLX` and
  //          `STAT` keys each open (`calculator_page_sheets.dart`), which inserts a **complete
  //          call** — for the same reason as `Σ`/`Π`/`∫dx`/`logₓy`: every one of these takes two or
  //          more arguments and **the keypad has no comma key**.
  //
  //          **These names are measured, not imagined.** The criterion is this table's usual one:
  //          the engine knows the spelling *and* means what we mean. Measured on the host (`qalc`
  //          5.12.0, the version this AAR bundles, `-p 16`, the bridge's own call sequence):
  //
  //          | input | what the engine prints | note |
  //          |---|---|---|
  //          | `conj(3+4i)` | `3 − 4i` | complex conjugate |
  //          | `re(3+4i)` | `3` | real part |
  //          | `im(3+4i)` | `4` | imaginary part |
  //          | `arg(3+4i)` | `53.13010235` (DEG) / `0.9272952180` (RAD) | the argument, **following the angle mode**, the same convention `sin` uses |
  //          | `mean(1,2,3,4)` | `2.5` | arithmetic mean |
  //          | `median(1,2,3,4)` | `2.5` | median |
  //          | `stdev(1,2,3,4)` | `1.290994449` | **sample** standard deviation (divisor n−1: √(5/3)) |
  //          | `var(1,2,3,4)` | `1.666666667` | **sample** variance (divisor n−1: 5/3) |
  //
  //          The last two rows' divisor is **measured** and is worth writing down: the engine gives
  //          the n−1 branch, not the population variance. This app has never had either name, so
  //          no "same name, different meaning" can arise — which is exactly why both columns are
  //          true here. What a name **taken apart into symbols** looks like was measured too
  //          (`zorkmid(1,2)` → `1E−21 B`, `gg(3)` → `3 g²`); none of the eight rows above has that
  //          shape.
  //
  //          `arg` following the angle mode is not a defect but what it should do: the app hands the
  //          angle mode to the engine (`MathEngine.evaluate`'s `angleMode`), and `arg` travels the
  //          same convention as `sin`.
  'conj': AppFunction(engineKnowsThisName: true, engineFunction: 'conj'),
  're': AppFunction(engineKnowsThisName: true, engineFunction: 're'),
  'im': AppFunction(engineKnowsThisName: true, engineFunction: 'im'),
  'arg': AppFunction(engineKnowsThisName: true, engineFunction: 'arg'),
  'mean': AppFunction(engineKnowsThisName: true, engineFunction: 'mean'),
  'median': AppFunction(engineKnowsThisName: true, engineFunction: 'median'),
  'stdev': AppFunction(engineKnowsThisName: true, engineFunction: 'stdev'),
  'var': AppFunction(engineKnowsThisName: true, engineFunction: 'var'),
  'matrix': AppFunction(engineKnowsThisName: true, engineFunction: 'matrix'),
  'sum': AppFunction(engineKnowsThisName: true, engineFunction: 'sum'),
  'product': AppFunction(engineKnowsThisName: true, engineFunction: 'product'),
  'integrate':
      AppFunction(engineKnowsThisName: true, engineFunction: 'integrate'),
  'diff': AppFunction(engineKnowsThisName: true, engineFunction: 'diff'),
  'limit': AppFunction(engineKnowsThisName: true, engineFunction: 'limit'),
  'rand': AppFunction(engineKnowsThisName: true, engineFunction: 'rand'),

  // 中文：**双变量统计那三个。** 它们与上面 `mean`/`median`/`stdev`/`var` 是同一类（只在引擎那边
  //       成立、键盘上没有键、由 `STAT` 面板插完整调用），差别只在**实参的形状**：上面那四个吃
  //       一行矩阵，这三个吃**两行**（第一行 X、第二行 Y）。
  //
  //       **名字是量出来的，不是猜的，而且猜的那个是错的。** HiPER 自己的命令名是
  //       `LINEAR_REG`/`PEARSON`…（weblate 上的 `command.name.*`），而**引擎里一个都不叫这些**：
  //       `getFunction` 对 `linearreg`/`LINEAR_REG`/`polyfit`/`polynomialfit`/`expfit`/`logfit`/
  //       `exponentialfit`/`logarithmicfit`/`regress`/`fit` 逐个返回空。真名在 `functions.xml.in`
  //       里是 `linearfit`/`quadraticfit`/`cubicfit`（`<title>Regression</title>`）与
  //       `pearson`/`spearman`/`covar`。宿主实测（`qalc` 5.12.0，与本 AAR 同版本，`-t`，同一串实参）：
  //
  //       | 输入 | 引擎印出来的 | 说明 |
  //       |---|---|---|
  //       | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,10))` | `1.000000000` | 皮尔逊相关系数 |
  //       | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` | `0.9958932065` | 同上，不完美相关 |
  //       | `spearman(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` | `1.000000000` | 斯皮尔曼秩相关 |
  //       | `covar(matrix(2,3,1,2,3,4,5,6))` | `0.6666666667` | 协方差 |
  //
  //       **「两行矩阵当两个实参」是量到的行为，机制没钉到。** 修复轮 10 量了：这六个统计函数的
  //       实参定义 `handlesVector()` 全是 **0**（`mean` 是 1），所以源码里那三处由它把守的支都不是
  //       拆分它们的那一支——本节原先按机制名写的那句是错的。**行数等于形参数时才成立**（实测：
  //       `covar(matrix(3,3,…))`/`covar(matrix(1,3,…))` 原样退回），而这六个都是两个形参。
  //
  //       **`linearfit`/`quadraticfit`/`cubicfit` 现在在表里，但只在一种形状下**（第三列），
  //       答案是 `2x`/`x²`/`x³`（**一个函数**，实测、种类 `symbolic`）。
  // English: **the three two-variable statistics.** They are the same class as
  //          `mean`/`median`/`stdev`/`var` above (they hold only on the engine's side, have no key on
  //          the keypad and the `STAT` sheet inserts a complete call) — the difference is **the shape
  //          of the argument**: those four take a one-row matrix, these three take **two rows**
  //          (first row X, second row Y).
  //
  //          **The names are measured, not guessed — and the guess is wrong.** HiPER's own command
  //          names are `LINEAR_REG`/`PEARSON`… (`command.name.*` on weblate), and **none of them is
  //          what the engine calls it**: `getFunction` comes back empty for `linearreg`,
  //          `LINEAR_REG`, `polyfit`, `polynomialfit`, `expfit`, `logfit`, `exponentialfit`,
  //          `logarithmicfit`, `regress` and `fit`. The real names in `functions.xml.in` are
  //          `linearfit`/`quadraticfit`/`cubicfit` (under `<title>Regression</title>`) and
  //          `pearson`/`spearman`/`covar`. Measured on the host (`qalc` 5.12.0, the version this AAR
  //          bundles, `-t`, the same argument string):
  //
  //          | input | what the engine prints | note |
  //          |---|---|---|
  //          | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,10))` | `1.000000000` | Pearson's r |
  //          | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` | `0.9958932065` | the same, imperfectly correlated |
  //          | `spearman(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` | `1.000000000` | Spearman's rho |
  //          | `covar(matrix(2,3,1,2,3,4,5,6))` | `0.6666666667` | covariance |
  //
  //          **"A two-row matrix becomes two arguments" is measured behaviour; the mechanism was
  //          not pinned.** Fix round 10 measured it: all six statistics functions below report
  //          `handlesVector()` **0** on their argument definitions (`mean` reports 1), so the three
  //          places in `MathStructure-calculate.cc` guarded by it are **not** the ones that split
  //          them — the sentence this section carried, naming that branch, was wrong. **It holds
  //          only while the row count equals the arity** (measured: `covar(matrix(3,3,…))` and
  //          `covar(matrix(1,3,…))` come straight back), and all six have two parameters.
  //
  //          **`linearfit`/`quadraticfit`/`cubicfit` are in the table now, but under one shape
  //          only** (the third column); their answer is `2x`/`x²`/`x³` (**a function**, measured,
  //          kind `symbolic`).
  'pearson': AppFunction(engineKnowsThisName: true, engineFunction: 'pearson'),
  'spearman':
      AppFunction(engineKnowsThisName: true, engineFunction: 'spearman'),
  'covar': AppFunction(engineKnowsThisName: true, engineFunction: 'covar'),

  // 中文：**三个拟合。** 名字与意思都量过：`Calculator::getFunction` 三问三中；意思是
  //       `linearfit(matrix(1,3,10,20,30),matrix(1,3,1,2,3))` → `0.1x`（X 不是 1…n 也照样读）、
  //       `quadraticfit(…)` → `0.01x²`、`cubicfit(…)` → `x³`。第三列是它们与上面那一批的分别。
  // English: **the three fits.** Name and meaning both measured: `getFunction` finds all three, and
  //          `linearfit(matrix(1,3,10,20,30),matrix(1,3,1,2,3))` → `0.1x` (a non-default X counts).
  'linearfit': AppFunction(
      engineKnowsThisName: true,
      engineFunction: 'linearfit',
      oneSeriesPerArgument: true),
  'quadraticfit': AppFunction(
      engineKnowsThisName: true,
      engineFunction: 'quadraticfit',
      oneSeriesPerArgument: true),
  'cubicfit': AppFunction(
      engineKnowsThisName: true,
      engineFunction: 'cubicfit',
      oneSeriesPerArgument: true),

  // 中文：**矩阵那一批：`MTRX` 第二功能（HiPER 的 `MATRIX_MENU`）菜单里插的名字。**
  //       它们与上面那一批同类（只在引擎那边成立、应用自己的解析器没有实现、由面板插**完整**调用），
  //       而且全都**围着本应用自己的矩阵写法** `matrix(行, 列, 元素…)` 转：菜单里每一项插的都是
  //       「一条调用包住 `matrix(2,2,1,2,3,4)`」，**不是**「包住用户此刻的表达式」。
  //
  //       **一、为什么不是「包住用户的表达式」——四行实测，这是本批次最要紧的一句话。**
  //       引擎对**标量**不报错，它给出一个看起来合理的值（宿主 `qalc` 5.12.0，与本 AAR 同版本）：
  //
  //       | 输入 | 引擎印出来的 | 说明 |
  //       |---|---|---|
  //       | `det(5)` | `5` | 标量原样退回 |
  //       | `inv(5)` | `0.2` | 倒数——**看起来就是一个答案** |
  //       | `transpose(5)` | `5` | 标量原样退回 |
  //       | `det(5,1,2)` | `5` | 多余实参**不报错**（见第三条） |
  //
  //       于是「包住光标前那一个值」在这里是**静默错值**的入口：表达式里正好是一个数时，屏幕上会
  //       出现一个没有人会怀疑的结果，而它答的不是被问的那个问题。完整插入没有这个状态——插出去的
  //       文本里**永远**含一个 `matrix(…)`，应用不会把一个标量交给 `det`。同一条理由也是
  //       `ins:sum`/`ins:mean` 那一批的形状（键盘上没有逗号键）。
  //
  //       **二、收下这四个的依据：名字与意思都量过**（宿主 `qalc` 5.12.0，`-t`；
  //       `getFunction` 那一列是同一台机器上的 `Calculator::getFunction`）：
  //
  //       | 名字 | `getFunction` | 引擎印出来的 | 说明 |
  //       |---|---|---|---|
  //       | `det` | `Determinant` | `det(matrix(2,2,1,2,3,4))` = `−2` | 行列式 |
  //       | `transpose` | `Transpose` | `transpose(matrix(2,2,1,2,3,4))` = `[1  3; 2  4]` | 转置 |
  //       | `inv` | `Matrix Inverse` | `inv(matrix(2,2,1,2,3,4))` = `[−2  1; 1.5  −0.5]` | 逆矩阵；**厂商更新日志 9.1 有一条 "Matrix inverse added to MTRX menu"** |
  //       | `identity` | `Identity` | `identity(2)` = `[1  0; 0  1]` | 单位矩阵 |
  //
  //       另量的几条（**量过但这轮不进表、不上面板**，写在这里免得下一轮重跑）：
  //       `adj`（`Adjugate (Adjoint)`，`adj(matrix(2,2,1,2,3,4))` = `[4  −2; −3  1]`，
  //       且 `adj(A)*A` = `[−2  0; 0  −2]` = `det(A)·I`，两处都对）、`dot`（`Dot Product`，
  //       `dot(matrix(1,2,1,2),matrix(1,2,3,4))` = `11`）、`cross`（`Cross Product`，
  //       `cross(matrix(1,3,1,0,0),matrix(1,3,0,1,0))` = `[0  0  1]`）——它们答得对，缺的是
  //       **来源**：厂商的菜单里有没有它们，这一轮没有拿到（`hiper_en.po` 已不在手上），而面板是
  //       「矩阵与向量菜单」，不能凭空替厂商列条目。
  //
  //       **三、实参个数：`det`/`inv`/`transpose` 都**不查个数**——多给的实参被丢掉，不报错。**
  //       实测（同一台宿主）：`det(matrix(2,2,1,2,3,4),1)` = `det(…,2)` = `det(…,1,2)` = `−2`，
  //       `inv(…,1)` 与 `transpose(…,1)` 同形。所以就「多一个实参」这一种手滑，屏幕上仍是同一个
  //       值；而**形状不对**的输入不会静默：`det(matrix(2,3,…))` 与 `inv(matrix(2,3,…))` 原样退回
  //       （`det([1  2  3; 4  5  6])`），`inv` 对奇异矩阵也原样退回。**退回（一个式子）不是错值**，
  //       屏幕上看得出来；这条边界正是这一批能进表的原因。
  //
  //       **四、`arg` 是安全的，`angle` 不是——两个都量过。** `arg(1+i)` 在 DEG 下是 `45`、
  //       RAD 下是 `0.7853981633974483`（跟角度模式走，与 `sin` 同一条约定；`arg` 本来就在上面
  //       那一批里）。**`angle(1+i)` 不是辐角**：`getFunction('angle')` 返回空，于是那个词被拆成
  //       符号，印出来是一个带单位的量——`qalc -t` 给 `(2.718281828 + 2.718281828i) L·ANG`，
  //       按桥的调用序列（RAD、APPROXIMATE）给
  //       `(271.8281828459045 + 271.8281828459045i) pg*m^5`。**两次印的字符串不一样，但两次都是
  //       带单位的量、都不是角**——所以「这个陷阱长什么样」这句话要按**类**说（带单位、不是角），
  //       不能按某一串字符说。`angle` 因此不进表。
  //
  //       **五、`rank`/`trace`/`echelon` 是本周最危险的一类：名字看着对，答案不是那个东西。**
  //       三个都量过，两个成因不同（宿主，同一串调用）：
  //
  //       | 名字 | `getFunction` | 用本应用拼法调它 | 真值 |
  //       |---|---|---|---|
  //       | `rank` | `Rank`（**引擎里真有这个函数**） | `rank(matrix(2,2,1,2,3,4))` = `[1  2; 3  4]`（矩阵原样回来） | 秩 = `2` |
  //       | `trace` | **空**（引擎里没有这个名字） | `trace(matrix(2,2,1,2,3,4))` = `[(512.0295827 GGy·m·s·rad)  …]` | 迹 = `5` |
  //       | `echelon` | **空** | `echelon(matrix(2,2,1,2,3,4))` = `[(0.1486441637n B·m⁴)  …]` | 行阶梯形 |
  //
  //       `rank` 那一行是最坏的一种：**名字是真的、函数是真的、答案的形状也对（进一个矩阵、出一个
  //       矩阵）**，而它不是秩。`rank(matrix(3,3,1,2,3,4,5,6,7,8,10))` 印成
  //       `[1  2  3; 4  5  6; 7  8  9]`——连最后一个元素都被改成了 `9`。这类错值屏幕上没有任何
  //       线索，所以这三个**一律不进表**：不做，就没有「按下去给一个看起来对的数」这条路。
  //       行阶梯形的**真名是 `rref`**（`Reduced Row Echelon Form`，实测
  //       `rref(matrix(2,2,1,2,3,4))` = `[1  0; 0  1]`），但它与 `adj`/`dot`/`cross` 同一条：
  //       缺的是来源，不是能力。
  //
  //       上面四条（一、三、五）与 `MTRX` 那一格、矩阵面板的禁用行是一组**同一份实测**，
  //       断言钉在 `test/features/calculator_drg_matrix_band_keys_test.dart` 与
  //       `test/features/calculator_matrix_menu_test.dart`。
  // English: **the matrix batch: the names the `MTRX` second function (HiPER's `MATRIX_MENU`) inserts.**
  //          They are the same class as the batch above (they hold only on the engine's side, this app's
  //          own parser does not implement them, and a sheet inserts a **complete** call), and they all
  //          revolve around **this app's own matrix spelling** `matrix(rows, cols, elements…)`: every
  //          entry inserts "a call around `matrix(2,2,1,2,3,4)`", **never** "a call around whatever the
  //          user has in the expression".
  //
  //          **1. Why not "wrap the user's expression" — four measurements, the most important sentence
  //          in this batch.** The engine does not error on a **scalar**; it answers with a
  //          plausible-looking value (host `qalc` 5.12.0, the version this AAR bundles):
  //
  //          | input | what the engine prints | note |
  //          |---|---|---|
  //          | `det(5)` | `5` | the scalar comes straight back |
  //          | `inv(5)` | `0.2` | the reciprocal — **it looks like an answer** |
  //          | `transpose(5)` | `5` | the scalar comes straight back |
  //          | `det(5,1,2)` | `5` | extra arguments **do not error** (see 3) |
  //
  //          So "wrap the value before the caret" is an entrance to a **silent wrong value** here: with
  //          a plain number in the expression, a result nobody would question appears on screen and it
  //          answers a different question. A complete insertion has no such state — the inserted text
  //          **always** holds a `matrix(…)`, so this app never hands a scalar to `det`. The same reason
  //          gives `ins:sum`/`ins:mean` their shape (the keypad has no comma key).
  //
  //          **2. What admits these four: name and meaning both measured** (host `qalc` 5.12.0, `-t`;
  //          the `getFunction` column is `Calculator::getFunction` on the same machine) — see the table
  //          above: `det`/`Determinant` → `−2`; `transpose`/`Transpose` → `[1  3; 2  4]`;
  //          `inv`/`Matrix Inverse` → `[−2  1; 1.5  −0.5]` (and the vendor's release notes 9.1 carry
  //          "Matrix inverse added to MTRX menu"); `identity`/`Identity` → `[1  0; 0  1]`.
  //
  //          Also measured, **but not entering the table or the sheet this round** (recorded so the next
  //          round need not re-measure): `adj` (`Adjugate (Adjoint)`, `adj(matrix(2,2,1,2,3,4))` =
  //          `[4  −2; −3  1]`, and `adj(A)*A` = `[−2  0; 0  −2]` = `det(A)·I`, both correct), `dot`
  //          (`Dot Product`, `dot(matrix(1,2,1,2),matrix(1,2,3,4))` = `11`) and `cross` (`Cross
  //          Product`, `cross(matrix(1,3,1,0,0),matrix(1,3,0,1,0))` = `[0  0  1]`). They answer
  //          correctly; what they lack is a **source** — whether the vendor's menu lists them was not
  //          obtained this round (`hiper_en.po` is no longer on hand), and a sheet called "Matrix and
  //          Vector Menu" may not invent entries on the vendor's behalf.
  //
  //          **3. Arity: `det`/`inv`/`transpose` do not check it — extra arguments are dropped, not
  //          rejected.** Measured (same host): `det(matrix(2,2,1,2,3,4),1)` = `det(…,2)` =
  //          `det(…,1,2)` = `−2`, and `inv(…,1)`/`transpose(…,1)` the same shape. So one argument too
  //          many still shows the same value, and a **wrong shape** is never silent:
  //          `det(matrix(2,3,…))` and `inv(matrix(2,3,…))` come straight back
  //          (`det([1  2  3; 4  5  6])`), and so does `inv` of a singular matrix. **Coming back as a
  //          formula is not a wrong value** — the screen shows it — and that boundary is exactly what
  //          admits this batch.
  //
  //          **4. `arg` is safe, `angle` is not — both measured.** `arg(1+i)` is `45` under DEG and
  //          `0.7853981633974483` under RAD (it follows the angle mode, the same convention `sin`
  //          uses; `arg` is already in the batch above). **`angle(1+i)` is not an argument**:
  //          `getFunction('angle')` returns nothing, so the word is taken apart into symbols and prints
  //          as a quantity carrying units — `qalc -t` gives
  //          `(2.718281828 + 2.718281828i) L·ANG` while the bridge's own call sequence (RAD,
  //          APPROXIMATE) gives `(271.8281828459045 + 271.8281828459045i) pg*m^5`. **The two strings
  //          differ, but both are unit-carrying quantities and neither is an angle** — so "what this
  //          trap looks like" has to be stated as a **class** (carries units, is not an angle), never
  //          as one particular string. `angle` therefore stays out of the table.
  //
  //          **5. `rank`/`trace`/`echelon` are this week's most dangerous class: the name looks right
  //          and the answer is not that thing.** All three measured, from two different causes (host,
  //          the same call string) — see the table above: `rank` **is a real engine function**
  //          (`getFunction` → `Rank`) and still returns the matrix unchanged; `trace` and `echelon` are
  //          **not names the engine has at all**, so the word is taken apart into symbols and the
  //          answer carries units. `rank`'s row is the worst kind: **the name is real, the function is
  //          real, and the shape is right (a matrix in, a matrix out)** — it just is not the rank.
  //          `rank(matrix(3,3,1,2,3,4,5,6,7,8,10))` prints `[1  2  3; 4  5  6; 7  8  9]`, even
  //          rewriting the last element to `9`. No screen would give that away, so these three **never
  //          enter the table**: with them not built, there is no "press it and get a plausible number"
  //          path at all. The row-echelon operation's **real name is `rref`** (`Reduced Row Echelon
  //          Form`; measured `rref(matrix(2,2,1,2,3,4))` = `[1  0; 0  1]`), but it shares the fate of
  //          `adj`/`dot`/`cross`: what is missing is a source, not a capability.
  //
  //          Items 1, 3 and 5 above are **one set of measurements** shared with the `MTRX` cell and the
  //          matrix sheet's grey rows; the assertions are pinned in
  //          `test/features/calculator_drg_matrix_band_keys_test.dart` and
  //          `test/features/calculator_matrix_menu_test.dart`.
  'det': AppFunction(engineKnowsThisName: true, engineFunction: 'det'),
  'transpose':
      AppFunction(engineKnowsThisName: true, engineFunction: 'transpose'),
  'inv': AppFunction(engineKnowsThisName: true, engineFunction: 'inv'),
  'identity':
      AppFunction(engineKnowsThisName: true, engineFunction: 'identity'),

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
  'fact': AppFunction(engineKnowsThisName: false, engineFunction: 'factorial'),
  'deg': AppFunction(engineKnowsThisName: false),
  'rad': AppFunction(engineKnowsThisName: false),
  // 中文：**`degangle`：度数记号 `°` 的求值名字，不是给用户按的函数。**
  //       它是归一化自己产出的名字——`30°` 写成 `degangle(30)`（理由、实测与「为什么不按模式改写
  //       文本」都在 `expression_parser.dart` 的 `_replaceDegreeSign` 上）——所以键位/面板**插不出
  //       它**，这一行也不是一个入口。
  //
  //       它必须在这张表里，理由有两条，方向相反：
  //       1. 解析器接受它（`ExpressionParser.functionNames` 里就有它，两者由覆盖测试钉成同一集合），
  //          而这一层的规矩是「解析器认得的名字一个都不能漏在表外」；
  //       2. **`engineKnowsThisName: false` 是判据的一部分**：引擎没有这个拼法，所以含 `°` 的表达式
  //          仍然落在「不可信」那一列，`canRead` 照旧判假——与修复前一模一样（那时这条归 `rad`）。
  //          漏掉这一行，`canRead` 会对含 `°` 的输入**判真**：那不是放宽，是一句假话
  //          （`unknownToEngine` 只认表里的名字，表外的名字它根本不看）。
  // English: **`degangle`: the evaluation name of the degree mark `°`, not a function to press.** It
  //          is a name normalisation produces on its own — `30°` is written `degangle(30)` (the
  //          argument, the measurements and "why not rewrite the text by mode" are on
  //          `_replaceDegreeSign` in `expression_parser.dart`) — so no key or sheet inserts it, and
  //          this row is not an entrance either.
  //
  //          It has to sit in this table for two reasons pointing in opposite directions:
  //          1. the parser accepts it (it is in `ExpressionParser.functionNames`; the coverage test
  //             pins the two to one set), and this layer's rule is that no name the parser knows may
  //             be missing from the table;
  //          2. **`engineKnowsThisName: false` is part of a judgement**: the engine has no such
  //             spelling, so an expression containing `°` still lands in the untrusted column and
  //             `canRead` still says false — exactly as before the fix (where that column entry was
  //             `rad`'s). Without this row `canRead` would say **true** for `°` inputs: not a
  //             relaxation but a false statement (`unknownToEngine` only knows the names in this
  //             table; a name outside it is never even looked at).
  'degangle': AppFunction(engineKnowsThisName: false),
};
