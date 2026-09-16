# 主题系统与自然显示基础 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立多主题设计 token 系统，并让计算器能用真正的数学排版渲染表达式（分数堆叠、真根号、规范上下标）。

**Architecture:** 表达式字符串仍是唯一真相；新增的 AST 从它派生，再由纯函数 `TexEmitter` 转成 TeX，最后由 `MathExpressionView` 逐顶层片段渲染。求值器、存储、全部工具不动。

**Tech Stack:** Flutter 3.44 / Dart 3.12，`flutter_math_fork`（KaTeX 的 Dart 移植，Apache-2.0）

**Spec:** `docs/superpowers/specs/2026-09-16-hiper-ui-flutter-first-design.md`

## Global Constraints

- 项目路径 `/home/nekorain/AndroidStudioProjects/NekoCalc`，分支 `feature/hiper-style-calculator`
- Flutter SDK 在 `/home/nekorain/Projects/flutter/bin`，**不在 PATH 上**，每条命令前需 `export PATH="/home/nekorain/Projects/flutter/bin:$PATH"`
- 基线：`flutter analyze` 零问题，`flutter test` 623 个全过。**每个任务结束时这两个数字都不能退步。**
- 所有新增代码注释用中英双语，与现有文件风格一致（现有代码形如 `// 中文：… \n // English: …`）
- **禁止硬编码颜色**：新增代码不得出现 `Color(0x...)` 字面量，一律取自主题 token
- 包名根为 `nekocalc`，import 用 `package:nekocalc/...`
- 每个任务结束必须 `git commit`，提交信息用 conventional commits（`feat:` / `test:` / `refactor:`）

---

### Task 1: 主题 token 系统

建立三层 token 体系，替代全项目 67 处硬编码颜色。本任务只新增文件，不改任何现有组件——零回归。

**Files:**
- Create: `lib/shared/presentation/calc_theme.dart`
- Test: `test/shared/calc_theme_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `class CalcKeyColors` — 键位语义色，字段：`digitBg digitFg operatorBg operatorFg functionBg functionFg variableBg variableFg modifierBg modifierFg destructiveBg destructiveFg accentBg accentFg shiftLabelFg pillBg pillFg`
  - `class CalcDisplayColors` — 显示区语义色，字段：`background expressionFg resultFg statusFg indicatorFg errorFg`
  - `class CalcTheme` — 字段：`String id`、`String name`、`Brightness brightness`、`CalcDisplayColors display`、`CalcKeyColors keys`、`Color keypadBackground`；静态常量 `roseCream` `lavenderMist` `peachSugar`；静态列表 `all`

- [ ] **Step 1: 写失败的测试**

创建 `test/shared/calc_theme_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

