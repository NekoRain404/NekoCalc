import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/variable_references.dart';

/// 中文：**`%` 的两种读法——一张逐条带理由的行为表。** 判据、厂商原文出处与参考实现的实测都写在
///       `lib/core/math/percentage_expansion.dart` 的文件头；这里只管钉住结果。
///
///       参考实现是宿主 `qalc` 5.12.0（它同时是本应用的引擎，且它自己的百分比设置默认就是
///       relative）。本文件里每一条 relative 的期望值都实测过 `qalc -t "<表达式>"`，两边逐条相同；
///       **刻意不同的**那几条在下面各自带 `reason` 写明为什么（`50+2^10%`、`sin(10%)`、
///       `5/50%^50%`）。
///
///       **`÷` 那一族是本轮修的**：上一轮把 `5÷50%` 的 0.001 记成「既有分歧、不在本轮范围」并留在
///       原地，那是错的——厂商手册 12.0 的 relative 一节把 `5 ÷ 50% → 10` 印成一条小题，而
///       direct 的定义同样给 10（`50%` 是 0.5），两边都不是 0.001。`÷` 那一族的取证与逐条对照
///       在下面 `÷ 与 %` 那一组里。
/// English: **The two readings of `%` — a behaviour table with a reason on every line.** The
///          judgement, the vendor's wording and the reference implementation's measurements are in
///          `lib/core/math/percentage_expansion.dart`'s header; this file only pins results.
///
///          The reference implementation is the host's `qalc` 5.12.0 (also this app's engine, and its
///          own percentage setting defaults to relative). Every relative expectation below was measured
///          with `qalc -t "<expression>"` and agrees line by line; the **deliberate exceptions** each
///          carry a `reason` saying why (`50+2^10%`, `sin(10%)`, `5/50%^50%`).
///
///          **The `÷` family is what this round fixed.** The previous round recorded `5÷50%` = 0.001 as
///          "a known divergence, out of scope" and left it alone; that was wrong — the vendor's manual
///          12.0 prints `5 ÷ 50% → 10` as a worked example in its relative section, and direct's own
///          definition gives 10 as well (`50%` is 0.5), so neither reading is 0.001. The evidence and the
///          line-by-line comparison for that family are in the `÷ 与 %` group below.
void main() {
  double parse(String source, {bool relative = false, bool degreeMode = false}) {
    return ExpressionParser(source,
            degreeMode: degreeMode, relativePercent: relative)
        .parse();
  }

  String normalized(String source, {bool relative = false}) {
    return ExpressionParser.normalizeExpressionInput(source,
        relativePercent: relative);
  }

  group('direct（默认）：与接入这个设置之前逐字节相同', () {
    test('厂商手册 direct 一节的四条', () {
      // 中文：手册 574–591 行的 direct 例子：`50+10%` = 50.1、`50−10%` = 49.9。
      // English: the manual's direct examples (lines 574–591): `50+10%` = 50.1, `50−10%` = 49.9.
      expect(parse('50+10%'), closeTo(50.1, 1e-12));
      expect(parse('50-10%'), closeTo(49.9, 1e-12));
      expect(parse('100+10%'), closeTo(100.1, 1e-12));
    });

    test('不传 relativePercent 与传 false 是同一次调用', () {
      // 中文：默认值就是 direct——`normalizeExpressionInput` 的那条路（名字层、变量引用、
      //       图形标签、去重键用的那条）看到的是同一个字符串，一个字都不许变。
      // English: the default is direct — the road `normalizeExpressionInput` takes for the name layer,
      //          variable references, graph labels and the de-duplication key sees one and the same
      //          string, and not a character of it may move.
      for (final source in <String>[
        '50+10%',
        '2^3%',
        '(20+30)+10%',
        '50+5%-5%',
        '1,200×50%',
      ]) {
        expect(normalized(source), normalized(source, relative: false),
            reason: source);
        expect(parse(source), parse(source, relative: false), reason: source);
      }
    });

    test('`÷` 那一族不再是分歧：`5/50%` 是 10（手册与 direct 的定义都这么说）', () {
      // 中文：**上一轮在这里写的是「既有分歧、本应用给 0.001」，本轮修掉了。** 归一化原先写
      //       `(X)/100`，那个除号与左边紧邻的除号在乘除层左结合，`5/50%` 于是读成 `5/50/100`；
      //       现在紧跟除号右边时整段括成 `((X)/100)`（判据与逐条对照见下面 `÷ 与 %` 那一组）。
      //       注意这两种读法**都不是模式问题**：厂商手册 relative 一节写 10，direct 的定义
      //       （`50%` 化成 0.5）同样写 10，所以改的是展开式的位置，两种模式一起改。
      // English: **the previous round recorded this as "a known divergence, this app answers 0.001";
      //          this round repairs it.** Normalisation used to write `(X)/100`, and that division
      //          associated leftwards with a division on its left, so `5/50%` read as `5/50/100`; to the
      //          right of a division it is now wrapped as `((X)/100)` (the judgement and the
      //          line-by-line comparison are in the `÷ 与 %` group below). Neither reading is a mode
      //          question: the vendor's relative section says 10 and direct's definition (`50%` is 0.5)
      //          says 10 too, so what moved is the expansion's position, in both modes at once.
      expect(parse('5/50%'), closeTo(10, 1e-12),
          reason: '手册 relative 一节的小题 `5 ÷ 50% → 10`');
      expect(parse('5/50%', relative: true), closeTo(10, 1e-12),
          reason: '`÷` 在两种模式下同值——厂商两节给的也都是 10');
    });

    test('剩下的那一处分歧是函数实参里的 `%`（角度单位那一层，两条都同值）', () {
      // 中文：`sin(10%)`：qalc 给 0.001745——它的 `%` 是单位，而**它这一侧的角度单位默认是度**，
      //       于是 sin(0.1°) = 0.001745；本应用给 sin(0.1) = 0.09983341664682815（RAD）。
      //       厂商两处都没写函数实参里的 `%`，而这一条的差来自角度单位而不是 `%` 的读法——
      //       把 `qalc -set "angle rad"` 打开，两边就是同一个数。两种模式在这一条上同值。
      // English: `sin(10%)`: qalc answers 0.001745 — its `%` is a unit and **its angle unit defaults to
      //          degrees** on that side, so it computes sin(0.1°) = 0.001745, while this app answers
      //          sin(0.1) = 0.09983341664682815 (RAD). The vendor writes nothing about `%` inside a
      //          function argument, and this difference comes from the angle unit rather than from the
      //          reading of `%` — with `qalc -set "angle rad"` the two give one and the same number.
      //          Both modes agree on this line.
      expect(parse('sin(10%)'), closeTo(0.09983341664682815, 1e-12));
      expect(parse('sin(10%)', relative: true),
          closeTo(0.09983341664682815, 1e-12));
      expect(parse('sin(50%)'), closeTo(0.479425538604203, 1e-12));
      expect(parse('abs(50%)'), closeTo(0.5, 1e-12));
    });
  });

  group('relative：厂商手册给值的四条 + 链式那条', () {
    test('手册 relative 一节逐条', () {
      expect(parse('50+10%', relative: true), closeTo(55, 1e-12));
      expect(parse('50-10%', relative: true), closeTo(45, 1e-12));
      expect(parse('50*10%', relative: true), closeTo(5, 1e-12));
      expect(parse('50+(10+10)%', relative: true), closeTo(60, 1e-12));
    });

    test('链式：第二个百分数按**累计值**算，不是按第一个操作数', () {
      // 中文：手册给的 `50+5%−5%` = 49.875 只能这么解释：（50 加 5% 得 52.5）再减 52.5 的 5%
      //       = 49.875。若第二个 5% 还是按 50 算，会得到 50.0（今天 direct 的值）。
      // English: the manual's `50+5%−5%` = 49.875 admits only one reading: (50 plus 5% is 52.5) then
      //          minus 5% **of 52.5** is 49.875. Were the second 5% still taken of 50, the answer would
      //          be 50.0 (today's direct value).
      expect(parse('50+5%-5%', relative: true), closeTo(49.875, 1e-12));
      expect(parse('50+5%-5%'), closeTo(50.0, 1e-12),
          reason: 'direct 下这里是 50.0——同一个输入，两种读法');
      expect(parse('50+10%+10%', relative: true), closeTo(60.5, 1e-12),
          reason: '第二个 10% 是 55 的 10%，不是 50 的');
      expect(parse('50+10%+10%+10%', relative: true), closeTo(66.55, 1e-12));
      expect(parse('100-10%-10%', relative: true), closeTo(81, 1e-12));
      expect(parse('1+10%+10%', relative: true), closeTo(1.21, 1e-12));
      expect(parse('5+10%+5', relative: true), closeTo(10.5, 1e-12),
          reason: '链上的非百分数项照旧只是加——折只发生在百分数项上');
    });
  });

  group('题目点名的那几条：两种模式并排', () {
    test('`50+10%` / `50-10%` / `(20+30)+10%`：前一个值就是左边那个值', () {
      expect(parse('(20+30)+10%'), closeTo(50.1, 1e-12));
      expect(parse('(20+30)+10%', relative: true), closeTo(55, 1e-12));
      expect(parse('2*3+10%', relative: true), closeTo(6.6, 1e-12),
          reason: '「前一个值」是左边那个**项的值** 6，不是它的文本 `2*3` 里的 2');
      expect(parse('2^3+10%', relative: true), closeTo(8.8, 1e-12));
      expect(parse('2*(50+10%)', relative: true), closeTo(110, 1e-12),
          reason: '括号里的链自己折，外面的乘法碰不到它');
      expect(parse('sqrt(50+10%)', relative: true), closeTo(7.416198487, 1e-9),
          reason: '函数实参里也是一条链');
      expect(parse('max(1,50+10%)', relative: true), closeTo(55, 1e-12),
          reason: '实参各算各的：逗号把两条链切开');
    });

    test('`10%` 单独出现：没有前一个值，就是 0.1', () {
      expect(parse('10%'), closeTo(0.1, 1e-12));
      expect(parse('10%', relative: true), closeTo(0.1, 1e-12));
      expect(parse('50%*2', relative: true), closeTo(1, 1e-12));
    });

    test('`10%+10%`：首项自己是百分数 → 整条链不折（0.2）', () {
      // 中文：厂商对此**一个字都没写**；这条是照参考实现补的（qalc 里 `%` 是单位，两个同单位量
      //       相加就是普通加法），而它同时等于本应用 direct 下的值，所以这一族两种模式同值。
      // English: the vendor says **nothing** about this; it is taken from the reference implementation
      //          (`%` is a unit in qalc, so two quantities of the same unit simply add) and it equals
      //          this app's direct value, making the family mode-invariant.
      expect(parse('10%+10%'), closeTo(0.2, 1e-12));
      expect(parse('10%+10%', relative: true), closeTo(0.2, 1e-12));
      expect(parse('50%+10%', relative: true), closeTo(0.6, 1e-12));
      expect(parse('(10%)+10%', relative: true), closeTo(0.2, 1e-12),
          reason: '括号包着的百分数仍然是一个百分数量');
      expect(parse('-10%+10%', relative: true), closeTo(0, 1e-12));
      expect(parse('20%+90', relative: true), closeTo(90.2, 1e-12));
      expect(parse('10%+50', relative: true), closeTo(50.1, 1e-12));
    });
  });

  group('× 与 ÷：厂商写了例子，而两个例子在两种读法下同值', () {
    test('`50×10%` = 5、`5÷50%` = 10 —— 两条都给了', () {
      // 中文：厂商在 relative 一节里给了 `50×10%` = 5 与 `5÷50%` = 10。前者与 direct 的定义同值
      //       （`×10%` 就是乘 0.1），所以 `×` 本来就没有第二条规则；后者按 direct 的定义也是 10，
      //       而本应用上一轮在**两种模式下都**给 0.001——那是展开式的位置错，不是读法错，本轮修了
      //       （见上面 direct 那一组的注释与下面 `÷ 与 %` 那一组）。两种模式在这条上一致。
      // English: under relative the vendor gives `50×10%` = 5 and `5÷50%` = 10. The first equals
      //          direct's definition (`×10%` is multiplying by 0.1), so `×` never had a second rule;
      //          the second is 10 under direct's definition too, and this app answered 0.001 in **both**
      //          modes — a misplacement of the expansion rather than a misreading, repaired this round
      //          (see the note in the direct group above and the `÷ 与 %` group below). Both modes agree.
      expect(parse('50*10%', relative: true), closeTo(5, 1e-12));
      expect(parse('50*10%'), closeTo(5, 1e-12));
      expect(parse('10%*50', relative: true), closeTo(5, 1e-12));
      expect(parse('5/50%'), closeTo(10, 1e-12));
      expect(parse('5/50%', relative: true), closeTo(10, 1e-12),
          reason: '÷ 的两种读法必须同值——这一条是「厂商没给第二条规则」的直接后果');
    });

    test('`×`/`÷`/`^` 的右操作数不是裸百分数时不折：50+10%*2 仍是 50.2', () {
      // 中文：参考实现实测：`50+10%*2` 50.2、`50+10%/2` 50.05、`50+2^10%` 也按 `/100` 走。
      //       判据是「`±` 的右操作数**恰好**是一个裸百分数字面量」，多一个运算符就不算。
      // English: measured on the reference implementation: `50+10%*2` is 50.2, `50+10%/2` is 50.05,
      //          and `50+2^10%` also divides by 100. The test is "the right operand of `±` is
      //          **exactly** one bare percentage literal"; one more operator disqualifies it.
      expect(parse('50+10%*2', relative: true), closeTo(50.2, 1e-12));
      expect(parse('50+10%/2', relative: true), closeTo(50.05, 1e-12));
      expect(parse('50-10%*2', relative: true), closeTo(49.8, 1e-12));
      expect(parse('200+10%*3', relative: true), closeTo(200.3, 1e-12));
      expect(parse('2^3%', relative: true), closeTo(0.08, 1e-12),
          reason: '`%` 落在整个外层项末尾的既有约定，两种模式同值');
      expect(parse('3%^2', relative: true), closeTo(0.0003, 1e-12));
      expect(parse('50+2^10%', relative: true), closeTo(60.24, 1e-12),
          reason: '**与 qalc 不同的一条**：qalc 在同一条式子上给 562（它把链里的 `b^e%` 读成 '
              '`b^(e−1)`，而单独一句 `2^10%` 它又给 10.24，自相矛盾）；厂商对此没有说法，'
              '本应用按自己那条已钉住的 `%` 约定读，两模式同值');
    });
  });

  group('÷ 与 %：展开式是一个原子（本轮修的缺陷）', () {
    test('除号右边那一族：逐条与 qalc 对照，两种模式同值', () {
      // 中文：**缺陷**：`_replacePercent` 写下的 `(X)/100` 在乘除层不是一个原子，它的除号与左边
      //       紧邻的除号**左结合**，于是 `5÷50%` 读成 `5/50/100` = 0.001。厂商手册 12.0 的
      //       relative 一节（`pdftotext -layout` 后 595–605 行）把 `What percentage is 5 out of
      //       50?  5 ÷ 50%  →  10` 印成一条小题；direct 一节的定义（`50%` 化成 0.5）同样给 10。
      //       修法是紧跟除号右边时整段括起来：`((X)/100)`，判据与代码在
      //       `lib/core/math/expression_input_normalization.dart` 的 `_replacePercent`。
      //
      //       **表里每一行的 `broken` 都是修之前屏幕上那个数**（本轮实测），`qalc` 是宿主
      //       `qalc` 5.12.0 的实测值。修完逐条相同——这也是「只动了除号那一族」的反面证据：
      //       表外那些形状一个数都没动（见下一条）。
      // English: **The defect**: the `(X)/100` written by `_replacePercent` is not an atom in the
      //          multiplicative layer — its division **associates leftwards** with a division on its
      //          left, so `5÷50%` read as `5/50/100` = 0.001. The vendor's manual 12.0 prints
      //          `What percentage is 5 out of 50?  5 ÷ 50%  →  10` as a worked example in its relative
      //          section (lines 595–605 after `pdftotext -layout`), and direct's definition (`50%` is
      //          0.5) gives 10 as well. The fix wraps the whole expansion when it sits to the right of a
      //          division: `((X)/100)` — the judgement and the code are in `_replacePercent`
      //          (`lib/core/math/expression_input_normalization.dart`).
      //
      //          Every row's `broken` is the number that was on screen before the fix (measured this
      //          round) and `qalc` is what the host's `qalc` 5.12.0 answers. After the fix the two agree
      //          line by line — which is also the reverse evidence for "only the division family moved":
      //          no shape outside this table changed by a single number (see the next test).
      const rows = <({String source, double broken, double fixed, double qalc})>[
        (source: '5/50%', broken: 0.001, fixed: 10, qalc: 10),
        (source: '(5+5)/50%', broken: 0.002, fixed: 20, qalc: 20),
        (source: '5÷50%×2', broken: 0.002, fixed: 20, qalc: 20),
        (source: '100/50%', broken: 0.02, fixed: 200, qalc: 200),
        (source: '1/2/50%', broken: 0.0001, fixed: 1, qalc: 1),
        (source: '5/-50%', broken: -0.001, fixed: -10, qalc: -10),
        (source: '5/-(-50)%', broken: 0.001, fixed: 10, qalc: 10),
        (source: '5/50%/2', broken: 0.0005, fixed: 5, qalc: 5),
        (source: '1/(2/50%)', broken: 2500, fixed: 0.25, qalc: 0.25),
        (source: '5/50%+1', broken: 1.001, fixed: 11, qalc: 11),
        (source: '5/(50)%', broken: 0.001, fixed: 10, qalc: 10),
        (source: '(5)/(50)%', broken: 0.001, fixed: 10, qalc: 10),
        (source: '5/-(50)%', broken: -0.001, fixed: -10, qalc: -10),
        (source: '5 / 50%', broken: 0.001, fixed: 10, qalc: 10),
        (source: '10%/10%', broken: 0.0001, fixed: 1, qalc: 1),
        (source: '5%÷5%', broken: 0.0001, fixed: 1, qalc: 1),
        (source: '5%*2/10%', broken: 0.0001, fixed: 1, qalc: 1),
        // 中文：幂也跟着进括号（`^` 比 `/` 紧，`3%^2` 的 0.0003 就是 `3/(100^2)`）——否则幂会改去
        //       乘那个**值**。四行的 qalc 逐个实测过。
        // English: a following power goes inside the brackets too (`^` binds tighter than `/`; the
        //          existing 0.0003 of `3%^2` **is** `3/(100^2)`) — otherwise the power would multiply
        //          the **value** instead. All four qalc numbers were measured.
        (source: '5/50%^2', broken: 0.00001, fixed: 1000, qalc: 1000),
        (source: '5/50%^2*3', broken: 0.00003, fixed: 3000, qalc: 3000),
        (source: '5/50%^2.5', broken: 0.000001, fixed: 10000, qalc: 10000),
        (source: '5/50%^(1/2)', broken: 0.01, fixed: 1, qalc: 1),
        (source: '5/50%^-1', broken: 10, fixed: 0.001, qalc: 0.001),
      ];

      for (final row in rows) {
        expect(parse(row.source), closeTo(row.fixed, 1e-9),
            reason: '${row.source}：修之前是 ${row.broken}，qalc 给 ${row.qalc}');
        expect(parse(row.source, relative: true), closeTo(row.fixed, 1e-9),
            reason: '${row.source}：`÷` 没有第二条规则，两种模式必须同值');
      }
    });

    test('折出来的形状：括号只加在除号右边', () {
      // 中文：形态本身也要钉——值是行为的契约，文本是**别的六个消费者**的契约。
      // English: the shape is pinned too — the value is the behaviour's contract, the text is the one
      //          the **other six consumers** read.
      expect(normalized('5/50%'), '5/((50)/100)');
      expect(normalized('5/50%', relative: true), '5/((50)/100)',
          reason: '相对模式在除号这一族上折出来的文本与 direct 逐字节相同');
      expect(normalized('5/-(50)%'), '5/-(((50))/100)');
      expect(normalized('5/50%^2'), '5/((50)/100^2)');
      expect(normalized('5/50%*2'), '5/((50)/100)*2',
          reason: '乘号不进括号——`*` 可交换，两种写法同值');
    });

    test('表外的形状一个字节都不许动（`+`/`-`/`*`/`^`/函数实参/裸百分数）', () {
      // 中文：**这是本轮的护栏。** 上一轮已按厂商与 qalc 逐条量过 `+`/`−`/`×`/`^` 与函数实参，
      //       本轮只许动除号那一族；下表把每个左邻都写死成**修之前的文本与值**（本轮实测），
      //       任何一行红了都说明改动溢出了除号那一族。
      // English: **this round's guard rail.** The previous round measured `+`/`−`/`×`/`^` and function
      //          arguments against the vendor and qalc line by line, and this round may move the division
      //          family only; the table below freezes every left neighbour at the **text and value it had
      //          before the fix** (measured this round), so any red line means the change spilled out of
      //          that family.
      const rows = <({String source, String directText, String relativeText})>[
        (source: '50%', directText: '(50)/100', relativeText: '(50)/100'),
        (source: '5+50%', directText: '5+(50)/100', relativeText: '(5)*(100+(50))/100'),
        (source: '5-50%', directText: '5-(50)/100', relativeText: '(5)*(100-(50))/100'),
        (source: '5*50%', directText: '5*(50)/100', relativeText: '5*(50)/100'),
        (source: '2^50%', directText: '2^(50)/100', relativeText: '2^(50)/100'),
        (source: '2^3%', directText: '2^(3)/100', relativeText: '2^(3)/100'),
        (source: '3%^2', directText: '(3)/100^2', relativeText: '(3)/100^2'),
        (source: '50%^2', directText: '(50)/100^2', relativeText: '(50)/100^2'),
        (source: '2^3%*5', directText: '2^(3)/100*5', relativeText: '2^(3)/100*5'),
        (source: '1+2^10%', directText: '1+2^(10)/100', relativeText: '1+2^(10)/100'),
        (source: '50%/2', directText: '(50)/100/2', relativeText: '(50)/100/2'),
        (source: '50%*2', directText: '(50)/100*2', relativeText: '(50)/100*2'),
        (source: '2*50%', directText: '2*(50)/100', relativeText: '2*(50)/100'),
        (source: '5*50%/2', directText: '5*(50)/100/2', relativeText: '5*(50)/100/2'),
        (source: '5/2*50%', directText: '5/2*(50)/100', relativeText: '5/2*(50)/100'),
        (source: '(5+5)%', directText: '((5+5))/100', relativeText: '((5+5))/100'),
        (
          source: '5*(5+5)%',
          directText: '5*((5+5))/100',
          relativeText: '5*((5+5))/100'
        ),
        (source: '5/(50%)', directText: '5/((50)/100)', relativeText: '5/((50)/100)'),
        (
          source: 'sqrt(50%)',
          directText: 'sqrt((50)/100)',
          relativeText: 'sqrt((50)/100)'
        ),
        (
          source: 'sin(50%)',
          directText: 'sin((50)/100)',
          relativeText: 'sin((50)/100)'
        ),
        (
          source: 'abs(50%)',
          directText: 'abs((50)/100)',
          relativeText: 'abs((50)/100)'
        ),
        (source: '1,200×50%', directText: '1200*(50)/100', relativeText: '1200*(50)/100'),
        (
          source: 'sqrt 25% + log 1e3%',
          directText: 'sqrt((25)/100) + log((1e3)/100)',
          relativeText: 'sqrt((25)/100) + log((1e3)/100)'
        ),
        (source: '50%+50%', directText: '(50)/100+(50)/100', relativeText: '(50)/100+(50)/100'),
        (source: '5%+5%', directText: '(5)/100+(5)/100', relativeText: '(5)/100+(5)/100'),
        (source: '10%+10%', directText: '(10)/100+(10)/100', relativeText: '(10)/100+(10)/100'),
        (source: '5%-2', directText: '(5)/100-2', relativeText: '(5)/100-2'),
        (source: '50+10%', directText: '50+(10)/100', relativeText: '(50)*(100+(10))/100'),
        (source: '50+10%*2', directText: '50+(10)/100*2', relativeText: '50+(10)/100*2'),
        (source: '50+10%/2', directText: '50+(10)/100/2', relativeText: '50+(10)/100/2'),
        (source: '50+2^10%', directText: '50+2^(10)/100', relativeText: '50+2^(10)/100'),
        (
          source: '50+(20+30)%',
          directText: '50+((20+30))/100',
          relativeText: '(50)*(100+((20+30)))/100'
        ),
        // 中文：`(20+10%)%` 这种套法里 `%` 一个一个吃掉：外面那个括号组先展开，里面那个 `10%`
        //       再展开，两种情况两种模式逐字节相同（相对模式对含 `%` 的括号组不折）。
        // English: in a nesting like `(20+10%)%` the `%`s are eaten one at a time — the outer bracket
        //          group expands first and the inner `10%` after it, byte for byte the same in both modes
        //          (the relative fold leaves a bracket group containing a `%` alone).
        (
          source: '50+(20+10%)%',
          directText: '50+((20+(10)/100))/100',
          relativeText: '50+((20+(10)/100))/100'
        ),
        (
          source: 'max(1,50+10%)',
          directText: 'max(1,50+(10)/100)',
          relativeText: 'max(1,(50)*(100+(10))/100)'
        ),
        (
          source: 'sqrt(50+10%)',
          directText: 'sqrt(50+(10)/100)',
          relativeText: 'sqrt((50)*(100+(10))/100)'
        ),
      ];

      // 中文：逐个形状把**两种模式**的归一化文本钉死；值由「文本 + 已钉住的读法」决定。
      // English: pin the normalised text of **both modes** shape by shape; the value follows from that
      //          text under the readings pinned elsewhere.
      for (final row in rows) {
        expect(normalized(row.source), row.directText, reason: row.source);
        expect(normalized(row.source, relative: true), row.relativeText,
            reason: row.source);
      }
    });

    test('指数里再套一个百分数：读得动，不是一句错（值谁也不给，遂不钉值）', () {
      // 中文：`5/50%^50%` 是本轮唯一一条**与谁都不同**的形状，写在这里是为了不让它悄悄变成一句错：
      //       修之前 1.0000000000000001e-103、修之后 56294995342131.2、qalc 给 1E101。
      //       它是「指数位置上又是一个百分数」——厂商手册一个字都没写。本轮对幂的吞并有一条护栏
      //       （`_percentPowerTailPattern` 的两个负向前瞻）：指数自己若是百分数字面量就不吞，
      //       否则后面那个 `%` 会没有操作数，**一个读得动的输入会变成一句错**。所以这里钉的是
      //       「读得动 + 两种模式同值」，而不是一个数。
      // English: `5/50%^50%` is the one shape this round leaves agreeing with nobody; it is recorded so
      //          that it does not quietly become an error: before the fix 1.0000000000000001e-103,
      //          after it 56294995342131.2, qalc 1E101. It is "a percentage in the exponent position",
      //          about which the vendor's manual says nothing. The power absorption carries a guard rail
      //          (the two negative lookaheads of `_percentPowerTailPattern`): when the exponent is itself
      //          a percentage literal it is not absorbed, because otherwise the following `%` would be
      //          left without an operand and **a readable input would turn into an error**. So what is
      //          pinned here is "it reads, and both modes agree", not a number.
      expect(parse('5/50%^50%'), isNotNull);
      expect(parse('5/50%^50%', relative: true), parse('5/50%^50%'));
      expect(normalized('5/50%^50%'), '5/((50)/100)^(50)/100');
      // 中文：同一族里另外两条：括号里套百分数的指数、以及被除号吃掉的半截指数——两条也都读得动。
      // English: two more of the same family — an exponent that is a bracketed percentage, and a
      //          half-eaten exponent under a division — both still read.
      expect(parse('5/50%^(50%)'), isNotNull);
      expect(parse('5/50%^(50%)', relative: true), parse('5/50%^(50%)'));
    });
  });

  group('边界与护栏：折不动就不折，绝不新造失败', () {
    test('归一化之后仍然裸露的 % 两种模式都读不懂', () {
      // 中文：`pi%`、`3!%` 到了解析器里还是一个裸露的 `%`（`_replacePercent` 只展开数字或
      //       括号组后面的），两种模式都必须抛同一句错——relative 不许把它们变得「能算」。
      // English: `pi%` and `3!%` still carry a bare `%` by the time the parser sees them
      //          (`_replacePercent` only expands a `%` after a number or a bracket group), and both
      //          modes must throw the same error — relative must not make them computable.
      for (final source in <String>['pi%', '3!%', 'e%']) {
        expect(() => parse(source), throwsFormatException, reason: source);
        expect(() => parse(source, relative: true), throwsFormatException,
            reason: source);
      }
    });

    test('括号不配对时整段放弃折叠，回落 direct 的读法', () {
      // 中文：`(50+10%` 少一个右括号。折叠放弃 = 归一化文本与 direct 逐字节相同，
      //       于是两种模式在同一个畸形输入上给同一句错，而不是一边多一点什么。
      // English: `(50+10%` is missing a closing bracket. Giving up the fold means the normalised text
      //          is byte-for-byte direct's, so both modes answer the same malformed input with the same
      //          error rather than one of them inventing something.
      expect(normalized('(50+10%', relative: true), normalized('(50+10%'));
      expect(() => parse('(50+10%'), throwsFormatException);
      expect(() => parse('(50+10%', relative: true), throwsFormatException);
    });

    test('括号里的百分数被折之后，外面那个 % 仍然读得懂', () {
      // 中文：`(20+10%)%` 这种形状**里面不折**（折了 `_replacePercent` 就不认得那个括号组了），
      //       所以相对模式不会比 direct 多出一句「读不懂」——两边同值 50.201。
      // English: a shape like `(20+10%)%` is left **unfolded inside** (folding it would stop
      //          `_replacePercent` recognising the bracket group), so relative does not answer "cannot
      //          read" where direct reads fine — both give 50.201.
      expect(parse('50+(20+10%)%'), closeTo(50.201, 1e-12));
      expect(parse('50+(20+10%)%', relative: true), closeTo(50.201, 1e-12));
    });

    test('形状不成立时不折：运算符后面的一元符号、空项、单个项', () {
      // 中文：折的判据之一是「这个 `+`/`-` 是**二叉**的」——它前面最近的非空格字符必须是一个值的
      //       结尾。于是 `50*+10%` 里那个 `+` 是一元的，整段只有一项，不折（两种模式读法相同）。
      //       这一条挡的是「相对模式在畸形输入上比 direct 多出一句错」那一类。
      // English: one of the fold's tests is "this `+`/`-` is **binary**" — the nearest non-space
      //          character before it must end a value. So the `+` in `50*+10%` is unary, the whole
      //          thing is one term, and nothing folds (both modes read it the same). This is what stops
      //          relative mode from answering an extra error on malformed input where direct copes.
      for (final source in <String>['50*+10%', '50+', '10%']) {
        expect(normalized(source, relative: true), normalized(source),
            reason: source);
      }
      // 中文：`50*+10%` 在 direct 下读得动（`50*+(10)/100` = 5），相对模式必须同样读得动；
      //       `50+` 两边都读不动——**"读得动/读不动"这件事本身也不许随模式变**。
      // English: `50*+10%` reads under direct (`50*+(10)/100` = 5) and must read under relative too;
      //          `50+` reads under neither — **whether it reads at all must not change with the mode**.
      expect(parse('50*+10%', relative: true), parse('50*+10%'));
      expect(parse('10%', relative: true), parse('10%'));
      expect(() => parse('50+'), throwsFormatException);
      expect(() => parse('50+', relative: true), throwsFormatException);
    });

    test('带符号与括号的百分数：`50--10%`、`50-(-10%)`、`50+(10)%`', () {
      expect(parse('50--10%', relative: true), closeTo(55, 1e-12));
      expect(parse('50-(-10%)', relative: true), closeTo(55, 1e-12));
      expect(parse('-50+10%', relative: true), closeTo(-55, 1e-12));
      expect(parse('50+(10)%', relative: true), closeTo(55, 1e-12));
      expect(parse('0-10%', relative: true), closeTo(0, 1e-12),
          reason: '0 的 10% 还是 0（qalc 同值）');
    });
  });

  group('模式只影响求值：另外五个消费者看到的文本一个字不改', () {
    test('相对模式折出来的文本仍然是引擎读得懂的那一种', () {
      // 中文：折法只把 `%` 改写成 `/100` 因子与括号，所以**引擎照样被问到**——两种模式下
      //       「先问引擎、问不到再回落旧解析器」这条权威结构完全一样。若相对模式改走「不问引擎」，
      //       同一个输入就会按设置落到两个不同的权威上（`°` 那一轮修的就是这个）。
      // English: the fold only rewrites `%` into `/100` factors and brackets, so **the engine is still
      //          asked** — the authority structure ("ask the engine, fall back to the legacy parser")
      //          is identical in both modes. Had relative taken the "do not ask the engine" road, one
      //          input would land on two different authorities depending on a setting (exactly what the
      //          `°` round fixed).
      expect(engineExpressionFor('50+10%', relativePercent: true),
          isA<TranslatedExpression>());
      expect(engineExpressionFor('50+10%'), isA<TranslatedExpression>());
      expect(engineExpressionFor('pi%', relativePercent: true),
          isA<UntranslatableExpression>(),
          reason: '裸露的 % 两种模式都翻译不了');
    });

    test('`canRead` / `canExpress` 在两种模式下判断相同', () {
      // 中文：名字层不传模式（它读的是默认归一化），而折法既不新增也不删除「读得懂 / 翻得过去」
      //       的构造——所以它对同一批输入的判断必须与相对模式下真正被求值的那段文本一致。
      // English: the name layer passes no mode (it reads the default normalisation) and the fold neither
      //          adds nor removes readable/translatable constructs, so its verdicts on a batch of inputs
      //          must match what the relative path actually evaluates.
      for (final source in <String>[
        '50+10%',
        'x+10%',
        'sqrt(50+10%)',
        'npr(5,2)+10%',
        'pi%',
        '50+(20+10%)%',
        '10%+10%',
      ]) {
        // 中文：名字层读的是**默认**归一化文本，求值那一侧读的是 relative 文本；两者在
        //       「读得懂 / 翻得过去」上必须给出同一个答案，否则「谁看到了什么」就分成两半了。
        //       （两条都要过一遍归一化：这些判据的入参本来是源码。）
        // English: the name layer reads the **default** normalised text while evaluation reads the
        //          relative one; the two must answer identically on "readable / translatable", or "who
        //          saw what" splits in two. (Both go through normalisation: those judgements take a
        //          source.)
        final plain = normalized(source);
        final folded = normalized(source, relative: true);
        expect(AppEngineVocabulary.canRead(folded),
            AppEngineVocabulary.canRead(plain),
            reason: source);
        expect(AppEngineVocabulary.canExpress(folded),
            AppEngineVocabulary.canExpress(plain),
            reason: source);
        expect(
          engineExpressionFor(source, relativePercent: true)
              is UntranslatableExpression,
          engineExpressionFor(source) is UntranslatableExpression,
          reason: source,
        );
      }
    });

    test('变量引用在折前折后是同一批名字', () {
      // 中文：折成**乘法因子**而不是加法项，正是为了这一条——`x+10%` 折完 `x` 仍然只出现一次，
      //       于是 `variable_references` 那一层（不传模式）看到的名字集合不变。
      // English: folding into a **multiplicative factor** rather than an additive term is precisely for
      //          this: after folding, `x` in `x+10%` still appears once, so the `variable_references`
      //          layer (which passes no mode) sees the same set of names.
      final folded = normalized('x+10%', relative: true);
      expect(folded, '(x)*(100+(10))/100');
      expect(RegExp('x').allMatches(folded).length, 1,
          reason: '名字只出现一次——加法形式会把它抄成两份');
      // 中文：变量替换那一层（不传模式）拿到折完的文本之后照常工作，而且值是相对的。
      // English: the variable-substitution layer (which passes no mode) works on the folded text as
      //          usual, and the value it yields is the relative one.
      final resolved = resolveVariableReferences(folded, const {'x': '4'});
      expect(ExpressionParser(resolved, degreeMode: false).parse(),
          closeTo(4.4, 1e-12));
    });
  });

  group('归一化文本的形状', () {
    test('折出来的形状逐条', () {
      expect(normalized('50+10%', relative: true), '(50)*(100+(10))/100');
      expect(normalized('50-10%', relative: true), '(50)*(100-(10))/100');
      expect(normalized('50+10%+10%', relative: true),
          '((50)*(100+(10))/100)*(100+(10))/100');
      expect(normalized('2*3+10%', relative: true), '(2*3)*(100+(10))/100');
      expect(normalized('sqrt(50+10%)', relative: true),
          'sqrt((50)*(100+(10))/100)');
      expect(normalized('50+10%', relative: false), '50+(10)/100',
          reason: 'direct 那条路一个字没动');
    });
  });
}
