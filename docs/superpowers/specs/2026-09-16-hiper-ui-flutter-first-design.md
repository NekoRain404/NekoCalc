# HiPER 式主屏 · Flutter 优先设计

日期：2026-09-16
状态：待实施
取代：`2026-09-16-hiper-style-calculator-design.md`（那份假设纯自建 AST，架构已变更）

## Goal

用 Flutter 把 NekoCalc 的主界面做成 HiPER Calc Pro 的形态：两行自然排版显示 + 单块密集键盘，
并建立一套**多主题、多配色**的设计系统。工程工具箱（79 个工具）完整保留，退到次级入口。

## 引擎决策：延后，先留接口

原计划用 libqalculate 做数值与符号引擎。技术验证（spike）结论：

| 项 | 结论 |
|---|---|
| 许可证 | libqalculate 是 **GPL-2.0-or-later**，与项目 GPL-3.0 兼容 ✅ |
| Android 绑定 | Maven Central 有现成 AAR（`com.jherkenhoff:libqalculate:5.8.2-2`），SWIG 生成，覆盖全部核心类 ✅ |
| ABI | arm64-v8a / armeabi-v7a / x86 / x86_64 全有 ✅ |
| Java API | `new Calculator()`、`calculate(String)`、`new PrintOptions()`、`print(po, format, colorize, tagtype)` 全部可用 ✅ |
| **LaTeX 输出** | **`TAG_TYPE_LATEX` 是 v5.12.0 才加入的，现成 AAR 是 5.8.2 —— 拿不到** ❌ |
| APK 体积 | 单 ABI 约 +13.2 MB（未经压缩）⚠ |

**结论：引擎集成有真实的前置成本，且与界面无关。** 因此本阶段：

- 界面与显示层**全用 Flutter 实现**，不引入任何原生依赖
- 求值继续用现有 `double` 求值器
- 引擎放在一个**接口后面**，后续可替换为 libqalculate，或纯 Dart 方案

这不损失进度：HiPER 的"专业感"里，**自然排版是界面层的功劳**，和引擎无关。引擎负责的是精度与符号能力，属于后续阶段。

## HiPER 主屏规格（已从官方截图与手册解码）

### 显示区：两行

```
┌──────────────────────────────────────────┐
│ RAD            M 1  4 5 6        More... │  ← 状态行
│                                          │
│   π/2 × √((2/3)² − 2√cos(2π))            │  ← 表达式行（自然排版）
│                                          │
│                            =  iπ√14 / 6  │  ← 结果行（右对齐，自然排版）
└──────────────────────────────────────────┘
  EXPR                    CPLX                 ← 模式标签
```

- 表达式行与结果行**都用自然排版**（分数堆叠、真根号、规范上下标）
- 状态行：角度模式（`RAD`）、记忆指示（`M`）、显示格式指示（`1 4 5 6` 等）、`More...` 按钮
- 结果行的 `EXPR` / `CPLX` 等指示器标明当前结果格式

### 键盘：6 列，主键行与 SHIFT 标签行交替

**这是 HiPER 不切页的关键机制。** 矮行是**下面那行主键的 SHIFT 功能标签**，不是独立按钮：

```
[SHIFT][MENU][ ◀ ][ ▶ ][ ⌫ ][ AC ]
 ▸DRG   FSE   MTRX   Π   d/dx            ← SHIFT 标签行
[ DRG ][x⇔E][ [::] ][ Σ ][∫dx][ 📷 ]
 hyp   sin⁻¹  cos⁻¹  tan⁻¹  ∠   logₓy    ← SHIFT 标签行
[  π  ][ sin ][ cos ][ tan ][ i ][ e ]
 lim    x³    ∛x    ˣ√y   10ˣ   eˣ
[ x⁻¹ ][ x² ][ √x  ][ xʸ ][ log ][ ln ]
 STAT  a b/c   Y   HISTORY  M+   M−
[D°M'S][ d/c ][ X ][XY,M ][ MR ][x→M]
 CPLX    ∞          %        mod
[  7  ][  8  ][  9  ][   (    ][  )  ]
 n!    nCr   nPr   ▸BIN     ▸OCT
[  4  ][  5  ][  6  ][   ×    ][  ÷  ]
 CNST  CONV  abs   ▸DEC     ▸HEX
[  1  ][  2  ][  3  ][   +    ][  −  ]
OTHER  ran#  Ans   EXP SI    =,＜＞
[  0  ][  .  ][+/−][  EXP   ][  ✓  ]
```

