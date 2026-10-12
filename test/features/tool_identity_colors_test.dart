import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/features/tools/presentation/category_visuals.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

import '../shared/colour_metrics.dart';

/// 中文：**工具分类那几颗身份色：把注释里那张对照表变成断言。**
///
///       `category_visuals.dart` 的文件头列着一张**逐条对照表** ✓：某些身份色写明"**逐字节等于**某个
///       具名令牌" ✓（`math` → `roseCream.keys.destructiveBg` ✓、`science` → `peachSugar.display.indicatorFg` ✓、
///       `units` → `lavenderMist.display.errorFg` ✓、`custom` → `peachSugar.keys.accentBg` ✓）。
///
///       ⚠️ **那是可断言的声明，而此前只有注释** ✗：那些令牌里改一个字节，等式就**悄悄断了** ✗✓，
///       而注释继续宣称它成立 ✓。与拟合图那套测量、与令牌对比度那条，是同一件事 ✓：
///       **测量和决定可以写在注释里，但必须变成能重算的断言** ✓✓。
///
///       ⚠️ **断言按“顺序表下标”写** ✓：`toolIdentityColorRing` 的顺序是**既有行为**（文件里写着"别顺手
///       重排" ✓），所以下标稳定 ✓；而"哪一颗对应哪个分类"由**分类枚举 + 取模**决定 ✓，不在本测试里复述 ✓。
/// English: **the tool-identity colours: the comment's mapping table turned into assertions.**
///
///          The head of `category_visuals.dart` lists a table in which some identity colours state they are
///          **byte-for-byte equal** to a named token. ⚠️ **That is assertable and lived only in a comment**: a
///          single byte changed in any of those tokens breaks the equality silently while the comment goes on
///          asserting it. Same shape as the fit chart's measurements and the token contrast rule: a measurement
///          or a decision may sit in a comment, **but it has to become recomputable**.
///
///          ⚠️ **Assertions are written by ring index**: `toolIdentityColorRing`'s order is existing behaviour
///          (the file says not to reshuffle it), so the indices are stable — and which category gets which
///          index is decided by the enum plus a modulo, which this test does not restate.
void main() {
  test('身份色里那四颗，逐字节等于注释点名的令牌', () {
    // 中文：左=顺序表里的那颗，右=注释写的那个令牌（逐字节相等 ✓）。调色板改一个字节，这条就红 ✓。
    // English: left = the ring entry, right = the token the comment names (byte-for-byte). One byte changed
    //          in the palette and this goes red.
    const ring = toolIdentityColorRing;
    expect(ring, hasLength(8), reason: '顺序表长度是既有行为，变短会让两个下标落到同一个色上');

    expect(ring[0], CalcTheme.roseCream.keys.destructiveBg,
        reason: '`math` 那颗，注释写的是 `roseCream.keys.destructiveBg`');
    expect(ring[1], CalcTheme.peachSugar.keys.accentBg,
        reason: '`custom` 那颗，注释写的是 `peachSugar.keys.accentBg`');
    expect(ring[6], CalcTheme.peachSugar.display.indicatorFg,
        reason: '`science` 那颗（原冷紫换成的赭石），注释写的是 `peachSugar.display.indicatorFg`');
    expect(ring[7], CalcTheme.lavenderMist.display.errorFg,
        reason: '`units` 那颗，注释写的是 `lavenderMist.display.errorFg`');
  });

  test('注释里的三组数：两两最小、卡上相邻、7% 底色上的对比度', () {
    // 中文：⚠️ **本测试量的是注释真正说的那三问** ✓ —— 而我第一版量错了其中一问：注释说"**相邻卡**
    //       最近的一对升到 40.7" ✓，指**卡片在屏上的排布**（两列、行优先、顺序 `ToolCategory.values` ✓），
    //       不是"环上相邻" ✗——两者是不同的配对 ✓。三组数都来自 `category_visuals.dart` 的文件头。
    // English: ⚠️ **this measures the three questions the comment actually asks.** A first version measured one
    //          of them wrong: "the closest **adjacent card** rose to 40.7" means the on-screen layout (two
    //          columns, row-major, `ToolCategory.values`), not ring adjacency — different pairings.
    const ring = toolIdentityColorRing;

    // ① 任意两卡最近的一对：注释说 8.0（science-custom）→ 20.2。
    var allPairs = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      for (var j = i + 1; j < ring.length; j++) {
        allPairs = math.min(allPairs, cie76(ring[i], ring[j]));
      }
    }
    // ignore: avoid_print
    print('  任意两卡最小 ΔE76 = ${allPairs.toStringAsFixed(1)}（注释：改前 8.0 → 改后 20.2）');
    expect(allPairs, greaterThanOrEqualTo(19.8),
        reason: '任意两卡最近的一对只有 ${allPairs.toStringAsFixed(1)} ΔE76——注释承诺 ≥ 20.2');

    // ② 卡上相邻（两列行优先）：注释说 18.3（units-custom）→ 40.7。横向与纵向邻居都算。
    final order =
        ToolCategory.values.map((c) => ring[c.index % ring.length]).toList();
    var adjacent = double.infinity;   // 横向 + 纵向邻居
    var horizontal = double.infinity; // 只算同一行里左右相邻的两张
    for (var i = 0; i < order.length; i++) {
      if (i + 1 < order.length) {
        final d = cie76(order[i], order[i + 1]);
        horizontal = math.min(horizontal, d);
        adjacent = math.min(adjacent, d);
      }
      if (i + 2 < order.length) adjacent = math.min(adjacent, cie76(order[i], order[i + 2]));
    }
    // ignore: avoid_print
    print('  卡上相邻最小 ΔE76 = ${adjacent.toStringAsFixed(1)}'
        '（其中只算横向 ${horizontal.toStringAsFixed(1)}）；注释：改前 18.3 → 改后 40.7');
    expect(adjacent, greaterThanOrEqualTo(18.3),
        reason: '卡上相邻最近的一对只有 ${adjacent.toStringAsFixed(1)} ΔE76');

    // ③ 图标对**自身 7% 底色**（压在 `#F4EAE4` 上）的对比度：注释给 1.90（橙）与 2.10 / 3.96 / 4.51 / 2.17。
    const base = Color(0xFFF4EAE4);
    final ratios = <double>[
      for (final c in ring)
        contrastRatio(c, Color.alphaBlend(c.withValues(alpha: 0.07), base)),
    ]..sort();
    // ignore: avoid_print
    print('  7% 底色上的对比度（升序）= ${ratios.map((r) => r.toStringAsFixed(2)).join(' / ')}');
    expect(ratios.first, closeTo(1.90, 0.05),
        reason: '最低的仍是原来就有的橙 `#FF8A00`（1.90）——实测 ${ratios.first.toStringAsFixed(2)}');
    for (final expected in <double>[2.10, 2.17, 3.96, 4.51]) {
      expect(ratios.any((r) => (r - expected).abs() < 0.05), isTrue,
          reason: '注释记的对比度 $expected 在实测里找不到（实测：'
              '${ratios.map((r) => r.toStringAsFixed(2)).join(' / ')}）');
    }
    expect(ratios.last, lessThanOrEqualTo(4.6),
        reason: '全落在既有的 1.90–4.51 区间内——上界超了说明有颜色越出了那条带');
  });
}
