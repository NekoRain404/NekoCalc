import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> unitToolDefinitions = [
  _unitTool('length', '长度', 'nm、μm、mm、cm、m、km、Mm、in、ft、mile 换算',
      ToolKind.length, 'm', 3.3),
  _unitTool('area', '面积', 'km²、ha、公顷、亩、m²、cm²、mm²、acre、ft²、in² 换算',
      ToolKind.area, 'm²', 1.2),
  _unitTool('volume', '体积', 'm³、L、mL、cm³、mm³、gal、qt、pt、fl oz、ft³、in³ 换算',
      ToolKind.volume, 'm³', 0.02),
  _unitTool('mass', '质量', 'kg、g、mg、Mg、t、lb、oz、斤 换算', ToolKind.mass, 'kg', 5),
  _unitTool('pressure', '压力', 'mPa、Pa、kPa、MPa、GPa、bar、mbar、psi、atm 换算',
      ToolKind.pressure, 'Pa', 101325),
  _unitTool('speed', '速度', 'm/s、km/h、mph、ft/s、m/min、cm/s、kn 换算', ToolKind.speed,
      'm/s', 10),
  _unitTool('temperature', '温度', '℃、℉、K、°R 换算', ToolKind.temperature, '℃', 25),
  _unitTool('voltage', '电压', 'μV、mV、V、kV、MV 换算', ToolKind.voltage, 'V', 3.3),
  _unitTool('frequency', '频率', 'mHz、Hz、kHz、MHz、GHz、THz 换算', ToolKind.frequency,
      'Hz', 1000),
  _unitTool('data_size', '数据单位', 'bit、B、KB/MB/GB 与 KiB/MiB/GiB 换算',
      ToolKind.dataSize, 'B', 1048576),
  _unitTool('time_unit', '时间', 'ns、μs、ms、s、min、h、day、week 换算',
      ToolKind.timeUnit, 's', 3600),
  _unitTool('acceleration', '加速度', 'm/s²、g、ft/s²、cm/s²、Gal 换算',
      ToolKind.accelerationUnit, 'm/s²', 9.80665),
  _unitTool(
      'force_unit', '力', 'mN、N、kN、MN、kgf、lbf 换算', ToolKind.forceUnit, 'N', 100),
  _unitTool(
      'power_unit', '功率', 'mW、W、kW、MW、hp、dBm 换算', ToolKind.powerUnit, 'W', 750),
  _unitTool('energy_unit', '能量', 'J、kJ、cal、kcal、BTU、eV、Wh、kWh、MWh、度 换算',
      ToolKind.energyUnit, 'J', 3600),
  _unitTool('angle_unit', '角度', 'deg、rad、turn、grad/gon、arcmin、arcsec 换算',
      ToolKind.angleUnit, 'deg', 180),
  _unitTool('current_unit', '电流', 'nA、μA、mA、A、kA、MA 换算', ToolKind.currentUnit,
      'A', 0.02),
  _unitTool('resistance_unit', '电阻', 'μΩ、mΩ、Ω、kΩ、MΩ、GΩ 换算',
      ToolKind.resistanceUnit, 'Ω', 10000),
  _unitTool('capacitance_unit', '电容', 'F、mF、μF、nF、pF、MF 换算',
      ToolKind.capacitanceUnit, 'F', 0.000001),
  _unitTool('inductance_unit', '电感', 'pH、nH、μH、mH、H、kH、MH 换算',
      ToolKind.inductanceUnit, 'H', 0.001),
  _unitTool('torque_unit', '扭矩', 'kN·m、N·m、mN·m、N·mm、kgf·cm、lbf·in、ozf·in 换算',
      ToolKind.torqueUnit, 'N·m', 10),
  _unitTool(
      'flow_unit',
      '流量',
      'mL/min、L/min、L/h、L/s、m³/h、m³/min、m³/s、GPM、CFM 换算',
      ToolKind.flowUnit,
      'L/min',
      60),
];

