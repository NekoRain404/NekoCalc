import 'package:flutter_test/flutter_test.dart';
// 中文：节点类型与 toDisplayUnits 由 expression_ast_parser.dart 转出，故无须再单独 import。
// English: Node types and toDisplayUnits are re-exported by expression_ast_parser.dart, so no
//          separate expr_node.dart import is needed.
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';

void main() {
  const parser = ExpressionAstParser();
  const tex = TexEmitter();
  String t(String s) => tex.emit(parser.parse(s));

  test('数字原样输出', () {
    expect(t('30'), '30');
    expect(t('1.5'), '1.5');
  });

  test('除号产生真正的分数堆叠', () {
    expect(t('a/b'), r'\frac{a}{b}');
  });

  test('幂产生上标而非 ^ 字符', () {
    expect(t('x^2'), 'x^{2}');
  });

  test('嵌套分数', () {
    expect(t('(a+b)/2'), r'\frac{a+b}{2}');
  });

  test('sqrt 产生真根号，且不再保留括号', () {
    expect(t('sqrt(x)'), r'\sqrt{x}');
  });

  test('cbrt 与 root 产生带次数的根号', () {
    expect(t('cbrt(x)'), r'\sqrt[3]{x}');
    expect(t('root(3,x)'), r'\sqrt[3]{x}');
  });

  test('三角函数用 LaTeX 函数名，保持正体', () {
    expect(t('sin(x)'), r'\sin\left(x\right)');
  });

  test('log 带下标 10', () {
    expect(t('log(x)'), r'\log_{10}\left(x\right)');
  });

  test('常量映射到希腊字母', () {
    expect(t('pi'), r'\pi');
    expect(t('e'), 'e');
  });

  test('阶乘是后缀', () {
    expect(t('x!'), 'x!');
  });

  test('显式括号在 TeX 中按需保留', () {
    expect(t('(1+2)*3'), r'\left(1+2\right)\cdot 3');
  });

  test('除法不需要显式括号，视觉分组由分数本身提供', () {
    expect(t('(a+b)/(c+d)'), r'\frac{a+b}{c+d}');
  });

  test('不完整输入降级为原文，不产生非法 TeX', () {
    expect(t('sin('), r'\text{sin(}');
  });

  test('emitUnits 按序产出', () {
    final units = toDisplayUnits(parser.parse('1+2'));
    expect(tex.emitUnits(units), ['1', '+', '2']);
  });

  // 中文：下面四条锁住转义与函数名的确切写法，四条都经渲染层逐条验证过。前三条是 TeX 本身的
  //       规矩（`%` 是注释符、`_` 是下标标记、反斜杠在 `\text{}` 里写作 `\textbackslash`），
  //       第四条 `\operatorname` 后的花括号是本引擎的额外要求，真 KaTeX 里只是普通分组。
  // English: The four tests below pin the exact spellings of the escapes and the function name, and
  //          all four were verified through the renderer. The first three are plain TeX rules (`%`
  //          is the comment character, `_` marks a subscript, and a backslash is written
  //          `\textbackslash` inside `\text{}`); the braces after `\operatorname` in the fourth are
  //          an extra requirement of this engine and are an ordinary group in real KaTeX.
  group('引擎兼容', () {
    test('百分号后缀必须转义，否则会被当成 TeX 注释吞掉', () {
      expect(t('50%'), r'50\%');
    });

    test('数字的下划线分隔符必须转义，否则会被排成下标', () {
      expect(t('1_000'), r'1\_000');
    });

    test('原文中的反斜杠转义为标准 LaTeX 的 textbackslash', () {
      expect(t('\\'), r'\text{\textbackslash{}}');
    });

    test('未知函数用 operatorname，实参表额外包一层花括号', () {
      expect(t('mod(7,3)'), r'\operatorname{mod}{\left(7, 3\right)}');
    });
  });
}
