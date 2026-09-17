import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';

/// 中文：一行里的全部实体键——主键条上的键，加上标签横带里的 `InlineKey`。
///       标签横带里的键曾经不在唯一性检查的遍历范围内，`▸DRG` 与主键 `DRG` 共用同一个
///       `angleMode` 就是这么漏过 CI 的；遍历必须覆盖两者，这一类冲突才有可能被挡住。
/// English: Every real key in a row — the main strip's keys plus the band's `InlineKey`s.
///          Band keys used to sit outside the uniqueness walk, which is how `▸DRG` sharing
///          `angleMode` with the main DRG key slipped past CI. The walk has to cover both.
Iterable<KeypadKey> _realKeys(KeypadRow row) sync* {
  yield* row.keys;
  for (final label in row.labels) {
    if (label is InlineKey) yield label.key;
  }
}

/// 中文：一个变体的签名 `id|键面文字|启用态`。
/// English: One variant's signature, `id|face label|enabled`.
String _variantSignature(KeyVariant v) =>
    '${v.id}|${v.label}|${v.enabled ? 'on' : 'off'}';

/// 中文：一个键的签名 `基准 | 分类 | shift:… | hyp:…`，变体缺省时不写那一段。
/// English: One key's signature, `base | category | shift:… | hyp:…`, with a variant's section
///          omitted when the key has none.
String _keySignature(KeypadKey k) => <String>[
      _variantSignature(k.base),
      k.category.name,
      if (k.shift != null) 'shift:${_variantSignature(k.shift!)}',
      if (k.hyp != null) 'hyp:${_variantSignature(k.hyp!)}',
    ].join(' ');

/// 中文：标签横带一格的签名——`-` 是空位，`hint:` 是不可点的纯提示，其余是横带里的实体键。
/// English: One label-band cell — `-` for an empty slot, `hint:` for a non-tappable hint, anything
///          else is a real band key.
String _labelSignature(KeypadLabel? label) => switch (label) {
      null => '-',
      ShiftLabel(:final String text) => 'hint:$text',
      InlineKey(:final KeypadKey key) => _keySignature(key),
    };

/// 中文：整张表的逐格快照，主键条部分。每一格是 `id|键面文字|分类|启用态`，带变体的键再跟上
///       `shift:…`/`hyp:…`。写成字面量是有意的：键位表就是这套键盘的**内容**，哪一格被删、
///       被挪位、id 被改写或启用态被翻转，都必须在这里留下一条可读的 diff。
/// English: The whole table's per-cell snapshot, main strips. Each cell reads
///          `id|face label|category|enabled`, with `shift:…`/`hyp:…` appended for keys that have
///          variants. A literal is the point: the table *is* this keypad's content, so a dropped,
///          mis-slotted, re-ided or disabled-flag-flipped cell has to leave a readable diff here.
const List<List<String>> _expectedKeyGrid = <List<String>>[
  <String>[
    "shift|SHIFT|on modifier",
    "drawer|MENU|on function",
    "dis:pagePrev|◀|off disabled",
    "dis:pageNext|▶|off disabled",
    "backspace|⌫|on destructive",
    "clear|AC|on destructive",
  ],
  <String>[
    "angleMode|DRG|on function",
    "dis:xchgE|x⇔E|off disabled",
    "ins:matrix|MTRX|on function",
    "ins:sum|Σ|on function shift:ins:product|Π|on",
    "ins:integrate|∫dx|on function",
    "dis:camera|📷|off disabled",
  ],
  <String>[
    "ins:pi|π|on function",
    "sin|sin|on function shift:asin|sin⁻¹|on hyp:sinh|sinh|on",
    "cos|cos|on function shift:acos|cos⁻¹|on hyp:cosh|cosh|on",
    "tan|tan|on function shift:atan|tan⁻¹|on hyp:tanh|tanh|on",
    "ins:i|i|on function",
    "ins:e|e|on function",
  ],
  <String>[
    "ins:^-1|x⁻¹|on function",
    "ins:^2|x²|on function shift:ins:^3|x³|on",
    "sqrt|√x|on function shift:cbrt|∛x|on",
    "ins:^|xʸ|on function shift:root|ˣ√y|on",
    "log|log|on function shift:ins:10^|10ˣ|on",
    "ln|ln|on function shift:ins:e^|eˣ|on",
  ],
  <String>[
    "dis:dms|D°M'S|off disabled",
    "dis:dc|d/c|off disabled",
    "dis:x|X|off disabled",
    "dis:xym|XY,M|off disabled",
    "memoryRecall|MR|on variable",
    "memoryStore|x→M|on variable",
  ],
  <String>[
    "7|7|on digit",
    "8|8|on digit",
    "9|9|on digit",
    "(|(|on operator",
    ")|)|on operator",
  ],
  <String>[
    "4|4|on digit",
    "5|5|on digit",
    "6|6|on digit",
    "*|×|on operator",
    "/|÷|on operator",
  ],
  <String>[
    "1|1|on digit",
    "2|2|on digit",
    "3|3|on digit",
    "+|+|on operator",
    "-|−|on operator",
  ],
  <String>[
    "0|0|on digit",
    ".|.|on digit",
    "negate|+/−|on function",
    "ins:exp|EXP|on function",
    "equals|✓|on accent",
  ],
];

