import 'package:flutter/material.dart';

import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';

// 中文：分类 / 工具的身份色。**八个值全部逐字节取自 `lib/shared/presentation/calc_theme.dart`
//       已有的色值**（四个本来就在用的老值除外，出处见下）——这里不是第二套私有调色板。八个色值在
//       本仓库里只出现在下面这八个常量里：分类 switch 与哈希表都引用它们，改色仍然只有一处。
//
//       **为什么动其中四个。** 全应用改用玫瑰奶霜的暖奶油底 `#F4EAE4`（色相 22.5°）之后，`math` 的
//       蓝 `#1677FF`（215°）、`units` 的蓝 `#2563EB`（221°）、`science` 的紫 `#8B5CF6`（258°）与
//       `custom` 的靛 `#6D5DFB`（246°）在色轮上离底色 190°~235°，八张分类卡里就这四张是冷色岛。
//       换掉之后八个色相是：玫瑰 352°、红 354°、绿 144°、琥珀 32°、赭 29°、莓红 348°、
//       青 180°（青是原有值，未动）、陶土 22°。
//
//       四个新值与其出处（逐字节相等，没有新造色）：
//         `math`    `#1677FF` → `_identityRose`      `#D98A94` = `roseCream.keys.destructiveBg`
//         `science` `#8B5CF6` → `_identityOchre`     `#98622F` = `peachSugar.display.indicatorFg`
//         `units`   `#2563EB` → `_identityRaspberry` `#B03A52` = `lavenderMist.display.errorFg`
//         `custom`  `#6D5DFB` → `_identityClay`      `#D98A5C` = `peachSugar.keys.accentBg`
//       其余四个（红 `#FF4D5E`、绿 `#23B45D`、橙 `#FF8A00`、青 `#0EA5A4`）在暖底上本来就站得住，
//       一个字节没动。
//
//       **可辨识度是用尺子量过的，不是看着挑的。** 分类卡在 360dp 手机上是两列，顺序就是
//       `ToolCategory.values`（math|electronics / mechanical|finance / science|units /
//       programming|custom）。在 Lab 里按 CIE76 量：**相邻卡最近的一对 ΔE 从 18.3（`units`-`custom`
//       两个冷色）升到 40.7**，**任意两卡最近的一对从 8.0（`science`-`custom`，紫配靛）升到 20.2**
//       ——八张卡比改之前分得更开，暖不是拿区分度换的。
//       图标对自身 7% 底色（`tool_widgets.dart` 里 `withValues(alpha: 0.07)` 压在 `#F4EAE4` 上）
//       的对比度：最低的仍是原来就有的橙 `#FF8A00`（1.90），四个新值为 2.10 / 3.96 / 4.51 / 2.17，
//       全落在既有的 1.90–4.51 区间内，没有一个是靠降低可读性换来的。
//
// English: Identity colours for categories and tools. **All eight values are taken byte-for-byte from
//          existing tokens in `lib/shared/presentation/calc_theme.dart`** (bar the four legacy values
//          already in use, listed below) — this is not a second private palette. Each value appears
//          exactly once in the repository, as the constants below; the category switch and the hash
//          table both reference them, so changing a colour still has one place to go.
//
//          **Why four of them moved.** Once every screen took Rose Cream's warm cream canvas `#F4EAE4`
//          (hue 22.5°), `math`'s blue `#1677FF` (215°), `units`' blue `#2563EB` (221°), `science`'s
//          violet `#8B5CF6` (258°) and `custom`'s indigo `#6D5DFB` (246°) sat 190°–235° away on the
//          colour wheel: four cool islands among the eight category cards. The eight hues are now
//          rose 352°, red 354°, green 144°, amber 32°, ochre 29°, raspberry 348°, teal 180° (teal is
//          a legacy value, untouched) and clay 22°.
//
//          The four replacements and where they come from (byte-for-byte; nothing was invented):
//            `math`    `#1677FF` → `_identityRose`      `#D98A94` = `roseCream.keys.destructiveBg`
//            `science` `#8B5CF6` → `_identityOchre`     `#98622F` = `peachSugar.display.indicatorFg`
//            `units`   `#2563EB` → `_identityRaspberry` `#B03A52` = `lavenderMist.display.errorFg`
//            `custom`  `#6D5DFB` → `_identityClay`      `#D98A5C` = `peachSugar.keys.accentBg`
//          The other four (red `#FF4D5E`, green `#23B45D`, amber `#FF8A00`, teal `#0EA5A4`) already
//          hold their own on the warm canvas and did not move a byte.
//
//          **Distinguishability was measured, not eyeballed.** The cards are two columns on a 360dp
//          phone, in `ToolCategory.values` order (math|electronics / mechanical|finance / science|units
//          / programming|custom). Measured in Lab with CIE76: **the closest adjacent pair goes from
//          ΔE 18.3 (`units`-`custom`, two cool hues) to 40.7**, and **the closest pair overall from 8.0
//          (`science`-`custom`, violet against indigo) to 20.2** — the eight cards separate better than
//          before, so the warmth was not bought with distinctness.
//          Icon against its own 7% fill (`withValues(alpha: 0.07)` over `#F4EAE4` in
//          `tool_widgets.dart`): the lowest is still the pre-existing amber `#FF8A00` (1.90); the four
//          new values are 2.10 / 3.96 / 4.51 / 2.17 — all inside the existing 1.90–4.51 band, so none
//          of them trades legibility away.

