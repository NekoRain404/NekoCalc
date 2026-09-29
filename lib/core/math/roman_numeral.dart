/// 中文：**整数 → 罗马数字。**
///
///       ⚠️ **这一条是"我们比引擎对"的地方，而不是"引擎能做所以接出来"的地方。**
///       引擎有一个同名函数，而它**在边界上会给出看着像答案的错值**——宿主 `qalc` 5.12.0 实测：
///
///       | 输入 | 引擎印出来 | 那是什么 |
///       |---|---|---|
///       | `roman(2026)` | `"MMXXVI"` | ✓ 规范写法 |
///       | `roman(3999)` | `"MMMCMXCIX"` | ✓ 规范写法里最大的一个 |
///       | `roman(0)` | **`0`** | ⚠️ **类型都变了**：回的是数字，不是字符串 |
///       | `roman(-1)` | **`"-I"`** | ⚠️ **凭空造了一个不存在的写法**（负数没有罗马数字） |
///       | `roman(4000)` | **`"MMMM"`** | ⚠️ **非规范**：4000 要用上划线（`IV̄`），`MMMM` 不是标准写法 |
///       | `roman(10000)` | **`"10000"`** | ⚠️ **直接放弃**，把输入原样当字符串还回来 |
///       | `roman(3.5)` | **`"VII / II"`** | ⚠️ **编了一套分数写法** |
///
///       后四行正是本仓最反对的那一类：**用户问的是罗马数字，拿回来的是一个看着像答案的东西**。
///       所以这里**不照抄引擎**：规范之外一律 `null`，由调用方照常印"没有答案"。
///
///       **范围判据是规范给的，不是拍的**：罗马数字没有 0，没有负数；标准写法只到 3999
///       （4000 起需要上划线，而那个记号在纯文本里排不出来）。所以定义域是 **1..3999**。
/// English: **integer → Roman numeral.**
///
///          ⚠️ **This is a place where we are more correct than the engine, not a place where "the
///          engine can do it so let's wire it up".** The engine has a same-named function and it
///          **produces plausible-looking wrong values at the boundaries** — measured on host `qalc`
///          5.12.0:
///
///          | input | engine prints | what that is |
///          |---|---|---|
///          | `roman(2026)` | `"MMXXVI"` | ✓ canonical |
///          | `roman(3999)` | `"MMMCMXCIX"` | ✓ the largest canonical form |
///          | `roman(0)` | **`0`** | ⚠️ **the type changed**: a number comes back, not a string |
///          | `roman(-1)` | **`"-I"`** | ⚠️ **a spelling invented out of nothing** (negatives have no Roman numeral) |
///          | `roman(4000)` | **`"MMMM"`** | ⚠️ **non-canonical**: 4000 needs an overline (`IV̄`), `MMMM` is not standard |
///          | `roman(10000)` | **`"10000"`** | ⚠️ **gives up**, handing the input back as a string |
///          | `roman(3.5)` | **`"VII / II"`** | ⚠️ **a fraction notation it made up** |
///
///          The last four are exactly the class this repository rejects: **the user asked for a Roman
///          numeral and got back something that looks like an answer**. So this does **not copy the
///          engine**: anything outside the canon returns `null` and the caller prints "no answer" as
///          usual.
///
///          **The range comes from the canon rather than from a guess**: Roman numerals have no zero and
///          no negatives, and the standard spelling stops at 3999 (4000 upwards needs an overline, a mark
///          plain text cannot set). The domain is therefore **1..3999**.
library;

/// 中文：规范写法的那张表，**从大到小**，含六组减法记法（`CM`/`CD`/`XC`/`XL`/`IX`/`IV`）。
///       贪心取用即是规范写法——这一点由 3999 与 3888 两条钉住（后者是规范里最长的一个）。
/// English: the canonical table, **largest first**, including the six subtractive pairs
///          (`CM`/`CD`/`XC`/`XL`/`IX`/`IV`). Greedy consumption *is* the canonical form — pinned by the
///          3999 and 3888 cases (the latter being the longest canonical spelling).
const List<(int, String)> _romanTable = <(int, String)>[
  (1000, 'M'),
  (900, 'CM'),
  (500, 'D'),
  (400, 'CD'),
  (100, 'C'),
  (90, 'XC'),
  (50, 'L'),
  (40, 'XL'),
  (10, 'X'),
  (9, 'IX'),
  (5, 'V'),
  (4, 'IV'),
  (1, 'I'),
];

/// 中文：**规范写法能表示的整数范围**——两端都包含。见文件头那段（0 与负数没有写法，
///       4000 起要上划线）。
/// English: **the integers the canonical spelling can represent** — both ends inclusive. See the file
///          head (zero and negatives have no spelling; 4000 upwards needs an overline).
const int kRomanMin = 1;
const int kRomanMax = 3999;

/// 中文：整数 → 罗马数字；**不在 `1..3999` 里就回 `null`**（调用方照常印"没有答案"）。
///
///       它**不收 `double`**：`3.5` 没有规范写法，而把浮点放进来就会引出"要不要四舍五入"
///       这个引擎已经答错的问题（它编了一套 `VII / II`）。调用方手里握着的是十进制**文本**，
///       整数性由它自己判——**判据留在能看见原文的那一层**。
/// English: integer → Roman numeral; **outside `1..3999` it returns `null`** (the caller prints "no
///          answer" as usual).
///
///          It **takes no `double`**: `3.5` has no canonical spelling, and letting floats in raises the
///          "do we round" question the engine already answered wrongly (it invented `VII / II`). The
///          caller holds a decimal **text**; integrality is its judgement to make — **the judgement
///          stays on the layer that can see the original text**.
String? toRoman(int value) {
  if (value < kRomanMin || value > kRomanMax) return null;
  final buffer = StringBuffer();
  var rest = value;
  for (final (amount, symbol) in _romanTable) {
    while (rest >= amount) {
      buffer.write(symbol);
      rest -= amount;
    }
  }
  return buffer.toString();
}
