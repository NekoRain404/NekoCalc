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

  group('度数记号 `°`：值是「当前角度单位下的这个角度」，两种模式都不再被换算两次', () {
    // 中文：**修复前的错值（设备 `d87f1aa3`，DEG）：** `sin(30°)` = 0.009138395397176044、
    //       `sin(90°)` = 0.02741213359204429、`tan(45°)` = 0.013708642534394055。归一化无条件把
    //       `30°` 写成 `rad(30)`（`rad` 是「度 → 弧度」换算、与模式无关，恒为 0.5235987755982988），
    //       而 DEG 的三角函数**再乘一次 π/180**——同一个角度被换算两次。RAD 只换算一次，所以
    //       RAD 一直是对的：那正是这条错值只在 DEG 下出现的原因。
    //
    //       **参考实现**（宿主 `qalc` 5.12.0，`-set "angle deg"` 与 `-set "angle rad"` 各测一遍）：
    //       `sin(30°)`/`sin(90°)`/`tan(45°)` 两种角度模式下都是 0.5 / 1 / 1——`°` 是一个显式单位，
    //       与模式无关。下面这六条因此**两种模式断同一个数**。
    //
    //       **判据的形状**：`°` 是「这个数是若干度」这句话本身，而本应用把角度数值写在当前角度
    //       单位下（DEG 下 `sin(30)` = 0.5、`asin(0.5)` = 30；RAD 下分别是 −0.988… 与
    //       0.5235987755982988）。于是 `30°` 在 DEG 下是 **30**（三角函数随后按度读它）、
    //       RAD 下是 **0.5235987755982988**（那边不再换算）——两条路上的 `sin(30°)` 都是 0.5。
    // English: **the wrong value before the fix (device `d87f1aa3`, DEG):** `sin(30°)` =
    //          0.009138395397176044, `sin(90°)` = 0.02741213359204429, `tan(45°)` =
    //          0.013708642534394055. Normalisation wrote `30°` as `rad(30)` unconditionally (`rad` is
    //          a degrees → radians conversion independent of the mode, always 0.5235987755982988) and
    //          DEG's trig multiplied **again** by π/180 — one angle converted twice. RAD converts once,
    //          which is exactly why that wrong value only ever appeared under DEG.
    //
    //          **The reference** (host `qalc` 5.12.0, measured with `-set "angle deg"` and again with
    //          `-set "angle rad"`): `sin(30°)`/`sin(90°)`/`tan(45°)` are 0.5 / 1 / 1 in **both** angle
    //          modes — `°` is an explicit unit and does not care about the mode. The six assertions
    //          below therefore assert one number in both modes.
    //
    //          **The shape of the judgement**: `°` is the sentence "this number is so many degrees",
    //          and this app writes an angle's value in the current angle unit (under DEG `sin(30)` =
    //          0.5 and `asin(0.5)` = 30; under RAD those are −0.988… and 0.5235987755982988). So `30°`
    //          is **30** under DEG (trig then reads it in degrees) and **0.5235987755982988** under RAD
    //          (that side does not convert again) — and `sin(30°)` is 0.5 on both roads.
    test('正弦、余弦、正切上的 `°`：两种模式给同一个数（参考实现的两个模式也一样）', () {
      for (final degreeMode in <bool>[false, true]) {
        final where = degreeMode ? 'DEG' : 'RAD';
        expect(parse('sin(30°)', degreeMode: degreeMode), closeTo(0.5, 1e-12),
            reason: '$where：`sin(30°)` 是 0.5——任何定义下都是（参考实现两个模式都是 0.5）');
        expect(parse('sin(90°)', degreeMode: degreeMode), closeTo(1, 1e-12),
            reason: '$where：`sin(90°)` = 1');
        expect(parse('tan(45°)', degreeMode: degreeMode), closeTo(1, 1e-12),
            reason: '$where：`tan(45°)` = 1（修复前 DEG 下是 0.013708642534394055）');
        expect(parse('cos(0°)', degreeMode: degreeMode), closeTo(1, 1e-12));
        expect(parse('sin(0°)', degreeMode: degreeMode), closeTo(0, 1e-12));
        // 中文：**嵌套同样成立**，这是「值按模式给」而不是「只在顶层做特判」的证据：
        //       `2*30°` 是 60 度这个角度，两种模式下的 sin 都是 sin(60°) = 0.8660254037844386。
        // English: **nesting holds too**, and that is the evidence that this is "the value belongs to
        //          the mode" rather than a special case at the top level: `2*30°` is the angle 60
        //          degrees, and `sin` of it is sin(60°) = 0.8660254037844386 in both modes.
        expect(parse('sin(2*30°)', degreeMode: degreeMode),
            closeTo(0.8660254037844386, 1e-12),
            reason: '$where：`2*30°` 是 60 度这个角度，不是两个数各自换算');
        expect(parse('sin(30°+15°)', degreeMode: degreeMode),
            closeTo(0.7071067811865476, 1e-12),
            reason: '$where：两个带 `°` 的角度相加，仍然是一个角度');
      }
    });

    test('`30°` 单用：DEG 下是 30，RAD 下是它的弧度值', () {
      // 中文：**这一条是上面那一组的另一半，也是它成立的原因。** 角度数值写在当前单位下，
      //       所以 `30°` 在 DEG 下就是 30——这正是 DEG 下三角函数「按度读实参」的反面。
      //       RAD 下它是 1.5707963267948966/3 = 0.5235987755982988，与修复前逐字相同。
      //       参考实现在两种模式下的 `30°` 都印成 `0.5235987756 rad`——它**带着单位印**，
      //       所以那两行说的是同一个角度，而不是同一个数；本应用印不了单位，只能印当前单位下的数。
      // English: **this is the other half of the group above, and the reason it holds.** An angle's
      //          value is written in the current unit, so `30°` is 30 under DEG — the mirror image of
      //          "trig reads its argument in degrees" there. Under RAD it is
      //          1.5707963267948966/3 = 0.5235987755982988, byte for byte what it was before the fix.
      //          The reference prints `30°` as `0.5235987756 rad` in both modes — it prints **with the
      //          unit**, so those two lines name one angle rather than one number; this app cannot print
      //          a unit and can only print the number in the current unit.
      expect(parse('30°', degreeMode: true), closeTo(30, 1e-12));
      expect(parse('30°', degreeMode: false), closeTo(0.5235987755982988, 1e-12));
      expect(parse('30°+30°', degreeMode: true), closeTo(60, 1e-12),
          reason: 'DEG 下两个 30 度的角相加是 60 度');
      expect(parse('30°+30°', degreeMode: false),
          closeTo(1.0471975511965976, 1e-12),
          reason: 'RAD 下同一个角度是 1.0471975511965976 弧度（修复前就是这个数）');
      // 中文：**`20％ + 90°` 在 RAD 下与修复前逐字相同**（0.2 + π/2）——这条式子原来是
      //       `normalizeExpressionInput` 那一组里的期望值，这里留住它，并在 DEG 下补上另一半。
      // English: **`20%+90°` under RAD is byte for byte what it was** (0.2 + π/2) — this expression
      //          already had an expectation in the normalisation group, kept here, with the DEG half
      //          added.
      expect(parse('20%+90°', degreeMode: false),
          closeTo(0.2 + math.pi / 2, 1e-12));
      expect(parse('20%+90°', degreeMode: true), closeTo(90.2, 1e-12));
    });

    test('归一化的文本不随角度模式变化：`30°` 一律写成 `degangle(30)`', () {
      // 中文：**这一条钉的是「为什么写成一个名字」那半个判据。** 按模式改写文本（DEG 写成 `30`、
      //       RAD 写成 `rad(30)`）会让归一化带上角度模式，而它有七个消费者，看到的必须是**同一个
      //       字符串**（修复轮 8、9）；引擎那条路更危险——RAD 文本含 `rad`（翻译器拒绝，引擎一次
      //       都不被问）而 DEG 文本是 `sin(30)`（翻译得过去），同一句输入会按模式走两个权威。
      //       写成一个名字之后文本与模式无关，模式只出现在求值那一处（`ExpressionParser.degreeMode`）。
      //       `degangle` 是**应用自己语言里的名字**：不在键位/面板能插的名单里，引擎没有它的写法
      //       （词表那一行 `engineKnowsThisName: false`），所以含 `°` 的表达式照旧一次都不送去
      //       让引擎猜——与修复前那条路逐字相同。
      // English: **this pins the other half of "why one name".** Rewriting the text by mode (`30`
      //          under DEG, `rad(30)` under RAD) would put the angle mode inside normalisation, and
      //          its seven consumers must see **one string** (fix rounds 8 and 9). The engine route is
      //          the sharper hazard: the RAD text contains `rad` (the translator refuses it, so the
      //          engine is never asked) while the DEG text is `sin(30)` (which translates) — one input
      //          would reach two different authorities depending on a setting. With one name the text
      //          is mode-independent and the mode appears only where evaluation happens
      //          (`ExpressionParser.degreeMode`). `degangle` is **a name in this app's own language**:
      //          no key or sheet inserts it, the engine has no spelling for it (its vocabulary row is
      //          `engineKnowsThisName: false`), so an expression containing `°` is still never sent to
      //          the engine to guess at — byte for byte the route it took before the fix.
      for (final source in <String>[
        '30°',
        'sin(30°)',
        'sin 90°',
        '2 30°',
        '(30°+15°)*2',
      ]) {
        final rad = ExpressionParser(source, degreeMode: false);
        final deg = ExpressionParser(source, degreeMode: true);
        expect(deg.text, rad.text,
            reason: '`$source`：归一化的文本只由输入决定，不由角度模式决定');
        expect(rad.text, contains('degangle('),
            reason: '`$source`：`°` 一律写成内部名字 `degangle(N)`');
      }
      expect(ExpressionParser('sin(30°)', degreeMode: true).text,
          'sin(degangle(30))');
      expect(ExpressionParser('30°', degreeMode: true).text, 'degangle(30)');
      // 中文：**幂等**——把归一化之后的文本再喂一次，结果不变（`degangle` 在函数名表里，
      //       所以第二遍的隐式乘法/别名那几步认得它）。
      // English: **idempotent** — feeding the normalised text back in changes nothing (`degangle` is
      //          in the function-name table, so the second pass's implicit-multiplication and alias
      //          steps recognise it).
      final once = ExpressionParser('2 30°+sin(45°)', degreeMode: true).text;
      expect(ExpressionParser(once, degreeMode: true).text, once);
    });

    test('用户自己写的 `rad(...)`/`deg(...)` 一个字节都没变', () {
      // 中文：**`°` 走的是内部名字，不是 `rad`。** 这两个函数是应用自己的换算器（HiPER 的
      //       `►RAD`/`►DEG`）：`rad(x)` 是「x 度，换成弧度」，`deg(x)` 是「x 弧度，换成度」，
      //       两者都与角度模式无关。所以 DEG 下 `sin(rad(30))` 是「把一个**弧度值**交给按度读实参的
      //       三角函数」——实参 0.5235987755982988 被当作度，0.009138395397176044。这一条**不是**
      //       被修掉的那个错值的残留：错值在 `30°` 那条路上（`°` 曾经被改写成 `rad(...)`，
      //       于是两者在文本上无法区分），而现在两者是不同的名字、各有各的定义。要让一个弧度值
      //       进 DEG 的三角函数，应用自己的写法是先换算：`sin(deg(0.5235987755982988))` = 0.5。
      // English: **`°` travels under an internal name, not under `rad`.** Those two functions are this
      //          app's own converters (HiPER's `►RAD`/`►DEG`): `rad(x)` is "x degrees, in radians" and
      //          `deg(x)` is "x radians, in degrees", both independent of the angle mode. So under DEG
      //          `sin(rad(30))` hands a **radian value** to a trig function that reads its argument in
      //          degrees — 0.5235987755982988 read as degrees, 0.009138395397176044. That is **not** a
      //          leftover of the bug that was fixed: the bug lived on the `°` road (`°` used to be
      //          rewritten to `rad(...)`, which made the two indistinguishable as text), and the two
      //          are now different names with different definitions. To feed a radian value into DEG's
      //          trig, this app's own spelling is to convert first:
      //          `sin(deg(0.5235987755982988))` = 0.5.
      expect(parse('rad(30)', degreeMode: true), closeTo(0.5235987755982988, 1e-12));
      expect(parse('rad(30)', degreeMode: false), closeTo(0.5235987755982988, 1e-12));
      expect(parse('deg(0.5235987755982988)', degreeMode: true), closeTo(30, 1e-9));
      expect(parse('sin(rad(30))', degreeMode: true),
          closeTo(0.009138395397176044, 1e-15),
          reason: 'DEG 下把弧度值交给按度读实参的 sin：应用自己的 `rad` 定义没变，这一条也是');
      expect(parse('sin(rad(30))', degreeMode: false), closeTo(0.5, 1e-12));
      expect(parse('sin(deg(0.5235987755982988))', degreeMode: true),
          closeTo(0.5, 1e-12),
          reason: '要按 DEG 的读法喂一个弧度值，应用自己的写法是先用 `deg(...)` 换成度');
    });
  });

  test('a function alias reads its comma the same way its canonical name does', () {    // 中文：**别名与规范名必须读成同一个东西，逗号也一样。** 实参个数表写的是**归一化之后**的
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

  test('方程里的等号不再被当成结果注解剥掉（不闭合就不剥）', () {
    // 中文：**这一条钉的是一个静默错值。** 剥结果注解那条规则只看「右边是不是数字」，
    //       不看左边有没有自由变量，于是把**方程**一起吃掉了：
    //
    //           粘贴 `2x+1=7`   → 屏幕上是 `2x+1=7`，送进引擎的是 `2x+1`
    //           粘贴 `x^2-4=0`  → 屏幕上是 `x^2-4=0`，送进引擎的是 `x^2-4`
    //
    //       **用户看着一个方程，拿到的是另一个式子的值。** 判据是「左边闭不闭合」：
    //       `x` 是自由变量，`2x+1` **不可能**等于 7，所以那个 `= 7` 从来就不是「这个算式的结果」。
    //
    //       **修完之后方程不会被算错，而是被如实拒绝**（解析器读不懂 `=`）——本项目一贯的取舍：
    //       **错值比错误坏**。
    // English: **this pins a silent wrong value.** The result-annotation rule looked only at whether
    //          the right side is a number and never at whether the left side has a free variable, so it
    //          swallowed **equations** whole:
    //
    //              paste `2x+1=7`   -> the screen reads `2x+1=7`, the engine is handed `2x+1`
    //              paste `x^2-4=0`  -> the screen reads `x^2-4=0`, the engine is handed `x^2-4`
    //
    //          **The user looks at an equation and gets another expression's value.** The criterion is
    //          whether the left side is closed: `x` is a free variable and `2x+1` **cannot** equal 7,
    //          so that `= 7` was never "this sum's result".
    //
    //          **After the fix an equation is not mis-computed but honestly refused** (the parser
    //          cannot read `=`) — this project's standing trade: **a wrong value is worse than an
    //          error.**
    for (final equation in <String>['2x+1=7', 'x^2-4=0', '3y=12', 'y^2=9']) {
      expect(ExpressionParser.normalizeExpressionInput(equation), equation,
          reason: '`$equation` 的等号被当成结果注解剥掉了——左边有自由变量，它不闭合');
      expect(() => parse(equation), throwsFormatException,
          reason: '`$equation` 应当被如实拒绝，而不是算成别的式子');
    }

    // 中文：**刻意避开了带角度的例子。** `sin(90) = 1` 看着更自然，但它**依赖角度模式**
    //       （这个测试上下文是弧度，`sin(90)` 是 0.894 不是 1）——**那是我第二版写错的地方**，
    //       而它红了之后看着像闸门坏了，其实只是我拿一个受别的开关影响的例子去量闸门。
    // English: **angle-dependent examples are deliberately avoided here.** `sin(90) = 1` reads more
    //          naturally but **depends on the angle mode** (this context is radians, where `sin(90)` is
    //          0.894, not 1) — **that was my second wrong version**, and when it went red it looked like
    //          the gate was broken when in fact I had measured the gate with an example another switch
    //          controls.
    expect(ExpressionParser.normalizeExpressionInput('2+2=4'), '2+2');
    expect(ExpressionParser.normalizeExpressionInput('sqrt(81) = 9'), 'sqrt(81)');
    expect(ExpressionParser.normalizeExpressionInput('2+2='), '2+2');
    expect(parse('2^10 = 1024'), closeTo(1024, 1e-9));
    expect(parse('2π = 6.283'), closeTo(2 * math.pi, 1e-9));
    expect(parse('0xFF = 255'), closeTo(255, 1e-9));
    expect(parse('1e3 = 1000'), closeTo(1000, 1e-9));
    expect(parse('sqrt(81) = 9'), closeTo(9, 1e-9));
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
