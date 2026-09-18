part of 'hiper_keypad.dart';

/// 中文：键盘的数字区——第 6–9 行（`7 8 9 ( )`、`4 5 6 × ÷`、`1 2 3 + −`、`0 . +/− EXP ✓`）。
///       这条缝为什么在这里，见 `hiper_keypad.dart` 里 `hiperKeypad` 上面那一段。
/// English: the keypad's number area — rows 6–9 (`7 8 9 ( )`, `4 5 6 × ÷`, `1 2 3 + −`,
///          `0 . +/− EXP ✓`). Why the seam is here: see the note above `hiperKeypad` in
///          `hiper_keypad.dart`.
const List<KeypadRow> _numberRows = <KeypadRow>[
  // 中文：行 6——数字 7 8 9 与括号。HiPER 在这里收窄为 5 列，标签横带只有 4 格，末格补 null。
  //       上方标签：**`CPLX` 从这一步起点亮**（原来是一颗灰键 `dis:cplx`），以及 ∞（`ins:inf`）、
  //       %（`ins:%`）、mod。
  // English: Row 6 — digits 7 8 9 and parentheses. HiPER narrows to five columns here, so the
  //          band above holds only four cells and the last slot is padded with null: **`CPLX` lights
  //          up from this step on** (it used to be a grey `dis:cplx`), plus ∞ (`ins:inf`), `%`
  //          (`ins:%`) and mod.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '7', id: '7'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '8', id: '8'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '9', id: '9'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '(', id: '('),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: ')', id: ')'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      // 中文：**`CPLX` 打开复数面板——它是一个入口，不是一个模式。** 这一步先量后定，量出来的是：
      //       复数**能力早就在**（引擎的 `EvaluationOptions.setAllow_complex(true)` 一直接着，
      //       实测 `sqrt(-4)` = `2i`、`(3+4i)(1-i)` = `7 + i`、`abs(3+4i)` = `5`），所以「打开复数
      //       模式」会是一颗**把已经开着的东西再打开一次**的键，它的指示灯会是一句假话。
      //       真正缺的只有**入口**：共轭、辐角、实部、虚部这四个函数键盘上没有键，而它们都要括号
      //       与实参——键盘给不出来，面板可以（与 `CONV`/`X` 同一种做法）。
      //       面板插入的是一次**一元函数**调用（`conj`/`arg`/`re`/`im` 走 `applyUnaryFunction`，
      //       与 `sin`/`abs`/`sqrt` 逐字同一条路），所以光标位置、撤销栈、边打边算全都照旧。
      // English: **`CPLX` opens the complex sheet — it is an entrance, not a mode.** This was measured
      //          before it was decided: the complex **capability has been there all along** (the
      //          engine's `EvaluationOptions.setAllow_complex(true)` is set, and `sqrt(-4)` = `2i`,
      //          `(3+4i)(1-i)` = `7 + i`, `abs(3+4i)` = `5` all measure correctly), so "turn complex
      //          mode on" would be a key that switches on what is already on, and its indicator lamp
      //          would be a lie. What is genuinely missing is the **entrance**: the four functions
      //          conjugate / argument / real part / imaginary part have no key, and each needs brackets
      //          and an argument — the keypad cannot supply that, a sheet can (the `CONV`/`X` shape).
      //          The sheet inserts a **unary function** call (`conj`/`arg`/`re`/`im` go through
      //          `applyUnaryFunction`, byte for byte the path `sin`/`abs`/`sqrt` take), so cursor
      //          position, the undo stack and as-you-type evaluation all behave as before.
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CPLX', id: 'openComplex'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '∞', id: 'ins:inf'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '%', id: 'ins:%'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'mod', id: 'mod'),
          category: KeyCategory.function,
        ),
      ),
      null,
    ],
  ),

  // 中文：行 7——数字 4 5 6 与乘除。id 用解析器友好的 `*`、`/`，键面仍显示 `×`、`÷`。
  //       上方标签：n!、nCr、nPr 三个函数键，加上 **`▸BIN`、`▸OCT`** 两个进制胶囊。
  //
  //       **`▸` 现在画上了——这是一处已经关掉的键面偏差。** 两个 `▸` 键面（本行两颗，加上行 8 的
  //       `▸DEC`/`▸HEX`、行 2 横带的 `▸DRG`）在过去写成不带 `▸` 的 `BIN`/`OCT`/`DEC`/`HEX`/`DRG`。
  //       本轮据此改回，依据是**厂商自己当前的键位**，逐条都是量出来的：
  //       1. **厂商官网的当前主屏截图**（`https://hiperlabs.eu/screenshots.html` →
  //          `assets/img/01 calculator.png`，本轮自己下载、逐格读过）：四个胶囊**字块里**印的正是
  //          `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX`，横带第一格是 `▸DRG`——**`▸` 在胶囊内部**，也就是说它是
  //          键面文字的一部分，不是胶囊上的装饰。
  //       2. **本机那张 1440×3200 真机截图**（`~/Downloads/04_媒体/…cz.hipercalc.p.jpg`）上同样是
  //          `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX`/`▸DRG`——两个布局版本在这一点上没有分歧。
  //       3. `▸`（U+25B8）是这个**换算家族名字的一部分**：厂商自己的更新日志把它写成
  //          `▸BASE` 函数（`msgctxt "releaseNotes"`，就在厂商字符串表的**第 8888 行**：
  //          `msgid "\\u25B8BASE function available in custom keyboards"`。本轮从
  //          `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/`
  //          重新取回核对，行号与原文都对得上，抄本见 `.superpowers/backup/mtrx-drg-report.md:150`；
  //          抽取文件 `/tmp/hiper_en.po` 在本机 `/tmp`，已不存在），
  //          而同一个家族在展开布局里是 `►DEG`/`►RAD`/`►GRAD` 三颗**没有第二功能、也没有 SHIFT** 的键。
  //
  //       ⚠️ 这条路上有两句话是假的，留在这里免得下一轮再抄一遍：**「`▸` 只是装饰」**（第一次的说法）
  //       与**「刻意不画，取舍理由尚未写下」**（第二次的说法——它写得对，但那个理由并不存在：
  //       没有任何一处记录说过为什么要省掉 `▸`）。现在两处都不再成立：画上了，理由就是上面三条。
  //       **判据与派发一字未动**——变的是键面文字，`baseBin`/`baseOct` 这些 id 与它们背后的动作没碰。
  // English: Row 7 — digits 4 5 6 with multiply and divide. The ids stay parser-friendly
  //          (`*`, `/`) while the faces show `×` and `÷`.
  //          Band above: the n!, nCr, nPr function keys plus the **`▸BIN`, `▸OCT`** base pills.
  //
  //          **The `▸` is drawn now — a key-face deviation closed.** The five `▸` faces (this row's two,
  //          row 8's `▸DEC`/`▸HEX` and row 2's `▸DRG` band cell) used to be written `BIN`/`OCT`/`DEC`/
  //          `HEX`/`DRG` without it. This round puts them back, on the vendor's **current** keypad,
  //          measured item by item:
  //          1. **The vendor's current main-screen screenshot**
  //             (`https://hiperlabs.eu/screenshots.html` → `assets/img/01 calculator.png`, downloaded
  //             and read cell by cell this round): the four capsules carry
  //             `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` **inside the capsule**, and the band's first cell is `▸DRG`
  //             — the arrow is part of the face text, not decoration on the capsule.
  //          2. **The device screenshot on this machine** (the 1440×3200 file cited above) reads the
  //             same `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX`/`▸DRG` — on this point the two layout versions agree.
  //          3. `▸` (U+25B8) is part of the **conversion family's name**: the vendor's own release notes
  //             spell it the `▸BASE` function (`msgctxt "releaseNotes"`, **line 8888** of the vendor
  //             string table: `msgid "\\u25B8BASE function available in custom keyboards"` —
  //             re-fetched and checked this round from
  //             `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/`,
  //             with a copy in `.superpowers/backup/mtrx-drg-report.md:150`; the extracted file
  //             `/tmp/hiper_en.po` was on this machine's `/tmp` and is gone),
  //             and the same family appears in the expanded layout as `►DEG`/`►RAD`/`►GRAD` keys in a
  //             layout that **has no second functions and no SHIFT at all**.
  //
  //          ⚠️ Two sentences on this road were false; both stay here so the next round does not copy
  //          them: **"`▸` is mere decoration"** (the first) and **"deliberately not drawn, the reason
  //          not yet written down"** (the second — accurate as a description, but there was no reason
  //          to write down: nothing anywhere recorded why the arrow was dropped). Neither holds now:
  //          it is drawn, and the reason is the three items above.
  //          **No judgement and no dispatch moved** — the faces changed; the ids `baseBin`/`baseOct`
  //          and the actions behind them were not touched.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '4', id: '4'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '5', id: '5'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '6', id: '6'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '×', id: '*'),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: '÷', id: '/'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'n!', id: 'fact'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'nCr', id: 'nCr'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'nPr', id: 'nPr'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '▸BIN', id: 'baseBin'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '▸OCT', id: 'baseOct'),
          category: KeyCategory.pill,
        ),
      ),
    ],
  ),

  // 中文：行 8——数字 1 2 3 与加减。`−` 的 id 是解析器用的 `-`。
  //       上方标签：CNST（常数分类）、CONV（单位换算）、abs，以及 **`▸DEC`、`▸HEX`** 两个进制胶囊。
  //
  //       **`CNST`/`CONV` 摆在这两格，跟的是厂商当前的默认键盘，不是本机那张截图——本轮实测。**
  //       两张图都对，差的是**布局版本**，所以这里把两边的读数都留下：
  //       - **厂商官网的当前主屏截图**（`https://hiperlabs.eu/screenshots.html` →
  //         `assets/img/01 calculator.png`，本轮自己下载逐格读过）：`1`/`2` 上方是 `CNST`/`CONV`，
  //         第 2 行第 6 格是**相机键**（上方无标签）——与本表**逐格一致**。
  //       - **本机那张 1440×3200 真机截图**（`~/Downloads/04_媒体/…cz.hipercalc.p.jpg`）：这两格是
  //         `gcd`/`lcm`，而 `CONV` 在第 2 行第 6 格、`CNST` 是它的第二功能。
  //       - **厂商自己的字符串说清了这是两个布局**（`cameraWindow.cameraRevoked.info` /
  //         `cameraWindow.permissionRevoked.text`）："If you want to use the former keyboard layout
  //         with the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select the
  //         **Custom / Version 10 keyboard**."——也就是说 `CONST`/`CONV` 的「原位」正是本机截图
  //         那一版（Version 10），当前默认布局把它们挪到了 `1`/`2` 的横带上，相机键占了原来那一格。
  //       - `gcd`/`lcm` 在当前默认布局上**没有格子**（相机版把它们从横带里换掉了），本应用与它一致：
  //         两个动作都在（`calculator_key_dispatch.dart` 的 `gcd`/`lcm` case），入口在「更多函数」面板。
  // English: Row 8 — digits 1 2 3 with plus and minus; the `−` face carries the parser's
  //          `-` id. Band above: CNST (constant category), CONV (unit conversion), abs, and the
  //          **`▸DEC`, `▸HEX`** base pills.
  //
  //          **`CNST`/`CONV` sit in these two cells because that is the vendor's *current* default
  //          keyboard, not because of the device screenshot — measured this round.** Both pictures
  //          are right; what differs is the **layout version**, so both readings stay here:
  //          - **The vendor's current main-screen screenshot** (`https://hiperlabs.eu/screenshots.html`
  //            → `assets/img/01 calculator.png`, downloaded and read cell by cell this round): above
  //            `1`/`2` are `CNST`/`CONV`, and row 2's sixth cell is the **camera key** with no label
  //            above it — **cell for cell the same as this table**.
  //          - **The device screenshot on this machine** (the 1440×3200 file cited above): those two
  //            cells read `gcd`/`lcm`, while `CONV` is row 2's sixth key with `CNST` as its second
  //            function.
  //          - **The vendor's own strings say these are two layouts** (`cameraWindow.cameraRevoked.info`
  //            / `cameraWindow.permissionRevoked.text`): "If you want to use the former keyboard layout
  //            with the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select
  //            the **Custom / Version 10 keyboard**." So the "original positions" of `CONST`/`CONV` are
  //            exactly what the device screenshot shows (Version 10); the current default layout moved
  //            them onto the `1`/`2` band cells and gave their old cell to the camera key.
  //          - `gcd`/`lcm` have **no cell** on the current default keyboard (the camera version swapped
  //            them out of the band), and this app agrees: both actions exist (the `gcd`/`lcm` cases in
  //            `calculator_key_dispatch.dart`) with their entrance in the "more functions" sheet.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '1', id: '1'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '2', id: '2'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '3', id: '3'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '+', id: '+'),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: '−', id: '-'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CNST', id: 'openConstants'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CONV', id: 'openUnits'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'abs', id: 'abs'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '▸DEC', id: 'baseDec'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '▸HEX', id: 'baseHex'),
          category: KeyCategory.pill,
        ),
      ),
    ],
  ),

  // 中文：行 9——0 / 小数点 / 正负号 / EXP / 等号。
  //       `EXP` 走 `ins:exp` 而不是计划书写的 `ins:e`：`ins:e` 已被上一行的 `e` 常量占用，
  //       两者同 id 会撞上「键的 id 全局唯一」。
  //       上方标签：OTHER（打开工具箱）、ran#（已启用：插引擎的 `rand()`）、禁用的 EXP SI 与
  //       =,＜＞、Ans。
  // English: Row 9 — 0 / decimal point / sign toggle / EXP / equals.
  //          `EXP` uses `ins:exp` rather than the plan's `ins:e`, which the `e` constant on
  //          the row above already owns — the collision would break the global id-uniqueness
  //          invariant.
  //          Band above: OTHER (opens the tools), an enabled ran# (it inserts the engine's
  //          `rand()`), the disabled EXP SI and =,＜＞, and Ans.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '0', id: '0'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '.', id: '.'), category: KeyCategory.digit),
      KeypadKey(
        base: KeyVariant(label: '+/−', id: 'negate'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'EXP', id: 'ins:exp'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: '✓', id: 'equals'),
        category: KeyCategory.accent,
      ),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'OTHER', id: 'openTools'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'ran#', id: 'ins:rand'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'Ans', id: 'ans'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'EXP SI', id: 'dis:expsi', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '=,＜＞', id: 'dis:compare', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
    ],
  ),
];
