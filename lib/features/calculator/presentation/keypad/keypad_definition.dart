import 'package:flutter/foundation.dart';

/// 中文：按键的语义分类，逐一对应 `CalcKeyColors` 的配色分组，另加一个 `disabled`，
///       表示网格为 HiPER 布局保留、但 NekoCalc 尚未实现的键位。
/// English: Semantic key categories mirroring the `CalcKeyColors` colour groups, plus
///          one extra `disabled` value for grid slots HiPER reserves but NekoCalc does
///          not implement yet.
enum KeyCategory {
  digit,
  operator,
  function,
  variable,
  modifier,
  destructive,
  accent,
  pill,
  disabled,
}

/// 中文：一个键在某一种修饰态下的外观与行为（键面文字 + 回调 id + 是否可用）。
/// English: How a key looks and behaves under one modifier state: face label,
///          reported action id, and whether it is usable.
@immutable
class KeyVariant {
  const KeyVariant({
    required this.label,
    required this.id,
    this.enabled = true,
  });

  /// 中文：键面上显示的文字。
  /// English: Text printed on the key face.
  final String label;

  /// 中文：按下后向上层回调的动作 id。
  /// English: Action id reported upwards when the key is pressed.
  final String id;

  /// 中文：是否可用；禁用键不回调任何动作。
  /// English: Whether the key is usable; a disabled key never reports an action.
  final bool enabled;
}

/// 中文：一个键位，含基准变体、语义分类，以及可选的 SHIFT / hyp 变体。
/// English: One keypad key: its base variant, semantic category, and the optional
///          SHIFT and hyp variants.
@immutable
class KeypadKey {
  const KeypadKey({
    required this.base,
    required this.category,
    this.shift,
    this.hyp,
  });

  /// 中文：无修饰态下使用的变体。
  /// English: Variant used when no modifier is active.
  final KeyVariant base;

  /// 中文：配色分组；禁用键必须为 `KeyCategory.disabled`。
  /// English: Colour group; disabled keys must use `KeyCategory.disabled`.
  final KeyCategory category;

  /// 中文：SHIFT 修饰态的变体，未提供时 SHIFT 对本品无效。
  /// English: Variant under the SHIFT modifier; absent when SHIFT does nothing here.
  final KeyVariant? shift;

  /// 中文：`hyp` 修饰态的变体（`sin`→`sinh` 等）。
  /// English: Variant under the `hyp` modifier (`sin` → `sinh`, …).
  final KeyVariant? hyp;
}

/// 中文：标签行里的一格——要么是纯文字标签，要么是一个可以点按的实体键。
/// English: One cell of a label row — either plain text or a real, tappable key.
sealed class KeypadLabel {
  const KeypadLabel();
}

/// 中文：标签行里的纯文字（HiPER 的 SHIFT 功能提示），不可点按。
/// English: Plain text inside a label row (HiPER's SHIFT hint); never tappable.
@immutable
class ShiftLabel extends KeypadLabel {
  const ShiftLabel(this.text);

  /// 中文：显示的文字。
  /// English: Text to display.
  final String text;
}

/// 中文：标签行里的实体键——HiPER 把 `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` 四个胶囊按钮放在标签横带里
///       （规格书第 17 行点名这是「矮行不是按钮」的**唯一例外**），它们同样有分类、SHIFT 变体与启用态。
///       **本应用还多放了一颗 `hyp`**：它在 HiPER 上是 `π` 的第二功能，这里做成了可直接点按的修饰键
///       ——这是立项时写下的**刻意偏离**，出处与理由见
///       `hiper_keypad_function_rows.dart` 第 3 行那一段与 `docs/superpowers/plans/2026-09-16-hiper-keypad-and-main-screen.md`。
/// English: A real key placed inside a label row — HiPER puts the four
///          `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` pills in the label band (the spec names them the **only
///          exception** to "the short row is not buttons"), so they keep a category, SHIFT variant and
///          enabled state of their own. **This app puts one more there, `hyp`**: on HiPER that is
///          `π`'s second function, here it is a directly tappable modifier — a **deliberate,
///          recorded deviation**; its provenance and reasoning are in the row-3 note of
///          `hiper_keypad_function_rows.dart` and in the plan cited above.
@immutable
class InlineKey extends KeypadLabel {
  const InlineKey(this.key);

  /// 中文：被包裹的完整键位定义。
  /// English: The complete key definition being wrapped.
  final KeypadKey key;
}

/// 中文：键盘的一行——主键条加上打印在每个主键上方的标签位。
///       行形状（`labels.length == keys.length`）不加运行时断言：`const` 构造的常量求值读不到
///       `List.length`，断言无法写在构造里，而放弃整张表的 `const` 代价更大。该不变式由
///       `test/features/keypad_definition_test.dart` 的「标签行与主键行等长」在 CI 中守住。
/// English: One keypad row — the main key strip plus the label slot printed above each key.
///          The row shape (`labels.length == keys.length`) carries no runtime assertion: constant
///          evaluation of a `const` constructor cannot read `List.length`, so the assertion cannot
///          live in the constructor, and giving up the whole table's `const` costs more. The
///          invariant is guarded in CI by 「标签行与主键行等长」 in
///          `test/features/keypad_definition_test.dart`.
@immutable
class KeypadRow {
  const KeypadRow({
    required this.keys,
    required this.labels,
  });

  /// 中文：本行的主键，自左至右。
  /// English: This row's main keys, left to right.
  final List<KeypadKey> keys;

  /// 中文：与 `keys` 一一对应的标签位，`labels[i]` 是 `keys[i]` 上方那一格。
  /// English: Label slots aligned one-to-one with `keys`; `labels[i]` sits above `keys[i]`.
  final List<KeypadLabel?> labels;
}

/// 中文：整个键盘的定义——渲染层只读它，改键位只需改这张表。
/// English: The whole keypad definition — the rendering layer only reads it, so
///          changing the layout is a change to this table alone.
@immutable
class KeypadDefinition {
  const KeypadDefinition(this.rows);

  /// 中文：自顶向下的全部行。
  /// English: All rows, top to bottom.
  final List<KeypadRow> rows;
}
