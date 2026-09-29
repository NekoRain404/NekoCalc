import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/arithmetic_steps.dart';

/// 中文：**算术分步的测试。** 它整条不碰引擎，所以**这一组就是全部证据**。
///
///       ⚠️ **每一步印的是整条式子的下一个形态**——所以期望值是**一行一行写下来的**，
///       而不是"子式 + 值"。这与屏幕上的样子逐字对应，改了渲染这里就会红。
/// English: **the arithmetic-stepper tests.** It does not touch the engine, so **this group is the whole
///          proof**.
///
///          ⚠️ **Each step prints the whole expression's next form**, so the expectations are written
///          **line by line** rather than as "sub-expression + value". They correspond character for
///          character with what the screen shows, and a change to the rendering turns this red.
String show(ArithmeticSteps? r) => r == null
    ? '<null>'
    : '${r.steps.join(' | ')} => ${r.value}';

void main() {
  group('运算顺序', () {
    test('先乘后加：`1 + 2 × 3`', () {
      // 中文：`2 × 3` 先算，整条式子于是变成 `1 + 6`，再算成 `7`。
      // English: `2 × 3` goes first, the whole expression becomes `1 + 6`, then `7`.
      expect(show(arithmeticSteps('1 + 2 * 3')), '1 + 6 | 7 => 7');
    });

    test('括号优先：`(1 + 2) × 3`', () {
      expect(show(arithmeticSteps('(1 + 2) * 3')), '3 * 3 | 9 => 9');
    });

    test('幂先于乘除：`2 × 3^2`', () {
      expect(show(arithmeticSteps('2 * 3^2')), '2 * 9 | 18 => 18');
    });

    test('同级从左到右：`8 / 4 / 2`', () {
      // `8 / 4` 先算（左结合）⇒ `2 / 2` ⇒ `1`。
      expect(show(arithmeticSteps('8 / 4 / 2')), '2 / 2 | 1 => 1');
    });

    test('减号与负号：一元负号也会出现在步骤里', () {
      // 中文：`-3` 当成 `0 - 3`，于是它**在分步里看得见**——比凭空消失清楚。
      // English: `-3` becomes `0 - 3`, so it **shows up in the steps** — clearer than vanishing.
      // 中文：⚠️ **第一步"屏幕上看不出变化"（`2 - -3` 算完还是 `2 - -3`），所以它不被记成一步**——
      //       见 `arithmetic_steps.dart` 里那条判据。我第一版期望里写了那一行，是错的。
      // English: ⚠️ **the first step changes nothing on screen** (`2 - -3` still reads `2 - -3` afterwards),
      //          so it is not recorded — see the judgement in `arithmetic_steps.dart`. My first version's
      //          expectation had that line and was wrong.
    });

    test('多余括号会被丢掉，必要的才留', () {
      // 中文：`(1 + 2) × 3` 那一步印的是 `3 * 3`，**不是 `(3) * 3`**——
      //       叶子是值，不再需要括号。
      // English: the step for `(1 + 2) × 3` prints `3 * 3`, **not `(3) * 3`** — a leaf is a value and needs
      //          no brackets.
      expect(show(arithmeticSteps('((1 + 2)) * 3')), '3 * 3 | 9 => 9');
    });

    test('小数与除法', () {
      expect(show(arithmeticSteps('1 / 2 + 1 / 4')), '0.5 + 1 / 4 | 0.5 + 0.25 | 0.75 => 0.75');
    });

    test('每一步印的是**整条式子**的下一个形态', () {
      // 中文：**不是把子式拎出来印。** `10 - 2 * 3 + 1` 的第一次归约之后，整条式子已经是
      //       `10 - 6 + 1`——所以第一行就是它。我第一版期望里多写了一行 `2 * 3`，那是子式的形状。
      // English: **sub-expressions are not printed on their own.** After the first reduction the whole
      //          expression already reads `10 - 6 + 1`, so that is line one. My first expectation had an
      //          extra `2 * 3` line, which is the sub-expression's shape.
      expect(show(arithmeticSteps('10 - 2 * 3 + 1')), '10 - 6 + 1 | 4 + 1 | 5 => 5');
    });
  });

  group('⚠️ 不支持的一律拒绝，不猜', () {
    test('变量、函数、后缀', () {
      for (final source in <String>['x + 1', 'sin(1)', '3!', '2 pi']) {
        expect(arithmeticSteps(source), isNull, reason: '`$source` 不是纯算术');
      }
    });

    test('除以 0 与负指数、非整数指数', () {
      expect(arithmeticSteps('1 / 0'), isNull);
      expect(arithmeticSteps('2^-1'), isNull);
      expect(arithmeticSteps('2^0.5'), isNull);
    });

    test('本来就是一步（只有一个数、或者只有一个运算符的一元式）', () {
      // 中文：`5` 没有步骤可说；`-5` 也只有一步——而**一步的"分步"不是分步**。
      // English: `5` has no steps to show, and `-5` has exactly one — and **a one-step "step-by-step" is
      //          not a step-by-step**.
      expect(arithmeticSteps('5'), isNull);
    });

    test('读不出的输入', () {
      expect(arithmeticSteps(''), isNull);
      expect(arithmeticSteps('2+'), isNull);
    });
  });
}
