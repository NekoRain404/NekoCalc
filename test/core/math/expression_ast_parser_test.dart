import 'package:flutter_test/flutter_test.dart';
// 中文：节点类型与 toDisplayUnits 都由 expression_ast_parser.dart 转出，
//       再单独 import expr_node.dart 会被 lint 判为多余导入。
// English: Node types and toDisplayUnits are re-exported by expression_ast_parser.dart, so a
//          separate expr_node.dart import would be flagged as an unnecessary import.
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';

void main() {
  const parser = ExpressionAstParser();
  ExprNode p(String s) => parser.parse(s);

  group('基础节点', () {
    test('数字', () {
      final n = p('30') as NumberNode;
      expect(n.literal, '30');
      expect(n.start, 0);
      expect(n.end, 2);
    });

    test('小数与科学计数法保持原样字面量', () {
      expect((p('1.5e3') as NumberNode).literal, '1.5e3');
    });

    test('常量与变量', () {
      final pi = p('pi') as ConstantNode;
      expect(pi.name, 'pi');
      final ans = p('Ans') as VariableNode;
      expect(ans.name, 'Ans');
    });
  });

  group('源码区间精确性', () {
    test('二元运算的两个操作数各自带正确区间', () {
      final b = p('12+34') as BinaryNode;
      expect(b.op, '+');
      expect((b.left as NumberNode).start, 0);
      expect((b.left as NumberNode).end, 2);
      expect((b.right as NumberNode).start, 3);
      expect((b.right as NumberNode).end, 5);
    });

    test('函数调用的区间覆盖整个调用', () {
      final f = p('sin(30)') as FunctionNode;
      expect(f.name, 'sin');
      expect(f.start, 0);
      expect(f.end, 7);
      expect((f.args.single as NumberNode).literal, '30');
    });

    test('显式括号产生 GroupNode 且区间含括号', () {
      final g = p('(1+2)') as GroupNode;
      expect(g.start, 0);
      expect(g.end, 5);
    });
  });

  group('隐式乘法', () {
    test('2x 解析为 ImplicitProductNode', () {
      final m = p('2x') as ImplicitProductNode;
      expect((m.left as NumberNode).literal, '2');
      expect((m.right as VariableNode).name, 'x');
    });

    test('3(x+1) 解析为隐式乘法', () {
      final m = p('3(1+2)') as ImplicitProductNode;
      expect(m.start, 0);
      // 中文：源码 '3(1+2)' 只有 6 个字符，区间取源码长度 [0, 6)（任务书此处写作 7，
      //       但区间必须落在源码内，否则点击定位会越过输入框末尾）。
      // English: The source '3(1+2)' is only 6 characters, so the span is [0, 6); the brief
      //          said 7, but spans must stay inside the source for tap-to-cursor mapping.
      expect(m.end, 6);
    });
  });

  group('不完整输入不得抛异常', () {
    test('未闭合的函数产生 ParseErrorNode 而不是异常', () {
      final n = p('sin(');
      expect(n, isA<ParseErrorNode>());
      final e = n as ParseErrorNode;
      expect(e.start, 0);
      expect(e.end, 4);
    });

    test('悬空运算符可解析', () {
      final n = p('2+');
      expect(n, isA<ExprNode>());
      expect(n.start, 0);
      expect(n.end, 2);
    });

    test('空表达式返回零长度节点', () {
      final n = p('');
      expect(n.start, 0);
      expect(n.end, 0);
    });
  });

  group('toDisplayUnits 摊平', () {
    test('把最外层运算链摊平成 操作数-运算符-操作数 序列', () {
      final units = toDisplayUnits(p('sin(30)+log(2)'));
      expect(units.length, 3);
      expect(units[0], isA<FunctionNode>());
      expect(units[1], isA<OperatorNode>());
      expect((units[1] as OperatorNode).op, '+');
      expect(units[2], isA<FunctionNode>());
    });

    test('只有单个操作数时返回单元素序列', () {
      final units = toDisplayUnits(p('42'));
      expect(units.length, 1);
      expect(units.single, isA<NumberNode>());
    });

    test('摊平后每个单元的区间连续且落在源码内', () {
      const src = '1+2*3';
      final units = toDisplayUnits(p(src));
      for (final u in units) {
        expect(u.start, greaterThanOrEqualTo(0));
        expect(u.end, lessThanOrEqualTo(src.length));
        expect(u.start, lessThanOrEqualTo(u.end));
      }
    });

    test('包裹操作数的运算符保持整体，不摊平', () {
      // 中文：`/` 生成 \frac{左}{右}、`^` 生成 {左}^{右}，这两个运算符的 TeX 需要两个操作数
      //       共处一个片段；一旦被摊平，渲染层只会拿到一个孤立的运算符，分数和幂就消失了。
      // English: `/` emits \frac{}{} and `^` emits {}^{}; their TeX needs both operands in one
      //          fragment, so splitting them would hand the renderer a bare operator and lose the
      //          fraction or the exponent.
      final fraction = toDisplayUnits(p('a/b')).single;
      expect(fraction, isA<BinaryNode>());
      expect((fraction as BinaryNode).op, '/');
      expect(toDisplayUnits(p('x^2')).length, 1);
      expect(toDisplayUnits(p('(a+b)/2')).length, 1);

      final units = toDisplayUnits(p('x^2+1'));
      expect(units.length, 3);
      final power = units[0] as BinaryNode;
      expect(power.op, '^');
      expect(power.start, 0);
      expect(power.end, 3);
      expect(units[1], isA<OperatorNode>());
      expect((units[1] as OperatorNode).op, '+');
      expect(units[2], isA<NumberNode>());
    });

    test('运算符单元的区间指向运算符自身，不含两侧空格', () {
      // 中文：渲染层把一次点击映射回输入框里的字符位置，靠的正是这两个字段；区间若被写成
      //       操作数边界（左操作数的 end / 右操作数的 start），点运算符就会跳到操作数那一侧。
      //       `12 + 34` 里 `+` 独自占据 [3,4)，两侧的空格都不属于它。
      // English: Mapping a tap back to a character position in the input rests on exactly these two
      //          fields; were the span taken from the operand boundaries (the left operand's end /
      //          the right operand's start), tapping an operator would jump to one of the operands.
      //          In `12 + 34` the `+` owns [3,4) alone; neither surrounding space belongs to it.
      const src = '12 + 34';
      final op = toDisplayUnits(p(src))[1] as OperatorNode;
      expect(op.op, '+');
      expect(op.start, 3);
      expect(op.end, 4);
      expect(src.substring(op.start, op.end), '+');
    });

    test('可摊平的运算符左右两侧都摊平，结果对称', () {
      // 中文：`+ - *` 的 TeX 都是普通中缀符号，可以安全拆成独立片段。
      // English: `+ - *` emit plain infix symbols, so they can safely become separate fragments.
      expect(toDisplayUnits(p('1+2*3')).length, 5);
      expect(toDisplayUnits(p('2*3+1')).length, 5);
      expect(toDisplayUnits(p('1+2*3')).length,
          toDisplayUnits(p('2*3+1')).length);
    });
  });

  group('度分秒字面量', () {
    // 中文：**这一个节点是表达式行排得出 `3°30′0″` 的原因**——从前 `°` 会让整段降级成
    //       `ParseErrorNode`（TeX 变成一段 `\text{…}` 字面文本）。判据与取值那条路共用同一个函数
    //       （`sexagesimal_literal.dart`），所以屏幕上排成公式的字符串与算得出值的字符串永远是同一个。
    // English: **this node is why the expression line can typeset `3°30′0″`** — `°` used to degrade
    //          the whole string to a `ParseErrorNode` (TeX became a `\text{…}` blob). The judgement is
    //          shared with the value road (one function, `sexagesimal_literal.dart`), so the string that
    //          typesets as a formula and the one that evaluates are always the same string.
    test('三段：一个节点覆盖整段，区间含三个记号', () {
      final n = p('3°30′0″') as SexagesimalNode;
      expect(n.degrees, '3');
      expect(n.minutes, '30');
      expect(n.seconds, '0');
      expect(n.start, 0);
      expect(n.end, 7);
    });

    test('缺席的段是 `null`（`3°0′` 的分在场且是 `0`，`3°` 的分不在场）', () {
      final withZero = p('3°0′') as SexagesimalNode;
      expect(withZero.minutes, '0');
      expect(withZero.seconds, isNull);
      final degreesOnly = p('3°') as SexagesimalNode;
      expect(degreesOnly.degrees, '3');
      expect(degreesOnly.minutes, isNull);
      expect(degreesOnly.end, 2);
    });

    test('字面量在整条表达式里：外面照旧是隐式乘法与运算符', () {
      final product = p('2 3°30′') as ImplicitProductNode;
      expect((product.right as SexagesimalNode).minutes, '30');
      // 中文：`3°30′5` **仍然是一个字面量**：秒那一段的记号可以省（`3°30′5` = `3°30′5″`，
      //       与归一化的 `degangle(3+30/60+5/3600)` 是同一句话）。**`″` 之后字面量才关上**，
      //       再跟一个数就是另一个因子（隐式乘法）：`3°30′0″5`。
      // English: `3°30′5` **is still one literal**: the seconds section may drop its mark (`3°30′5` =
      //          `3°30′5″`, the same sentence normalisation writes as `degangle(3+30/60+5/3600)`).
      //          **`″` is what closes the literal**, so a number after it is another factor (an
      //          implicit product): `3°30′0″5`.
      final unmarkedSeconds = p('3°30′5') as SexagesimalNode;
      expect(unmarkedSeconds.minutes, '30');
      expect(unmarkedSeconds.seconds, '5');
      final trailing = p('3°30′0″5') as ImplicitProductNode;
      expect((trailing.left as SexagesimalNode).seconds, '0');
      expect((trailing.right as NumberNode).literal, '5');
    });

    test('不是字面量的形状照旧降级（与归一化的拒绝同一份判据）', () {
      for (final source in <String>['30′', '3°′30″', '3°30′″', '1_000°30′']) {
        expect(p(source), isA<ParseErrorNode>(),
            reason: '`$source` 不是字面量：取值那条路也拒绝它，两边必须一致');
      }
      // 中文：`30° 2` —— 空格断开，`30°` 是一个字面量，`2` 是另一个因子（隐式乘法）。
      // English: `30° 2` — the space breaks it: `30°` is one literal and `2` another factor.
      expect(p('30° 2'), isA<ImplicitProductNode>());
    });
  });
}
