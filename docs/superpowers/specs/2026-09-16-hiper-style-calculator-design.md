# HiPER 式主屏与自然显示设计

日期：2026-09-16
状态：待评审

## Goal

把 NekoCalc 的主界面重做成 HiPER Calc Pro 的形态：单一键盘、无标签页、所见即所得的数学排版显示。
工程工具箱（79 个工具）完整保留，但退到次级入口。

这次改动**只碰界面与渲染层**。计算语义、数值精度、历史、持久化、全部工具逻辑保持不变。

## 产品定位

主屏是一个科学计算器，不是一个工具箱。

- **主屏**：表达式 + 自然显示结果 + 单一键盘。没有标签页，没有应用名标题行，没有常驻状态卡。
- **次级入口**：侧边抽屉（☰）通往 工具 / 笔记 / 历史。
- **工具箱**：25,613 行代码全部保留，功能不减，只是不再是主界面的并列一等公民。

这样做的理由是：HiPER 4.9 星、4000 万下载的形态是经过验证的；而 `calculator_page.dart`
当前有 211dp 溢出、函数页无法输入数字、需要滚动才点得到操作按钮。主屏重写本来就该做。

## 核心决策：String 仍是唯一真相

表达式继续以 canonical `String` 为准。AST 是从它**派生**出来的只读结构。

这是本设计最关键的一条，它带来三个直接好处：

1. **求值器完全不动** —— `expression_parser.dart`（939 行）继续把字符串算成 `double`，
   结果数值行为零变化。
2. **存储层完全不动** —— 历史、笔记、持久化、剪贴板继续存字符串，无迁移、无兼容问题。
3. **623 个测试继续有意义** —— 它们测的是字符串进、数值出，这条契约不变。

代价是每次表达式变化要重新解析一次。表达式通常几十个字符，解析成本可忽略。

将来接入符号引擎时，再把 AST 提升为唯一真相——那是一次独立的、有明确前置条件的迁移。
本设计不预先承担那个成本。

## Architecture

```
canonical String（唯一真相，不变）
      │
      │  ① ExpressionAstParser.parse()          ← 新增，复用现有词法规则
      ▼
   ExprNode 树（每个节点带 start/end 源码区间）
      │
      │  ② TexEmitter.emit()                     ← 新增，纯函数
      ▼
   List<TexFragment>（按顶层节点切分）
      │
      │  ③ MathExpressionView                    ← 新增 widget
      ▼
   逐节点 Math.tex() 并排  →  节点级命中测试
```

### 模块边界

| 新增模块 | 位置 | 职责 | 依赖 |
|---|---|---|---|
| `ExprNode` 及子类 | `lib/core/math/ast/expr_node.dart` | 只读语法树，节点携带源码区间 | 无 |
| `ExpressionAstParser` | `lib/core/math/ast/expression_ast_parser.dart` | String → AST，含不完整输入 | `ExprNode` |
| `TexEmitter` | `lib/core/math/ast/tex_emitter.dart` | AST → TeX 片段 | `ExprNode` |
| `MathExpressionView` | `lib/features/calculator/presentation/widgets/math_expression_view.dart` | 渲染 + 节点级命中 | `flutter_math_fork`, `TexEmitter` |

三个核心模块都是纯函数式的、不依赖 Flutter，可以直接单元测试。

## 组件设计

### ExprNode

```dart
sealed class ExprNode {
  const ExprNode({required this.start, required this.end});
  final int start;   // 闭区间起点，canonical String 偏移
  final int end;     // 开区间终点
}
```

节点类型：

