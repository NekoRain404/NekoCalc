import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

/// 中文：**名字逐个核对的第二半：取值。** 词表里「引擎对这个拼法的答案能不能用」那一列，
///       在修复轮 3 里是**每个名字一个样本**并且**应用侧的值是手写的**——这正是 `log` 与 `mod`
///       两次都漏掉的根本原因（各有一个样本恰好没踩到分歧）。
///
///       这个文件把它变成**可重复、覆盖面明确**的核对：
///
///       - **应用侧的值是算出来的**：`ExpressionParser(表达式)`，也就是应用自己的求值器，
///         不是谁手写的一个数；
///       - **引擎侧的值是量出来的**：由 `tool/qalculate_semantics_probe/probe.cc` 对
///         libqalculate 5.12.0 跑出来（它用的就是桥的调用序列），下面是它的**逐行输出**；
///       - **判据**：两边同一个值时，词表必须标「答案可用」；两边不同时，必须标「不可用」。
///         于是**再出现一个 `log`/`mod`，不管它落在哪个样本上，这张表都会红**——
///         而修法只有一条：把它标成不可信（或者改掉应用自己的语义）。
///
///       覆盖面（**具体数字，不吹**）：**40 个样本**，覆盖词表 42 个名字里的 **29 个**，
///       其中 **8 个名字有 2 个以上样本**（`sin`/`atan2`/`round`/`floor`/`ceil`/`mod`/`root`/…），
///       其余 21 个各一个。**这不是「每个名字都有多个样本」**——真正的改进是：
///       应用侧的值**算出来**而不是手写，判据**按名字**判（任一样本分歧 ⇒ 该名字不可信），
///       并且样本里**有意放了负数、小数、零、多实参与负的第二个实参**——`mod` 与 `log` 的分歧
///       正是藏在这类地方。**没覆盖到的名字**：词表里那 13 个实参不是数字的名字
///       （`matrix`/`sum`/`product`/`integrate`/`diff`/`limit`/`rand`，以及 `ncr`/`npr`/`fact`/
///       `deg`/`rad`/`log` 这几个引擎压根没有对应函数的——它们由下一条测试与形状判据承担）。
/// English: **the second half of the per-name check: values.** In fix round 3 the vocabulary's "may
///          the engine's answer for this spelling be used" column had **one sample per name and a
///          hand-written app-side value** — which is exactly why `log` and `mod` both slipped
///          through (each had one sample that happened to miss the divergence).
///
///          This file turns it into a **repeatable, explicitly-scoped** cross-check:
///
///          - **the app-side value is computed**: `ExpressionParser(expression)`, this app's own
///            evaluator, not a number somebody wrote down;
///          - **the engine-side values are measured**: by `tool/qalculate_semantics_probe/probe.cc`
///            against libqalculate 5.12.0 (the same call sequence the bridge uses); the table below is
///            its **verbatim output**;
///          - **the test**: where the two agree the vocabulary must say "usable"; where they differ it
///            must say "not usable". So **another `log`/`mod` turns this table red on whichever sample
///            it lands on**, and the only fix is to mark that name untrusted (or change this app's own
///            semantics).
///
///          Scope (**concrete numbers, no rounding up**): **40 samples** covering **29 of the
///          vocabulary's 42 names**, of which **8 names carry more than one sample**
///          (`sin`/`atan2`/`round`/`floor`/`ceil`/`mod`/`root`/…), the other 21 having one each. This
///          is **not** "every name has several samples" — the real improvement is that the app-side
///          value is *computed* rather than written down, that the judgement is **per name** (any
///          divergent sample makes that name untrusted), and that the samples deliberately include
///          negatives, fractions, zero, multi-argument calls and a negative second argument — where
///          `mod`'s and `log`'s divergences hid. **Not covered**: the 13 names in the vocabulary whose
///          arguments are not numbers (`matrix`/`sum`/`product`/`integrate`/`diff`/`limit`/`rand`, plus
///          `ncr`/`npr`/`fact`/`deg`/`rad`/`log`, which the engine has no counterpart for at all) — the
///          next test and the shape rules carry those.
void main() {
  test('应用与引擎的取值逐例核对；有分歧的名字必须在词表里标成不可信', () {
    // 中文：**按名字判**，不是按样本判——分歧只要出现在**任何一个**样本上，那个名字就不可信
    //       （`mod` 正是这样：`mod(7,3)` 两边都是 1，`mod(7,-3)` 引擎 `-2`、应用 `1`）。
    // English: judged **per name**, not per sample — a divergence on **any** sample makes that name
    //          untrusted (`mod` is exactly this: `mod(7,3)` is 1 on both sides, while `mod(7,-3)` is
    //          `-2` from the engine and `1` from this app).
    final byName = <String, List<String>>{};
    for (final entry in _engineValues.entries) {
      final expression = entry.key;
      final name = RegExp(r'^([A-Za-z][A-Za-z0-9]*)\(').firstMatch(expression)!.group(1)!;
      final appValue = ExpressionParser(expression, degreeMode: false).parse();
      final engineValue = _leadingNumber(entry.value);
      final same = (appValue - engineValue).abs() <= 1e-9 * (1 + appValue.abs());
      if (!same) {
        byName.putIfAbsent(name, () => <String>[]).add(
            '$expression（应用 $appValue / 引擎 ${entry.value}）');
      } else {
        byName.putIfAbsent(name, () => <String>[]);
      }
    }

    for (final entry in byName.entries) {
      final name = entry.key;
      final divergences = entry.value;
      final trusted = !AppEngineVocabulary.unknownToEngine.contains(name);
      expect(
        trusted,
        divergences.isEmpty,
        reason: divergences.isEmpty
            ? '$name：这张表里的样本两边全一致，词表却说它不可用——一致的样本不该被拦。'
            : '$name：这些样本两边不一致，词表却说引擎的答案可用——'
                'tier 1 会直接采用引擎的值。分歧：${divergences.join('；')}',
      );
    }
  });

  test('引擎根本没有这个函数的名字一律不可信', () {
    // 中文：这一半靠 `getFunction` 量（`tool/…/probe.cc` 的姊妹脚本问过符号表）：
    //       `ncr`/`npr`/`fact` 在引擎里既不是函数、也不是变量、也不是单位。
    // English: this half is measured with `getFunction` (a sibling probe asks the symbol table):
    //          `ncr`/`npr`/`fact` are neither a function, nor a variable, nor a unit in the engine.
    for (final name in <String>['ncr', 'npr', 'fact']) {
      expect(AppEngineVocabulary.unknownToEngine, contains(name));
      expect(AppEngineVocabulary.functionNames[name]!.engineKnowsThisName, isFalse);
    }
  });
}

