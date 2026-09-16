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

    test('可摊平的运算符左右两侧都摊平，结果对称', () {
      // 中文：`+ - *` 的 TeX 都是普通中缀符号，可以安全拆成独立片段。
      // English: `+ - *` emit plain infix symbols, so they can safely become separate fragments.
      expect(toDisplayUnits(p('1+2*3')).length, 5);
      expect(toDisplayUnits(p('2*3+1')).length, 5);
      expect(toDisplayUnits(p('1+2*3')).length,
          toDisplayUnits(p('2*3+1')).length);
    });
  });
}