| 节点 | 承载 | 例子 |
|---|---|---|
| `NumberNode` | 数字字面量 | `30`、`1.5e3` |
| `ConstantNode` | 常量 | `pi`、`e`、`Ans` |
| `VariableNode` | 自由变量 | `x`、`y`（图形页使用） |
| `BinaryNode` | 二元运算 | `+`、`-`、`*`、`/`、`^` |
| `UnaryNode` | 一元前缀 | 负号 |
| `PostfixNode` | 后缀 | `!`、`%`、`²` |
| `FunctionNode` | 函数调用，含参数列表 | `sin(30)`、`root(3,x)`、`log(2,8)` |
| `GroupNode` | 显式括号 | `(a+b)` |
| `ImplicitProductNode` | 隐式乘法 | `2x`、`3(x+1)` |
| `ListNode` | 顶层逗号列表 | `1,2,3` |
| `ParseErrorNode` | 无法解析的片段 | `sin(` 的未闭合部分 |

**`start`/`end` 是节点级光标定位的全部依据**，必须精确到 canonical String 的偏移。

### 不完整表达式的处理

用户输入过程中必然出现不完整表达式（`sin(`、`2+`）。当前行为是解析失败即显示"等待输入"。

新设计必须让**显示层容忍不完整输入**：

- 解析器遇到无法解析的尾部时，产出 `ParseErrorNode` 而不是抛异常。
- `TexEmitter` 对 `ParseErrorNode` 原样输出其源码文本，不产出 TeX 结构。
- `MathExpressionView` 对每个顶层片段独立渲染：TeX 解析失败的片段**降级为等宽文本**，
  不影响其余片段的排版。

这样 `sin(30)+log(2` 会渲染成「排版良好的 `sin(30)+` 部分」+「文本形式的 `log(2`」，
而不是整行失败或整行飘红。

### TexEmitter

按 AST 结构产出 TeX。关键映射：

| AST | TeX |
|---|---|
| `BinaryNode('/')` | `\frac{左}{右}` |
| `BinaryNode('^')` | `{左}^{右}` |
| `FunctionNode('sqrt')` | `\sqrt{参数}` |
| `FunctionNode('root')` | `\sqrt[次数]{被开方数}` |
| `FunctionNode('abs')` | `\left|参数\right|` |
| `FunctionNode('sin')` 等 | `\sin(...)`，函数名用 `\operatorname` 兜底 |
| `ConstantNode('pi')` | `\pi` |
| `PostfixNode('!')` | `{操作数}!` |
| `ImplicitProductNode` | 相邻节点直接拼接，必要时插入 `\cdot` |

`GroupNode` 在 TeX 中通常**不再需要括号**（`\frac` 和 `\sqrt` 自带视觉分组），
这正是自然显示比现在好看的原因之一。但 `GroupNode` 的 `start`/`end` 仍要保留，
因为源码里的括号是真实的编辑对象。

### MathExpressionView

```dart
MathExpressionView({
  required String expression,
  required bool naturalDisplay,        // 对应现有设置的"数学符号"模式
  required int? cursorIndex,           // null 表示不显示光标
  void Function(int sourceOffset)? onTapOffset,
})
```

渲染方式：把 AST 的**顶层节点**各自渲染成一个 `Math.tex()`，在横向滚动容器中并排。

选择这个切分方式的原因有两个：

**其一，命中测试。** 每个顶层节点是一个真实的 Flutter widget，点击时由 Flutter
原生的命中测试直接确定落在哪个节点上，取其 `start` 作为光标偏移。
**这完全不依赖 `flutter_math_fork` 的任何内部 API** —— 比解析它的布局树可靠得多。

**其二，光标可以按源码位置插入片段之间。** 既然渲染单元是"顶层节点序列"，
光标就成了序列中的一个独立元素：在 `cursorIndex` 所属的位置插入一个光标 widget 即可，
不需要在 TeX 内部做文章。当 `cursorIndex` 为 null 时不插入。

`naturalDisplay` 对应现有的 `expressionDisplayMode` 设置：为真时走 TeX 自然排版，
为假时整行降级为等宽文本，保留用户"原始文本"偏好的语义。

`Math.tex()` 的 `onErrorFallback` 用于把该片段降级成文本，而不是抛错。

### 显示态与编辑态的交接

| 状态 | 使用 | 光标 |
|---|---|---|
| 显示态 | `MathExpressionView`（自然排版） | 见下方"显示态光标" |
| 编辑态 | 现有 `InlineExpressionEditor` | 精确到字符 |

