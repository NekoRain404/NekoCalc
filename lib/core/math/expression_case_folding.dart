part of 'expression_parser.dart';

/// 中文：**归一化里的那一次大小写折叠——应用自己的名字折成小写，单位拼法一个字节都不动。**
///
///       **它修的是什么。** 从前这一步是 `text.toLowerCase()`，整段文本一次折干净。于是
///       [kAppUnits] 那 120 个拼法里**带大写字母的 50 个**（`L`/`Pa`/`J`/`W`/`B`/`A`/`kWh`…）
///       在归一化之后已经不是表里的拼法了，而翻译层那句判据是按**原样**查表的
///       （[AppEngineVocabulary.variableUnknownToEngine] 里的 `isAppUnit(name)`）——它永远查不到
///       它们。实测（`test/domain/unit_symbol_case_test.dart` 的那一趟逐格扫描，修复前）：
///       120 个里 **50 个**过不去，`1 bar to Pa` 的拒绝理由是「引擎不认识这个自由变量：`pa`」，
///       而 `5 Pa` 连单独站着都被拒。`CONV` 面板列着它们，按下去每一格都报错。
///
///       **这不是打字错误，是两条各自都对的规矩撞在一起：**
///
///       - 函数名**必须**大小写不敏感（`SIN(30)` = `Sin(30)`）——折叠就是为它存在的；
///       - 单位名**必须**大小写敏感（`m` 是米、`M` 是兆前缀；`t` 是吨、`T` 是特斯拉）——
///         表里 `mA`/`mF`/`mH`/`mC` 与 `A`/`F`/`H`/`C` 并排摆着，折了就等于把它们看成一个。
///
///       所以折叠不能整段做，也不能不做：**它按名字的归属分两半**——应用自己定义的名字（函数名、
///       别名、常量、变量、词运算符）折；**引擎定义的符号（单位名）不折**。
///
///       **规则一句话：一个字母开头的标识符 token，只要它*可能*是某个单位拼法（大小写不敏感地
///       像表里某一个），又不是一次调用的名字，就原样留下；其余一律折成小写。**
///
///       **为什么是「可能像」而不是「就是」。** 因为「就是」仍然让折叠去回答「用户写的是哪个单位」
///       ——那正是这条缺陷的形状。折了 `KM` 就得到 `1 km`（千米），而引擎读 `1 KM` 得到的是
///       `1 K`（开尔文）；折了 `T` 得到吨，引擎读的是特斯拉。宿主实测（`/usr/bin/qalc` 5.12.0，
///       与打包进 AAR 的同版本，`-t`）：
///
///       | 用户打的 | 引擎读出来的 | 折成小写之后应用读到的 | |
///       |---|---|---|---|
///       | `1 KM` | `1 K`（开尔文） | `1 km`（千米） | 错值 |
///       | `1 M` | `1E6`（兆前缀） | `1 m`（米） | 错值 |
///       | `1 T` | `1 T`（特斯拉） | `1 t`（吨） | 错值 |
///       | `1 S` | `1 S`（西门子） | `1 s`（秒） | 错值 |
///       | `1 H` | `1 H`（亨利） | `1 h`（小时） | 错值 |
///       | `1 G` | `1 G`（高斯） | `1 g`（克） | 错值 |
///       | `1 MBAR` | `1 megabar` | `1 mbar`（毫巴） | 错值（差 10⁹） |
///       | `1 CAL` | `1 L·s·A²` | `1 cal`（卡） | 错值 |
///       | `1 MOL` | `1E6 mm³` | `1 mol`（摩尔） | 错值 |
///       | `1 IN` | `1 N`（牛顿） | `1 in`（英寸） | 错值 |
///       | `1 In` | `n` | `1 in`（英寸） | 错值 |
///       | `1 Gal` | `10 mm/s²` | `1 gal`（加仑） | 错值 |
///       | `1 RAD` | `3.335640952 mA·C·m` | `1 rad`（弧度） | 错值 |
///
///       这些**今天全都在折**，而且全都在那 50 个之外——同一条规则的另一半。修完之后它们原样送到
///       按原样查表的那一句，查不到就拒绝：**报错，而不是一个看着合理的值**（这个项目最老的那条
///       规矩）。**反方向也一样，两个例子**：`Pa` 之所以能用，正是因为没人再折它；而 `B`（字节，
///       表里真有这一格）今天折成 `b`——表里没有——于是一个**表里有的**拼法被折叠变成了拒绝，
///       与 `Pa` 是同一类。另外几个变体（`HZ`/`KWH`/`PA`/`WH`/`AH`）今天折成表外的小写，本来
///       就已经是拒绝，修前修后没有差别。
///
///       **代价写在这里，别让它成为下一轮的意外**：有少数变体引擎读得与表里那个拼法**完全相同**
///       （实测 `1 MPH` 与 `1 mph` 都是 `447.04 mm/s`；`1 Cup`/`1 Ton` 同样一致），它们现在也一律
///       拒绝。这是**有意选的一边**：「引擎碰巧同意」是一个开放面（下一个版本未必同意），而单位
///       身份是**用户的输入**，不该由我们折出来。用户要那个单位，`CONV` 面板上按一下给的正是表里
///       的拼法。整批量的量测：120 个拼法里 **85 个**的大写变体引擎读成**另一个量**（只有 35 个
///       一致），所以这条规则的收益远大于代价。
///
///       **调用位置那一半是必须的，而且用的就是解析器自己那条判据。** `C` 是本应用里唯一一个
///       既是别名（键上的 `nCr`，写法 `C(...)`）又是单位拼法（库仑）的名字。名字后面跟着 `(` 就是
///       一次调用（`ExpressionAstParser._parseName`：`if (source[_index] == '(') return _parseCall(…)`），
///       否则是一个裸词（`ExpressionParser._parsePrimary` 那一句 `Function $name needs (`）。
///       归一化这里问的是同一个问题，所以 `C(1,234)` 走的仍然是今天那条路（折成 `c(1,234)`、
///       别名折成 `ncr(1,234)`，逗号是实参分隔符），而 `5 C` 原样留给按原样查表的那一句。
///
///       **为什么不干脆把 `text.toLowerCase()` 删掉（文本原样，查表那一侧改成大小写不敏感）。**
///       那个方向要动的不是一处，是一整层：旧解析器 `_parsePrimary` 的 `switch` 按 `'sin'`/`'pi'`
///       这样的小写字面量分派、`_normalizeBareUnaryFunctionCalls` 与隐式乘法那两条正则按小写名字
///       认 `名字(...)`、进制前缀 `0x` 与十六进制数字 `A-F`、科学计数法 `1E3`、LaTeX 命令、别名表
///       `lg`/`c`/`p`——每一处都要各自改成大小写不敏感，而**漏掉任何一处就是一处静默的行为改变**
///       （漏掉进制那处，`0X1F` 就从 31 变成一句错误）。这条规则让折叠照旧发生在**一个地方**：
///       文本里除了单位拼法仍全是小写，上面每一处一个字都不用改。
///
///       **七个消费者看到的仍然是同一个字符串**（这是修复轮 8、9 与 `°` 那一轮的规矩）：折叠就在
///       [ExpressionParser.normalizeExpressionInput] 原来那一步的位置上，输入输出都是纯函数，
///       所以 `ExpressionParser`、`engineExpressionFor`、`canRead`/`canExpress`、
///       `resolveVariableReferences`、图形标签、提交去重键、持久化读到的还是同一个字符串。
///       变的只是它长什么样：**单位拼法保住了自己的大小写**。
///
/// English: **the one case fold inside normalisation — this app's own names fold to lower case, unit
///          spellings do not move a byte.**
///
///          **What it repairs.** This step used to be `text.toLowerCase()`, flattening the whole text.
///          So **50 of [kAppUnits]' 120 spellings** (every one carrying a capital: `L`/`Pa`/`J`/`W`/
///          `B`/`A`/`kWh`…) were no longer table spellings after normalisation, while the translation
///          layer's judgement looks the name up **verbatim** (`isAppUnit(name)` in
///          [AppEngineVocabulary.variableUnknownToEngine]) and could never find them. Measured (the
///          cell-by-cell sweep in `test/domain/unit_symbol_case_test.dart`, before the fix): **50 of
///          120** failed, `1 bar to Pa` was refused with "the engine does not know this free variable:
///          `pa`", and `5 Pa` was refused standing alone. The `CONV` sheet lists them and every cell
///          errors.
///
///          **This is not a typo; it is two rules, each correct, colliding:**
///
///          - function names **must** be case-insensitive (`SIN(30)` = `Sin(30)`) — the fold exists for
///            them;
///          - unit names **must** be case-sensitive (`m` is metre, `M` is the mega prefix; `t` is the
///            tonne, `T` the tesla) — `mA`/`mF`/`mH`/`mC` sit in the table beside `A`/`F`/`H`/`C`, and
///            folding reads them as one.
///
///          So the fold can be neither whole-text nor absent: **it splits by who owns the name** — the
///          names this app defines (function names, aliases, constants, variables, the word operator)
///          fold; the symbols the engine defines (unit names) do not.
///
///          **The rule in one sentence: a letter-led identifier token that *could* be a unit spelling
///          (case-insensitively similar to one in the tables) and is not a call name survives
///          verbatim; every other token folds to lower case.**
///
///          **Why "could be" rather than "is".** Because "is" still lets the fold answer "which unit did
///          the user write" — which is this defect's very shape. Folding `KM` yields `1 km`
///          (kilometres) while the engine reads `1 KM` as `1 K` (kelvin); folding `T` yields tonnes
///          where the engine reads tesla. Host measurements (`/usr/bin/qalc` 5.12.0, the version the
///          AAR bundles, `-t`) — see the table above.
///
///          Every one of those is folded **today** and every one sits outside the 50: the other half
///          of one rule. After the fix they travel verbatim to the verbatim lookup and are refused
///          when not found: **an error, not a plausible value** (this project's oldest rule). The same
///          rule is why `Pa` works at all — nobody folds it any more.
///
///          **The price, written down so it is not next round's surprise**: a few variants are read by
///          the engine **exactly** as the table spelling (measured: `1 MPH` and `1 mph` are both
///          `447.04 mm/s`; `1 Cup` and `1 Ton` agree likewise), and they are refused now too. That side
///          is **chosen deliberately**: "the engine happens to agree" is an open surface (the next
///          version need not), while unit identity is **the user's input** and must not be folded into
///          shape. A user who wants that unit presses it in the `CONV` sheet, which hands over the
///          table's own spelling. The bulk measurement: of the 120 spellings, **85** have an upper-case
///          variant the engine reads as **another quantity** (only 35 agree), so the rule's gain is far
///          larger than its cost.
///
///          **The call-position half is required, and it is the parsers' own test.** `C` is this app's
///          only name that is both an alias (the keypad's `nCr`, written `C(...)`) and a unit spelling
///          (the coulomb). A name followed by `(` is a call (`ExpressionAstParser._parseName`:
///          `if (source[_index] == '(') return _parseCall(…)`), otherwise it is a bare word
///          (`ExpressionParser._parsePrimary`'s `Function $name needs (`). Normalisation asks the same
///          question here, so `C(1,234)` still takes today's road (folded to `c(1,234)`, aliased to
///          `ncr(1,234)`, the comma an argument separator) while `5 C` is left verbatim for the
///          verbatim lookup.
///
///          **Why not simply delete `text.toLowerCase()` (keep the text verbatim and make the lookups
///          case-insensitive instead).** That direction touches a whole layer rather than one place:
///          the legacy parser's `_parsePrimary` dispatches on lower-case literals such as `'sin'`/
///          `'pi'`; `_normalizeBareUnaryFunctionCalls` and the two implicit-multiplication regexes
///          recognise `name(...)` by its lower-case spelling; the radix prefix `0x` with hex digits
///          `A-F`; scientific notation `1E3`; the LaTeX commands; the alias table `lg`/`c`/`p` —
///          each would have to become case-insensitive on its own, and **missing any one is a silent
///          behaviour change** (miss the radix one and `0X1F` stops being 31). This rule keeps the
///          folding in **one place**: outside unit spellings the text is still all lower case, so not
///          one of those sites changes.
///
///          **All seven consumers still see one string** (the rule of fix rounds 8 and 9 and of the
///          `°` round): the fold sits exactly where `text.toLowerCase()` used to, and is a pure
///          function of its input, so `ExpressionParser`, `engineExpressionFor`, `canRead`/
///          `canExpress`, `resolveVariableReferences`, the graph label, the submit de-duplication key
///          and persistence all read the same string. What changed is what it looks like: **unit
///          spellings keep their case.**
String _foldAppNames(String source) {
  return source.replaceAllMapped(_appNameToken, (match) {
    final token = match.group(0)!;
    if (!_unitSpellingsIgnoringCase.contains(token.toLowerCase())) {
      return token.toLowerCase();
    }
    return _isCallName(source, match.end) ? token.toLowerCase() : token;
  });
}