/// 中文：分类 / 工具身份色的唯一定义处；色值出处见文件头（`calc_theme.dart` 或原有分类色）。
/// English: The single definition point for the identity colours; provenance is in the file head
///          (`calc_theme.dart` or a legacy category colour).
const Color _identityRose = Color(0xFFD98A94);
const Color _identityRed = Color(0xFFFF4D5E);
const Color _identityGreen = Color(0xFF23B45D);
const Color _identityAmber = Color(0xFFFF8A00);
const Color _identityOchre = Color(0xFF98622F);
const Color _identityRaspberry = Color(0xFFB03A52);
const Color _identityTeal = Color(0xFF0EA5A4);
const Color _identityClay = Color(0xFFD98A5C);

/// 中文：工具按 `id.codeUnits` 求和取模取色的顺序表。**长度必须保持 ≥ 8**（现在正好 8，与八个
///       分类的身份色一一对应，且八个色值互不相同）：`% colors.length` 一旦变短，两个下标就会
///       落到同一个色值上，同一屏里的工具图标开始重色。顺序是既有行为（决定哪个 id 拿哪个色），
///       不要顺手重排。
/// English: The ordered table tools hash into via `id.codeUnits`. **Its length must stay ≥ 8**
///          (exactly 8 today, one per category identity colour, all eight pairwise distinct): shorten
///          it and `% colors.length` lands two indices on one value, so tools on a single screen start
///          repeating colours. The order is existing behaviour (it decides which id gets which colour)
///          — do not reshuffle it in passing.
const List<Color> _toolIdentityColors = <Color>[
  _identityRose,
  _identityClay,
  _identityAmber,
  _identityGreen,
  _identityRed,
  _identityTeal,
  _identityOchre,
  _identityRaspberry,
];

extension ToolCategoryVisuals on ToolCategory {
  IconData get icon {
    return switch (this) {
      ToolCategory.math => Icons.functions,
      ToolCategory.electronics => Icons.electric_bolt,
      ToolCategory.mechanical => Icons.precision_manufacturing,
      ToolCategory.finance => Icons.trending_up,
      ToolCategory.science => Icons.science,
      ToolCategory.units => Icons.swap_horiz,
      ToolCategory.programming => Icons.data_object,
      ToolCategory.custom => Icons.tune,
    };
  }

  Color get color {
    return switch (this) {
      ToolCategory.math => _identityRose,
      ToolCategory.electronics => _identityRed,
      ToolCategory.mechanical => _identityGreen,
      ToolCategory.finance => _identityAmber,
      ToolCategory.science => _identityOchre,
      ToolCategory.units => _identityRaspberry,
      ToolCategory.programming => _identityTeal,
      ToolCategory.custom => _identityClay,
    };
  }
}

