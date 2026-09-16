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

  test('root 超过两个实参时退回完整实参表，不丢弃任何一个', () {
    // 中文：`root` 只认"次数, 被开方数"两个实参。多出来的实参不能悄悄消失——那会让显示与
    //       用户输入不一致，而显示层是唯一真源的回读；此时整条调用退回普通函数写法。
    // English: `root` means (degree, radicand) and nothing else. An extra argument must not vanish
    //          silently — the display would then disagree with what the user typed, and the
    //          display is the only read-back of the single source of truth — so the whole call
    //          falls back to the ordinary function form.
    expect(
      t('root(1,2,3)'),
      r'\operatorname{root}{\left(1, 2, 3\right)}',
    );
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

  // 中文：并置乘法把两个操作数的 TeX 直接拼在一起，而 TeX 的控制词按"反斜杠 + 尽可能多的字母"
  //       贪婪匹配：`\pi` 后面紧跟字母会拼成一个不存在的控制词（`pi x` → `\pix`）。引擎拒收它，
  //       于是**整个片段**退回纯文本——字符串断言的测试看不到，只有渲染测试能。下面两半都要锁：
  //       会粘连的地方必须有分隔，本来就正确的写法必须一字不动。
  // English: Juxtaposition concatenates the two operands' TeX directly, and TeX matches a control
  //          word greedily — a backslash plus as many letters as it can take — so a letter right
  //          after `\pi` merges into an undefined control word (`pi x` -> `\pix`). The engine
  //          rejects it and the **whole fragment** falls back to plain text, something a
  //          string-equality test cannot see. Both halves are pinned below: a separator wherever
  //          the two would merge, and byte-identical output where they never did.
  group('并置乘法不会把控制词与后面的字母粘连', () {
    test('常量后的字母操作数被花括号隔开', () {
      expect(t('pi x'), r'\pi{x}');
      expect(t('pi e'), r'\pi{e}');
      expect(t('tau t'), r'\tau{t}');
      expect(t('phi f'), r'\phi{f}');
      expect(t('inf x'), r'\infty{x}');
      expect(t('infinity y'), r'\infty{y}');
    });

    test('左侧本身是并置乘法时同样隔开', () {
      expect(t('2 pi x'), r'2\pi{x}');
    });

    test('函数实参里的并置同样隔开', () {
      expect(t('sin(pi x)'), r'\sin\left(\pi{x}\right)');
    });

    test('右操作数是不带括号的幂时，指数仍留在上标里', () {
      expect(t('pi x^2'), r'\pi{x^{2}}');
    });

    test('不会粘连的写法一字不变', () {
      // 中文：`\pi2` 合法（数字终止控制词），`\pi\sin` 也合法（反斜杠另起一个控制词），
      //       因此这些写法不该被多出来的花括号污染。
      // English: `\pi2` is valid (a digit ends the control word) and so is `\pi\sin` (the backslash
      //          opens a new one), so these spellings must not pick up stray braces.
      expect(t('pi 2'), r'\pi2');
      expect(t('pi pi'), r'\pi\pi');
      expect(t('pi sin(2)'), r'\pi\sin\left(2\right)');
      expect(t('2x'), '2x');
      expect(t('3(x+1)'), r'3\left(x+1\right)');
      expect(t('x y'), 'xy');
    });
  });

  // 中文：`parse` 与 `emit` 都"永不抛异常"，而病态输入最容易让这句话失守——500 层括号足以把
  //       递归下降的调用栈撑爆。这里同时钉住三件事：解析不抛、发射不抛，并且深度上限一旦触发，
  //       结果退化成**覆盖整段源码**的一个 `\text{…}`，而不是把嵌套原样展开——所以产物长度与
  //       输入同量级。少了这条，"永不抛"和"有界"都只是注释里的承诺。
  // English: `parse` and `emit` both promise never to throw, and pathological input is where that
  //          promise breaks first — 500 nested parentheses are enough to blow a recursive-descent
  //          stack. Three things are pinned here at once: parsing does not throw, emitting does not
  //          throw, and once the depth cap trips the result degrades into a single `\text{…}`
  //          covering the whole source instead of expanding the nesting, so the output stays the
  //          same order of magnitude as the input. Without it, "never throws" and "bounded" are
  //          only promises in a comment.
  test('病态深嵌套不抛异常，且整段退化为有界的文本片段', () {
    final source = '${'(' * 500}1${')' * 500}';
    final fragments = tex.emitUnits(toDisplayUnits(parser.parse(source)));

    // 中文：整段退化 = 恰好一个片段；这本身就说明 500 层嵌套没有被展开。
    // English: Whole-string degradation means exactly one fragment, which by itself shows the 500
    //          levels were not expanded.
    expect(fragments.length, 1);
    expect(fragments.single, startsWith(r'\text{'));
    // 中文：完整展开每层要约 13 个字符（`\left(` + `\right)`），退化产物只比原文多一个外壳，
    //       因此"小于两倍"这个界足以把两者分开。
    // English: Fully expanding a level costs about 13 characters (`\left(` + `\right)`), while the
    //          degraded form adds only a wrapper around the source, so a factor of two separates
    //          the two cleanly.
    expect(fragments.single.length, lessThan(source.length * 2));
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
