import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';

/// 中文：**我们跟的是厂商"当前默认布局"——三条可执行的断言。**
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
///       ✅ **③ 第 2 行第 6 格是相机键，键面是 `📷`**（`hiper_keypad_angle_matrix_row.dart:594`：
///          `KeyVariant(label: '📷', id: 'dis:camera')` ✓、分类 `KeyCategory.disabled` ✓）。
///          ⚠️ **这一条我第一版写错过一次** ✗：我按 `base.icon` 找键面，实测 `null` ✓ ——
///          而键面本来就在 `label` 上（`icon` 为 null 时画的就是这几个字 ✓，见 `keypad_definition.dart`
///          对 `label` 的注释 ✓）。**那次"找不到"是我的字段名错，不是键位错** ✓ —— 与 §5x 那句同形：
///          一个读数错了，结论就会整条错 ✓。
///
///       ⚠️ **三条各自的对照都做过，而且都当场红了** ✓✓（`trap` 还原、sha256 前后一致 ✓）：
///       ① `number_rows.dart:242` 的 `label: 'CNST'` → `'gcd'` ⇒ `Expected: 'CNST' Actual: 'gcd'` ✓
///       ② `band_key_rows.dart:203` 横带里的 `label: 'hyp'` → `'gcd'`（`1`/`2` 那一行不动）
///          ⇒ 报「出现即说明键位被换回了旧版布局：**`[横带 gcd]`**」✓ —— 这一条证明的是**扫描**本身有效 ✓
///       ③ `angle_matrix_row.dart:594` 相机键的键面 `'📷'` → `'x'` ⇒ `Expected: '📷' Actual: 'x'` ✓
///       **三条都做过对照之后，它们才各自算一次测量** ✓ —— 今天已经吃过一次空对照：一个改不动的字符串
///       让"通过"其实只是原样重跑 ✓✗。
/// English: **all three assertions have been controlled, and each went red on the spot** (`trap`-restored,
///          sha256 unchanged): ① `CNST`→`gcd`, ② a *band* cell →`gcd` while the `1`/`2` row is untouched
///          (which proves the **scan** itself works), ③ the camera face `📷`→`x`. Only after a control does
///          each of them count as a measurement — this day already produced one **void** control, where a
///          string that did not exist made "passed" merely a re-run.
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

    // ③ 相机键：第 2 行第 6 格，键面是 `📷`。⚠️ **键面在 `label` 上，不是 `icon`** ✓ —— 我第一版看错了字段。
    // English: the camera key — row 2's sixth cell, face `📷`. ⚠️ The face lives on `label`, not `icon`.
    KeypadRow? cameraRow;
    for (final r in rows) {
      if (r.labels.any((l) => _bandText(l) == 'FSE')) {
        cameraRow = r;
        break;
      }
    }
    expect(cameraRow, isNotNull, reason: '找不到横带里有 FSE 的那一行（相机键所在行）');
    expect(cameraRow!.keys.length, greaterThan(5), reason: '那一行不足 6 格');
    expect(cameraRow.keys[5].base.label, '📷',
        reason: '第 6 格应当是相机键——厂商当前默认用它占掉了旧版放 `CONV` 的那一格');
    expect(cameraRow.keys[5].category, KeyCategory.disabled,
        reason: '相机键是禁用键（`dis:` 前缀那一族）——它是厂商布局的记录，不是本应用的动作');
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