唯一的例外：`▸BIN ▸OCT ▸DEC ▸HEX` 是**真按钮**，被特意放进标签行。

**这从根上解决了当前"函数页打不出数字、必须切页"的问题** —— 数字键永远在位。

### 配色语义体系

背景色承载**语义分类**，换主题时必须保住这套规则：

| 类别 | 语义 |
|---|---|
| 数字键 | 最高对比 |
| 运算符 | 次高对比 |
| 函数键 | 常规 |
| 变量 / 记忆 | 独立色相（HiPER 用蓝） |
| SHIFT | 模态键，独立色相 |
| 退格 / 清空 | **破坏性操作**，暖色警示 |

## 主题系统要求

用户明确要求：**提前留好多主题、多配色**，且基础色调偏柔和。

因此本设计**不允许硬编码颜色**。当前项目有 67 处 `Color(0x...)` 硬编码，必须先收敛为 token。

三层 token：

```
Primitive（原始色阶）  rose-50 … rose-900
        ↓
Semantic（语义映射）   keyDigitBg / keyOperatorBg / keyFunctionBg /
                       keyVariableBg / keyModifierBg / keyDestructiveBg /
                       displayBg / keypadBg / resultFg / expressionFg
        ↓
Theme（主题包）        每套主题给出一组 Semantic 取值
```

新增主题 = 新增一个 Theme 常量集，不改任何组件代码。

首批主题：

| 主题 | 说明 |
|---|---|
| `roseCream` 玫瑰奶霜 | 暖调玫瑰 + 奶油，柔和 |
| `lavenderMist` 薰衣草雾 | 冷调紫罗兰，最接近现有紫蓝色系 |
| `peachSugar` 蜜桃砂糖 | 蜜桃珊瑚 + 浅杏，温暖活泼 |

每套都要有浅色与深色两个变体。

## 架构

```
表达式 String（唯一真相，不变）
      │
      │  ① ExpressionAstParser          ← 新增
      ▼
   ExprNode 树（节点带 start/end 源码区间）
      │
      │  ② TexEmitter                   ← 新增，纯函数
      ▼
   TeX 片段列表（按顶层节点切分）
      │
      │  ③ MathExpressionView           ← 新增 widget
      ▼
   逐节点 Math.tex() 并排 → 节点级命中测试
```

三个模块都不依赖 Flutter（`MathExpressionView` 除外），可直接单元测试。

**求值器、历史、持久化、剪贴板、79 个工具、623 个测试全部不动。**

## 键盘布局：不切页

主屏键盘按上述 HiPER 结构重写。**数字键与四则运算符永远在位**，函数键围绕它们排布，
SHIFT 键切换第二功能，`◀ ▶` 翻页切换整套键位。

**移除**：应用名标题行、`_padTabs()` 双标签页、常驻结果状态卡、常驻记忆条、底部三个操作按钮、
主屏的 `SingleChildScrollView`（重写后不得滚动）。

## 导航

底部 4 tab 改为侧边抽屉（☰）：工具 / 笔记 / 历史 / 设置。
工具页内部的分类、搜索、收藏、最近使用**全部保留不变**。

## 非目标

- 不引入 libqalculate 或任何原生依赖
- 不改数值引擎（仍是 `double`）
- 不做任意精度、符号运算、复数、矩阵、方程求解
- 不做 3D 图形、RPN、自定义键盘编辑
- 不删减 79 个工具
- 不改数据存储格式

## 测试策略

- **单元**：`ExpressionAstParser`（各节点类型、不完整输入的 `ParseErrorNode`、`start`/`end` 精确性、隐式乘法）；`TexEmitter`（各节点 TeX 输出、括号消除、错误节点降级）；主题 token 完整性（每套主题的 Semantic 键齐全）
- **widget**：`MathExpressionView` 渲染与降级、点击命中偏移；主屏在 320/360/412dp 下**不溢出、不滚动**；SHIFT 键切换第二功能；主题切换后所有键位取到新色
- **回归**：现有 623 个测试全部保持通过

## 风险

| 项 | 处置 |
|---|---|
| `flutter_math_fork` 依赖足迹（带入 provider / flutter_svg，49 个依赖变动） | 已实测解析通过；用 `MathExpressionView` 封装隔离，必要时可换渲染后端 |
| 包 16 个月未更新 | 同上，隔离在封装内 |
| 引擎延后导致精度仍是 double | 明确接受；引擎在接口后，后续可替换 |
| HiPER 按键语义需逐键核对 | 以官方手册 PDF v12.0 与截图为依据，逐键对照 |
