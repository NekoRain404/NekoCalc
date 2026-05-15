import 'package:flutter/material.dart';

import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';

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
      ToolCategory.math => const Color(0xFF1677FF),
      ToolCategory.electronics => const Color(0xFFFF4D5E),
      ToolCategory.mechanical => const Color(0xFF23B45D),
      ToolCategory.finance => const Color(0xFFFF8A00),
      ToolCategory.science => const Color(0xFF8B5CF6),
      ToolCategory.units => const Color(0xFF2563EB),
      ToolCategory.programming => const Color(0xFF0EA5A4),
      ToolCategory.custom => const Color(0xFF6D5DFB),
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
      'dbm' => Icons.network_check,
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
      'inflation' => Icons.price_change,
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
    final colors = [
      const Color(0xFF1677FF),
      const Color(0xFF6D5DFB),
      const Color(0xFFFF8A00),
      const Color(0xFF23B45D),
      const Color(0xFFFF4D5E),
      const Color(0xFF0EA5A4),
      const Color(0xFF8B5CF6),
      const Color(0xFF2563EB),
    ];
    final index =
        id.codeUnits.fold<int>(0, (sum, code) => sum + code) % colors.length;
    return colors[index];
  }
}
