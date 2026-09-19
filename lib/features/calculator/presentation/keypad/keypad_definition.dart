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

/// 中文：键面上画得出来的**图形**——键面不是文字的那几格在这里点名。
///
///       **为什么这个类型存在。** 渲染层过去只有一条路：把 `KeyVariant.label` 当文字画出来。
///       HiPER 上有一格的路不是这一条——矩阵键的键面上画的是方括号里 2×2 的四个空心方格，
///       不是 `MTRX` 这个词（`MTRX` 是它**上方那一格**的字，厂商自己给这个位置定的规矩：
///       `quickTour.page.SECOND_FUNCTION.text2` = *"The key's second function is displayed in the
///       label above."*）。那个图**不是一个 Unicode 字符**：Unicode 里没有「方括号包着 2×2 四个
///       空心方格」这一个码位（§Geometric Shapes 里最近的是 `▦` U+25A6「带正交网格填充的方块」
///       与 `⊞` U+229E「带加号的方块」，都是**一个**方块，不是四个），所以它既不能像相机键那样
///       写成一个字符，也不能像 `D°M'S` 那样写成一行文字。
///
///       **长宽比挂在这个枚举上，因为它是量出来的、不是画的时候定的。** 逐格读数与来源写在
///       `hiper_keypad_angle_matrix_row.dart` 矩阵那一格的长注释里；画法在渲染层的
///       `KeyFaceIconView`。
/// English: A **figure** a key face can draw — the cells whose face is not text are named here.
///
///          **Why this type exists.** The rendering layer used to have one path: draw
///          `KeyVariant.label` as text. One cell on HiPER does not travel that path — the matrix
///          key's face draws four hollow squares in a 2×2 grid between brackets, not the word
///          `MTRX` (`MTRX` is the text of the cell **above** it, which is where the vendor's own rule
///          puts a second function: `quickTour.page.SECOND_FUNCTION.text2` = *"The key's second
///          function is displayed in the label above."*). That figure **is not a Unicode
///          character**: Unicode has no code point for "brackets around a 2×2 grid of hollow
///          squares" (the nearest in the Geometric Shapes block are `▦` U+25A6, "square with
///          orthogonal crosshatch fill", and `⊞` U+229E, "squared plus" — both are **one** square,
///          not four), so it can be neither a single character like the camera key nor one line of
///          text like `D°M'S`.
///
///          **The aspect ratio lives on this enum because it was measured, not chosen while
///          drawing.** The cell-by-cell readings and their sources are in the long note on the
///          matrix cell in `hiper_keypad_angle_matrix_row.dart`; the drawing itself is
///          `KeyFaceIconView` in the rendering layer.
enum KeyFaceIcon {
  /// 中文：矩阵键的键面（HiPER）：方括号包着 2×2 的四个空心方格。宽 118 px、高 86 px，
  ///       也就是厂商那张 1440×3200 真机图上这一格字形的实测外框（x 543..660、y 1332..1417）。
  /// English: the matrix key's face (HiPER): a 2×2 grid of hollow squares between brackets.
  ///          118 px wide by 86 px tall — the measured bounding box of this cell's glyph on the
  ///          vendor's 1440×3200 device screenshot (x 543..660, y 1332..1417).
  matrix(width: 118, height: 86);

  const KeyFaceIcon({required this.width, required this.height});

  /// 中文：图形自身的宽（与 `height` 同单位，只用于比例）。
  /// English: The figure's own width (same unit as `height`; only the ratio matters).
  final double width;

  /// 中文：图形自身的高。
  /// English: The figure's own height.
  final double height;

  /// 中文：宽高比——渲染层按它从一个高度推宽度，图形因此不会被拉变形。
  /// English: Width over height — the rendering layer derives the width from a height with it, so
  ///          the figure can never be stretched out of shape.
  double get aspectRatio => width / height;
}

/// 中文：一个键在某一种修饰态下的外观与行为（键面文字或键面图形 + 回调 id + 是否可用）。
/// English: How a key looks and behaves under one modifier state: the face's text or figure, the
///          reported action id, and whether it is usable.
@immutable
class KeyVariant {
  const KeyVariant({
    required this.label,
    required this.id,
    this.enabled = true,
    this.icon,
  });

  /// 中文：这个键的**名字**，也是键面文字。`icon` 为 null 时它就是画在键面上的那几个字；
  ///       给了 `icon` 时键面画的是那个图形，而这个名字仍然有效——横带里的提示写的是它、
  ///       快照记的是它、`ins:matrix` 那一类 id 的词表条目也叫它。**名字与画法分开**，
  ///       正是因为 HiPER 上有一格两者不同（矩阵键：名字 `MTRX`，键面是一张图）。
  ///       **它不能为空**：`test/features/keypad_definition_test.dart` 守着
  ///       「未禁用的键必须有非空 id 与 label」。
  /// English: The key's **name**, and its face text. When `icon` is null these are the characters
  ///          drawn on the face; when `icon` is given the face draws that figure instead, and the
  ///          name still stands — the band hint above spells it, the snapshot records it, and the
  ///          vocabulary entry for an id such as `ins:matrix` calls the key by it. **Name and
  ///          drawing are separate fields** precisely because on HiPER one cell differs between
  ///          them (the matrix key: named `MTRX`, faced with a figure). **It may not be empty**:
  ///          「未禁用的键必须有非空 id 与 label」 in `test/features/keypad_definition_test.dart`
  ///          guards that.
  final String label;

  /// 中文：按下后向上层回调的动作 id。
  /// English: Action id reported upwards when the key is pressed.
  final String id;

  /// 中文：是否可用；禁用键不回调任何动作。
  /// English: Whether the key is usable; a disabled key never reports an action.
  final bool enabled;

  /// 中文：键面画这个图形而不是 `label` 那几个字；null 表示照旧画文字。取值见 `KeyFaceIcon`。
  /// English: The face draws this figure instead of the characters of `label`; null means "draw the
  ///          text as before". The values are on `KeyFaceIcon`.
  final KeyFaceIcon? icon;
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
