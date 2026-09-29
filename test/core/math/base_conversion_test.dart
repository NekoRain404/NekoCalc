import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/base_conversion.dart';

/// 中文：**进制换算的测试。**
///
///       **这一组就是全部证据，不必等真机。** 它是纯函数，不经过引擎——而这正是把它从引擎那条路
///       上搬下来的理由之一（见 `base_conversion.dart` 的文件头：桥用的 `calculate` 根本不做
///       `to hex`，那是量出来的）。
///
///       ⚠️ **期望值不是我自己算的**，是拿**另一个独立实现**（Python 的 `hex()`/`bin()`/`oct()`
///       以及一段按定义写的长除法）跑出来的。**自己手算一遍再拿同一个脑子去核，等于没有核。**
/// English: **the base-conversion tests.**
///
///          **This group is the whole proof; no device is needed.** It is a pure function and does not go
///          through the engine — which is one of the reasons it was moved off that road (see
///          `base_conversion.dart`'s head: the bridge's `calculate` does not do `to hex` at all, and
///          that was measured).
///
///          ⚠️ **The expected values are not mine**: they came from **a separate implementation**
///          (Python's `hex()`/`bin()`/`oct()` plus a long division written straight off the definition).
///          **Working it out by hand and then checking it with the same head is no check at all.**
void main() {
  group('整数：与独立实现逐位相同', () {
    test('四颗键各自那一个进制', () {
      expect(convertToBase('100', 2)?.digits, '1100100');
      expect(convertToBase('100', 8)?.digits, '144');
      expect(convertToBase('100', 10)?.digits, '100');
      expect(convertToBase('100', 16)?.digits, '64');
    });

    test('借位与全 1 的那两个边界值', () {
      // 255 是十六进制里第一个两位都是字母的数，也是二进制里第一个八位全 1。
      expect(convertToBase('255', 16)?.digits, 'FF');
      expect(convertToBase('255', 2)?.digits, '11111111');
      expect(convertToBase('255', 8)?.digits, '377');
    });

    test('任意进制：字母表一直用到 Z（35）', () {
      expect(convertToBase('10', 7)?.digits, '13');
      expect(convertToBase('1000', 16)?.digits, '3E8');
      expect(convertToBase('35', 36)?.digits, 'Z');
      expect(convertToBase('36', 36)?.digits, '10');
    });

    test('符号、科学计数法、千分位分隔都收', () {
      expect(convertToBase('-255', 16)?.digits, '-FF');
      expect(convertToBase('+255', 16)?.digits, 'FF');
      // 一千的十六进制是 3E8——科学计数法必须走同一个结果。
      expect(convertToBase('1E3', 16)?.digits, '3E8');
      expect(convertToBase('1e3', 16)?.digits, '3E8');
      expect(convertToBase('1,000', 16)?.digits, '3E8');
      expect(convertToBase(' 100 ', 16)?.digits, '64');
    });

    test('零', () {
      expect(convertToBase('0', 16)?.digits, '0');
      expect(convertToBase('0.0', 2)?.digits, '0');
      expect(convertToBase('-0', 16)?.digits, '-0');
    });
  });

  group('小数', () {
    test('除得尽的不算截断', () {
      // 中文：**这一条挡住的是"把除尽了也标成截断"。** 那样写会告诉用户"还有位数没印"，
      //       而其实没有了——一个假的省略号与一个漏印的数字一样是错值。
      // English: **this stops "dividing out" being marked truncated too.** That would tell the user
      //          "there are more digits" when there are none — a false ellipsis is a wrong value just
      //          as a dropped digit is.
      expect(convertToBase('2.5', 16)?.digits, '2.8');
      expect(convertToBase('2.5', 16)?.truncated, isFalse);
      expect(convertToBase('2.5', 2)?.digits, '10.1');
      expect(convertToBase('2.5', 2)?.truncated, isFalse);
      // 0.5 在二进制里一位就够，在十六进制里也是。
      expect(convertToBase('0.5', 2)?.digits, '0.1');
      expect(convertToBase('0.5', 2)?.truncated, isFalse);
    });

    test('除不尽的要标成截断，而且位数真的停在上限', () {
      // 0.1 在二进制里是无限循环小数：前 20 位是 0001 1001 1001 1001 1001。
      // 中文：**位宽是给整串的，`0.` 那两个字符也占位。** 20 位预算 ⇒ 小数点后 17 位 + 一个 `…`。
      //       我第一版把预算当成"小数位数"，于是期望值比实际长——**代码是对的，错的是期望**。
      // English: **the width belongs to the whole string, and the `0.` spends two of it.** A budget of
      //          20 ⇒ seventeen fractional digits plus one `…`. My first version read the budget as
      //          "fractional digits", so the expectation came out longer than the result — **the code
      //          was right and the expectation was wrong.**
      final result = convertToBase('0.1', 2);
      expect(result?.truncated, isTrue, reason: '0.1 在二进制里除不尽');
      expect(result?.digits, '0.00011001100110011…');
      expect(result?.digits.length, 20);
    });

    test('小数位宽由 maxDigits 决定，与整数部分共用同一个预算', () {
      // 中文：**预算共用一个，不是各算各的。** 屏幕上那一格就那么宽——整数用掉的位，
      //       小数就不该再要。
      // English: **one budget, not one each.** That cell on screen is only so wide — digits the
      //          integer part spends are digits the fraction cannot have.
      expect(convertToBase('0.1', 2, maxDigits: 5)?.digits, '0.00…');
    });
  });

  group('⚠️ 不猜：读不出来的一律 null', () {
    test('不是数的一律拒绝', () {
      for (final text in <String>[
        '',
        '   ',
        'abc',
        'NaN',
        'infinity',
        '1.2.3',
        '1..2',
        '1e',
        '1e2e3',
        '--1',
      ]) {
        expect(convertToBase(text, 16), isNull, reason: '`$text` 不是一个十进制数');
      }
    });

    test('进制在 2..36 之外一律拒绝', () {
      // 中文：字母表只有 36 个符号。放到 37 就没有符号可用了——**宁可说"读不出"，
      //       也不许回退成别的进制**（那会印出一个看着像答案的错值）。
      // English: the alphabet holds 36 symbols. At 37 there is nothing left to write — **better to say
      //          "cannot read it" than to silently fall back to another base**, which would print a
      //          wrong value that looks like an answer.
      for (final radix in <int>[0, 1, -16, 37, 100]) {
        expect(convertToBase('100', radix), isNull, reason: '进制 $radix 不在 2..36');
      }
    });
  });

  group('大数：精确，然后按位宽截断', () {
    test('超出 double 量程的值也算得对（`BigInt` 那一步的意义）', () {
      // 中文：**这一条是"不用 double"的凭据。** 1e30 是 100 位二进制 / 25 位十六进制，
      //       远在 double 的精确整数范围之外，而它在这里是 `BigInt`，逐位可查——
      //       上面那串是 **Python 的 `hex(10**30)` 原文抄下来的**。
      //       ⚠️ **我第一次把那串的尾数凭印象写成了 `…400000`，实际是 `…40000000`**：
      //       25 位的东西不能靠记忆补，这正是"期望值必须来自独立实现"的理由。
      // English: **this is the evidence for "not a double".** 1e30 is 100 binary / 25 hexadecimal
      //          digits, far beyond a double's exact integer range, while here it is a `BigInt` and
      //          checkable digit by digit — the string above is **copied verbatim from Python's
      //          `hex(10**30)`**. ⚠️ **My first attempt typed its tail from memory as `…400000` when it
      //          is `…40000000`**: a 25-digit value cannot be filled in from memory, which is exactly
      //          why the expected values have to come from a separate implementation.
      expect(convertToBase('1e30', 16, maxDigits: 30)?.digits,
          'C9F2C9CD04674EDEA40000000');
      expect(convertToBase('1e30', 16, maxDigits: 30)?.truncated, isFalse);
      // 默认预算下截断处必须看得见。
      final cut = convertToBase('1e30', 16);
      expect(cut?.truncated, isTrue);
      expect(cut?.digits, 'C9F2C9CD04674EDEA40…');
      expect(cut?.digits.length, 20);
    });

    test('二进制下 1e30 的前 20 位与独立实现相同', () {
      // 二进制下 1e30 是整 100 位，20 位预算 ⇒ 19 位 + `…`；前 20 位由独立实现给出。
      expect(convertToBase('1e30', 2)?.digits, '1100100111110010110…');
      expect(convertToBase('1e30', 2, maxDigits: 101)?.digits,
          startsWith('11001001111100101100'));
      expect(convertToBase('1e30', 2, maxDigits: 101)?.digits.length, 100);
    });
  });
}
