import 'package:flutter_test/flutter_test.dart';
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

  test('相邻身份色的距离：把注释里那个 18.3 重算一遍，并留下限', () {
    // 中文：注释说相邻卡最近的一对"从 18.3 起"（改动后更宽 ✓）。这里量**当前**值并打印 ✓；
    //       下限取在 18.3 **之下** ✓ —— 用来抓"又挤回去了"，而不是把今天的数冻死 ✓。
    // English: the comment says the closest adjacent pair "starts at 18.3" and got wider. The current value is
    //          measured and printed here; the floor sits **below** 18.3 — to catch "squeezed again" rather than
    //          freeze today's number.
    const ring = toolIdentityColorRing;
    var closest = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      final d = cie76(ring[i], ring[(i + 1) % ring.length]);
      if (d < closest) closest = d;
    }
    // ignore: avoid_print
    print('  相邻身份色最小 ΔE76 = ${closest.toStringAsFixed(1)}（注释记的是改前 18.3）');
    expect(closest, greaterThanOrEqualTo(15.0),
        reason: '相邻身份色最近的一对只有 ${closest.toStringAsFixed(1)} ΔE76 —— 卡片又挤在一起了');
  });
}
