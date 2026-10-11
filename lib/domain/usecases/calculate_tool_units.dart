import '../entities/tool_definition.dart';

/// 中文：**温度换算——这一族换算器里唯一留在引擎里的一份。**
///
///       另外 21 个（长度、面积、体积、质量、压力、速度、电压、频率、数据、时间、加速度、力、
///       功率、能量、角度、电流、电阻、电容、电感、扭矩、流量）本来也在这里，每一个都是一张
///       `单位记号 → 相对倍率` 的表，由 `UnitConverter` 乘一遍。**那张表与 `UnitConverter` 已经
///       删除**：它们的换算今天由引擎自己的单位翻译层做（`5 km to mi`），而目录里那 21 张卡并成了
///       一张打开 `CONV` 面板的卡（`unit_convert`）。证明"删得掉"的检索与那两处调用的去向写在
///       当轮报告里；这里只留结论：**这一族今天只剩温度一格，所以这个文件只剩一个函数。**
///
///       温度为什么没跟着走：它的四个记号里 `℃`/`℉` **刻意不在**可插入的单位表里
///       （`app_unit_catalog.dart` 的 `_replaceDegree` 让应用侧 `5 °C` 读作"5 乘摄氏度"而不是
///       "5 摄氏度"），`K` 与 `°R` 同样不在那张表里，而 `'C'` 已经是库仑
///       （`AppUnit('C', '库仑', '电学')`）。**它不可替代，所以它留下。**
/// English: **temperature — the one converter of this family still in the engine.**
///
///          The other 21 (length, area, volume, mass, pressure, speed, voltage, frequency, data,
///          time, acceleration, force, power, energy, angle, current, resistance, capacitance,
///          inductance, torque, flow) used to live here too, each a table of `unit token → factor`
///          multiplied by `UnitConverter`. **Those tables and `UnitConverter` are deleted**: the engine
///          translates units itself today (`5 km to mi`), and the catalogue's 21 cards became one card
///          that opens the `CONV` sheet (`unit_convert`). The greps proving nothing else called them,
///          and where the two callers went, are in that round's report; the conclusion lives here:
///          **one cell of this family is left, so this file holds one function.**
///
///          Why temperature did not go with them: two of its four tokens, `℃`/`℉`, are
///          **deliberately absent** from the insertable unit table (`_replaceDegree` in
///          `app_unit_catalog.dart` keeps app-side `5 °C` from meaning "5 degrees Celsius"), `K` is
///          not in that table either, and the `'C'` token is already coulomb
///          (`AppUnit('C', '库仑', '电学')`). **It cannot be replaced, so it stays.**
List<ToolResult> temperatureResults(Map<String, double> valuesByKey) {
  final celsius = valuesByKey['value'] ?? 0;
  return [
    ToolResult.number('℃', celsius, '℃', primary: true),
    ToolResult.number('℉', celsius * 9 / 5 + 32, '℉'),
    ToolResult.number('K', celsius + 273.15, 'K'),
    ToolResult.number('°R', (celsius + 273.15) * 9 / 5, '°R'),
  ];
}
