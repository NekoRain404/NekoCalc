import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';

/// 中文：**我们跟的是厂商"当前默认布局"——两条可执行的断言，外加一条已量到一半的记录。**
///
///       键位与 HiPER 的对照此前**只有一次读图**（记在 `hiper_keypad_number_rows.dart` 的类注释里：
///       厂商当前主屏截图 `assets/img/01 calculator.png` 与本机那张 1440×3200 真机截图，**两套布局**，
///       并引了厂商字符串说明为何不同 ✓）。那张图**不能进仓库**（别人的界面材料 ✓），于是"我们是照它排的"
///       这句话**没有可执行的东西守着** ✗。这个文件只钉注释**已经写明**的那几处 —— 不需要读图 ✓、
///       不需要转录 ✓、也不碰别人的材料 ✓。
///
///       ✅ **① `CNST`/`CONV` 落在 `1`/`2` 上方的横带里**（当前默认布局；旧版 Version 10 那里是 `gcd`/`lcm`）。
///       ✅ **② 没有任何一格的键面或横带写着 `gcd`/`lcm`** —— 这正是"**看起来像差异**"的那一处，
///          所以它值得一条明确的**不存在**断言 ✓✓（注释写的是"没有格子" ✓，这一条把它变成会红的检查 ✓）。
///       ⚠️ **③ 相机键：已量到它存在，键面的表示还没查清，所以这里不断言它** ✗ ——
///          它确实在第 2 行第 6 格 ✓（`hiper_keypad.dart` 与 `hiper_keypad_angle_matrix_row.dart` 的文件头
///          都写着「行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 / **相机**」✓），id 是 **`dis:camera`** ✓
///          （`dis:` 前缀 = 禁用键，见 `hiper_keypad.dart` 的文件头 ✓）。但它的**键面**不是 `base.icon`
///          ✗（实测：那一格 `base.icon == null`），而"键面画什么"在这套键盘里是**内容**之一
///          （见 `keypad_definition_test.dart` 关于图形进签名的注释 ✓）—— 所以它该由**另一次测量**回答，
///          而不是由我这里猜一个字段名 ✓。
/// English: **we follow the vendor's *current default* layout — two executable assertions, plus one
///          half-measured note.**
///
///          The comparison had been **one reading of screenshots** (recorded in the class comment). That image
///          **cannot enter the repository**, so the sentence "we are arranged after it" had nothing executable
///          guarding it. This file pins only what the comment **already states**.
///
///          ✅ ① `CNST`/`CONV` sit in the band above `1`/`2` in the current default (the older Version 10 layout
///          had `gcd`/`lcm` there). ✅ ② no cell's face or band reads `gcd`/`lcm` — the one place that *looks
///          like a difference*, so it earns an explicit **absence** assertion.
///          ⚠️ ③ **the camera key: measured to exist, its face not yet established, so not asserted here.**
///          It is genuinely row 2's sixth cell (both file heads say 「行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 /
///          相机」) with id **`dis:camera`** (the `dis:` prefix marks a disabled key) — but its face is **not**
///          `base.icon` (measured: `null`), and what a face draws is part of this keypad's **content**. That
///          deserves its own measurement rather than a guessed field name.
void main() {
  test('厂商当前默认布局：CNST/CONV 在 1/2 上方，而 gcd/lcm 没有格子', () {
    final rows = hiperKeypad.rows;
    expect(rows, isNotEmpty, reason: '键位表是空的，这条检查的前提就不成立');

    // ① 按内容找含 `1`/`2` 的那一行（不写死行号），读它上方对应的两格。
    KeypadRow? digitRow;
    for (final row in rows) {
      final labels = row.keys.map((k) => k.base.label).toList();
      if (labels.contains('1') && labels.contains('2')) {
        digitRow = row;
        break;
      }
    }
    expect(digitRow, isNotNull, reason: '找不到含 1/2 的那一行');
    final row = digitRow!;
    final oneAt = row.keys.indexWhere((k) => k.base.label == '1');
    final twoAt = row.keys.indexWhere((k) => k.base.label == '2');
    expect(_bandText(row.labels[oneAt]), 'CNST',
        reason: '`1` 上方应当是 `CNST`——厂商当前默认把 `CONST` 放在这里');
    expect(_bandText(row.labels[twoAt]), 'CONV',
        reason: '`2` 上方应当是 `CONV`——同一个位置，旧版（Version 10）放的是 `gcd`/`lcm`');

    // ② ⚠️ 全文扫一遍：`gcd`/`lcm` 不该出现在任何键面或横带上。
    final offenders = <String>[];
    for (final r in rows) {
      for (final key in r.keys) {
        if (key.base.label == 'gcd' || key.base.label == 'lcm') {
          offenders.add('键面 ${key.base.label}');
        }
        // 中文：SHIFT 变体也算键面（`gcd` 可能只挂在某个变体上）。
        // English: a SHIFT variant is a face too — `gcd` could hide on one.
        final shift = key.shift;
        if (shift != null && (shift.label == 'gcd' || shift.label == 'lcm')) {
          offenders.add('SHIFT 键面 ${shift.label}');
        }
      }
      for (final label in r.labels) {
        final text = _bandText(label);
        if (text == 'gcd' || text == 'lcm') offenders.add('横带 $text');
      }
    }
    expect(offenders, isEmpty,
        reason: '当前默认布局里 gcd/lcm 没有格子（两个动作仍在调度表里，入口在「更多函数」面板）'
            '——出现即说明键位被换回了旧版布局：$offenders');
  });
}

/// 中文：横带那一格上的**字**。提示格（`ShiftLabel`）与真按钮格（`InlineKey`）都读文本；
///       读不到就回空串（"没有标签"是合法状态 ✓，相机键那一格就是这种 ✓）。
/// English: the text on a band cell. Hint cells (`ShiftLabel`) and real button cells (`InlineKey`) are both
///          read for their text; an unreadable one comes back empty ("no label" is legal — the camera key's
///          cell is exactly that).
String _bandText(KeypadLabel? label) {
  if (label is ShiftLabel) return label.text;
  if (label is InlineKey) return label.key.base.label;
  return '';
}