点击显示态任意位置 → 进入编辑态，光标落到**最近顶层节点的 `start` 偏移**。

#### 显示态光标

显示态**保留光标**，通过上文说的"片段间插入"实现（`cursorIndex` 非 null 时插入）。

这样做是为了保持现有行为：用户需要看见下一次按键会落在哪里。若显示态没有光标，
用户点击前的输入位置就完全不可见，是相对当前实现的倒退。

光标位置只在**顶层节点的边界**上精确；若 `cursorIndex` 落在某个节点内部，
光标渲染在该节点**之前**。这是节点级定位精度的自然结果，与已接受的取舍一致。

编辑态**一行不改**。`_MathSourceOffsetMap` 继续服务编辑态内部的精确光标定位。

已知退化：进出编辑态时字形会从排版体跳回等宽文本。这个跳变**已经存在**
（当前是"数学符号渲染"↔"原始文本"），不是新增问题。

### 主屏重写

`calculator_page.dart` 重写为 HiPER 式布局，自上而下只有一个纵向流：

```
☰  DEG/RAD                                    设置
┌──────────────────────────────────────────┐
│  表达式（自然排版，右对齐，可横向滚动）        │
│  = 结果                                   │
└──────────────────────────────────────────┘
   [ ← 函数区（方案待定）→ ]                  ← 见下方"键盘布局"
   [ (  )  %  ⌫ ]
   [ 7  8  9  ÷ ]
   [ 4  5  6  × ]
   [ 1  2  3  − ]
   [ +/− 0  .  = ]
```

**注意**：上面的函数区是**占位示意，尚未定稿**。

### 键盘布局（未决，实施前必须定稿）

唯一已确定的是：**数字键与 `+ - × ÷` 必须与函数键同时可见**。
这是本次重写的核心修正——当前函数页 57 个键里没有任何数字和四则运算符，
`sin(30)+log(2)` 需要 13 次点击、其中 4 次是纯切页。

函数区具体采用哪种组织方式尚未决定。三个候选：

| 方案 | 形态 | 代价 |
|---|---|---|
| A | 常驻数字区 + 顶部横向滑动函数带 | 57 个函数横向滑动较长 |
| B | 保留双标签页，两边都补数字区 | 未解决同屏共存，且更挤 |
| C | 单键盘 + 可展开科学面板（Google 计算器 9.0 形态） | 函数多一次点击 |

**HiPER 的做法是第四种**，需要一并评估：数字区恒常存在，函数页用方向箭头翻页切换，
并且键盘布局可由用户自定义。既然目标是仿造 HiPER，C 与 HiPER 方案都应纳入比较。

该决定在步骤 2 开始前单独确认，不阻塞步骤 1。

移除的东西：

- 应用名 + logo 标题行（计算器页不需要报应用名）
- `_padTabs()`（Basic/函数 双标签页）
- 常驻的 `_resultStatusCard()`（改为仅在出错时出现）
- 常驻的 `_memoryBar()`（收进抽屉或函数带）
- 底部三个操作按钮（收进溢出菜单）
- `SingleChildScrollView`（主屏不再滚动）

**函数键与数字键共存**是这次重写的核心修正。当前函数页 57 个键里没有任何数字和
`+ - × ÷`，导致 `sin(30)+log(2)` 需要 13 次点击、其中 4 次是纯切页。

### 导航重构

`app_shell.dart` 的底部 4 tab 导航改为：

- 主屏无底部导航
- 侧边抽屉（☰）提供 工具 / 笔记 / 历史 / 设置 入口
- 工具页内部的分类、搜索、收藏、最近使用**全部保留不变**

## 错误处理

| 情况 | 行为 |
|---|---|
| 表达式不完整 | 显示层按上述降级策略渲染；不飘红、不显示"需要修正" |
| TeX 生成失败 | 该顶层片段降级为等宽文本 |
| `Math.tex` 解析失败 | `onErrorFallback` 降级为等宽文本，不影响其他片段 |
| 表达式为空 | 显示区显示占位提示，键盘可用 |
| 求值出错 | 沿用现有中文错误信息（`缺少右括号` 等），仅在此时显示状态行 |