extension ToolDefinitionVisuals on ToolDefinition {
  IconData get icon {
    return switch (id) {
      'quadratic' => Icons.superscript,
      'linear_system' => Icons.grid_3x3,
      'percentage' => Icons.percent,
      'exponential_log' => Icons.stacked_line_chart,
      'probability' => Icons.casino_outlined,
      'statistics' => Icons.bar_chart,
      'data_fit' => Icons.ssid_chart,
      'matrix' => Icons.apps,
      'complex' => Icons.blur_circular,
      'vector' => Icons.open_with,
      'triangle' => Icons.change_history,
      'circle' => Icons.circle_outlined,
      'scale_ratio' => Icons.aspect_ratio,
      'ohms_law' => Icons.electric_bolt,
      'voltage_divider' => Icons.call_split,
      'rc_filter' => Icons.waves,
      'resistor_network' => Icons.linear_scale,
      'capacitor_network' => Icons.view_column,
      'inductor_network' => Icons.all_inclusive,
      'led_resistor' => Icons.light_mode_outlined,
      'op_amp_gain' => Icons.change_history,
      'adc_resolution' => Icons.memory,
      'lc_resonance' => Icons.graphic_eq,
      'dcdc_feedback' => Icons.power,
      'ldo_power' => Icons.thermostat,
      'capacitor_charge' => Icons.battery_charging_full,
      'battery_life' => Icons.battery_5_bar,
      'pcb_current' => Icons.route,
      'wire_voltage_drop' => Icons.cable,
      'timer_555' => Icons.timer,
      'thermal_rise' => Icons.device_thermostat,
      'gear_ratio' => Icons.settings,
      'torque_power' => Icons.speed,
      'spring' => Icons.compress,
      'cylinder' => Icons.air,
      'force' => Icons.arrow_forward,
      'pulley_ratio' => Icons.sync,
      'screw_lead' => Icons.rotate_right,
      'pressure_force' => Icons.vertical_align_bottom,
      'friction' => Icons.drag_indicator,
      'inclined_plane' => Icons.show_chart,
      'beam_bending' => Icons.architecture,
      'stress_strain' => Icons.straighten,
      'section_area' => Icons.crop_square,
      'safety_factor' => Icons.health_and_safety,
      'flow_velocity' => Icons.water,
      'material_weight' => Icons.inventory_2,
      'loan' => Icons.account_balance,
      'annuity' => Icons.savings,
      'installment' => Icons.credit_card,
      'break_even' => Icons.balance,
      'electricity_cost' => Icons.electrical_services,
      'compound' => Icons.trending_up,
      'profit_margin' => Icons.sell,
      'roi' => Icons.insights,
      'discount' => Icons.local_offer,
      'tax' => Icons.receipt_long,
      'npv' => Icons.timeline,
      'motion' => Icons.directions_run,
      'free_fall' => Icons.south,
      'work_power' => Icons.bolt,
      'kinetic_energy' => Icons.energy_savings_leaf,
      'density' => Icons.opacity,
      'concentration' => Icons.biotech,
      'ideal_gas' => Icons.bubble_chart,
      'heat' => Icons.local_fire_department,
      'wavelength' => Icons.sensors,
      'half_life' => Icons.hourglass_bottom,
      'ph' => Icons.science,
      'bmi' => Icons.monitor_weight,
      'fuel_economy' => Icons.local_gas_station,
      'base_convert' => Icons.pin,
      'timestamp' => Icons.schedule,
      'color_convert' => Icons.palette,
      'base64' => Icons.code,
      'url_codec' => Icons.link,
      'json_format' => Icons.data_object,
      'ascii_unicode' => Icons.text_fields,
      'bitwise' => Icons.schema,
      'checksum' => Icons.verified,
      'uuid' => Icons.fingerprint,
      'jwt_decode' => Icons.badge_outlined,
      'query_params' => Icons.manage_search,
      'html_entities' => Icons.html,
      'regex_test' => Icons.rule,
      'text_stats' => Icons.format_size,
      'csv_json' => Icons.table_chart,
      'fnv_crc' => Icons.tag,
      'custom_formula' => Icons.tune,
      _ => category.icon,
    };
  }

  Color get color {
    final index = id.codeUnits.fold<int>(0, (sum, code) => sum + code) %
        _toolIdentityColors.length;
    return _toolIdentityColors[index];
  }
}
