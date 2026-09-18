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
  //       上方标签：n!、nCr、nPr 三个函数键，加上 BIN、OCT 两个进制胶囊
  //       （label 不含 HiPER 的 `▸` 装饰）。
  // English: Row 7 — digits 4 5 6 with multiply and divide. The ids stay parser-friendly
  //          (`*`, `/`) while the faces show `×` and `÷`.
  //          Band above: the n!, nCr, nPr function keys plus the BIN and OCT base pills
  //          (labels drop HiPER's decorative `▸`).
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
          base: KeyVariant(label: 'BIN', id: 'baseBin'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'OCT', id: 'baseOct'),
          category: KeyCategory.pill,
        ),
      ),
    ],
  ),

  // 中文：行 8——数字 1 2 3 与加减。`−` 的 id 是解析器用的 `-`。
  //       上方标签：CNST（常数分类）、CONV（单位换算）、abs，以及 DEC、HEX 两个进制胶囊。
  // English: Row 8 — digits 1 2 3 with plus and minus; the `−` face carries the parser's
  //          `-` id. Band above: CNST (constant category), CONV (unit conversion), abs, and
  //          the DEC and HEX base pills.
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
          base: KeyVariant(label: 'DEC', id: 'baseDec'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'HEX', id: 'baseHex'),
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