/// 中文：逐格快照的标签横带部分，与 `_expectedKeyGrid` 同为 `(行, 格)` 索引。
/// English: The label bands' half of the per-cell snapshot; indexed the same `(row, slot)` way as
///          `_expectedKeyGrid`.
const List<List<String>> _expectedLabelGrid = <List<String>>[
  <String>[
    "-",
    "-",
    "-",
    "-",
    "-",
    "-",
  ],
  <String>[
    "hint:DRG",
    "hint:FSE",
    "hint:MTRX",
    "hint:Π",
    "hint:d/dx",
    "-",
  ],
  <String>[
    "hyp|hyp|on modifier",
    "hint:sin⁻¹",
    "hint:cos⁻¹",
    "hint:tan⁻¹",
    "dis:angle|∠|off disabled",
    "ins:logxy|logₓy|on function",
  ],
  <String>[
    "ins:limit|lim|on function",
    "hint:x³",
    "hint:∛x",
    "hint:ˣ√y",
    "hint:10ˣ",
    "hint:eˣ",
  ],
  <String>[
    "dis:stat|STAT|off disabled",
    "dis:abc|a b/c|off disabled",
    "dis:y|Y|off disabled",
    "openHistory|HISTORY|on function",
    "memoryAdd|M+|on variable",
    "memorySubtract|M−|on variable",
  ],
  <String>[
    "dis:cplx|CPLX|off disabled",
    "ins:inf|∞|on function",
    "ins:%|%|on function",
    "mod|mod|on function",
    "-",
  ],
  <String>[
    "fact|n!|on function",
    "nCr|nCr|on function",
    "nPr|nPr|on function",
    "baseBin|BIN|on pill",
    "baseOct|OCT|on pill",
  ],
  <String>[
    "openConstants|CNST|on function",
    "openUnits|CONV|on function",
    "abs|abs|on function",
    "baseDec|DEC|on pill",
    "baseHex|HEX|on pill",
  ],
  <String>[
    "openTools|OTHER|on function",
    "ins:rand|ran#|on function",
    "ans|Ans|on function",
    "dis:expsi|EXP SI|off disabled",
    "dis:compare|=,＜＞|off disabled",
  ],
];

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
        for (final k in _realKeys(row)) {
          ids.add(k.base.id);
          if (k.shift != null) ids.add(k.shift!.id);
          if (k.hyp != null) ids.add(k.hyp!.id);
        }
      }
      final dup =
          ids.where((id) => ids.where((x) => x == id).length > 1).toSet();
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
    test('共 9 个主键行，其中 8 行带标签带', () {
      expect(hiperKeypad.rows.length, 9);
      expect(
        hiperKeypad.rows.where((r) => r.labels.any((l) => l != null)).length,
        8,
      );
    });

    test('数字键与四则运算符永远在位', () {
      final all =
          hiperKeypad.rows.expand((r) => r.keys).map((k) => k.base.id).toSet();
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

  group('内容快照与主屏派发契约', () {
    // 中文：逐格快照。上面那些不变量（等长、唯一、分类）对**内容**一无所知：把 `x²` 的 id 改成
    //       `ins:^9`、把某格的提示挪到隔壁、把某个键的启用态翻过来，它们全都照样通过。这条按
    //       `(行, 格)` 逐格比签字，出问题时 reason 直接指出是哪一行哪一格。
    // English: the per-cell snapshot. The invariants above know nothing about the *content*: re-iding
    //          `x²` to `ins:^9`, sliding a hint into the neighbouring slot or flipping a key's enabled
    //          flag all keep them green. This compares signatures cell by cell and names the exact
    //          `(row, slot)` in the failure reason.
    test('逐格快照：id / 键面文字 / 分类 / 启用态 / 变体', () {
      expect(hiperKeypad.rows.length, _expectedKeyGrid.length,
          reason: '行数与快照不符');
      for (int r = 0; r < hiperKeypad.rows.length; r++) {
        final row = hiperKeypad.rows[r];
        expect(row.keys.length, _expectedKeyGrid[r].length,
            reason: '第 ${r + 1} 行的主键个数与快照不符');
        expect(row.labels.length, _expectedLabelGrid[r].length,
            reason: '第 ${r + 1} 行的标签格数与快照不符');
        for (int c = 0; c < row.keys.length; c++) {
          expect(_keySignature(row.keys[c]), _expectedKeyGrid[r][c],
              reason: '第 ${r + 1} 行第 ${c + 1} 格（主键）与快照不符');
        }
        for (int c = 0; c < row.labels.length; c++) {
          expect(_labelSignature(row.labels[c]), _expectedLabelGrid[r][c],
              reason: '第 ${r + 1} 行第 ${c + 1} 格（标签横带）与快照不符');
        }
      }
    });

    // 中文：本计划的核心承诺是「改键位表，别的地方不用动」——但键位表只有真的被主屏接住才算数。
    //       这条走遍全表（主键、SHIFT/hyp 变体、标签横带里的实体键），把每个**已启用**的 id 拿去
    //       问主屏：它要么在 `_pressKey` 的显式 case 里（`CalculatorPage.dispatchedKeyIds`），要么
    //       属于刻意按字面量输入的那一类（数字、小数点、括号与加减，
    //       `CalculatorPage.defaultInputKeyIds`）。`×`/`÷` 的 id 与主屏分派对不上，就是这么上的
    //       真机——那时没有任何测试问过这个问题。
    // English: the plan's central promise is "edit the table, change nothing else", but the table only
    //          counts if the screen really accepts it. This walks the whole table (main keys, SHIFT/hyp
    //          variants and the band's real keys) and asks the screen about every **enabled** id: it
    //          must be either one of `_pressKey`'s explicit cases
    //          (`CalculatorPage.dispatchedKeyIds`) or belong to the deliberately-verbatim class —
    //          digits, decimal point, brackets, plus and minus (`CalculatorPage.defaultInputKeyIds`).
    //          The `×`/`÷` id mismatch reached the device because no test asked this question.
    test('表里每个已启用的 id 主屏都接得住', () {
      const dispatched = CalculatorPage.dispatchedKeyIds;
      const defaultInput = CalculatorPage.defaultInputKeyIds;
      final unhandled = <String>[];
      final declaredThoughDisabled = <String>[];

      for (final row in hiperKeypad.rows) {
        for (final key in _realKeys(row)) {
          final variants = <KeyVariant?>[key.base, key.shift, key.hyp];
          if (key.category == KeyCategory.disabled) {
            // 中文：禁用的格子永不触发，主屏不该声称自己处理它——那只会掩盖「这个 id 其实没人接」。
            // English: a disabled cell never fires, so the screen must not claim to handle it; claiming
            //          would hide the fact that nothing actually accepts that id.
            for (final v in variants) {
              if (v != null && dispatched.contains(v.id)) {
                declaredThoughDisabled.add(v.id);
              }
            }
            continue;
          }
          for (final v in variants) {
            if (v == null || !v.enabled) continue;
            if (!dispatched.contains(v.id) && !defaultInput.contains(v.id)) {
              unhandled.add(v.id);
            }
          }
        }
      }

      expect(dispatched.intersection(defaultInput), isEmpty,
          reason: '两个集合必须互斥：一个 id 要么走显式 case，要么走 default 的字面量输入');
      expect(
        unhandled,
        isEmpty,
        reason: '主屏接不住这些 id：$unhandled —— 给 `_pressKey` 加 case 并同步 '
            '`CalculatorPage.dispatchedKeyIds`；若它本就该按字面量输入，则加进 '
            '`CalculatorPage.defaultInputKeyIds`',
      );
      expect(declaredThoughDisabled, isEmpty,
          reason: '禁用的键位不该出现在 dispatchedKeyIds 里：$declaredThoughDisabled');
    });

    // 中文：渲染层判断「哪个修饰键正被按下」时不需要任何 id 常量——它比的是当前
    //       `KeypadModifier` 的枚举名与键的 id（见 `calculator_keypad.dart` 的 `_isActiveModifier`）。
    //       这条把那层隐式契约摆到明面上：改枚举名或改表里修饰键的 id，这里就会红，而不是让
    //       「按下的修饰键用强调色」这个提示悄悄消失。
    // English: the rendering layer needs no id constant to tell which modifier key is latched — it
    //          compares the current `KeypadModifier`'s enum name with the key's id (see
    //          `_isActiveModifier` in `calculator_keypad.dart`). This puts that implicit contract on
    //          the record: renaming an enum value or a modifier id in the table turns this red instead
    //          of silently losing the "latched modifier wears the accent colour" signal.
    test('修饰键的 id 与 KeypadModifier 的枚举名一致', () {
      final modifierIds = <String>{};
      for (final row in hiperKeypad.rows) {
        for (final key in _realKeys(row)) {
          if (key.category == KeyCategory.modifier) modifierIds.add(key.base.id);
        }
      }
      expect(modifierIds, <String>{
        for (final m in KeypadModifier.values)
          if (m != KeypadModifier.none) m.name,
      });
    });
  });
}
