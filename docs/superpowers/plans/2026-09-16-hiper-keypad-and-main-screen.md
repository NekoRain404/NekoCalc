# HiPER 式键盘与主屏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把计算器主屏换成 HiPER Calc Pro 的形态：6 列密集键盘（主键行与 SHIFT 标签行交替）+ 两行自然排版显示 + 侧边抽屉导航。

**Architecture:** 键盘是**纯数据驱动**的——`KeypadDefinition` 描述行、键、SHIFT 变体与启用态，`CalculatorKeypad` 只负责按定义渲染并把按键 id 回调出去。按键 id 复用现有 `CalculatorController` 的动作词汇，所以求值、历史、持久化、79 个工具全部不动。

**Tech Stack:** Flutter 3.44 / Dart 3.12，依赖 Plan 1 已交付的 `CalcTheme`、`MathExpressionView`

**Spec:** `docs/superpowers/specs/2026-09-16-hiper-keypad-and-main-screen-design.md`

## Global Constraints

- 项目路径 `/home/nekorain/AndroidStudioProjects/NekoCalc`，分支 `main`
- Flutter SDK 在 `/home/nekorain/Projects/flutter/bin`，**不在 PATH 上**，每条命令前需 `export PATH="/home/nekorain/Projects/flutter/bin:$PATH"`
- 基线：`flutter analyze` 零问题，`flutter test` **700 个全过**。**每个任务结束时这两个数字都不能退步。**
- 所有新增代码注释用中英双语（`// 中文：… \n // English: …`）
- **禁止硬编码颜色**：一律取自 `CalcTheme`。加新主题时不得触碰组件文件
- 包名根为 `nekocalc`
- 每个任务结束必须 `git commit`，conventional commits
- **不得修改** `lib/core/math/expression_parser.dart`

## Plan 1 已交付的接口（逐字使用）

```dart
// lib/shared/presentation/calc_theme.dart
class CalcKeyColors {
  final Color digitBg, digitFg, operatorBg, operatorFg,
      functionBg, functionFg, variableBg, variableFg,
      modifierBg, modifierFg, destructiveBg, destructiveFg,
      accentBg, accentFg, shiftLabelFg, pillBg, pillFg;
}
class CalcDisplayColors {
  final Color background, expressionFg, resultFg, statusFg, indicatorFg, errorFg;
}
class CalcTheme {
  final String id, name;
  final Brightness brightness;
  final CalcDisplayColors display;
  final CalcKeyColors keys;
  final Color keypadBackground;
  CalcTheme get dark;                       // 同 id 的深色变体
  static const CalcTheme roseCream, lavenderMist, peachSugar;
  static const List<CalcTheme> all;         // 三套浅色
}

// lib/features/calculator/presentation/widgets/math_expression_view.dart
class MathExpressionView extends StatelessWidget {
  const MathExpressionView({
    required String expression,
    bool naturalDisplay = true,
    int? cursorIndex,
    void Function(int sourceOffset)? onTapOffset,
    TextStyle? textStyle,
    Key? key,
  });
}

// lib/application/controllers/calculator_controller.dart（现有，只读使用）
void setAngleMode(String)  void input(String)  void append(String)
void applyUnaryFunction(String)  void applyBinaryFunction(String)
void backspace()  void clear()  void continueWithResult()
void memoryAdd()  void memorySubtract()  void memoryRecall()  void memoryClear()
void undo()  void redo()  String copyText()  String noteBody()
Future<CalculatorSubmitResult> submit()  Future<CalculatorSaveNoteResult> saveToNote()
// 只读状态：expression, cursorIndex, result, angleMode, hasError,
//          resultStatusTitle, resultStatusMessage, memoryValue
```

---

### Task 1: KeypadDefinition 数据模型与 HiPER 键位表

键盘的全部内容都在这里。渲染只读它。

