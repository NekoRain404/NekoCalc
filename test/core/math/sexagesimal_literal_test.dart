import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/sexagesimal_literal.dart';

/// 中文：**度分秒字面量的文法与取值**——一张逐条的对照表，每一行都带着它的出处。
///
///       - **厂商定下的**：HiPER 手册 v12.0 `DEGREES, MINUTES, SECONDS` 一节
///         （`pdftotext -layout` 第 246–253 行）只有两组例子：三段的 `3 D°M′S 30 D°M′S 0 D°M′S`
///         → `3.5`，与 `3.5` → `3°30´ 0´´`。三段齐全那一行是**逐字**的依据；其余没有一句。
///       - **参考实现（宿主 `qalc` 5.12.0，本应用同一个 libqalculate）**：缺席的段是 0、记号说了
///         算、小数与超过 60 的分都照算、负号作用于整个量值——本文件在每一行上写出实测值。
///       - **我定的**：`3°30`（尾数不带记号）读作**分**。参考实现读成 `3° × 30`（`90°`），
///         而键盘按出来的中间态**必然**经过它，边打边算会在屏幕上先给出 90、再给出 0。整条论证在
///         `lib/core/math/sexagesimal_literal.dart` 的文件头上。
///
///       归一化产出的**文本**与**值**都在这里钉住：文本一律是 `degangle(度+分/60+秒/3600)`，
///       与角度模式无关；值由求值器按模式给（DEG 下就是那个度数，RAD 下是它的弧度）。
/// English: **the DMS literal's grammar and value** — a row-by-row table, each row carrying where it
///          comes from.
///
///          - **settled by the vendor**: HiPER manual v12.0's `DEGREES, MINUTES, SECONDS` section
///            (`pdftotext -layout` lines 246–253) holds exactly two examples — the three-part
///            `3 D°M′S 30 D°M′S 0 D°M′S` → `3.5` and `3.5` → `3°30´ 0´´`. The complete three-part row is
///            the **verbatim** ground; nothing else has a sentence.
///          - **the reference** (host `qalc` 5.12.0, the same libqalculate this app ships): an absent
///            part is 0, the mark says which unit, fractional parts and minutes past 60 are arithmetic,
///            and a minus sign applies to the whole magnitude — every row below writes its measured
///            value.
///          - **decided here**: `3°30` (an unmarked trailing number) reads as **minutes**. The
///            reference reads it as `3° × 30` (`90°`), and the states the keypad necessarily passes
///            through include it, so as-you-type evaluation would show 90 and then 0. The full
///            argument is on `lib/core/math/sexagesimal_literal.dart`'s header.
///
///          Both the **text** normalisation writes and the **value** are pinned here: the text is
///          always `degangle(degrees+minutes/60+seconds/3600)` and does not depend on the angle mode,
///          while the value comes from the evaluator in that mode (the degree count under DEG, its
///          radian value under RAD).
void main() {
  double value(String source, {required bool degreeMode}) =>
      ExpressionParser(source, degreeMode: degreeMode).parse();

  group('三段与缺席的段：值', () {
    test('三段齐全：手册那个例子（厂商逐字定下）', () {
      // 中文：手册原文 `3 D°M′S 30 D°M′S 0 D°M′S` → `3.5`。
      // English: the manual's own line: `3 D°M′S 30 D°M′S 0 D°M′S` → `3.5`.
      expect(value('3°30′0″', degreeMode: true), closeTo(3.5, 1e-12));
      expect(value('3°30′0″', degreeMode: false), closeTo(0.061086523819801536, 1e-12));
    });

    test('缺秒（`3°30′`）= 3.5：缺席的那一段是 0（参考实现同向）', () {
      expect(value('3°30′', degreeMode: true), closeTo(3.5, 1e-12));
      expect(value('3°30′', degreeMode: false), closeTo(0.061086523819801536, 1e-12));
      // 中文：宿主实测 `qalc -s "angle deg" "3°30′"` = `3.5°`。
      // English: host measurement `qalc -s "angle deg" "3°30′"` = `3.5°`.
    });

    test('缺分（`3°0′30″`）= 3 + 30/3600，与「只有秒」同值（记号说了算）', () {
      expect(value('3°0′30″', degreeMode: true), closeTo(3.0083333333333333, 1e-12));
      expect(value('3°0′30″', degreeMode: false),
          closeTo(0.052505321664162746, 1e-15));
      // 中文：宿主实测 `3°0′30″` = `3.008333333°`、`3°30"` = `3.008333333°`——同一个数。
      // English: host measurements `3°0′30″` = `3.008333333°` and `3°30"` = `3.008333333°` — one number.
      expect(value('3°30″', degreeMode: true), closeTo(3.0083333333333333, 1e-12));
      expect(value('3°30″', degreeMode: false),
          closeTo(0.052505321664162746, 1e-15));
    });

    test('只有度（`3°`）：老路一个字节没动——DEG 下 3、RAD 下 0.05235987755982988', () {
      // 中文：**`cc6ce91` 那条路**。它在本轮之前就工作，`expression_parser_test.dart` 那一组
      //       逐条钉着它；这里再钉一次是因为新的字面量文法就住在它旁边。
      // English: **`cc6ce91`'s road.** It worked before this round and
      //          `expression_parser_test.dart`'s group pins it row by row; it is pinned again here
      //          because the new literal grammar lives right next to it.
      expect(value('3°', degreeMode: true), closeTo(3, 1e-12));
      expect(value('3°', degreeMode: false), closeTo(0.05235987755982988, 1e-15));
    });

    test('小数与超过 60 的段：就是那条算式（参考实现同向）', () {
      expect(value('3.5°30′', degreeMode: true), closeTo(4, 1e-12));
      expect(value('3°30.5′', degreeMode: true), closeTo(3.5083333333333333, 1e-12));
      expect(value('3°90′', degreeMode: true), closeTo(4.5, 1e-12));
      expect(value('0°0′1″', degreeMode: true), closeTo(0.0002777777777777778, 1e-15));
      // 中文：宿主实测 `3.5°30′` = `4°`、`3°30.5′` = `3.508333333°`、`3°90′` = `4.5°`。
      // English: host measurements `3.5°30′` = `4°`, `3°30.5′` = `3.508333333°`, `3°90′` = `4.5°`.
    });

    test('负号：作用在整个量值上，`-(3°30′)` 与 `-3°30′` 是同一个数', () {
      expect(value('-3°30′', degreeMode: true), closeTo(-3.5, 1e-12));
      expect(value('-3°30′', degreeMode: false), closeTo(-0.061086523819801536, 1e-12));
      // 中文：**判据是「加括号不许换值」**：`-3°30′` 与 `-(3°30′)` 恒等，所以负号留在字面量外面。
      //       另一条读法（-3 度 + 30 分 = -2.5）会让两者不等，而屏幕上分不出为什么。
      //       宿主实测 `-3°30′` = `−3.5°`。
      // English: **the test is "brackets must not change the value"**: `-3°30′` is identical to
      //          `-(3°30′)`, so the sign stays outside the literal. The other reading (−3 degrees plus
      //          30 minutes = −2.5) would make the two differ with nothing on screen to say why. Host
      //          measurement: `-3°30′` = `−3.5°`.
      expect(value('-(3°30′)', degreeMode: true), closeTo(-3.5, 1e-12));
    });

    test('中间态（不带记号的尾数）：读作下一段，这一条与参考实现不同', () {
      // 中文：`3°30` 是键盘按到一半的**必然**状态（`3` `D°M'S` `3` `0`），`3°30′0` 是再按一次的
      //       状态。照参考实现（`90°`、`0°`）读，屏幕上会先给出两个错值再落到 3.5。
      // English: `3°30` is a state the keypad **necessarily** passes through (`3` `D°M'S` `3` `0`) and
      //          `3°30′0` is the next one. Under the reference's reading (`90°`, `0°`) the screen would
      //          show two wrong values before landing on 3.5.
      expect(value('3°30', degreeMode: true), closeTo(3.5, 1e-12));
      expect(value('3°30', degreeMode: false), closeTo(0.061086523819801536, 1e-12));
      expect(value('3°30′0', degreeMode: true), closeTo(3.5, 1e-12));
      expect(value('30°2', degreeMode: true), closeTo(30.033333333333335, 1e-12));
      // 中文：宿主实测（参考实现的读法，本应用**故意不照做**）：`3°30` = `90°`、`3°30′0` = `0°`。
      // English: host measurements (the reference's reading, which this app **deliberately does not
      //          follow**): `3°30` = `90°`, `3°30′0` = `0°`.
    });

    test('字面量之后紧跟的数：另一个数，隐式乘法（参考实现同向）', () {
      expect(value('3°30′0″5', degreeMode: true), closeTo(17.5, 1e-12));
      // 中文：宿主实测 `3°30′0″5` = `17.5°`。
      // English: host measurement `3°30′0″5` = `17.5°`.
      expect(value('2*3°30′', degreeMode: true), closeTo(7, 1e-12));
    });
  });

  group('归一化写出来的文本：一份、且与角度模式无关', () {
    test('每一段的数原样转写，不预先算成小数', () {
      expect(ExpressionParser.normalizeExpressionInput('3°30′0″'),
          'degangle(3+30/60+0/3600)');
      expect(
          ExpressionParser.normalizeExpressionInput('3°30′'), 'degangle(3+30/60)');
      expect(ExpressionParser.normalizeExpressionInput('3°0′30″'),
          'degangle(3+0/60+30/3600)');
      expect(ExpressionParser.normalizeExpressionInput('3°30″'),
          'degangle(3+30/3600)');
      expect(ExpressionParser.normalizeExpressionInput('1°20′'),
          'degangle(1+20/60)');
      // 中文：**只有度时逐字节等于老写法**——`cc6ce91` 那条路走的就是这一个字符串。
      // English: **degrees alone is byte for byte the old spelling** — the string `cc6ce91`'s road
      //          travels.
      expect(ExpressionParser.normalizeExpressionInput('30°'), 'degangle(30)');
      expect(ExpressionParser.normalizeExpressionInput('-3°30′'),
          '-degangle(3+30/60)');
    });

    test('文本里没有模式：DEG 与 RAD 拿到的是同一个字符串', () {
      // 中文：归一化**没有**角度模式参数（`normalizeExpressionInput` 的签名里没有它），所以
      //       「同一个输入两个权威」那种危险在这条路上不存在。模式只在求值器那一侧
      //       （`ExpressionParser.degreeMode`，也就是 `degangle` 那一支）。
      // English: normalisation has **no** angle-mode parameter (`normalizeExpressionInput`'s signature
      //          has none), so the "one input, two authorities" hazard does not exist on this road.
      //          The mode lives on the evaluator's side only (`ExpressionParser.degreeMode`, the
      //          `degangle` arm).
      const source = '3°30′0″';
      expect(ExpressionParser.normalizeExpressionInput(source),
          ExpressionParser.normalizeExpressionInput(source));
      expect(ExpressionParser.normalizeExpressionInput(source), isNot(contains('rad')));
      expect(ExpressionParser.normalizeExpressionInput(source), isNot(contains('deg(')));
    });

    test('字面量与整条表达式一起：外面的运算符不受影响', () {
      expect(ExpressionParser.normalizeExpressionInput('sin(30°30′)'),
          'sin(degangle(30+30/60))');
      expect(value('sin(30°30′)', degreeMode: true), closeTo(0.5075383629607041, 1e-12));
      expect(value('sin(30°30′)', degreeMode: false), closeTo(0.5075383629607041, 1e-12));
      // 中文：`sin` 在两种模式下都给同一个数——与 `sin(30°)` 那条既有断言同一个形状。
      // English: `sin` answers the same number in both modes — the shape the existing `sin(30°)`
      //          assertion has.
    });
  });

  group('不是字面量的形状：fail-closed（两个解析器都拒绝）', () {
    test('`′`/`″` 单独出现、顺序不对、缺记号时的残段', () {
      for (final source in <String>[
        '30′', // 没有度
        '30″',
        '3°′30″', // 分的位置上只有记号
        '3°30′″', // 秒的位置上只有记号
        '3°30′0″′',
      ]) {
        expect(
          () => value(source, degreeMode: true),
          throwsA(isA<FormatException>()),
          reason: '`$source` 不是度分秒字面量，应用自己的解析器要拒绝它',
        );
      }
    });

    test('空格断开的部分不算一段：`30° 2` 仍是隐式乘法（今天怎么读，现在还怎么读）', () {
      // 中文：**这一条是「不带空格」那条决定的代价说明**：只有紧挨着的写法才是字面量，所以
      //       每一个带空格的输入都保持本轮之前的样子。`30° 2` 归一化之后是 `degangle(30) 2`——
      //       老正则给的是同一串（它也只吃得下 `30°`）。
      // English: **this row spells out the price of "no spaces"**: only adjacent writing is a literal,
      //          so every spaced input keeps the reading it had before this round. `30° 2` normalises
      //          to `degangle(30) 2` — the same string the old regex produced (it too could only read
      //          `30°`).
      expect(ExpressionParser.normalizeExpressionInput('30° 2'), 'degangle(30) 2');
      expect(ExpressionParser.normalizeExpressionInput('3° 30'), 'degangle(3) 30');
    });

    test('名字字符、下划线分组与点开头都不算字面量的起点（沿用老 lookbehind）', () {
      for (final source in <String>['x5°30′', '1_000°30′', '.5°30′']) {
        expect(ExpressionParser.normalizeExpressionInput(source), source,
            reason: '`$source` 一个字都不该被改写');
      }
      // 中文：`(3)5°30′` 反过来**是**字面量：括号不是名字字符，老正则也认它。
      // English: `(3)5°30′` **is** a literal, on the other hand: a bracket is not a name character and
      //          the old regex accepted it too.
      expect(ExpressionParser.normalizeExpressionInput('(3)5°30′'),
          '(3)*degangle(5+30/60)');
    });

    test('ASCII 的 `\'`/`"` 不是记号：本应用只认 `′`/`″`', () {
      // 中文：**这是刻意的**：结果行印出来的是 `°′″`，键盘插进去的也是它们。`'`/`"` 在本应用的
      //       语法里从来没有含义，本轮不发明一个。
      // English: **deliberate**: the result line prints `°′″` and the keypad inserts the same ones.
      //          `'`/`"` have never meant anything in this app's grammar and this round invents no
      //          meaning for them.
      expect(() => value('3°30\'0"', degreeMode: true),
          throwsA(isA<FormatException>()));
    });
  });

  group('读出来的字面量本身（两个消费者共用的那一个函数）', () {
    test('区间覆盖整个字面量，段是原样的数字文本', () {
      final literal = readSexagesimalLiteral('3°30′0″', 0)!;
      expect(literal.degrees, '3');
      expect(literal.minutes, '30');
      expect(literal.seconds, '0');
      expect(literal.start, 0);
      expect(literal.end, 7);
      expect(literal.normalizedCall, 'degangle(3+30/60+0/3600)');
    });

    test('缺席的段是 `null`，不是 `0`（`3°0′` 与 `3°` 是两件事）', () {
      final withZeroMinute = readSexagesimalLiteral('3°0′', 0)!;
      expect(withZeroMinute.minutes, '0');
      expect(withZeroMinute.seconds, isNull);
      final degreesOnly = readSexagesimalLiteral('3°', 0)!;
      expect(degreesOnly.minutes, isNull);
      expect(degreesOnly.end, 2);
    });

    test('不在数字上、或数字后面不是 `°` 时回 null', () {
      expect(readSexagesimalLiteral('30′', 0), isNull);
      expect(readSexagesimalLiteral('x30°', 1), isNull,
          reason: '前面是名字字符：老 lookbehind 逐字沿用');
      expect(readSexagesimalLiteral('3°30′', 2), isNull,
          reason: '从 `0` 开始读不是字面量的起点（`0′` 没有度）');
    });

    test('记号常量与 TeX 写法各只有一份', () {
      expect(SexagesimalMarks.degree, '°');
      expect(SexagesimalMarks.minute, '′');
      expect(SexagesimalMarks.second, '″');
      expect(SexagesimalMarks.degreeTex, r'^\circ');
      expect(SexagesimalMarks.minuteTex, "'");
      expect(SexagesimalMarks.secondTex, "''");
      expect(SexagesimalMarks.texSeparator, r'\,');
    });
  });
}