/// 中文：一个标识符 token（字母开头，后跟字母或数字）——与两个解析器的分词器同形
///       （`ExpressionParser._readName` 与 `ExpressionAstParser._isNameChar` 的 `[A-Za-z][A-Za-z0-9]*`）。
/// English: one identifier token (a letter, then letters or digits) — the same shape both parsers'
///          tokenisers use (`[A-Za-z][A-Za-z0-9]*` in `ExpressionParser._readName` and
///          `ExpressionAstParser._isNameChar`).
final RegExp _appNameToken = RegExp(r'[A-Za-z][A-Za-z0-9]*');

/// 中文：两张单位表的拼法**折成小写**之后的集合——「这个 token 有没有可能是一个单位拼法」的问法。
///       两张表都要（[kAppUnitSymbols] 与 [kAngleUnitSymbols]）：`deg` 只在后者里，而它与别的拼法
///       一样有大小写这回事（`DEG` 同样不该折）。**不新增第三份清单**：这就是那两张表本身。
///
///       **表里真有一对只差大小写的拼法**：`h`（小时）与 `H`（亨利）。它们折过之后落在同一个键上
///       ——那没关系，这个集合回答的是「这个 token 有没有可能是单位拼法」（两者都是 ⇒ 两者都原样
///       留下），**不是一个 token 对应哪个单位**；「哪个单位」由按原样查表的那一句回答，而它现在
///       拿到的正是用户打的那一个字节。这一对由 `test/domain/unit_symbol_case_test.dart` 钉住。
/// English: the two unit tables' spellings, **lower-cased** — the question "could this token be a unit
///          spelling". Both tables are needed ([kAppUnitSymbols] and [kAngleUnitSymbols]): `deg` lives
///          only in the latter and has case like any other spelling (`DEG` must not fold either). **No
///          third list is invented**: these are the two tables themselves.
///
///          **The tables really do hold a pair differing only by case**: `h` (hour) and `H` (henry).
///          Lower-cased they land on one key — which is harmless, because this set answers "could this
///          token be a unit spelling" (both are ⇒ both survive verbatim), **not "which unit is this
///          token"**. That question is answered by the verbatim lookup, which now receives exactly the
///          bytes the user typed. The pair is pinned by `test/domain/unit_symbol_case_test.dart`.
final Set<String> _unitSpellingsIgnoringCase = <String>{
  for (final symbol in kAppUnitSymbols) symbol.toLowerCase(),
  for (final symbol in kAngleUnitSymbols) symbol.toLowerCase(),
};

/// 中文：这个 token 是不是一次调用的名字——它后面（允许空白）紧跟着 `(`。**与解析器同一条判据**
///       （见 `_foldAppNames` 的文件头），所以这里不引入第二条「什么是调用」的规则。
/// English: whether this token is a call name — `(` follows it (whitespace allowed). **The parsers' own
///          test** (see the header on `_foldAppNames`), so no second rule of "what is a call" is
///          introduced.
bool _isCallName(String source, int end) {
  var index = end;
  while (index < source.length && source[index].trim().isEmpty) {
    index++;
  }
  return index < source.length && source[index] == '(';
}