/// 中文：从引擎的打印里取出前导数字。反三角函数那一族会带一个 ` rad` 后缀
///       （引擎把它们印成角度量），本表只比对数值本身——` rad` 这件事由 `unit` 那一支
///       在显示层处理（它让引擎这些答案不参与 tier 1 的十进制采用）。
/// English: the leading number of the engine's printing. The inverse trigonometric family carries a
///          ` rad` suffix (the engine prints them as angle quantities); this table compares the value
///          itself — the ` rad` is the display layer's business (the `unit` branch keeps those answers
///          out of tier 1's decimal adoption).
double _leadingNumber(String engineText) {
  final match = RegExp(r'^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?')
      .firstMatch(engineText.trim());
  expect(match, isNotNull, reason: '引擎的取值不是数字：$engineText');
  return double.parse(match!.group(0)!);
}

/// 中文：**引擎的值**——`tool/qalculate_semantics_probe/probe.cc` 在 libqalculate 5.12.0 上的
///       逐行输出（原样抄写）。
/// English: **the engine's values** — verbatim output of `tool/qalculate_semantics_probe/probe.cc`
///          against libqalculate 5.12.0.
const Map<String, String> _engineValues = <String, String>{
  'sin(1)': '0.8414709848078965',
  'sin(-1)': '-0.8414709848078965',
  'cos(0)': '1',
  'tan(0.5)': '0.5463024898437905',
  'asin(0.5)': '0.5235987755982989 rad',
  'acos(0.5)': '1.047197551196598 rad',
  'atan(1)': '0.7853981633974483 rad',
  'sinh(1)': '1.175201193643801',
  'cosh(1)': '1.543080634815244',
  'tanh(1)': '0.7615941559557649',
  'cot(1)': '0.6420926159343307',
  'sec(1)': '1.850815717680926',
  'csc(1)': '1.188395105778121',
  'log(100)': '4.605170185988091',
  'log2(8)': '3',
  'ln(2)': '0.6931471805599453',
  'exp(1)': '2.718281828459045',
  'abs(-3)': '3',
  'sqrt(2)': '1.414213562373095',
  'cbrt(-8)': '-2',
  'floor(1.7)': '1',
  'floor(-1.7)': '-2',
  'ceil(1.2)': '2',
  'ceil(-1.2)': '-1',
  'round(1.5)': '2',
  'round(-1.5)': '-2',
  'round(2.5)': '3',
  'min(3,1)': '1',
  'max(3,1)': '3',
  'mod(7,3)': '1',
  'mod(7,-3)': '-2',
  'mod(-7,3)': '2',
  'mod(-7,-3)': '-1',
  'gcd(24,18)': '6',
  'lcm(4,6)': '12',
  'root(27,3)': '3',
  'root(3,27)': '1.041528498231435',
  'atan2(1,1)': '0.7853981633974483 rad',
  'sqrt(9)': '3',
  'exp(0)': '1',
};