void main() {
  group('CalcTheme', () {
    test('exposes three built-in themes with distinct ids', () {
      expect(CalcTheme.all.length, 3);
      final ids = CalcTheme.all.map((t) => t.id).toSet();
      expect(ids.length, 3, reason: '主题 id 必须互不相同');
    });

    test('every theme defines both a light and a dark variant', () {
      final byId = {for (final t in CalcTheme.all) t.id: t};
      expect(byId['roseCream']!.brightness, Brightness.light);
      expect(byId['roseCream']!.dark.brightness, Brightness.dark);
      expect(byId['lavenderMist']!.brightness, Brightness.light);
      expect(byId['lavenderMist']!.dark.brightness, Brightness.dark);
      expect(byId['peachSugar']!.brightness, Brightness.light);
      expect(byId['peachSugar']!.dark.brightness, Brightness.dark);
    });

    test('semantic key colours are distinct within a theme', () {
      const t = CalcTheme.roseCream;
      final bg = <Color>[
        t.keys.digitBg,
        t.keys.operatorBg,
        t.keys.functionBg,
        t.keys.variableBg,
        t.keys.modifierBg,
        t.keys.destructiveBg,
      ];
      expect(bg.toSet().length, bg.length,
          reason: '每类按键的背景色必须可区分，否则语义分类失效');
    });

    test('destructive keys are visually distinct from modifier keys', () {
      const t = CalcTheme.roseCream;
      expect(t.keys.destructiveBg, isNot(t.keys.modifierBg),
          reason: '破坏性操作与模态键不能同色，否则误触风险');
    });

    test('foreground contrasts with its own background', () {
      for (final t in CalcTheme.all) {
        for (final pair in [
          (t.keys.digitBg, t.keys.digitFg),
          (t.keys.operatorBg, t.keys.operatorFg),
          (t.keys.functionBg, t.keys.functionFg),
          (t.display.background, t.display.expressionFg),
        ]) {
          final ratio = _contrast(pair.$1, pair.$2);
          expect(ratio, greaterThan(4.5),
              reason: '${t.id}: 对比度 $ratio 低于 4.5，不可读');
        }
      }
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
export PATH="/home/nekorain/Projects/flutter/bin:$PATH"
cd /home/nekorain/AndroidStudioProjects/NekoCalc
flutter test test/shared/calc_theme_test.dart
```
Expected: FAIL，报 `Target of URI doesn't exist: 'package:nekocalc/shared/presentation/calc_theme.dart'`

- [ ] **Step 3: 实现主题**

创建 `lib/shared/presentation/calc_theme.dart`。要点：

- 三个类都用 `@immutable` + `const` 构造，字段全部 `final`
- `CalcTheme` 增加 `CalcTheme get dark`，返回同色系的深色变体
- 每套主题的色值须满足对比度 ≥ 4.5（Step 1 的测试会验证）
- 破坏性操作（退格/清空）用**暖红**、模态键（SHIFT）用**独立色相**——这是 HiPER 的语义约定，换色相可以，取消分类不行

三套主题的基础色相：

| id | name | 数字键底 | 运算符底 | 破坏性 | 模态 |
|---|---|---|---|---|---|
| `roseCream` | 玫瑰奶霜 | 近白暖色 | 玫瑰 #F4B8AE | #D98A94 | #8FC7A8 |
| `lavenderMist` | 薰衣草雾 | 近白冷色 | 紫罗兰 #C9BFF0 | #9A8AD6 | #8FC7A8 |
| `peachSugar` | 蜜桃砂糖 | 近白暖色 | 蜜桃 #F9C6A5 | #E89878 | #8FC7A8 |

深色变体：背景压到 `#1A1A1E` 量级，前景提到 `#F0EDF2` 量级，语义色相保持不变、明度降低。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/shared/calc_theme_test.dart
```
Expected: PASS，5 个测试全过。若对比度测试失败，调整相应色值直到通过。

- [ ] **Step 5: 确认无回归**

```bash
flutter analyze && flutter test
```
Expected: `No issues found!`，且测试数 ≥ 623 + 5

- [ ] **Step 6: 提交**

```bash
git add lib/shared/presentation/calc_theme.dart test/shared/calc_theme_test.dart
git commit -m "feat(theme): add multi-theme semantic colour tokens"
```

---

### Task 2: 表达式 AST

把表达式字符串解析成带源码区间的语法树。**关键约束：解析器必须容忍不完整输入**——用户打字过程中必然出现 `sin(`、`2+` 这类中间态，不能抛异常。

**Files:**
- Create: `lib/core/math/ast/expr_node.dart`
- Create: `lib/core/math/ast/expression_ast_parser.dart`
- Test: `test/core/math/expression_ast_parser_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `sealed class ExprNode`，字段 `final int start; final int end;`（start 闭区间、end 开区间，均为 canonical String 偏移）
  - 子类：`NumberNode(literal)`、`ConstantNode(name)`、`VariableNode(name)`、`OperatorNode(op)`、`UnaryNode(op, operand)`、`BinaryNode(op, left, right)`、`PostfixNode(op, operand)`、`FunctionNode(name, args)`、`GroupNode(child)`、`ImplicitProductNode(left, right)`、`ParseErrorNode(text)`
  - `class ExpressionAstParser`，方法 `ExprNode parse(String source)`
  - 顶层函数 `List<ExprNode> toDisplayUnits(ExprNode node)` —— 把最外层的二元运算链摊平成显示序列

- [ ] **Step 1: 写失败的测试**

创建 `test/core/math/expression_ast_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/ast/expr_node.dart';
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
      expect(m.end, 7);
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
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/core/math/expression_ast_parser_test.dart
```
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 实现 ExprNode**

创建 `lib/core/math/ast/expr_node.dart`：按 Interfaces 一节定义 sealed 类与全部子类。每个子类构造都要 `required super.start, required super.end`。

`toDisplayUnits` 实现要点：递归摊平 `BinaryNode` 的左结合链。对 `a+b+c`（即 `BinaryNode(+, BinaryNode(+, a, b), c)`）应产出 `[a, +, b, +, c]`，其中运算符的区间取自源码里该运算符自身的位置。非二元节点原样返回单元素列表。

- [ ] **Step 4: 实现 ExpressionAstParser**

创建 `lib/core/math/ast/expression_ast_parser.dart`。实现要点：

- 递归下降，优先级：`,` < `+ -` < `* /` < 一元 `-` < `^` < 后缀 `! %` < 原子
- 复用 `lib/core/math/expression_parser.dart` 的词法规则（数字、标识符、函数的识别范围），但**不要改动那个文件**
- 每个节点的 `start`/`end` 必须取自它消费的源码片段
- **遇到无法继续的位置不抛异常**，而是产出 `ParseErrorNode(text: 从失败点到末尾的原文, start: 失败点, end: 源码长度)`
- 空串返回 `ParseErrorNode(text: '', start: 0, end: 0)`

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/core/math/expression_ast_parser_test.dart
```
Expected: PASS，全部 14 个测试通过

- [ ] **Step 6: 确认无回归**

```bash
flutter analyze && flutter test
```

- [ ] **Step 7: 提交**

```bash
git add lib/core/math/ast/ test/core/math/expression_ast_parser_test.dart
git commit -m "feat(math): add expression AST with source spans"
```

---

### Task 3: TeX 生成

把 AST 转成 TeX 片段。纯函数，无 Flutter 依赖。

**Files:**
- Create: `lib/core/math/ast/tex_emitter.dart`
- Test: `test/core/math/tex_emitter_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ExprNode` 及全部子类、`toDisplayUnits`
- Produces:
  - `class TexEmitter`，`const TexEmitter()`
  - `String emit(ExprNode node)` —— 单节点转 TeX
  - `List<String> emitUnits(List<ExprNode> units)` —— 按序转每个显示单元

- [ ] **Step 1: 写失败的测试**

创建 `test/core/math/tex_emitter_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
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
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/core/math/tex_emitter_test.dart
```
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 实现 TexEmitter**

创建 `lib/core/math/ast/tex_emitter.dart`。要点：

- 用 `switch` 对 sealed 类做穷尽匹配
- 函数名映射表：`sin/cos/tan/asin/acos/atan/sinh/cosh/tanh/cot/sec/csc` → `\sin` 等；`log` → `\log_{10}`；`log2` → `\log_{2}`；`ln` → `\ln`；`abs` → `\left|…\right|`；`sqrt` → `\sqrt{…}`；`cbrt` → `\sqrt[3]{…}`；`root(n,x)` → `\sqrt[n]{x}`；未知函数名回退 `\operatorname{名字}\left(…\right)`
- 二元运算：`/` → `\frac{}{}`；`^` → `{}^{}`；`*` → `\cdot`；`+` `-` 原样
- `GroupNode`：默认**不加**括号（视觉分组由 `\frac`/`\sqrt` 提供），但**当父节点是 `ImplicitProductNode` 或运算符优先级要求时必须加** `\left(…\right)`。实现方式：`emit` 增加一个内部参数记录是否为分组上下文
- `ParseErrorNode` → `\text{原文}`，原文里的 `\`、`{`、`}`、`$`、`&`、`#`、`_`、`%`、`~`、`^` 需转义

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/core/math/tex_emitter_test.dart
```
Expected: PASS，14 个测试全过

- [ ] **Step 5: 确认无回归**

```bash
flutter analyze && flutter test
```

- [ ] **Step 6: 提交**

```bash
git add lib/core/math/ast/tex_emitter.dart test/core/math/tex_emitter_test.dart
git commit -m "feat(math): emit TeX from expression AST"
```

---

### Task 4: MathExpressionView 渲染组件

把 TeX 渲染成自然排版的数学显示，并支持点击定位与光标。

**Files:**
- Modify: `pubspec.yaml`（新增 `flutter_math_fork` 依赖）
- Create: `lib/features/calculator/presentation/widgets/math_expression_view.dart`
- Test: `test/features/math_expression_view_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ExpressionAstParser` / `toDisplayUnits`，Task 3 的 `TexEmitter`
- Produces:
  - `class MathExpressionView extends StatelessWidget`
  - 构造参数：`required String expression`、`bool naturalDisplay = true`、`int? cursorIndex`、`void Function(int sourceOffset)? onTapOffset`、`TextStyle? textStyle`

- [ ] **Step 1: 加依赖**

```bash
export PATH="/home/nekorain/Projects/flutter/bin:$PATH"
cd /home/nekorain/AndroidStudioProjects/NekoCalc
flutter pub add flutter_math_fork
flutter pub get
```
Expected: 解析成功。会带入 `provider`、`flutter_svg` 等传递依赖，并可能升级 `sqflite` 系列——**升级后立刻跑一次全量测试确认无回归**。

- [ ] **Step 2: 写失败的测试**

创建 `test/features/math_expression_view_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders a simple expression without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '1+2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a fraction expression naturally', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '(a+b)/2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MathExpressionView), findsOneWidget);
  });

  testWidgets('falls back to plain text when natural display is off',
      (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(
      expression: '(a+b)/2',
      naturalDisplay: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('(a+b)/2'), findsOneWidget);
  });

  testWidgets('renders incomplete input without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: 'sin(')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty expression without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a fragment reports a source offset inside the input',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(host(MathExpressionView(
      expression: '1+2',
      onTapOffset: (o) => tapped = o,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MathExpressionView));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped, inInclusiveRange(0, 3));
  });

  testWidgets('does not report taps when onTapOffset is null', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '1+2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MathExpressionView));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

```bash
flutter test test/features/math_expression_view_test.dart
```
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 4: 实现 MathExpressionView**

创建 `lib/features/calculator/presentation/widgets/math_expression_view.dart`。要点：

- `naturalDisplay == false` 时整行用单个 `Text(expression)` 渲染，走原始文本路径
- `naturalDisplay == true` 时：
  1. `ExpressionAstParser().parse(expression)` → `toDisplayUnits(...)` → `TexEmitter().emitUnits(...)`
  2. 把每个片段包成一个独立的 `Math.tex(fragment, textStyle: ...)` widget，放进横向 `SingleChildScrollView`（`reverse: true`）里的 `Row`
  3. **每个片段各自包一层 `GestureDetector`**，`onTap` 回调该片段的 `start` 偏移给 `onTapOffset` —— 这是节点级定位的实现机制，**不依赖 flutter_math_fork 的任何内部 API**
  4. `Math.tex` 的 `onErrorFallback` 把该片段降级为 `Text(原文)`
- `cursorIndex != null` 时，在遍历片段时按区间插入一个光标 widget（2×字号高的细矩形），位置取"最后一个 `end <= cursorIndex` 的片段之后"
- 测试里 `find.text('(a+b)/2')` 能命中，说明 `naturalDisplay: false` 分支必须是单个 `Text`

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/features/math_expression_view_test.dart
```
Expected: PASS，7 个测试全过

- [ ] **Step 6: 确认无回归（重要：本任务动了依赖树）**

```bash
flutter analyze && flutter test
```
Expected: `No issues found!`，测试数 ≥ 623 + 5 + 14 + 14 + 7 = 663。
**若 `sqflite` 升级导致任何测试失败，先解决依赖问题再继续，不要带着红测试往下走。**

- [ ] **Step 7: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/features/calculator/presentation/widgets/math_expression_view.dart test/features/math_expression_view_test.dart
git commit -m "feat(calculator): render expressions with natural math typesetting"
```

---

## 完成标准

本计划完成时：

- `flutter analyze` 零问题
- `flutter test` 全过，测试数 ≥ 663（基线 623 + 新增 40）
- 存在一个能渲染自然排版的 `MathExpressionView`，且支持节点级点击定位
- 三套主题 token 就绪，新增代码**零硬编码颜色**
- **主界面尚未改动** —— 这是 Plan 2 的范围

## 后续（Plan 2，本计划完成后另写）

1. HiPER 式键盘：键位定义数据模型 + 6 列主键/SHIFT 标签行渲染
2. 主屏重写：两行显示 + 键盘 + 状态行，消除溢出与滚动
3. 导航重构：底部 tab → 侧边抽屉
