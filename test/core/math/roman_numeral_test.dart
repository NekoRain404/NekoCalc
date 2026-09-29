import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/roman_numeral.dart';

/// 中文：**罗马数字的测试。**
///
///       ⚠️ **两组期望值，来源不同，都必须写清**：
///
///       1. **"对的那一半"来自引擎**——宿主 `qalc` 5.12.0 的 `roman(n)`，`1`/`4`/`9`/`40`/`90`/
///          `400`/`900`/`1990`/`2026`/`3888`/`3999` 逐条量过（见 `.superpowers/backup/engine-capability-probe.md`）。
///          **那是"引擎在规范范围内是对的"这一句的证据。**
///       2. **"错的那一半"也来自引擎**，而它**不是**期望值，是**反例**——
///          `roman(10000)` 回 `"10000"`、`roman(-1)` 回 `"-I"`、`roman(0)` 回数字 `0`、
///          `roman(3.5)` 回 `"VII / II"`。**这一组钉的是"我们不照抄它"。**
///
///       把这四行写成断言而不是注释，是因为**它们正是这个函数存在的理由**：
///       一个"能用"的实现很容易顺手把这些边界也照抄过来。
/// English: **the Roman-numeral tests.**
///
///          ⚠️ **two sets of expected values, from different sources, both spelled out**:
///
///          1. **the correct half comes from the engine** — host `qalc` 5.12.0's `roman(n)`, measured one
///             by one for `1`/`4`/`9`/`40`/`90`/`400`/`900`/`1990`/`2026`/`3888`/`3999` (see
///             `.superpowers/backup/engine-capability-probe.md`). **That is the evidence for "the engine
///             is right inside the canon".**
///          2. **the wrong half also comes from the engine**, and it is **not** an expected value but a
///             **counter-example** — `roman(10000)` gives `"10000"`, `roman(-1)` gives `"-I"`,
///             `roman(0)` gives the number `0`, `roman(3.5)` gives `"VII / II"`. **This set pins "we do
///             not copy it".**
///
///          Writing those four as assertions rather than as a comment is deliberate: **they are the very
///          reason this function exists.** A "working" implementation would happily copy those
///          boundaries too.
void main() {
  group('规范写法：期望值逐条来自引擎（它在规范范围内是对的）', () {
    test('六组减法记法与基本符号', () {
      expect(toRoman(1), 'I');
      expect(toRoman(4), 'IV');
      expect(toRoman(5), 'V');
      expect(toRoman(9), 'IX');
      expect(toRoman(40), 'XL');
      expect(toRoman(90), 'XC');
      expect(toRoman(400), 'CD');
      expect(toRoman(900), 'CM');
    });

    test('多符号组合与三个端点', () {
      expect(toRoman(1990), 'MCMXC');
      // 中文：2026 是引擎实测过的那个值，也是本项目自己用的年份。
      expect(toRoman(2026), 'MMXXVI');
      // 3888 是**规范里最长的一个**写法（15 个字符），3999 是**最大的一个**。
      expect(toRoman(3888), 'MMMDCCCLXXXVIII');
      expect(toRoman(3999), 'MMMCMXCIX');
    });
  });

  group('⚠️ 引擎在边界上给的是"看着像答案的错值"，这一组钉的是**我们不照抄**', () {
    test('零与负数：没有规范写法，回 null（引擎回 `0` 与 `"-I"`）', () {
      // 中文：`roman(0)` 引擎回的是**数字** `0`——连类型都变了；`roman(-1)` 回 `"-I"`，
      //       那是**凭空造出来的**：罗马数字的记法里没有负号，也没有 0。
      // English: the engine's `roman(0)` returns the **number** `0` — even the type changed — and
      //          `roman(-1)` returns `"-I"`, **invented out of nothing**: Roman notation has no minus
      //          sign and no zero.
      expect(toRoman(0), isNull);
      expect(toRoman(-1), isNull);
      expect(toRoman(-3999), isNull);
    });

    test('4000 起回 null（引擎回 `"MMMM"`，那是非规范的）', () {
      // 中文：规范的 4000 要写成带**上划线**的 `IV̄`，而纯文本排不出那个记号——
      //       于是范围到此为止。引擎给的 `MMMM` 是常见的**非规范**写法，
      //       而 `roman(10000)` 更糟：**它把输入原样还了回来**。
      // English: canonical 4000 needs an **overlined** `IV̄`, which plain text cannot set — so the range
      //          stops here. The engine's `MMMM` is a common but **non-canonical** spelling, and
      //          `roman(10000)` is worse still: **it hands the input straight back.**
      expect(toRoman(4000), isNull);
      expect(toRoman(10000), isNull);
    });

    test('范围的端点本身是收着的', () {
      expect(kRomanMin, 1);
      expect(kRomanMax, 3999);
      expect(toRoman(kRomanMin), isNotNull);
      expect(toRoman(kRomanMax), isNotNull);
      expect(toRoman(kRomanMin - 1), isNull);
      expect(toRoman(kRomanMax + 1), isNull);
    });
  });

  test('⚠️ 它不收 double：整数性由握着原文的那一层判', () {
    // 中文：**签名上没有 `double` 这个口子。** 引擎的 `roman(3.5)` 回 `"VII / II"`——
    //       一套**它自己编的**分数写法。把浮点挡在类型外面，那个问题就无从出现，
    //       而调用方（手里是十进制文本）本来就知道那是不是整数。
    // English: **there is no `double` opening in the signature.** The engine's `roman(3.5)` returns
    //          `"VII / II"` — a fraction notation **it made up**. Keeping floats outside the type keeps
    //          that question from arising at all, and the caller (holding the decimal text) already knows
    //          whether it is an integer.
    expect(toRoman(3), 'III');
    expect(toRoman(3.0.toInt()), 'III');
  });
}