**Files:**
- Create: `lib/features/calculator/presentation/keypad/keypad_definition.dart`
- Create: `lib/features/calculator/presentation/keypad/hiper_keypad.dart`
- Test: `test/features/keypad_definition_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `enum KeyCategory { digit, operator, function, variable, modifier, destructive, accent, pill, disabled }`
  - `class KeyVariant { const KeyVariant({required String label, required String id, bool enabled = true}); final String label; final String id; final bool enabled; }`
  - `class KeypadKey { const KeypadKey({required KeyVariant base, required KeyCategory category, KeyVariant? shift, KeyVariant? hyp}); final KeyVariant base; final KeyCategory category; final KeyVariant? shift; final KeyVariant? hyp; }`
  - `sealed class KeypadLabel`；`class ShiftLabel extends KeypadLabel { const ShiftLabel(String text); final String text; }`（标签行里的**纯文字**，不可点）；`class InlineKey extends KeypadLabel { const InlineKey(this.key); final KeypadKey key; }`（标签行里的**实体键**，可点）

**为什么标签行要能装实体键**：HiPER 的标签行不是纯标签行——`▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` 是四个真按钮，`hyp` 也需要落在这一格的视觉位置上。所以标签行的每一项要么是 `ShiftLabel`（纯文字），要么是 `InlineKey`（包一个完整的 `KeypadKey`，因而同样有分类、SHIFT 变体与启用态）。`hyp` 与四个胶囊都用 `InlineKey`，胶囊的 `category` 是 `KeyCategory.pill`。
  - `class KeypadRow { const KeypadRow({required List<KeypadKey> keys, required List<KeypadLabel?> labels}); final List<KeypadKey> keys; final List<KeypadLabel?> labels; }`（`labels.length == keys.length`）
  - `class KeypadDefinition { const KeypadDefinition(List<KeypadRow> rows); final List<KeypadRow> rows; }`
  - `const KeypadDefinition hiperKeypad = ...`

**关于 `hyp` 的裁定（与 HiPER 有一处刻意偏离）**：HiPER 把 `hyp` 放在 `π` 的 SHIFT 位上，形成「SHIFT→π→hyp 模式→sin→sinh」的嵌套修饰。本计划把它改为**占据同一格但可直接点按的修饰键**（以 `InlineKey` 放进标签行，与四个胶囊同一机制），理由：单层修饰机制即可覆盖，而 `sinh`/`cosh`/`tanh` 是 NekoCalc 已有能力，不能因为换键盘而失去入口。视觉位置与 HiPER 一致。

- [ ] **Step 1: 写失败的测试**

创建 `test/features/keypad_definition_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';

