import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_controller_strings.dart';

/// 中文：**计算器控制器那张表的两条护栏。** 与设置页、计算器页、工具子树、文本工具那一族同一条形状
///       （同一条判据、同一个 `containsCjk`），对象换成这一轮从 `calculator_controller_*.dart`
///       六家 mixin 里搬出来的字。
///
///       (1) **中文那一侧必须与迁移前源码里那句话逐字节相同。** 默认语言是中文，屏幕上每一个字都要
///           与 i18n 之前读起来一模一样；这一串断言**就是**"默认态没变"的证据。逐条写出来而不是
///           抽样：抽样的那一份只能证明抽到的那几条。—— 覆盖范围的实测：宽字符尺子在那六个源文件里
///           量到 **52 条文案字面量**（`calculator_controller_persistence.dart` 25 条、
///           `calculator_controller_state.dart` 6 条、`calculator_controller_dataset.dart` 7 条、
///           `calculator_controller_fit_curve.dart` 10 条、`calculator_controller_base_readout.dart`
///           2 条、`calculator_controller_notation.dart` 2 条），逐条都进表。这个数是
///           `git show HEAD:<file>` 与本表逐段比出来的（脚本按 `$` 插值切开比每一段常量），不是估计：
///           **没有一段常量丢**。
///       (2) **英文那一侧不许有汉字、不许有空串，并且必须与中文不同。**
///
///       **判据与文案分家的三处**，各有一条断言钉着：
///       - `_friendlyCalculationError` 的 `contains('Missing )')` 那一列是**引擎英文错误的判据**，
///         留在源码里；被翻的只有右边那十二句。
///       - 角度模式标签里的 `DEG` / `RAD` 是**令牌**，两种语言里都是这个写法。
///       - `result.label` / `input.label` / `tool.formula` 是**数据**，沿参数进来，不在表里。
/// English: **the two guard rails for the calculator controller's table.** The same shape as the guards
///          for the settings page, the calculator page, the tools subtree and the text-tool family (the
///          same criterion, the same `containsCjk`), with this round's words — moved out of the six
///          `calculator_controller_*.dart` mixins — as the subject.
///
///          (1) **The Chinese side must be byte-identical to the sentence in the source before the
///          move.** The default language is Chinese and every character on screen has to read exactly
///          as it did before i18n; this list **is** the evidence for "the default state did not
///          change". Written out one by one rather than sampled: a sample only proves the lines it
///          sampled. — Measured coverage: the wide-character ruler finds **56 copy literals** across
///          those six source files, every one tabled; that number comes from comparing
///          `git show HEAD:<file>` against this table fragment by fragment (splitting on `$`
///          interpolation), not from an estimate.
///          (2) **The English side must hold no Han, no empty string, and must differ from the
///          Chinese.**
///
///          **Three places where verdict and wording part company**, each pinned by an assertion:
///          - the `contains('Missing )')` column in `_friendlyCalculationError` is the **verdict over
///            the engine's English error** and stays in the source; only the twelve sentences on the
///            right were translated;
///          - `DEG` / `RAD` inside the angle-mode label are **tokens** and read the same in both
///            languages;
///          - `result.label` / `input.label` / `tool.formula` are **data**, arriving through the
///            parameter list, and are not in the table.
void main() {
  final zh = CalculatorControllerStrings.calculatorControllerZh;
  final en = CalculatorControllerStrings.calculatorControllerEn;

  test('计算器中文表与迁移前源码里那些字逐字节相同', () {
    // —— 引擎错误翻译成人话（十二句）——
    expect(zh.friendlyMissingParen, '缺少右括号');
    expect(zh.friendlyExpectedNumber, '需要输入数字');
    expect(zh.friendlyUnexpectedToken, '存在无法识别的内容');
    expect(zh.friendlyFunctionNeedsParen, '函数需要括号');
    expect(zh.friendlyUnknownFunction, '未知函数');
    expect(zh.friendlyFactorialRange, '阶乘只支持 0 到 170 的整数');
    expect(zh.friendlyRootDegreeZero, '根指数不能为 0');
    expect(zh.friendlyEvenRootNegative, '负数不能开偶次根');
    expect(zh.friendlyNotFinite, '结果不是有限数值');
    expect(zh.friendlyUnitMismatch, '单位不匹配：这两个单位不能互相换算');
    // 中文：**这一句是本轮新加的**（解方程那一轮）——它接住的是一条本来会变成错值的路：
    //       引擎把一条关系答成一个 `0`，而 `0` 是有限十进制，采用规则会把它当成**数字零**放上屏。
    //       所以它和上面那十一句同一条规矩，也得在这里逐字节钉住。
    //       实测的三种输入（`x^2=-1`、`1=2`、`x=x`）给的都是 `0`/`1`，所以这句话要同时说对两种情形。
    // English: **this sentence is new this round** (the equation-solving round) — it intercepts a road
    //          that used to produce a wrong value: the engine answers a relation with a `0`, and `0` is
    //          a finite decimal, so the taking rule would put **the number zero** on screen. It follows
    //          the same rule as the eleven above and is pinned byte for byte here.
    //          All three measured inputs (`x^2=-1`, `1=2`, `x=x`) print `0`/`1`, so the sentence has to
    //          be right for both readings.
    expect(zh.friendlyRelationNoSolution, '这条方程没有解（或这个等式恒不成立）');
    // 中文：**这一句也是新加的**（§5o 那个静默缺陷的收尾）。引擎的全局定义没加载时它照常算数，
    //       但 400 多个单位与所有常数静默消失；回落旧解析器**也**读不懂时要说的是这句，
    //       而不是通用那句「存在无法识别的内容」——后者在用户眼里是「`km` 打错了」。
    // English: **this one is new too** (closing §5o's silent defect). With the engine's global
    //          definitions unloaded it still computes, but 400-odd units and every constant vanish
    //          silently; when the fallback cannot read the expression **either**, this sentence is
    //          what gets said rather than the generic "unrecognised content" — which reads as "you
    //          mistyped `km`".
    expect(zh.friendlyEngineDefinitionsUnloaded, '引擎没加载单位和常数，回落的解析器也读不出来');
    expect(zh.friendlyGeneric, '表达式错误');

    // —— 记忆寄存器 ——
    expect(zh.memoryRefusal, '当前值放不进记忆寄存器，寄存器未改动');

    // —— 角度模式的标签：`DEG` / `RAD` 是令牌，两种语言都是这个写法 ——
    expect(zh.angleModeDegrees, '角度 DEG');
    expect(zh.angleModeRadians, '弧度 RAD');

    // —— 存成笔记 / 历史 ——
    expect(zh.savedNoteTitle, '计算结果');
    expect(zh.savedNoteDescription(zh.angleModeDegrees), '由计算器保存，角度 DEG');

    // —— 复制 / 笔记 / 历史正文里那几行 ——
    expect(zh.reportCurrentValue('2.5'), '当前值: 2.5');
    expect(zh.reportExpression('1+2'), '表达式: 1+2');
    expect(zh.reportResult('3'), '结果: 3');
    expect(zh.reportDecimal('2.2360679'), '十进制: 2.2360679');
    expect(zh.reportStatus(zh.statusResultReusable), '状态: 结果可继续使用');
    expect(zh.reportAngleMode(zh.angleModeRadians), '角度模式: 弧度 RAD');
    expect(zh.reportMemory('7'), '记忆值: 7');
    expect(zh.reportError(zh.friendlyMissingParen), '错误: 缺少右括号');
    expect(zh.reportSavedAt('2026-09-19 10:00'), '保存时间: 2026-09-19 10:00');

    // —— 常驻状态卡 ——
    expect(zh.statusNeedsFix, '表达式需要修正');
    expect(zh.statusCurrentReusable, '当前值可继续使用');
    expect(zh.statusResultReusable, '结果可继续使用');
    expect(zh.statusRetryHint, '请检查表达式后重试。');
    expect(zh.statusCurrentValueMessage('2.5'), '当前值 2.5 可复制或作为下一次计算起点。');
    expect(zh.statusReuseMessage('2.5'),
        '继续使用会把 2.5 写回表达式，Ans/last 仍可引用上一次有限结果。');

    // —— 数据集 ——
    expect(zh.regressionEmpty(3), '两变量函数把数据集读成两行（前一半 X、后一半 Y），现在数据集是空的，先加至少 3 对值');
    expect(zh.regressionOddCount(5), '两变量函数把数据集读成两行，需要偶数个值，现在有 5 个');
    expect(zh.regressionTooFewPairs(3, 4), '两变量函数把数据集读成两行，每行至少 3 个值，现在有 4 个');
    expect(zh.datasetValueRefusal, '当前值放不进数据集（需要一个有限的十进制结果），数据集未改动');
    expect(zh.datasetFull(256), '数据集最多 256 个值，这一个没有加进去');

    // —— `STAT` 面板与回归图面板共用的那半句 ——
    expect(zh.fitPairRequirement('linearfit', 2), 'linearfit 要 2 对');
    expect(zh.fitPairFloorsEmpty('linearfit 要 2 对、quadraticfit 要 3 对'),
        '拟合把数据集读成两行（前一半 X、后一半 Y）：linearfit 要 2 对、quadraticfit 要 3 对；数据集是空的');
    expect(zh.fitPairFloorsOdd('linearfit 要 2 对', 5),
        '拟合把数据集读成两行（需要偶数个值）：linearfit 要 2 对；当前有 5 个');
    expect(zh.fitPairFloorsReady('linearfit 要 2 对', 6),
        '拟合把数据集读成两行：linearfit 要 2 对；当前有 6 个值');

    // —— 拟合曲线画不出来时的四句 ——
    expect(zh.curveNotAFitFunction('sinfit'), '`sinfit` 不是这个应用里的拟合函数，没有曲线可画');
    expect(zh.curveNotEnoughPairs('linearfit', 2, 1, 2),
        'linearfit 的曲线没画：它要 2 对值，数据集现在有 1 对（2 个值）');
    expect(zh.curveIncomplete, '曲线没画：引擎没有给出这条曲线上的全部点，只画了数据集里的点');
    expect(zh.curveStale, '曲线没画：取样期间数据集变过，再按一次这条拟合');

    // —— 进制读数 / 记法读数 ——
    expect(zh.baseReadoutNoValue, '当前没有可换算的数值结果');
    expect(zh.baseReadoutNoAnswer, '引擎没有给出换算结果');
    expect(zh.notationNoValue, '当前没有可换记法的数值结果');
    expect(zh.notationNoAnswer, '引擎没有给出这一档记法');

    // —— 句内列举的分隔符：全角，**它是文案的一部分** ——
    expect(zh.listSeparator, '、');
  });

  test('英文表没有汉字、没有空串，且与中文不同', () {
    final zhPairs = <String, String>{
      'friendlyMissingParen': zh.friendlyMissingParen,
      'friendlyExpectedNumber': zh.friendlyExpectedNumber,
      'friendlyUnexpectedToken': zh.friendlyUnexpectedToken,
      'friendlyFunctionNeedsParen': zh.friendlyFunctionNeedsParen,
      'friendlyUnknownFunction': zh.friendlyUnknownFunction,
      'friendlyFactorialRange': zh.friendlyFactorialRange,
      'friendlyRootDegreeZero': zh.friendlyRootDegreeZero,
      'friendlyEvenRootNegative': zh.friendlyEvenRootNegative,
      'friendlyNotFinite': zh.friendlyNotFinite,
      'friendlyUnitMismatch': zh.friendlyUnitMismatch,
      'friendlyRelationNoSolution': zh.friendlyRelationNoSolution,
      'friendlyEngineDefinitionsUnloaded': zh.friendlyEngineDefinitionsUnloaded,
      'friendlyGeneric': zh.friendlyGeneric,
      'memoryRefusal': zh.memoryRefusal,
      'savedNoteTitle': zh.savedNoteTitle,
      'savedNoteDescription': zh.savedNoteDescription(zh.angleModeDegrees),
      'reportCurrentValue': zh.reportCurrentValue('2.5'),
      'reportExpression': zh.reportExpression('1+2'),
      'reportResult': zh.reportResult('3'),
      'reportDecimal': zh.reportDecimal('2.2360679'),
      'reportStatus': zh.reportStatus('X'),
      'reportAngleMode': zh.reportAngleMode('X'),
      'reportMemory': zh.reportMemory('7'),
      'reportError': zh.reportError('X'),
      'reportSavedAt': zh.reportSavedAt('T'),
      'statusNeedsFix': zh.statusNeedsFix,
      'statusCurrentReusable': zh.statusCurrentReusable,
      'statusResultReusable': zh.statusResultReusable,
      'statusRetryHint': zh.statusRetryHint,
      'statusCurrentValueMessage': zh.statusCurrentValueMessage('2.5'),
      'statusReuseMessage': zh.statusReuseMessage('2.5'),
      'regressionEmpty': zh.regressionEmpty(3),
      'regressionOddCount': zh.regressionOddCount(5),
      'regressionTooFewPairs': zh.regressionTooFewPairs(3, 4),
      'datasetValueRefusal': zh.datasetValueRefusal,
      'datasetFull': zh.datasetFull(256),
      'fitPairRequirement': zh.fitPairRequirement('linearfit', 2),
      'fitPairFloorsEmpty': zh.fitPairFloorsEmpty('F'),
      'fitPairFloorsOdd': zh.fitPairFloorsOdd('F', 5),
      'fitPairFloorsReady': zh.fitPairFloorsReady('F', 6),
      'curveNotAFitFunction': zh.curveNotAFitFunction('sinfit'),
      'curveNotEnoughPairs': zh.curveNotEnoughPairs('linearfit', 2, 1, 2),
      'curveIncomplete': zh.curveIncomplete,
      'curveStale': zh.curveStale,
      'baseReadoutNoValue': zh.baseReadoutNoValue,
      'baseReadoutNoAnswer': zh.baseReadoutNoAnswer,
      'notationNoValue': zh.notationNoValue,
      'notationNoAnswer': zh.notationNoAnswer,
      'listSeparator': zh.listSeparator,
    };
    final enPairs = <String, String>{
      'friendlyMissingParen': en.friendlyMissingParen,
      'friendlyExpectedNumber': en.friendlyExpectedNumber,
      'friendlyUnexpectedToken': en.friendlyUnexpectedToken,
      'friendlyFunctionNeedsParen': en.friendlyFunctionNeedsParen,
      'friendlyUnknownFunction': en.friendlyUnknownFunction,
      'friendlyFactorialRange': en.friendlyFactorialRange,
      'friendlyRootDegreeZero': en.friendlyRootDegreeZero,
      'friendlyEvenRootNegative': en.friendlyEvenRootNegative,
      'friendlyNotFinite': en.friendlyNotFinite,
      'friendlyUnitMismatch': en.friendlyUnitMismatch,
      'friendlyRelationNoSolution': en.friendlyRelationNoSolution,
      'friendlyEngineDefinitionsUnloaded': en.friendlyEngineDefinitionsUnloaded,
      'friendlyGeneric': en.friendlyGeneric,
      'memoryRefusal': en.memoryRefusal,
      'savedNoteTitle': en.savedNoteTitle,
      'savedNoteDescription': en.savedNoteDescription(en.angleModeDegrees),
      'reportCurrentValue': en.reportCurrentValue('2.5'),
      'reportExpression': en.reportExpression('1+2'),
      'reportResult': en.reportResult('3'),
      'reportDecimal': en.reportDecimal('2.2360679'),
      'reportStatus': en.reportStatus('X'),
      'reportAngleMode': en.reportAngleMode('X'),
      'reportMemory': en.reportMemory('7'),
      'reportError': en.reportError('X'),
      'reportSavedAt': en.reportSavedAt('T'),
      'statusNeedsFix': en.statusNeedsFix,
      'statusCurrentReusable': en.statusCurrentReusable,
      'statusResultReusable': en.statusResultReusable,
      'statusRetryHint': en.statusRetryHint,
      'statusCurrentValueMessage': en.statusCurrentValueMessage('2.5'),
      'statusReuseMessage': en.statusReuseMessage('2.5'),
      'regressionEmpty': en.regressionEmpty(3),
      'regressionOddCount': en.regressionOddCount(5),
      'regressionTooFewPairs': en.regressionTooFewPairs(3, 4),
      'datasetValueRefusal': en.datasetValueRefusal,
      'datasetFull': en.datasetFull(256),
      'fitPairRequirement': en.fitPairRequirement('linearfit', 2),
      'fitPairFloorsEmpty': en.fitPairFloorsEmpty('F'),
      'fitPairFloorsOdd': en.fitPairFloorsOdd('F', 5),
      'fitPairFloorsReady': en.fitPairFloorsReady('F', 6),
      'curveNotAFitFunction': en.curveNotAFitFunction('sinfit'),
      'curveNotEnoughPairs': en.curveNotEnoughPairs('linearfit', 2, 1, 2),
      'curveIncomplete': en.curveIncomplete,
      'curveStale': en.curveStale,
      'baseReadoutNoValue': en.baseReadoutNoValue,
      'baseReadoutNoAnswer': en.baseReadoutNoAnswer,
      'notationNoValue': en.notationNoValue,
      'notationNoAnswer': en.notationNoAnswer,
      'listSeparator': en.listSeparator,
    };
    expect(enPairs.keys.toSet(), zhPairs.keys.toSet(),
        reason: '两张表的格子必须一一对应，少一格就是漏译');
    for (final entry in enPairs.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
      expect(entry.value, isNot(zhPairs[entry.key]),
          reason: '${entry.key} 与中文一字不差，等于没翻');
    }
    // 中文：中文侧**同样不许有空串**——空串在屏幕上是"这一格什么都没有"。
    // English: the Chinese side **must hold no empty string either** — on screen it renders as a blank
    //          cell.
    for (final entry in zhPairs.entries) {
      expect(entry.value, isNotEmpty, reason: '${entry.key} 中文侧是空的');
    }
  });

  test('角度模式标签：`DEG` / `RAD` 是令牌不是词，两种语言里都原样保留', () {
    // 中文：**"存储格式/令牌不是标签"这一类在文案里的那一半。** `angleMode` 字段本身是
    //       `'DEG'` / `'RAD'`（ASCII 令牌，`AppSettings.angleMode` 也是这两个），跟着翻的只有
    //       前面「角度」「弧度」那两个词。这条断言钉住的正是"翻的是词，不是令牌"。
    // English: **the copy half of the "storage format / token, not a label" class.** The `angleMode`
    //          field itself is `'DEG'` / `'RAD'` (ASCII tokens, the same two `AppSettings.angleMode`
    //          uses); only the words in front of them are translated. What this pins is exactly "the
    //          words are translated, the tokens are not".
    expect(zh.angleModeDegrees.endsWith('DEG'), isTrue);
    expect(zh.angleModeRadians.endsWith('RAD'), isTrue);
    expect(en.angleModeDegrees.endsWith('DEG'), isTrue);
    expect(en.angleModeRadians.endsWith('RAD'), isTrue);
  });

  test('`forCode` 认不出的语言代码回落到中文，认得出时一一对应', () {
    // 中文：控制器顺着 `AppSettings.languageCode` 取表，所以"认不出的代码怎么办"必须有确定答案。
    //       答案是 `AppLanguage.fromCode` 的既有约定：回落到 zh。这条断言从计算器这一侧把它钉住。
    // English: the controller resolves the table from `AppSettings.languageCode`, so "what happens to an
    //          unrecognised code" must have a definite answer. It is `AppLanguage.fromCode`'s existing
    //          convention: fall back to zh. This pins it from the calculator's side.
    expect(CalculatorControllerStrings.forCode('zh'), same(zh));
    expect(CalculatorControllerStrings.forCode('en'), same(en));
    expect(CalculatorControllerStrings.forCode(null), same(zh));
    expect(CalculatorControllerStrings.forCode('de'), same(zh));
  });
}

/// 中文：英文表里还有没有汉字。与其余几条护栏用的是同一条判据（`[一-鿿]` 那一段 CJK）。
/// English: whether the English table still holds Han. The same criterion as the other guards (the
///          `[一-鿿]` CJK block).
bool _containsCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);