final List<ToolDefinition> textToolDefinitions = [
  _textTool('base_convert', '进制转换', '二进制、八进制、十进制、十六进制转换',
      ToolCategory.programming, '编码', '支持 0x、#、h、0b、b、0o、o 与全角数字输入。'),
  _textTool('timestamp', '时间戳转换', 'Unix 时间戳与日期转换', ToolCategory.programming,
      '时间', '支持秒/毫秒时间戳、小数秒、ISO、本地和中文日期时间。'),
  // 中文：**日期计算**——HiPER 手册里 `date` 与 `calendar` 的命中是 **0**，它没有这一类能力（本仓
  //       `engine-capability-probe.md` 有齐零验证的做法）。它算日期却不进入引擎，理由写在
  //       `text_tool_date_tools.dart` 的文件头。
  _textTool('date_calc', '日期计算', '两个日期相差多少天、某个日期加减几天', ToolCategory.math,
      '常用', '支持两个日期的间隔、单日期加减天数、今天起算，并给出星期、年内天数与 ISO 周。'),
  _textTool('color_convert', 'RGB/HEX颜色', 'RGB、HEX、HSL 颜色转换',
      ToolCategory.programming, '编码', '支持 HEX、RGB/RGBA、HSL/HSLA 和常用 CSS 命名色。'),
  _textTool('base64', 'Base64', 'Base64 编码解码', ToolCategory.programming, '编码',
      '自动识别普通文本、Base64、Base64URL 和 data URL，输出标准/Base64URL/data URL 可复制格式。'),
  _textTool('url_codec', 'URL编码', 'URL 编码与解码', ToolCategory.programming, '编码',
      '自动识别完整 URL、query string 和 URL 组件，输出长度变化、百分号片段和 query 参数数量。'),
  _textTool('json_format', 'JSON格式化', 'JSON 格式化与校验', ToolCategory.programming,
      '数据', '输入 JSON 或 JSON Lines，输出格式化结果和结构摘要。'),
  _textTool(
      'ascii_unicode',
      'ASCII/Unicode',
      '字符码点查询',
      ToolCategory.programming,
      '编码',
      '输出码点、UTF-16、UTF-32、UTF-8、HTML 实体和字符分类，并支持 U+ 与 \\u 反查。'),
  _textTool('bitwise', '位运算', 'AND / OR / XOR / NOT 与移位',
      ToolCategory.programming, '数据', '输入两个整数或 A/B 标签，输出常用位运算结果。'),
  _textTool('checksum', '校验和', '文本字节校验和', ToolCategory.programming, '数据',
      '支持 UTF-8 文本和十六进制字节，输出 SUM8、XOR8、LRC。'),
  _textTool('uuid', 'UUID生成', '生成/校验 UUID', ToolCategory.programming, '编码',
      '留空生成随机 UUID v4，粘贴 UUID 可标准化并识别版本与 variant。'),
  _textTool(
      'jwt_decode',
      'JWT解析',
      '解析 JWT Header / Payload',
      ToolCategory.programming,
      '数据',
      '离线解码 Header/Payload，校核 claims 时间但不验证签名。'),
  _textTool('query_params', 'Query参数', 'URL 查询参数解析', ToolCategory.programming,
      '数据', '解析 URL 或 query string，输出键值表和 JSON。'),
  _textTool('html_entities', 'HTML实体', 'HTML 实体编码解码', ToolCategory.programming,
      '编码', '支持常见命名实体、十进制和十六进制数字实体。'),
  _textTool('regex_test', '正则测试', '正则匹配预览', ToolCategory.programming, '数据',
      '第一行输入正则，后续输入测试文本，输出匹配位置。'),
  _textTool('text_stats', '文本统计', '字符、词、行和字节统计', ToolCategory.programming, '数据',
      '统计字符、段落、UTF-8 字节和中英文/数字/标点分布。'),
  _textTool('csv_json', 'CSV转JSON', 'CSV / TSV 转 JSON',
      ToolCategory.programming, '数据', '支持逗号、Tab、分号和竖线分隔，首行作为表头。'),
  _textTool('fnv_crc', 'FNV/CRC32', 'FNV-1a 与 CRC32 哈希',
      ToolCategory.programming, '编码', '支持 UTF-8 文本和十六进制字节的 FNV-1a/CRC32。'),
  _textTool('custom_formula', '自定义公式', '创建自己的公式工具', ToolCategory.custom, '公式',
      '支持 a、b、c 三个变量和常用数学函数。'),
];

ToolDefinition _textTool(
  String id,
  String title,
  String description,
  ToolCategory category,
  String group,
  String explanation,
) {
  return ToolDefinition(
    id: id,
    title: title,
    description: description,
    category: category,
    kind: ToolKind.staticOnly,
    group: group,
    inputs: const [],
    formula: '文本输入工具',
    explanation: explanation,
  );
}

ToolDefinition _unitTool(String id, String title, String description,
    ToolKind kind, String unit, double value) {
  return ToolDefinition(
    id: id,
    title: title,
    description: description,
    category: ToolCategory.units,
    kind: kind,
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'value', label: '输入值', unit: unit, defaultValue: value)
    ],
    formula: '目标值 = 输入值 × 单位倍率',
    explanation: '支持工程常用单位快速换算。',
  );
}
