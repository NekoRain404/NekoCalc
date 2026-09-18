import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

void main() {
  double parse(String source, {bool degreeMode = false}) {
    return ExpressionParser(source, degreeMode: degreeMode).parse();
  }

  test('evaluates operator precedence and parentheses', () {
    expect(parse('2+3×4'), 14);
    expect(parse('(2+3)×4'), 20);
    expect(parse('2^3^2'), 512);
    expect(parse('-2^2'), -4);
    expect(parse('(-2)^2'), 4);
    expect(parse('2^-2'), closeTo(0.25, 1e-12));
    expect(parse('2^-2^2'), closeTo(0.0625, 1e-12));
  });

  test('evaluates common scientific functions', () {
    expect(parse('sqrt(16)+log(100)+ln(e)'), closeTo(7, 1e-9));
    expect(parse('abs(-7)+exp(0)'), closeTo(8, 1e-9));
  });

  test('evaluates extended functions', () {
    expect(
        parse('fact(5)+floor(2.9)+ceil(2.1)+round(2.5)'), closeTo(128, 1e-9));
    expect(parse('sinh(0)+cosh(0)+tanh(0)'), closeTo(1, 1e-9));
    expect(parse('cbrt(27)+log2(8)+min(7,3)+max(7,3)+mod(7,3)'),
        closeTo(17, 1e-9));
    expect(parse('ncr(5,2)+npr(5,2)+gcd(24,18)+lcm(4,6)'), closeTo(48, 1e-9));
    expect(parse('root(27,3)+deg(pi)+rad(180)'), closeTo(186.1415926536, 1e-9));
  });

  test('evaluates variadic aggregate functions', () {
    expect(parse('min(7, 3, -2, 4)'), closeTo(-2, 1e-12));
    expect(parse('max(1, 2^3, sqrt(81), 4)'), closeTo(9, 1e-12));
    expect(parse('gcd(84, 126, 210)'), closeTo(42, 1e-12));
    expect(parse('lcm(3, 4, 5, 6)'), closeTo(60, 1e-12));
  });

  test('evaluates postfix factorial notation', () {
    expect(parse('5!'), closeTo(120, 1e-9));
    expect(parse('3! + 4!'), closeTo(30, 1e-9));
    expect(parse('(3+2)!'), closeTo(120, 1e-9));
    expect(parse('2^3!'), closeTo(64, 1e-9));
    expect(parse('-2^3!'), closeTo(-64, 1e-9));
    expect(parse('-3!'), closeTo(-6, 1e-9));
    expect(() => parse('2.5!'), throwsFormatException);
  });

  test('supports degree mode for trigonometry', () {
    expect(parse('sin(30)+cos(60)', degreeMode: true), closeTo(1, 1e-9));
    expect(parse('asin(0.5)', degreeMode: true), closeTo(30, 1e-9));
    expect(
        parse('cot(45)+sec(60)+csc(30)', degreeMode: true), closeTo(5, 1e-9));
    expect(parse('atan2(1,1)', degreeMode: true), closeTo(45, 1e-9));

    // 中文：**以数字结尾的函数名后面跟一个「看起来像千分位」的实参**——`_startsFunctionArgument`
    //       只看 `(` 前面的那个字符是不是字母或 `)`，于是 `atan2(` 被判成「不是函数调用」，
    //       `7,100` 里的逗号被当成千分位剥掉，整条变成 `atan2(7100)`（一个实参）→ `atan(7100)`
    //       → `1.570796`（实测修复前 `1.570655`，因为 `atan2` 单实参时退化成 `atan`）。
    //       正确的读法是两个实参 `7` 与 `100` → `atan(7/100)` = `0.069886…`。
    // English: **a function name ending in a digit followed by an argument that looks like a grouped
    //          number** — `_startsFunctionArgument` only looks at whether the character before `(` is a
    //          letter or `)`, so `atan2(` counts as "not a function call" and the comma in `7,100` is
    //          stripped as a thousands separator, leaving `atan2(7100)` (one argument) → `atan(7100)`.
    //          The correct reading is two arguments `7` and `100` → `atan(7/100)` = `0.069886…`.
    expect(parse('atan2(7,100)'), closeTo(0.0698860016, 1e-9));
    // 中文：第二个实参同样是「看起来像千分位」的形状（`1,234`）——这一条在修复前给
    //       `atan(1234)` = `1.569…`。
    // English: the second argument is the same "looks grouped" shape (`1,234`) — before the fix this
    //          gave `atan(1234)` = `1.569…`.
    expect(parse('atan2(1,234)'), closeTo(0.0042734783, 1e-9));
    // 中文：**同一个形状，正确的读法却相反**——`log2` 只吃一个实参，所以 `1,024` 在这里必须
    //       读成千分位（`log2(1024)` = 10），而不是两个实参。判据因此不能是「名字以数字结尾」，
    //       只能是**这个函数接不接受两个以上实参**（解析器自己的参数表就是权威）。
    //       `2(1,234)` 更直白：括号前面根本不是函数，逗号是千分位 → 2468。
    // English: **the same shape, the opposite correct reading** — `log2` takes one argument, so
    //          `1,024` here has to read as a thousands separator (`log2(1024)` = 10), not as two
    //          arguments. The criterion therefore cannot be "the name ends in a digit"; it has to be
    //          **whether this function accepts two or more arguments** (the parser's own argument
    //          table is the authority). `2(1,234)` is starker still: there is no function before the
    //          bracket at all, the comma is a thousands separator → 2468.
    expect(parse('log2(1,024)'), closeTo(10, 1e-9));
    expect(parse('2(1,234)'), closeTo(2468, 1e-9));
    expect(parse('12(345,678)'), closeTo(4148136, 1e-9));
  });

  test('refuses trigonometric poles in degree mode', () {
    // 中文：**角度制下的奇点：那里没有值，不是「值很大」。** `tan`/`sec` 在 90° 的奇数倍没有定义
    //       （`cos` 在那里恰好是 0），`cot`/`csc` 在 180° 的整数倍没有定义（`sin` 在那里是 0）。
    //
    //       | 表达式 | 参考实现（`qalc -set "angle deg"`） | 本应用（修复前） |
    //       |---|---|---|
    //       | `tan(90)` | 拒绝（原样印回 `tan(90.00000000)`） | **1.6331239353195370e16** |
    //       | `tan(270)` | 拒绝 | **5.443746451065123e15** |
    //       | `tan(-90)` | 拒绝 | **-1.6331239353195370e16** |
    //       | `sec(90)` | `1 / 0` | **1.6331239353195370e16** |
    //       | `sec(270)` | `1 / 0` | **-5.443746451065123e15** |
    //       | `csc(0)` | `1 / 0` | 拒绝（`Infinity`，唯一本来就对的那一格） |
    //       | `csc(180)` | `1 / 0` | **8.165619676597685e15** |
    //       | `csc(360)` | `1 / 0` | **-4.0828098382988425e15** |
    //       | `cot(0)` | `1 / 0` | 拒绝（`Infinity`，同上） |
    //       | `cot(180)` | `−1 / 0` | **-8.165619676597685e15** |
    //       | `cot(360)` | `1 / 0` | **-4.0828098382988425e15** |
    //
    //       那两格之所以一直是对的，只是因为 `math.tan(0)` 是**精确的** 0——不是因为判据对；
    //       其余每一格都是「一个不存在的值被答成了一个有限数」。
    // English: **Trigonometric poles in degree mode: the value does not exist there — this is not "a
    //          big value".** `tan`/`sec` are undefined at odd multiples of 90° (`cos` is exactly 0
    //          there) and `cot`/`csc` at integer multiples of 180° (`sin` is 0 there).
    //
    //          | expression | reference (`qalc -set "angle deg"`) | this app (before the fix) |
    //          |---|---|---|
    //          | `tan(90)` | refused (prints `tan(90.00000000)` back) | **1.6331239353195370e16** |
    //          | `tan(270)` | refused | **5.443746451065123e15** |
    //          | `tan(-90)` | refused | **-1.6331239353195370e16** |
    //          | `sec(90)` | `1 / 0` | **1.6331239353195370e16** |
    //          | `sec(270)` | `1 / 0` | **-5.443746451065123e15** |
    //          | `csc(0)` | `1 / 0` | refused (`Infinity` — the one cell that was already right) |
    //          | `csc(180)` | `1 / 0` | **8.165619676597685e15** |
    //          | `csc(360)` | `1 / 0` | **-4.0828098382988425e15** |
    //          | `cot(0)` | `1 / 0` | refused (`Infinity`, as above) |
    //          | `cot(180)` | `−1 / 0` | **-8.165619676597685e15** |
    //          | `cot(360)` | `1 / 0` | **-4.0828098382988425e15** |
    //
    //          Those two cells were only ever right because `math.tan(0)` is an **exact** 0 — not
    //          because the judgement was right; every other cell answered a question that has no
    //          answer with a finite number.
    const poles = <String>[
      'tan(90)', 'tan(270)', 'tan(-90)', 'tan(450)', 'tan(-270)', 'tan(810)',
      'sec(90)', 'sec(270)', 'sec(-90)', 'sec(450)',
      'cot(0)', 'cot(180)', 'cot(360)', 'cot(-180)', 'cot(540)',
      'csc(0)', 'csc(180)', 'csc(360)', 'csc(-180)', 'csc(540)',
    ];
    for (final source in poles) {
      expect(parse(source, degreeMode: true).isFinite, isFalse,
          reason: '$source 在角度制下没有值，返回的必须是非有限数（而不是一个看起来像答案的数）');
    }
  });

  test('a pole poisons the whole expression instead of leaving a number', () {
    // 中文：**NaN 的传染性是这条修法的一半。** 奇点若只是「一个大数」，`0*tan(90)` 会得到 0、
    //       `tan(90)-tan(90)` 会得到 0——两个都是对一个没有值的问题的「答案」。判据下在实参上、
    //       返回 NaN，整条表达式于是连同外层一起变成非有限，与 `sqrt(-1)` 那种传染同一个道理。
    // English: **NaN's contagion is half of this fix.** If a pole were merely "a large number", then
    //          `0*tan(90)` would be 0 and `tan(90)-tan(90)` would be 0 — both an "answer" to a
    //          question that has none. Judging the argument and returning NaN makes the whole
    //          expression non-finite along with its neighbours, the same way `sqrt(-1)` spreads.
    for (final source in <String>[
      'tan(90)-tan(90)',
      '0*tan(90)',
      'tan(90)*0',
      'tan(90)+1',
      'cot(180)+1',
      '1/tan(90)',
      'sqrt(tan(90))',
      'abs(tan(90))',
      '2^tan(90)',
    ]) {
      expect(parse(source, degreeMode: true).isFinite, isFalse, reason: source);
    }
  });

  test('keeps every neighbour of a pole computing', () {
    // 中文：**判据要精确到「实参正好是 90°/180° 的整数倍」，宽一格就变成误伤。** 下面左边这些
    //       挨着奇点却没有一个是奇点；右边那两个是**反例**——`tan` 在 90° 的**偶数**倍、`cot` 在
    //       180° 的**非整数**倍都有值，所以「奇数倍」那半句不是修饰，是判据本身。
    // English: **The judgement must be exact — "the argument is exactly an integer multiple of
    //          90°/180°"; one step looser and it becomes friendly fire.** Everything on the left sits
    //          next to a pole and none of them is one; the two on the right are **counter-examples**:
    //          `tan` has a value at **even** multiples of 90° and `cot` at **non-integer** multiples of
    //          180°, so the "odd" half is not decoration — it is the judgement.
    expect(parse('tan(89.9)', degreeMode: true), closeTo(572.9572133543032, 1e-9));
    expect(parse('tan(90.0001)', degreeMode: true),
        closeTo(-572957.795144547, 1e-9));
    expect(parse('tan(90.5)', degreeMode: true),
        closeTo(-114.58865012931172, 1e-12));
    expect(parse('cot(180.5)', degreeMode: true),
        closeTo(114.58865012931253, 1e-12));
    expect(parse('tan(89.99999999999999)', degreeMode: true).isFinite, isTrue,
        reason: '离 90 最近的那个非 90 的 double 不是奇点');
    expect(parse('tan(90.00000000000001)', degreeMode: true).isFinite, isTrue);
    expect(parse('cot(45)', degreeMode: true), closeTo(1, 1e-12));
    expect(parse('sec(0)', degreeMode: true), closeTo(1, 1e-12));
    expect(parse('csc(90)', degreeMode: true), closeTo(1, 1e-12));
    expect(parse('tan(180)', degreeMode: true), closeTo(0, 1e-12),
        reason: '90° 的偶数倍：tan 有值');
    expect(parse('tan(360)', degreeMode: true), closeTo(0, 1e-12));
    expect(parse('cot(90)', degreeMode: true), closeTo(0, 1e-12),
        reason: '180° 的非整数倍：cot 有值');
    expect(parse('sec(180)', degreeMode: true), closeTo(-1, 1e-12));
    expect(parse('csc(270)', degreeMode: true), closeTo(-1, 1e-12));
    expect(parse('tan(1e15)', degreeMode: true).isFinite, isTrue,
        reason: '1e15 不是 90 的整数倍');
    expect(parse('1e300', degreeMode: true), 1e300,
        reason: '合法的大数不受这条判据影响');
  });

  test('the multiplicity test is exact, not a double round-trip', () {
    // 中文：**判据落在整数域里，不在 double 里。** `90*2^60` = 1.0376293541461623e20 是一个**精确**
    //       的 double，也**精确**地是 180 的整数倍（= 180×2^59），所以 `cot` 在那里没有值；同一个
    //       角度是 90 的**偶数**倍，`tan` 在那里有值。写成 `degrees / 180 * 180 == degrees` 这种
    //       double 往返判定会在更大的数上自己转回原值（实测 `(1e300/90)*90 == 1e300` 是 `true`，
    //       而 1e300 根本不是 90 的整数倍），把合法的大角度误判成奇点——所以这里是 [BigInt] 整除。
    // English: **The judgement lives in the integer domain, not in doubles.** `90*2^60` =
    //          1.0376293541461623e20 is an **exact** double and exactly a multiple of 180 (= 180×2^59),
    //          so `cot` has no value there; the same angle is an **even** multiple of 90, so `tan`
    //          does have one. Written as a double round-trip (`degrees / 180 * 180 == degrees`) the
    //          test lands back on itself for large values (measured: `(1e300/90)*90 == 1e300` is
    //          `true`, while 1e300 is not a multiple of 90 at all) and would call a legitimate large
    //          angle a pole — hence [BigInt] division here.
    expect(parse('cot(90*2^60)', degreeMode: true).isFinite, isFalse,
        reason: '90*2^60 是 180 的整数倍');
    expect(parse('tan(90*2^60)', degreeMode: true).isFinite, isTrue,
        reason: '但它是 90 的偶数倍，tan 在那里有值');
  });

  test('a non-finite argument stays a non-finite result, not a crash', () {
    // 中文：`tan(1/0)` 的实参是 `Infinity`——奇点判据必须**先**放它过去（`BigInt.from(Infinity)`
    //       会抛 `ArgumentError`），再由 `math.tan` 给出 NaN。两条路的结论都是「结果不是有限数值」，
    //       但抛异常会让屏幕上是「表达式错误」——那是退步。
    // English: `tan(1/0)` passes `Infinity` — the pole test has to step aside **first**
    //          (`BigInt.from(Infinity)` throws `ArgumentError`) and let `math.tan` produce the NaN.
    //          Both roads end at "结果不是有限数值", but an exception would put "表达式错误" on screen,
    //          which is a regression.
    for (final source in <String>[
      'tan(1/0)',
      'tan(-1/0)',
      'sec(1/0)',
      'cot(1/0)',
      'csc(1/0)',
    ]) {
      expect(() => parse(source, degreeMode: true), returnsNormally,
          reason: source);
      expect(parse(source, degreeMode: true).isFinite, isFalse, reason: source);
    }
  });

  test('radian mode is untouched: 90 is an ordinary number there', () {
    // 中文：**同一个输入在 RAD 下必须一字不改。** `tan(90)` 在弧度制里是一个普通的数（−1.9952…），
    //       那个 90 没有任何特殊含义；RAD 真正的奇点是 π/2，而 `math.pi/2` 只是**离** π/2 最近的
    //       那个 double——`tan` 在它上面有值，拒绝它才是答错。两种模式因此不可能共用一条判据。
    // English: **The same input must not move a digit under RAD.** `tan(90)` is an ordinary number in
    //          radians (−1.9952…) and that 90 carries no special meaning; RAD's real poles are at π/2,
    //          and `math.pi/2` is merely the double **nearest** π/2 — `tan` has a value there, so
    //          refusing it would be the wrong answer. The two modes cannot share one judgement.
    expect(parse('tan(90)'), closeTo(-1.995200412208242, 1e-12));
    expect(parse('tan(90)').isFinite, isTrue);
    expect(parse('tan(pi/2)').isFinite, isTrue,
        reason: 'math.pi/2 不是 π/2，它上面有值——这正是不按大小一刀切的理由');
    expect(parse('cot(0)').isFinite, isFalse, reason: 'RAD 下本来就是 Infinity');
    expect(parse('1/tan(0)').isFinite, isFalse);
  });

  test('a function alias reads its comma the same way its canonical name does', () {
    // 中文：**别名与规范名必须读成同一个东西，逗号也一样。** 实参个数表写的是**归一化之后**的
    //       名字（`ncr`/`npr`/`log`），而 [_startsFunctionArgument] 读的是**归一化之前**的文本
    //       ——别名替换跑在逗号归一化之后。于是同一颗键的两种拼法给出两个不同的值：
    //
    //       | 表达式 | 逗号读成 | 值 |
    //       |---|---|---|
    //       | `ncr(1,234)` | 分隔符 → `ncr(1, 234)` | 0（挑不出 234 个） |
    //       | `c(1,234)` / `C(1,234)` | 千分位 → `c(1234)` | **1234** ✗ |
    //       | `log(1,024)` | 分隔符 → 底数为 1024 | 0（log₁₀₂₄1） |
    //       | `lg(1,024)` / `log10(1,024)` | 千分位 → `lg(1024)` | **3.0103** ✗ |
    //
    //       大小写是同一个缺陷的另一半：这段文本此时**还没有经过 `.toLowerCase()`**
    //       （`_normalizeGroupedNumberSeparators` 跑在它前面），所以 `C`/`NCR` 也进不了那张表。
    // English: **an alias has to read the comma the way its canonical name does.** The argument table
    //          is written in **post-normalisation** names (`ncr`/`npr`/`log`) while
    //          [_startsFunctionArgument] reads the **pre-normalisation** text — the alias replacement
    //          runs after the comma normalisation. Two spellings of the same key therefore gave two
    //          different values:
    //
    //          | expression | comma read as | value |
    //          |---|---|---|
    //          | `ncr(1,234)` | a separator → `ncr(1, 234)` | 0 (cannot choose 234 of 1) |
    //          | `c(1,234)` / `C(1,234)` | a thousands separator → `c(1234)` | **1234** ✗ |
    //          | `log(1,024)` | a separator → base 1024 | 0 (log₁₀₂₄1) |
    //          | `lg(1,024)` / `log10(1,024)` | a thousands separator → `lg(1024)` | **3.0103** ✗ |
    //
    //          Case is the other half of the same defect: the text has **not** been through
    //          `.toLowerCase()` yet at this point (`_normalizeGroupedNumberSeparators` runs before it),
    //          so `C`/`NCR` do not reach the table either.
    expect(parse('ncr(1,234)'), closeTo(0, 1e-9));
    expect(parse('c(1,234)'), closeTo(0, 1e-9));
    expect(parse('C(1,234)'), closeTo(0, 1e-9));
    expect(parse('NCR(1,234)'), closeTo(0, 1e-9));
    expect(parse('log(1,024)'), closeTo(0, 1e-9));
    expect(parse('lg(1,024)'), closeTo(0, 1e-9));
    expect(parse('log10(1,024)'), closeTo(0, 1e-9));
    // 中文：同一张表的**反例**照旧——`log2` 只吃一个实参，逗号仍是千分位；括号前面不是函数也一样。
    // English: the **counter-examples** for the same table still hold — `log2` takes one argument, so
    //          its comma is still a thousands separator, and so is one before a bracket with no
    //          function in front of it.
    expect(parse('log2(1,024)'), closeTo(10, 1e-9));
    expect(parse('2(1,234)'), closeTo(2468, 1e-9));
  });

  test('normalizes common pasted function aliases', () {
    expect(parse('lg(100)+arcsin(0.5)'), closeTo(2 + math.asin(0.5), 1e-9));
    expect(parse('arccos(0.5)+arctan(1)'),
        closeTo(math.acos(0.5) + math.atan(1), 1e-9));
    expect(parse('∛27 + 2∛8'), closeTo(7, 1e-9));
  });

  test('normalizes calculator style bare function arguments', () {
    expect(parse('sqrt 9 + log 100'), closeTo(5, 1e-9));
    expect(parse('sin 30 + cos 60', degreeMode: true), closeTo(1, 1e-9));
    expect(parse('ln e + abs -5 + exp 0'), closeTo(7, 1e-9));
    expect(parse('lg 100 + arcsin 0.5'), closeTo(2 + math.asin(0.5), 1e-9));
    expect(parse('log2 8 + floor 2.9 + ceil 2.1'), closeTo(8, 1e-9));
    expect(parse('sqrt 25% + log 1e3%'), closeTo(1.5, 1e-9));
    expect(parse('sin 90°'), closeTo(1, 1e-9));
  });

  test('normalizes displayed math symbols back into parser expressions', () {
    expect(parse('log₁₀(100)+log₂(8)'), closeTo(5, 1e-9));
    expect(parse('e^(ln(5))+1.2×10³'), closeTo(1205, 1e-9));
    expect(parse('³√(27)+2⁴√16'), closeTo(7, 1e-9));
    expect(parse('|-5|+(5)!+C(5,2)+P(5,2)'), closeTo(155, 1e-9));
  });

  test('normalizes common latex expression input', () {
    expect(parse(r'\frac{1}{2} + \sqrt{9}'), closeTo(3.5, 1e-12));
    expect(parse(r'\sqrt[3]{27} + \sin(\pi/2)'), closeTo(4, 1e-12));
    expect(parse(r'\left(2+3\right)\cdot 4'), closeTo(20, 1e-12));
    expect(parse(r'\operatorname{max}{(1,2)}'), closeTo(2, 1e-12));
  });

  test('normalizes common mathematical constants', () {
    expect(parse('τ'), closeTo(2 * math.pi, 1e-12));
    expect(parse('tau / pi'), closeTo(2, 1e-12));
    expect(parse('φ^2 - φ'), closeTo(1, 1e-12));
    expect(parse(r'\varphi + \phi'), closeTo(1 + math.sqrt(5), 1e-12));
    expect(parse('1 / ∞'), closeTo(0, 1e-12));
  });

  test('normalizes indexed root notation', () {
    expect(parse('√[3](27)'), closeTo(3, 1e-9));
    expect(parse('√[4]16'), closeTo(2, 1e-9));
    expect(parse('2√[3](8+19)'), closeTo(6, 1e-9));
  });

  test('normalizes pasted math notation and implicit multiplication', () {
    expect(parse('２（３＋４）'), closeTo(14, 1e-9));
    expect(parse('2sin(rad(90)) + 3π'), closeTo(11.4247779608, 1e-9));
    expect(
        parse('2τ + 3φ'), closeTo(4 * math.pi + 3 * 1.618033988749895, 1e-9));
    expect(parse('τ(1+1)'), closeTo(4 * math.pi, 1e-9));
    expect(parse('2πsin(π/2)'), closeTo(2 * math.pi, 1e-9));
    expect(parse('πe + φτ'),
        closeTo(math.pi * math.e + 1.618033988749895 * 2 * math.pi, 1e-9));
    expect(parse('(2+3)(4+1)'), closeTo(25, 1e-9));
    expect(parse('√(16)+2²+3³'), closeTo(35, 1e-9));
    expect(parse('√9+√π'), closeTo(3 + math.sqrt(math.pi), 1e-9));
    expect(parse('50％ + 90°'), closeTo(2.0707963268, 1e-9));
    expect(parse('½ + ¼ + ¾'), closeTo(1.5, 1e-12));
    expect(parse('2½ + 1⅓'), closeTo(3.8333333333, 1e-9));
  });

  test('normalizes calculator style number formatting', () {
    expect(parse('1,200 + 3,400.5'), closeTo(4600.5, 1e-9));
    expect(parse('1_000 + 2_500.5'), closeTo(3500.5, 1e-9));
    expect(parse('1_000e-3 + 1e1_0'), closeTo(10000000001, 1e-3));
    expect(parse('1,200×50%'), closeTo(600, 1e-9));
    expect(parse('6÷2 + 4×3'), closeTo(15, 1e-9));
    expect(parse('max(1,200)'), closeTo(200, 1e-9));
    expect(() => parse('12,34 + 1'), throwsFormatException);
    expect(() => parse('1__2 + 1'), throwsFormatException);
    expect(() => parse('1_.2 + 1'), throwsFormatException);
  });

  test('normalizes pasted calculator result annotations', () {
    expect(parse('6*7='), closeTo(42, 1e-9));
    expect(parse('6*7 = 42'), closeTo(42, 1e-9));
    expect(parse('sqrt(81) ≈ 9'), closeTo(9, 1e-9));
    expect(parse('ans = 1,234.5'), closeTo(1234.5, 1e-9));
    expect(parse('表达式: 2π\n结果: 6.283185'), closeTo(2 * math.pi, 1e-9));
    expect(() => parse('1=1'), throwsFormatException);
  });

  test('parses programming radix number literals', () {
    expect(parse('0xff + 0b1010 + 0o10'), closeTo(273, 1e-9));
    expect(parse('0xFF_FF / 0b1111'), closeTo(4369, 1e-9));
    expect(parse('2(0x10 + 1)'), closeTo(34, 1e-9));
    expect(parse('0x10π'), closeTo(16 * math.pi, 1e-9));
    expect(() => parse('0x + 1'), throwsFormatException);
    expect(() => parse('0x_FF + 1'), throwsFormatException);
    expect(() => parse('0xFF_ + 1'), throwsFormatException);
    expect(() => parse('0xF__F + 1'), throwsFormatException);
  });

  test('normalizes scientific notation variants and superscripts', () {
    expect(parse('1.2×10^3 + 4'), closeTo(1204, 1e-9));
    expect(parse('2.5·10⁻³'), closeTo(0.0025, 1e-12));
    expect(parse('3x10⁺2'), closeTo(300, 1e-9));
    expect(parse('2⁻³'), closeTo(0.125, 1e-12));
    expect(parse('10⁶ + 1'), closeTo(1000001, 1e-9));
  });

  test('throws on incomplete expressions', () {
    expect(() => parse('sqrt(16'), throwsFormatException);
    expect(() => parse('2+'), throwsFormatException);
    expect(() => parse('min()'), throwsFormatException);
    expect(() => parse('sin()'), throwsFormatException);
    expect(() => parse('atan2(1,2,3)'), throwsFormatException);
  });
}