## 迁移策略

本设计**不删除**任何现有能力。分两步落地，每步可独立验证：

**步骤 1 —— 渲染层（不动 UI）**
新增 `ast/` 三个模块与 `MathExpressionView`。此时主屏仍是旧的，新组件先由单元测试和
一个独立的预览页验证。全部新代码，零回归风险。

**步骤 2 —— 主屏与导航重写**
重写 `calculator_page.dart` 与 `app_shell.dart`，接入 `MathExpressionView`。

`MathExpressionText`（702 行）在步骤 2 之后降级为编辑态与兜底路径，**暂不删除**，
待新路径稳定后再单独清理。

## 兼容性

必须保持不变的契约：

- `expression_parser.dart` 的输入输出（字符串 → `double`）
- `CalculatorController` 的公开 API 与状态机（仅新增"取当前 AST"的只读接口）
- 历史与笔记的存储格式
- 79 个工具的入口与行为
- 剪贴板与粘贴解析行为

## 测试策略

**新增单元测试**（纯 Dart，无 Flutter 依赖）：

- `ExpressionAstParser`：每种节点类型；**不完整输入的 `ParseErrorNode` 产出**；
  `start`/`end` 偏移的精确性；隐式乘法；嵌套函数；逗号参数列表
- `TexEmitter`：每种节点的 TeX 输出；`GroupNode` 的括号消除；错误节点的原样输出

**新增 widget 测试**：

- `MathExpressionView` 渲染成功 / 片段降级 / 点击命中返回正确的源码偏移
- 主屏在 320dp / 360dp / 412dp 下**不溢出、不滚动**
- 函数带与数字键同时可见
- 抽屉可达 工具 / 笔记 / 历史

**回归**：现有 623 个测试必须全部保持通过。

**手工验证**：真机上确认自然排版观感、点击定位手感、进出编辑态的字形跳变是否可接受。

## 风险与未决项

| 项 | 说明 | 处置 |
|---|---|---|
| 依赖足迹 | `flutter_math_fork` 带入 `provider`、`flutter_svg`、`vector_graphics`，共 49 个依赖变动（含 sqflite 传递升级） | 已实测解析通过；实施时逐项确认无行为影响 |
| 包维护状态 | `flutter_math_fork` 最后发布 2025-05，已 16 个月未更新 | 通过 `MathExpressionView` 封装隔离，必要时可替换后端 |
| 点击定位精度 | 从字符级降到顶层节点级 | 已确认接受 |
| 许可证 | 项目为 GPL-3.0；`flutter_math_fork` 是 Apache-2.0，无冲突。后续 libqalculate / Giac 等引擎选项需单独核实 | **按用户要求押后统一处理** |
| 键盘布局细节 | 函数键与数字键如何同屏共存尚未定稿，HiPER 的翻页式布局需一并评估 | 见"键盘布局"一节；步骤 2 开始前单独确认 |

## Non-Goals

本设计明确**不做**：

- 不改数值引擎（仍是 `double`）
- 不做任意精度、符号运算、复数、矩阵、方程求解
- 不做 3D 图形、RPN、可自定义键盘
- 不删减或改动 79 个工具的功能
- 不把 AST 提升为唯一真相
- 不改动历史、笔记、持久化的数据格式

这些属于后续阶段，各自独立立项。

## 后续阶段（不在本设计范围）

1. **引擎升级**：任意精度 / 精确分数 / π 与 √ 的精确形式
2. **符号后端**：解方程、求导、积分——AST 已经预留了接口位置
3. **动效与设计系统**：67 个硬编码颜色收敛为 token；补动效层（当前全 App 仅 2 处动画）
4. **历史闭环**：历史项"载入到计算器"重算；计算器页历史入口
5. **发现性**：命令面板；单位浏览器；工具交叉引用
