import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> unitToolDefinitions = [
  // 中文：**单位换算那一张卡——它不是计算器，是那一个面板的入口。**
  //
  //       它顶替的是原先 21 张换算卡（长度、面积、体积、质量、压力、速度、电压、频率、数据、
  //       时间、加速度、力、功率、能量、角度、电流、电阻、电容、电感、扭矩、流量）。那 21 张卡
  //       与键盘上的 `CONV` 键做的是同一件事，而引擎自己就会换算（`5 km to mi`），所以目录里
  //       只留一个入口：**点它 = 按 `CONV`**。
  //
  //       三处构造上的后果，都不是笔误：
  //         · `inputs` 是空的、`kind` 是 `staticOnly`——**目录里没有这个工具的算法**，那正是
  //           `staticOnly` 那一格的意思（文本工具用的是同一格）。`calculateTool` 因此不需要
  //           为它加一个分支，也不该加：它没有任何"输入 → 结果"的算法可算。
  //         · 它进不了详情页：`openToolDetail` 认出 `opensUnitSheet` 的这一类，不推路由，
  //           而是把请求交给外壳（`AppShell` → 计算页 `_openUnitSheet`）。**面板只有一份**，
  //           就是 `CONV` 打开的那一个；`tool_navigation.dart` 上写着这条路由的形状。
  //         · `formula` / `explanation` 与 `_unitTool` 那两条逐字节相同：面板做的事就是
  //           "目标值 = 输入值 × 单位倍率"，这两句今天也仍被 `temperature` 用着，
  //           所以它们不是死条目。
  // English: **the one unit-conversion card — not a calculator but the entrance to that one sheet.**
  //
  //          It replaces the 21 converter cards (length, area, volume, mass, pressure, speed, voltage,
  //          frequency, data, time, acceleration, force, power, energy, angle, current, resistance,
  //          capacitance, inductance, torque, flow). Those cards did exactly what the keypad's `CONV`
  //          key does, and the engine converts on its own (`5 km to mi`), so the catalogue keeps one
  //          entrance: **tapping it is pressing `CONV`**.
  //
  //          Three consequences of the construction, none of them an accident:
  //            · `inputs` is empty and `kind` is `staticOnly` — **there is no algorithm for this tool in
  //              the catalogue**, which is exactly what that kind means (the text tools use the same
  //              cell), so `calculateTool` needs no branch for it and must not grow one: there is no
  //              "input → result" algorithm to run.
  //            · It cannot reach the detail page: `openToolDetail` recognises the `opensUnitSheet`
  //              class, pushes no route, and hands the request to the shell (`AppShell` →
  //              `_openUnitSheet` on the calculator page). **There is one sheet**, the one `CONV`
  //              opens; the shape of that route is written on `tool_navigation.dart`.
  //            · `formula` / `explanation` are byte-identical to `_unitTool`'s: what the sheet does is
  //              "target = input × unit factor", and `temperature` still uses both strings, so neither
  //              is a dead entry.
  _unitSheetTool('unit_convert', '单位换算', '长度、面积、体积、质量、压力、电学等单位换算'),
  _unitTool('temperature', '温度', '℃、℉、K、°R 换算', ToolKind.temperature, '℃', 25),
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
  // 中文：**不确定度传播**——HiPER 手册里 `uncertainty` 与 `±` 的命中都是 **0**。
  _textTool('derive_steps', '求导分步', '把求导的每一步与所用法则写出来', ToolCategory.math,
      '常用', '对 x 求导并逐步写出用了哪条法则：和、积、幂、负号；不会的那一步如实停下，绝不跳过。'),
  _textTool('uncertainty', '不确定度传播', '多个测量值的合成不确定度与主要误差来源',
      ToolCategory.science, '物理',
      '输入若干「值 ± 不确定度」，给出和与差的合成不确定度、积与商的相对不确定度，以及哪一项是主要误差来源。'),
  // 中文：**质因数分解**——HiPER 手册里 `factor` 有 5 处命中（它有这个能力）。它不走引擎，
  //       理由是量出来的：引擎分不动时**会把输入原样退回来**（见 `text_tool_factor_tools.dart`）。
  // 中文：**算术分步**——对照表里最后一条「HiPER 有、我们没有」的东西。它不走引擎，
  //       理由与求导分步同源（纯函数 ⇒ 单测就是全部证据）。
  _textTool('arithmetic_steps', '算术分步', '把四则运算的运算顺序一步步写出来', ToolCategory.math,
      '常用', '按运算顺序把式子一步步化简：先乘除后加减、括号优先、同级从左到右；不支持的写法如实说明。'),
  _textTool('prime_factor', '质因数分解', '把一个整数分解成质因数', ToolCategory.math,
      '常用', '输入一个整数，给出质因数分解（指数合并、按质数升序）；1 与 0 没有质因数分解，如实说明。'),
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

/// 中文：**"目录里没有算法、点开是别处的界面"的那一格**（今天是 `unit_convert`）。
///       它借用 `staticOnly` 那个 kind——那片代码是"这里没有输入 → 结果的算法"，
///       **不是"这是文本工具"**（判断文本工具的是 `ToolCapabilities.usesTextDetail`，
///       按 id 判定，与 kind 无关）。`inputs` 为空、`formula` / `explanation` 与 `_unitTool`
///       共用同两条字串，于是这张卡在检索里仍按那两句中文命中，而英文表里不必新增条目。
/// English: **the cell for "no algorithm in the catalogue, the screen it opens lives elsewhere"**
///          (today `unit_convert`). It borrows the `staticOnly` kind, which means "there is no
///          input → result algorithm here" rather than "this is a text tool" (what makes a text tool is
///          `ToolCapabilities.usesTextDetail`, decided by id, not by kind). `inputs` is empty and
///          `formula` / `explanation` share `_unitTool`'s two strings, so the card still matches those
///          two Chinese sentences in search and the English tables need no new entries.
ToolDefinition _unitSheetTool(String id, String title, String description) {
  return ToolDefinition(
    id: id,
    title: title,
    description: description,
    category: ToolCategory.units,
    kind: ToolKind.staticOnly,
    featured: true,
    inputs: const [],
    formula: '目标值 = 输入值 × 单位倍率',
    explanation: '支持工程常用单位快速换算。',
  );
}
