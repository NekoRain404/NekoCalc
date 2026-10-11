import '../../domain/entities/tool_category.dart';

/// 搜索别名和示例数据表。
class ToolSearchData {
  ToolSearchData._();

  static const Map<String, List<String>> unitSearchAliases = {
    // 中文：**这一格是"单位换算那一张卡"的别名表。** 原先 21 个换算工具在这里各有一张
    //       逐单位的关键词表（`psi`、`MWh`、`平方英尺`…），那些表随工具一起删除——
    //       单位记号本身仍可搜，但搜的是**计算页那个面板**（`CONV`），不是工具目录。
    //       留下的这几条说的是这张卡自己：它叫什么、它开的是哪个面板。
    // English: **the alias list of the one unit-conversion card.** The 21 converter tools each had a
    //          per-unit keyword list here (`psi`, `MWh`, `平方英尺`, …) and those lists went with the
    //          tools — unit tokens are still searchable, but inside the calculator's own sheet
    //          (`CONV`), not in the tools catalogue. What is left describes the card itself: what it is
    //          called and which sheet it opens.
    'unit_convert': [
      'unit conversion',
      'unit converter',
      'convert units',
      'measurement conversion',
      '单位换算',
      '单位转换',
    ],
    'temperature': [
      'temperature converter',
      'celsius',
      'fahrenheit',
      'kelvin',
      'rankine',
      'degc',
      'degf',
      'degr',
      'c to f',
      'f to c',
      '温度换算',
      '摄氏度',
      '华氏度',
      '开尔文',
      '兰氏度',
    ],
  };


  static const List<String> generalSearchExamples = [
    '贷款',
    'json',
    // 中文：**这两个示例原先搜的是换算工具**（`kΩ` → 电阻换算、`平方英尺` → 面积换算）。
    //       那 21 个工具并成一张打开 `CONV` 面板的卡之后，那两条搜索一个工具都找不到了——
    //       示例是**拿去搜的词**，点下去什么都不该空着回来，所以换成今天真的找得到的两个：
    //       `单位换算`（那张卡）与 `摄氏度`（留下的温度换算）。
    // English: **these two used to search conversion tools** (`kΩ` → the resistance converter,
    //          `平方英尺` → the area one). With those 21 tools folded into one card that opens the
    //          `CONV` sheet neither query finds a tool any more — an example is **a word to search
    //          with**, and tapping one must not come back empty, so they are replaced by two that do
    //          resolve today: `单位换算` (that card) and `摄氏度` (the temperature converter that
    //          stayed).
    '单位换算',
    '摄氏度',
    'word count',
    'theta-ja',
  ];

  static const Map<ToolCategory, List<String>> searchExamplesByCategory = {
    ToolCategory.math: [
      '二次方程',
      '矩阵',
      '统计',
      'curve fitting',
      '比例',
      '三角形',
    ],
    ToolCategory.electronics: [
      '欧姆',
      '分压',
      'rc filter',
      'dBm',
      'theta-ja',
      '电池续航',
    ],
    ToolCategory.mechanical: [
      '扭矩',
      'beam deflection',
      'section modulus',
      '安全系数',
      '流量',
      '弹簧',
    ],
    ToolCategory.finance: [
      '贷款',
      '复利',
      'ROI',
      '折扣',
      'NPV',
      '电费',
    ],
    ToolCategory.science: [
      '自由落体',
      'ideal gas',
      'half life',
      'pH',
      '热量',
      '波长',
    ],
    ToolCategory.units: [
      // 中文：**这一格的六个示例全部换过。** 原先那六个（`kΩ`、`平方英尺`、`cubic feet`、`MWh`、
      //       `psi`、`uF`）每一个都只在被删掉的那个换算工具里存在，点下去一个结果都没有。
      //       今天的单位换算分类里有两张卡：`unit_convert`（这张卡自己）与 `temperature`，
      //       所以示例也只剩它们真正搜得到的词。
      // English: **all six of these were replaced.** Every one of the previous six (`kΩ`, `平方英尺`,
      //          `cubic feet`, `MWh`, `psi`, `uF`) existed only inside a deleted converter tool and
      //          would have returned nothing. The units category holds two cards today — `unit_convert`
      //          (this card) and `temperature` — so the examples are the words that really find them.
      '单位换算',
      'unit conversion',
      '温度',
      '摄氏度',
      'fahrenheit',
      'degc',
    ],
    ToolCategory.programming: [
      'json',
      'jwt token',
      'url params',
      'base64',
      'regex',
      'timestamp',
    ],
    ToolCategory.custom: [
      '公式',
      '工作流',
      '自定义',
      '参数',
      '模板',
      '计算',
    ],
  };

}