void main() {
  group('KeypadDefinition 完整性', () {
    test('标签行与主键行等长', () {
      for (final row in hiperKeypad.rows) {
        expect(row.labels.length, row.keys.length,
            reason: '每一行都必须为每个键留出标签位（无标签时为 null）');
      }
    });

    test('键的 id 全局唯一', () {
      final ids = <String>[];
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          ids.add(k.base.id);
          if (k.shift != null) ids.add(k.shift!.id);
          if (k.hyp != null) ids.add(k.hyp!.id);
        }
      }
      final dup = ids.where((id) => ids.where((x) => x == id).length > 1).toSet();
      expect(dup, isEmpty, reason: '重复的键 id 会让 action 分派产生歧义: $dup');
    });

    test('禁用的键必须属于 disabled 分类', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (!k.base.enabled) {
            expect(k.category, KeyCategory.disabled,
                reason: '${k.base.id} 未启用却不是 disabled 分类');
          }
        }
      }
    });

    test('未禁用的键必须有非空 id 与 label', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (k.base.enabled) {
            expect(k.base.id, isNotEmpty);
            expect(k.base.label, isNotEmpty);
          }
        }
      }
    });

    test('SHIFT 变体存在时其 id 不得与基准 id 相同', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (k.shift != null) {
            expect(k.shift!.id, isNot(k.base.id),
                reason: '${k.base.id} 的 SHIFT 变体没有独立行为，应改为 null');
          }
        }
      }
    });
  });

  group('HiPER 网格形状', () {
    test('共 17 行：9 个主键行 + 8 个标签行交替', () {
      expect(hiperKeypad.rows.length, 17);
    });

    test('数字键与四则运算符永远在位', () {
      final all = hiperKeypad.rows
          .expand((r) => r.keys)
          .map((k) => k.base.id)
          .toSet();
      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(all, contains(d), reason: '数字键 $d 必须存在');
      }
      for (final op in ['+', '-', '*', '/']) {
        expect(all, contains(op), reason: '运算符 $op 必须存在');
      }
    });

    test('破坏性键分类正确', () {
      final destructive = hiperKeypad.rows
          .expand((r) => r.keys)
          .where((k) => k.category == KeyCategory.destructive)
          .map((k) => k.base.id)
          .toSet();
      expect(destructive, {'backspace', 'clear'});
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
export PATH="/home/nekorain/Projects/flutter/bin:$PATH"
cd /home/nekorain/AndroidStudioProjects/NekoCalc
flutter test test/features/keypad_definition_test.dart
```
Expected: FAIL，`Target of URI doesn't exist: 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart'`

- [ ] **Step 3: 实现数据模型**

创建 `lib/features/calculator/presentation/keypad/keypad_definition.dart`，按 Interfaces 一节定义全部类型。要点：
- 三个类都用 `@immutable` + `const` 构造，字段全部 `final`
- `KeypadRow` 的构造加断言 `assert(labels.length == keys.length)`
- `KeyCategory` 的八个值对应 `CalcKeyColors` 的语义分组，加上 `disabled`

- [ ] **Step 4: 实现 HiPER 键位表**

创建 `lib/features/calculator/presentation/keypad/hiper_keypad.dart`。逐格如下（`☐` = 禁用）。

**动作 id 的约定**：能直接用 `CalculatorController` 现有方法表达的，用无前缀 id（如 `sin`、`pi`、`backspace`、`clear`、`equals`、`memoryAdd`、`openHistory`、`openTools`、`angleMode`）；需要插入文本的用 `ins:` 前缀（如 `ins:pi`）；禁用键用 `dis:` 前缀（如 `dis:matrix`）。

| 行 | 主键 | 标签行（同上标） |
|---|---|---|
| 1 | `shift`(modifier) `drawer`(function) `☐pagePrev` `☐pageNext` `backspace`(destructive) `clear`(destructive) | 无标签行 |
| 2 | — | `▸DRG` `☐FSE` `☐MTRX` `☐Π` `☐d/dx` `—` |
| 3 | `angleMode`(function) `☐x⇔E` `☐matrix` `☐sum` `☐integral` `☐camera` | 见上行 |
| 4 | — | `hyp`(InlineKey·modifier) `sin⁻¹` `cos⁻¹` `tan⁻¹` `☐∠` `☐logₓy` |
| 5 | `ins:pi`(function) `sin` `cos` `tan` `☐i` `ins:e` | — |
| 6 | — | `☐lim` `x³` `∛x` `ˣ√y` `10ˣ` `eˣ` |
| 7 | `x⁻¹`(function) `x²` `√x` `xʸ` `log` `ln` | — |
| 8 | — | `☐STAT` `☐a b/c` `☐Y` `openHistory` `M+` `M−` |
| 9 | `☐D°M'S` `☐d/c` `☐X` `☐XY,M` `MR` `x→M` | — |
| 10 | — | `☐CPLX` `∞` `%` `mod` |
| 11 | `7` `8` `9` `(` `)` (digit/operator) | — |
| 12 | — | `n!` `nCr` `nPr` `▸BIN`(InlineKey·pill) `▸OCT`(InlineKey·pill) |
| 13 | `4` `5` `6` `×` `÷` (digit/operator) | — |
| 14 | — | `CNST` `CONV` `abs` `▸DEC`(InlineKey·pill) `▸HEX`(InlineKey·pill) |
| 15 | `1` `2` `3` `+` `−` (digit/operator) | — |
| 16 | — | `openTools` `☐ran#` `Ans` `☐EXP SI` `☐=,＜＞` |
| 17 | `0` `.` `+/−` `EXP` `✓`(=, accent) | — |

键位映射细则（英文标签对应可用的中文/符号键，逐条不得随意更改）：

| HiPER 标签 | 本计划 | id | 说明 |
|---|---|---|---|
| `sin`/`cos`/`tan` | 启用 | `sin` `cos` `tan` | 走 `applyUnaryFunction` |
| `sin⁻¹`/`cos⁻¹`/`tan⁻¹` | 启用 | `asin` `acos` `atan` | 分别为上表 `sin`/`cos`/`tan` 的 shift |
| `hyp` | 启用（修饰键） | `hyp` | 激活时 `sin`→`sinh`、`cos`→`cosh`、`tan`→`tanh`，见下 |
| `π`/`e` | 启用 | `ins:pi` `ins:e` | `e` 为 shift 无、base 插入 `e` |
| `x²`/`x³` | 启用 | `ins:^2` `ins:^3` | `x³` 是 `x²` 的 shift |
| `√x`/`∛x` | 启用 | `sqrt` `cbrt` | `∛x` 是 `√x` 的 shift |
| `xʸ`/`ˣ√y` | 启用 | `ins:^` `root` | `ˣ√y` 是 `xʸ` 的 shift |
| `x⁻¹` | 启用 | `ins:^-1` | |
| `log`/`ln` | 启用 | `log` `ln` | |
| `10ˣ`/`eˣ` | 启用 | `ins:10^` `ins:e^` | 分别为 `log`/`ln` 的 shift |
| `M+`/`M−`/`MR`/`x→M` | 启用 | `memoryAdd` `memorySubtract` `memoryRecall` `memoryStore` | `memoryStore` = 现有 `memoryAdd` 语义 |
| `HISTORY` | 启用 | `openHistory` | 打开抽屉的历史入口 |
| `OTHER` | 启用 | `openTools` | 打开工具箱（NekoCalc 的对应物） |
| `CNST` | 启用 | `openConstants` | 打开工具箱的常数分类 |
| `CONV` | 启用 | `openUnits` | 打开工具箱的单位换算 |
| `∞` | 启用 | `ins:inf` | 解析器常量集含 `inf` |
| `%`/`mod` | 启用 | `ins:%` `mod` | |
| `n!`/`nCr`/`nPr` | 启用 | `fact` `nCr` `nPr` | |
| `abs` | 启用 | `abs` | |
| `Ans` | 启用 | `ans` | 插入 `reusableResult` |
| `EXP` | 启用 | `ins:e` | 科学计数法输入 |
| `+/−` | 启用 | `negate` | |
| `DRG` | 启用 | `angleMode` | NekoCalc 只有 DEG/RAD，循环切换两者 |
| `MENU` | 启用 | `drawer` | 打开侧边抽屉 |
| `SHIFT` | 启用 | `shift` | 修饰键 |
| `▸BIN` `▸OCT` `▸DEC` `▸HEX` | 启用（`InlineKey`·`pill` 分类） | `baseBin` `baseOct` `baseDec` `baseHex` | 打开工具箱的进制换算；**label 用 `BIN`/`OCT`/`DEC`/`HEX`，不含 `▸`**（那个三角是装饰，由渲染层画或不画都不影响测试） |
| 其余标 `☐` 者 | **禁用** | `dis:<name>` | 分类 `disabled` |

**记号说明**：上表里 `☐` 是本计划用来标记「禁用」的排版记号，**不是 label 的一部分**。禁用键的 label 就是 HiPER 原文（`MTRX`、`Σ`、`∫dx`、`lim`、`i`、`∠`、`CPLX`、`D°M'S`、`d/c`、`X`、`XY,M`、`STAT`、`a b/c`、`Y`、`ran#`、`EXP SI`、`=,＜＞`、`◀`、`▶`、`x⇔E`、`logₓy`），分类为 `disabled`，id 用 `dis:` 前缀加小写名（如 `dis:matrix`、`dis:sum`）。

`hyp` 的实现：`sin`/`cos`/`tan` 三个键各自带 `hyp: KeyVariant(label: 'sinh'|'cosh'|'tanh', id: 'sinh'|'cosh'|'tanh')`，各自**也带 `shift:`** 指向 `asin`/`acos`/`atan`。渲染时修饰态为 `hyp` 用 `hyp`，为 `shift` 用 `shift`。

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/features/keypad_definition_test.dart
```
Expected: PASS，8 个测试全过

- [ ] **Step 6: 确认无回归**

```bash
flutter analyze && flutter test
```
Expected: `No issues found!`，测试数 ≥ 708

- [ ] **Step 7: 提交**

```bash
git add lib/features/calculator/presentation/keypad/keypad_definition.dart \
        lib/features/calculator/presentation/keypad/hiper_keypad.dart \
        test/features/keypad_definition_test.dart
git commit -m "feat(calculator): add data-driven HiPER keypad definition"
```

---

### Task 2: CalculatorKeypad 渲染组件

**Files:**
- Create: `lib/features/calculator/presentation/keypad/calculator_keypad.dart`
- Test: `test/features/calculator_keypad_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `KeypadDefinition`、`KeypadRow`、`KeypadKey`、`KeyVariant`、`KeypadLabel`、`ShiftLabel`、`InlineKey`、`KeyCategory`；Plan 1 的 `CalcKeyColors`
- Produces:
  - `enum KeypadModifier { none, shift, hyp }`
  - `class CalculatorKeypad extends StatelessWidget`，构造参数：`required KeypadDefinition definition`、`required KeypadModifier modifier`、`required CalcKeyColors colors`、`required Color background`、`required ValueChanged<String> onKey`、`required VoidCallback onToggleShift`、`required VoidCallback onToggleHyp`

- [ ] **Step 1: 写失败的测试**

创建 `test/features/calculator_keypad_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget pad({
  KeypadModifier modifier = KeypadModifier.none,
  ValueChanged<String>? onKey,
  VoidCallback? onToggleShift,
  VoidCallback? onToggleHyp,
}) =>
    host(CalculatorKeypad(
      definition: hiperKeypad,
      modifier: modifier,
      colors: CalcTheme.roseCream.keys,
      background: CalcTheme.roseCream.keypadBackground,
      onKey: onKey ?? (_) {},
      onToggleShift: onToggleShift ?? () {},
      onToggleHyp: onToggleHyp ?? () {},
    ));

void main() {
  testWidgets('renders every enabled key label', (tester) async {
    await tester.pumpWidget(pad());
    for (final row in hiperKeypad.rows) {
      for (final k in row.keys) {
        if (k.base.enabled) {
          expect(find.text(k.base.label), findsWidgets,
              reason: '启用的键 ${k.base.id} 未渲染');
        }
      }
    }
  });

  testWidgets('tapping a digit reports its id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('7').first);
    expect(tapped, ['7']);
  });

  testWidgets('under shift, a main key reports its shift id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(modifier: KeypadModifier.shift, onKey: tapped.add));
    await tester.tap(find.text('sin').first);
    expect(tapped, ['asin']);
  });

  testWidgets('under hyp, sin reports sinh', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(modifier: KeypadModifier.hyp, onKey: tapped.add));
    await tester.tap(find.text('sin').first);
    expect(tapped, ['sinh']);
  });

  testWidgets('disabled main keys report nothing', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    // Σ 是第 3 行的主键且为禁用态；不要拿标签行的文字（如 MTRX）来测，
    // 标签本就不可点，那样会通过但测不到「禁用键不触发」这件事。
    await tester.tap(find.text('Σ').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('shift labels are not tappable', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('MTRX').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('tapping SHIFT invokes onToggleShift, not onKey', (tester) async {
    final tapped = <String>[];
    var toggled = 0;
    await tester.pumpWidget(pad(onKey: tapped.add, onToggleShift: () => toggled++));
    await tester.tap(find.text('SHIFT').first);
    expect(toggled, 1);
    expect(tapped, isEmpty);
  });

  testWidgets('pill buttons are tappable and report ids', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('BIN').first);
    expect(tapped, ['baseBin']);
  });

  testWidgets('no key paints a hardcoded colour from the theme', (tester) async {
    const theme = CalcTheme.lavenderMist;
    await tester.pumpWidget(host(CalculatorKeypad(
      definition: hiperKeypad,
      modifier: KeypadModifier.none,
      colors: theme.keys,
      background: theme.keypadBackground,
      onKey: (_) {},
      onToggleShift: () {},
      onToggleHyp: () {},
    )));
    // 数字键底应为该主题的 digitBg
    final digit = tester.widget<Container>(
      find.ancestor(of: find.text('7').first, matching: find.byType(Container)).first,
    );
    expect((digit.decoration as BoxDecoration).color, theme.keys.digitBg);
  });

  testWidgets('does not overflow at 320, 360 and 412 dp', (tester) async {
    for (final w in [320.0, 360.0, 412.0]) {
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(pad());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽度 $w 下溢出');
    }
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/features/calculator_keypad_test.dart
```
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 实现渲染**

创建 `lib/features/calculator/presentation/keypad/calculator_keypad.dart`。要点：

- 纵向 `Column`，逐行渲染。每行 = 可选标签条 + 主键条
- 主键条用 `Row` + `Expanded` 平分宽度，这样 6 键行与 5 键行各自等分，与 HiPER 的两套列宽一致
- 三种视觉：
  - **主键**：圆角矩形，底色取自 `category`（`digit`→`digitBg/Fg`，`operator`→`operatorBg/Fg`，`function`→`functionBg/Fg`，`variable`→`variableBg/Fg`，`modifier`→`modifierBg/Fg`，`destructive`→`destructiveBg/Fg`，`accent`→`accentBg/Fg`，`disabled`→降饱和 + `shiftLabelFg`）
  - **标签条**：矮行。`ShiftLabel` 渲染为纯文字，色 `shiftLabelFg`，无边框、不可点；`InlineKey` 按其所包 `KeypadKey` 的 `category` 渲染——`pill` 分类用 `pillBg`/`pillFg` 画胶囊并挂 `onTap`，`modifier` 分类（即 `hyp`）按修饰键规则渲染
  - **修饰键**：`modifier` 分类的键在激活时加边框或改用 `accentBg`
- 命中态：`InkWell` + `borderRadius`，`onTap` 调用 `onKey(id)`
- 禁用键：**不挂 `onTap`**（回调不触发），视觉降饱和
- 修饰态取值优先级：`hyp` 变体存在且 `modifier == KeypadModifier.hyp` → 用 `hyp`；否则 `modifier == KeypadModifier.shift` 且 `shift != null` → 用 `shift`；否则用 `base`
- `SHIFT` 键自身 `onTap` → `onToggleShift()`；`hyp` 键 → `onToggleHyp()`

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/features/calculator_keypad_test.dart
```
Expected: PASS，10 个测试全过

- [ ] **Step 5: 确认无回归**

```bash
flutter analyze && flutter test
```
Expected: 测试数 ≥ 718

- [ ] **Step 6: 提交**

```bash
git add lib/features/calculator/presentation/keypad/calculator_keypad.dart \
        test/features/calculator_keypad_test.dart
git commit -m "feat(calculator): render the HiPER keypad from its definition"
```

---

### Task 3: 两行显示组件 CalculatorDisplay

**Files:**
- Create: `lib/features/calculator/presentation/widgets/calculator_display.dart`
- Test: `test/features/calculator_display_test.dart`

**Interfaces:**
- Consumes: Plan 1 的 `MathExpressionView`、`CalcDisplayColors`
- Produces:
  - `class CalculatorDisplay extends StatelessWidget`，构造参数：`required String expression`、`required String result`、`required bool hasError`、`required String statusTitle`、`required String statusMessage`、`required int? cursorIndex`、`required String angleMode`、`required bool hasMemory`、`required CalcDisplayColors colors`、`required bool naturalDisplay`、`void Function(int)? onTapOffset`、`VoidCallback? onMore`、`VoidCallback? onOpenDrawer`

**☰ 抽屉按钮的位置（跨任务约定）**：它属于状态行最左侧，由本任务渲染，`onOpenDrawer` 为 null 时不渲染。带 `tooltip: '打开导航'`——Task 5 的测试靠这个 tooltip 找到它。**Task 4 与 Task 5 都不要另外再造一个 ☰。**

- [ ] **Step 1: 写失败的测试**

创建 `test/features/calculator_display_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget display({
  String expression = '1+2',
  String result = '3',
  bool hasError = false,
  int? cursorIndex,
  bool naturalDisplay = true,
  VoidCallback? onMore,
  VoidCallback? onOpenDrawer,
}) =>
    host(CalculatorDisplay(
      expression: expression,
      result: result,
      hasError: hasError,
      statusTitle: hasError ? '表达式需要修正' : '等待输入',
      statusMessage: hasError ? '缺少右括号' : '',
      cursorIndex: cursorIndex,
      angleMode: 'DEG',
      hasMemory: false,
      colors: CalcTheme.roseCream.display,
      naturalDisplay: naturalDisplay,
      onMore: onMore,
      onOpenDrawer: onOpenDrawer,
    ));

void main() {
  testWidgets('shows the expression through MathExpressionView', (tester) async {
    await tester.pumpWidget(display());
    expect(find.byType(MathExpressionView), findsOneWidget);
  });

  testWidgets('shows the angle mode indicator', (tester) async {
    await tester.pumpWidget(display());
    expect(find.text('DEG'), findsOneWidget);
  });

  testWidgets('shows a leading equals sign before the result', (tester) async {
    await tester.pumpWidget(display(result: '3'));
    expect(find.text('='), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('shows the error message only when there is an error', (tester) async {
    await tester.pumpWidget(display(hasError: false));
    expect(find.text('缺少右括号'), findsNothing);
    await tester.pumpWidget(display(hasError: true));
    expect(find.text('缺少右括号'), findsOneWidget);
  });

  testWidgets('More button is tappable when provided', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(display(onMore: () => tapped++));
    await tester.tap(find.text('More...'));
    expect(tapped, 1);
  });

  testWidgets('drawer button carries the tooltip the shell test looks for',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(display(onOpenDrawer: () => opened++));
    await tester.tap(find.byTooltip('打开导航'));
    expect(opened, 1);
  });

  testWidgets('degrades to plain text when naturalDisplay is off', (tester) async {
    await tester.pumpWidget(display(expression: '(a+b)/2', naturalDisplay: false));
    expect(find.text('(a+b)/2'), findsOneWidget);
  });

  testWidgets('renders an empty expression without throwing', (tester) async {
    await tester.pumpWidget(display(expression: '', result: '0'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/features/calculator_display_test.dart
```
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 实现**

创建 `lib/features/calculator/presentation/widgets/calculator_display.dart`。布局自上而下：

1. **状态行**：左起角度模式 chip（`DEG`/`RAD`）、记忆指示（`M` 或留空）、Spacer、`More...` 按钮（`onMore` 为 null 时不渲染）
2. **表达式行**：`MathExpressionView`，右对齐，`fontSize` 取 19、颜色 `colors.expressionFg`，外面套横向 `SingleChildScrollView(reverse: true)`
3. **结果行**：右对齐，前缀 `=` 用 `colors.resultFg`，后面接结果。**结果行暂时是纯文本**——Plan 1 的求值器只产出 `double`，精确形式（`iπ√14/6`）需要引擎，不在本阶段
4. **错误行**：仅 `hasError` 为真时渲染，文字色 `colors.errorFg`

整块用 `colors.background` 作底。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/features/calculator_display_test.dart
```
Expected: PASS，8 个测试全过

- [ ] **Step 5: 确认无回归**

```bash
flutter analyze && flutter test
```

- [ ] **Step 6: 提交**

```bash
git add lib/features/calculator/presentation/widgets/calculator_display.dart \
        test/features/calculator_display_test.dart
git commit -m "feat(calculator): add the two-line calculator display"
```

---

### Task 4: 主屏重写

**Files:**
- Modify: `lib/features/calculator/presentation/calculator_page.dart`（整体替换 `build` 与键盘相关部分）
- Test: `test/features/calculator_page_test.dart`（已存在，需保持通过）

**Interfaces:**
- Consumes: Task 1 的 `hiperKeypad`、Task 2 的 `CalculatorKeypad`/`KeypadModifier`、Task 3 的 `CalculatorDisplay`
- Produces: 无新公开类型；`CalculatorPage` 的构造参数保持不变

- [ ] **Step 1: 先跑现有测试建立基线**

```bash
flutter test test/features/calculator_page_test.dart
```
记录通过数，重写后不得低于它。

- [ ] **Step 2: 写新增的失败测试**

在 `test/features/calculator_page_test.dart` 的 `main()` **内部末尾**追加下面这个 group。文件底部已有一个 `Widget _testApp()`（第 367 行起），它构造 `CalculatorPage` 并注入 `_FakeDatabase` 与 `AppSettings`——**直接复用它，不要新建**。

```dart
group('HiPER 式主屏', () {
  testWidgets('数字键与函数键同时可见，无需切页', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(find.text('7'), findsWidgets);
    expect(find.text('sin'), findsWidgets);
  });

  testWidgets('主屏没有纵向滚动容器', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      ),
      findsNothing,
      reason: '主屏不得出现纵向滚动（当前有 211dp 溢出）',
    );
  });

  testWidgets('点数字键把数字写进表达式', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').first);
    await tester.pumpAndSettle();
    expect(_displayedExpression(tester), contains('7'));
  });

  testWidgets('按 SHIFT 后 sin 执行 sin⁻¹', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHIFT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('sin').first);
    await tester.pumpAndSettle();
    expect(_displayedExpression(tester), contains('asin'));
  });
});
```

表达式**不要用 `find.textContaining` 断言**——它现在由 `MathExpressionView` 渲染成 `RichText`，`find.text*` 找不到，测试会因为错误的原因失败（或虚假通过）。在文件里加这个辅助函数，直接读组件的 `expression`：

```dart
String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;
```

需要在文件顶部加 `import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';`。

注意「主屏没有纵向滚动容器」那条**不能用 `find.byType(SingleChildScrollView)`**——表达式行本身是横向滚动的 `SingleChildScrollView`，按类型断言会误报。必须按 `scrollDirection == Axis.vertical` 过滤。

- [ ] **Step 3: 运行确认失败**

```bash
flutter test test/features/calculator_page_test.dart
```
Expected: 新增的 4 个失败（`find.text('sin')` 找不到、主屏存在 `SingleChildScrollView`）

- [ ] **Step 4: 重写主屏**

改写 `calculator_page.dart` 的 `build`。新结构自上而下：

```
Scaffold
 └ Column
    ├ CalculatorDisplay        （Task 3）
    ├ Spacer / 固定间距
    └ CalculatorKeypad         （Task 2）
```

**删除**：应用名标题行、`_padTabs()`、`_functionPanel()`、`_basicKeyboard()`、`_displayToolbar()`、`_memoryBar()`、`_resultStatusCard()`、`_actions()`、外层 `SingleChildScrollView`、`_basicKeyboardHeight()`/`_functionPanelHeight()` 的高度计算。

**保留**：`_pressKey(String key)` 的分派逻辑——它是 id → 控制器动作的映射，重写时**扩展**它而不是丢弃。新增以下 case：`shift`（切修饰态）、`hyp`（切修饰态）、`drawer`/`openHistory`/`openTools`/`openConstants`/`openUnits`（导航回调）、`negate`（`+/−`）、`ans`（插入 `reusableResult`）、`ins:` 前缀的各条插入。

**状态**：页面新增 `KeypadModifier _modifier` 与 `bool _hypActive`；`shift` 与 `hyp` 互斥（点一个清另一个）。修饰态在**一次按键后自动复位**（与 HiPER 一致），`hyp` 除外——它是持续态，需再点一次退出。

高度分配：`CalculatorDisplay` 取可用高度的 38%，**clamp 下限为 176dp**（不是 150dp —— Task 3 的评审按真实 Android 字体度量推导出，显示区的固定行在双行错误下需要 ≈165dp，150dp 会在窗口高度低于约 395dp 时必然溢出：横屏、分屏、自由窗口都命中），上限 230dp，其余给键盘。键盘用 `Expanded` 填满，**不设固定高度**。

`modifierActive` 无需显式传：`CalculatorKeypad` 现在由 `modifier ?? (modifier != KeypadModifier.none)` 自行推导（`calculator_keypad.dart:154`），不传也会正确高亮标签带。

`CalculatorDisplay` 的 ☰ 按钮（`onOpenDrawer`）必须接上，它的 `tooltip: '打开导航'` 是 Task 5 测试的锚点。

- [ ] **Step 5: 运行确认通过**

```bash
flutter test test/features/calculator_page_test.dart
```
Expected: PASS，且总数不低于 Step 1 记录值 + 4

- [ ] **Step 6: 确认无回归 + 窄屏不溢出**

```bash
flutter analyze && flutter test
```
Expected: `No issues found!`，测试数 ≥ 730

- [ ] **Step 7: 提交**

```bash
git add lib/features/calculator/presentation/calculator_page.dart \
        test/features/calculator_page_test.dart
git commit -m "feat(calculator): rebuild the main screen around the HiPER keypad"
```

---

### Task 5: 抽屉导航

**Files:**
- Modify: `lib/shared/presentation/app_shell.dart`
- Create: `lib/shared/presentation/app_drawer.dart`
- Test: `test/features/app_shell_test.dart`（若不存在则新建）

**Interfaces:**
- Consumes: 现有 `AppShell` 的页面集合与 `onOpenSettings` 回调
- Produces: `class AppDrawer extends StatelessWidget`，构造参数：`required int selectedIndex`、`required ValueChanged<int> onSelect`、`required VoidCallback onOpenSettings`

- [ ] **Step 1: 写失败的测试**

创建 `test/features/app_shell_test.dart`。本仓库的测试惯例是**每个文件自带一个私有的 `_FakeDatabase`**（见 `calculator_page_test.dart:388`、`settings_page_test.dart:412`），沿用该惯例：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/shared/presentation/app_shell.dart';

Widget _app() => MaterialApp(
      home: AppShell(
        db: _FakeDatabase(),
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
        onSettingsChanged: () async {},
        onThemeModeChanged: (_) {},
      ),
    );

void main() {
  testWidgets('主屏没有底部导航栏', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('点 ☰ 后抽屉出现且含四个入口', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    expect(find.text('工具'), findsWidgets);
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('点抽屉里的「笔记」后笔记页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    expect(find.text('笔记'), findsWidgets);
  });
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

**实现约束**：主屏上的 ☰ 按钮必须带 `tooltip: '打开导航'`，否则上面的测试找不到它。抽屉里的四项文案固定为 工具 / 笔记 / 历史 / 设置。

- [ ] **Step 2: 运行确认失败**

```bash
flutter test test/features/app_shell_test.dart
```
Expected: FAIL（`NavigationBar` 仍在、找不到 ☰）

- [ ] **Step 3: 实现**

创建 `lib/shared/presentation/app_drawer.dart`：`Drawer` + `ListView`，四项 `ListTile`（工具 / 笔记 / 历史 / 设置），当前项高亮，底部一项「设置」调 `onOpenSettings`。颜色全部取自 `CalcTheme`。

改写 `app_shell.dart`：
- 移除底部 `NavigationBar`
- `Scaffold` 加 `drawer: AppDrawer(...)`
- 保留 `PageView` 与 `_KeepAlivePage`（保活与性能优化已经在里面）
- 主屏的 ☰ 走 `Scaffold.of(context).openDrawer()`

- [ ] **Step 4: 运行确认通过**

```bash
flutter test test/features/app_shell_test.dart
```

- [ ] **Step 5: 全量确认**

```bash
flutter analyze && flutter test
```
Expected: `No issues found!`，测试数 ≥ 733

- [ ] **Step 6: 提交**

```bash
git add lib/shared/presentation/app_drawer.dart lib/shared/presentation/app_shell.dart \
        test/features/app_shell_test.dart
git commit -m "feat(shell): replace bottom tabs with a navigation drawer"
```

---

## 完成标准

- `flutter analyze` 零问题；`flutter test` 全过且 ≥ 733
- 主屏为 HiPER 形态：6 列键盘、主键行与 SHIFT 标签行交替、数字键与函数键同屏
- 主屏**不滚动**（当前有 211dp 溢出）
- 侧边抽屉可达 工具 / 笔记 / 历史 / 设置
- 新增代码**零硬编码颜色**；加第四套主题不需触碰组件文件
- **真机验证**：在已连接的小米 11（arm64-v8a, Android 14）上 `flutter run`，确认手感与窄屏布局

## 后续（不在本计划范围）

结果行的精确形式（需引擎）、键盘翻页（`◀ ▶`）、自定义键盘布局编辑、Casio/Sharp 按键标题风格、禁用键的后续实现。
