import '../math/result_text_rules.dart';
import 'package:flutter/services.dart';

import '../math/math_engine.dart';
import '../math/math_result.dart';
import 'qalculate_channel.dart';

/// 中文：把 [QalculateChannel] 包成 [MathEngine]。这一层只做三件事：
///
///       1. **把异常吃掉**。通道在原生侧缺席时抛 [MissingPluginException]、原生侧用
///          `result.error` 回复时抛 [PlatformException]，两者都变成一条 `ok: false` 的回执。
///          引擎是新增能力，不是新的故障点，所以任何失败都必须能在这里停下来。
///          （等待上限不在这里：超时是**提交路径**的事，由控制器自己计时——那里的定时器能在
///          `dispose` 时取消，`Future.timeout` 的不行。见 `CalculatorController.engineTimeout`。）
///       2. **把原生字段映射成三形态**：`decimal` 同时是显示文本与十进制形态，`latex` 是排版形态。
///       3. **把 `decimal` 洗成机器可解析**。显示取整归 Dart 的 `formatNumber`，但那份取整的输入
///          必须是干净的数字：原生侧已经关掉 Unicode 符号与千分位，这里再兜一次底——两边都做，
///          任何一边失效都不会让 [MathResult.decimalValue] 静默变成 null（记忆寄存器会静默加 0、
///          `Ans`/`last` 会静默失效，正是 3c 要消灭的失败类别换了个入口重新长出来）。
///
/// English: Wraps [QalculateChannel] as a [MathEngine]. This layer does exactly three things:
///
///          1. **Swallow exceptions.** The channel throws [MissingPluginException] when there is no
///             native side and [PlatformException] when the native side replies with
///             `result.error`; both become an `ok: false` receipt. The engine is a new capability
///             and not a new failure point, so every failure has to stop here. (The wait is not
///             capped here: the timeout belongs to the *submit path*, which times the call itself —
///             its timer can be cancelled on `dispose`, which a `Future.timeout` timer cannot. See
///             `CalculatorController.engineTimeout`.)
///          2. **Map the native fields onto the three forms**: `decimal` is both the display text
///             and the decimal form, `latex` is the typeset form.
///          3. **Wash `decimal` into something machine-parseable.** Display rounding belongs to
///             Dart's `formatNumber`, but that rounding needs a clean number as its input: the
///             native side already turns Unicode signs and digit grouping off, and this normalizes
///             again as a backstop — with both in place, either one failing cannot silently make
///             [MathResult.decimalValue] null (the memory register would silently add 0 and
///             `Ans`/`last` would silently stop resolving: the failure class 3c set out to delete,
///             growing back through a different entrance).
class QalculateMathEngine implements MathEngine {
  const QalculateMathEngine({this.channel = const QalculateChannel()});

  final QalculateChannel channel;

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    final Map<String, String> payload;
    try {
      payload = await channel.evaluate(expression, angleMode: angleMode);
    } on PlatformException catch (error) {
      // 中文：原生侧用 `result.error(...)` 回复（参数不合法、引擎抛了 Error）时走这里。
      // English: The native side answered with `result.error(...)` — bad arguments, or the engine
      //          threw an Error of its own.
      return EngineReply.failure(
        'platform_error: ${error.code} ${error.message}'.trim(),
      );
    } on MissingPluginException catch (error) {
      // 中文：没有原生侧——桌面、`flutter test` 与单元测试环境的常态，不是异常情况。
      // English: No native side — the normal case on desktop, under `flutter test` and in unit
      //          tests. Not an exceptional situation.
      return EngineReply.failure('missing_plugin: ${error.message}'.trim());
    }
    return _replyFrom(payload);
  }

  /// 中文：把原生回执翻译成一条 [EngineReply]。`ok` 的含义是**这一次有没有可用答案**，所以它比
  ///       原生的 `ok` 严格一点：被中止的求值、以及没有 `decimal` 的回执都算没有答案——前者按定义
  ///       是不完整的，后者没有可以放到显示区上的东西。
  /// English: Translates the native receipt into an [EngineReply]. `ok` means *did this call produce
  ///          a usable answer*, so it is stricter than the native `ok`: an aborted evaluation and a
  ///          receipt without a `decimal` both count as no answer — the first is by definition
  ///          incomplete, the second carries nothing that could go on the display.
  static EngineReply _replyFrom(Map<String, String> payload) {
    final messages = payload['messages'] ?? '';
    final aborted = payload['aborted'] == 'true';
    if (payload['ok'] != 'true') {
      return EngineReply.failure(
        'engine_error: ${payload['error'] ?? ''}'.trim(),
        messages: messages,
        aborted: aborted,
      );
    }
    if (aborted) {
      return EngineReply.failure(
        'engine_aborted',
        messages: messages,
        aborted: true,
      );
    }
    final decimal = _normalizeDecimal(payload['decimal'] ?? '');
    if (decimal.isEmpty) {
      return EngineReply.failure('engine_no_decimal', messages: messages);
    }
    return EngineReply.success(
      MathResult(
        displayText: decimal,
        displayTex: (payload['latex'] ?? '').trim(),
        // 中文：分数写法（HiPER 的 `d/c` 那一颗键要的东西）。它与 `latex` 是**同一个结构**的两次
        //       打印，只是 `number_fraction_format` 不同，值严格相等（见 `printOptions`）。
        //       原生侧不认识这个字段（版本不匹配）时这里是空串 = 「这一次没有分数写法」，
        //       于是那一颗键是空操作——与引擎缺席、旧解析器上屏走的是同一条路，不会去猜一个分数。
        // English: the fraction spelling (what HiPER's `d/c` key is for). It and `latex` are two
        //          prints of **one structure** differing only in `number_fraction_format`, so the
        //          values are strictly equal (see `printOptions`). A native side that does not know
        //          the field (a version mismatch) leaves this empty = "no fraction spelling this
        //          time", which makes that key a no-op — the same route as an absent engine or the
        //          legacy parser on screen, and it never invents a fraction.
        fractionTex: (payload['fraction'] ?? '').trim(),
        // 中文：**带分数写法**（HiPER 结果格式菜单里 `Mixed number` 那一格）。它与 `latex`、
        //       `fraction` 是**同一个结构**的三次打印，只是 `number_fraction_format` 取了第三个值
        //       （`FRACTION_COMBINED`），所以值严格相等（见 `QalculateOptions.printOptions`）。
        //       与分数那一格同一条路：原生侧不认识这个字段（版本不匹配）时这里是空串 = 「这一次没有
        //       带分数写法」，那一格于是不存在，不会去猜一个。
        // English: **the mixed-number spelling** (HiPER's `Mixed number` cell in the result format
        //          menu). It and `latex`/`fraction` are three prints of **one structure**, differing
        //          only in a third value of `number_fraction_format` (`FRACTION_COMBINED`), so the
        //          values are strictly equal (see `QalculateOptions.printOptions`). Same road as the
        //          fraction cell: a native side that does not know the field (a version mismatch)
        //          leaves this empty = "no mixed-number spelling this time" and the cell then does not
        //          exist, rather than one being guessed.
        mixedTex: (payload['mixed'] ?? '').trim(),
        // 中文：度分秒写法（HiPER 的 `DMS` 那一格）。它与 `decimal` 是**同一个 `approximated`
        //       结构**的两次打印，所以那一串里的值逐位等于十进制那一份（见 `QalculateEngine`）。
        //       原生侧不认识这个字段（版本不匹配）、引擎缺席、旧解析器上屏、或走的是换算那一支时，
        //       这里都是空串 = 「这一次没有度分秒写法」，于是那一颗键是空操作，不去猜一个。
        //       这里只做 `trim`：**形状（`°`/`′`/`″` 三段）由 `ResultPresentation` 一处判**，
        //       判不过就整格不要——拿不准时宁可没有这一格，也不印一串读不出来的东西。
        // English: the DMS spelling (HiPER's `DMS` cell). It and `decimal` are two renders of **one
        //          `approximated` structure**, so the value in that string equals the decimal half
        //          digit for digit (see `QalculateEngine`). A native side that does not know the field
        //          (a version mismatch), an absent engine, the legacy parser on screen, or the
        //          conversion branch all leave it empty = "no DMS spelling this time", which makes
        //          that key a no-op rather than a guess. Only `trim` happens here: **the shape**
        //          (three `°`/`′`/`″` sections) **is judged in one place, `ResultPresentation`**, and
        //          anything that fails that check loses the whole cell — when in doubt, no cell rather
        //          than a string nobody can read.
        dmsText: (payload['dms'] ?? '').trim(),
        // 中文：形状由原生侧用引擎自己的判据填（见 `QalculateMathEngine` 那一侧的 `kind`）。
        //       **认不出来的一律按 `arithmetic` 处理**：那是「不显示」的那一支，也就是放宽之前的
        //       行为——原生侧要是没发这个字段（版本不匹配），整个 tier 2 就自动退回旧行为，
        //       而不是默默什么都放行。
        // English: the shape is filled in by the native side from the engine's own predicates (the
        //          `kind` there). **Anything unrecognised counts as `arithmetic`**: that is the
        //          "do not display" branch, i.e. the behaviour from before the relaxation. If the
        //          native side does not send the field at all (a version mismatch), tier 2 falls back
        //          to the old behaviour instead of silently letting everything through.
        resultKind: _resultKindFrom(payload['kind']),
        // 中文：十进制形态就是洗干净的 decimal 本身，**不再过 `decimalTextOf`**：那个方法会无条件
        //       剥逗号，而逗号刚在上面按位置判过——再剥一次等于把 fail-closed 的那道判定又拆掉
        //       （`5,656854` 会变成 `5656854`，一个静默的错值）。这里只问一句「它是不是一个有限
        //       数」：是就原样存进十进制形态，不是（带单位的结果、`Infinity`、判不出来的逗号）就
        //       留空，表示「这一次没有十进制形态」，数值消费者据此不再解析，而不是解析失败后取 0。
        // English: The decimal form is the washed decimal itself, **no longer passed through
        //          `decimalTextOf`**: that method strips commas unconditionally, and a comma was just
        //          judged positionally above — stripping it again would dismantle the fail-closed
        //          decision (`5,656854` would become `5656854`, a silently wrong value). Only one
        //          question is asked here: is it a finite number? If so it becomes the decimal form
        //          as it stands; if not (a result carrying a unit, `Infinity`, an unreadable comma)
        //          the field stays empty, meaning "no decimal form this time", so numeric consumers
        //          stop rather than taking 0 after a failed parse.
        decimalText: decimalTextIsFinite(decimal) ? decimal : '',
      ),
      messages: messages,
    );
  }

  /// 中文：原生侧发来的形状字符串 → [EngineResultKind]。取值逐字对应 `QalculateEngine.KIND_*`；
  ///       认不出（含字段缺失、空串）一律 [EngineResultKind.arithmetic]——理由见调用点。
  /// English: the native shape string → [EngineResultKind]. The values match `QalculateEngine.KIND_*`
  ///          verbatim; anything unrecognised (a missing field, an empty string) becomes
  ///          [EngineResultKind.arithmetic] — see the call site for why.
  static EngineResultKind _resultKindFrom(String? raw) => switch (raw) {
        'conversion' => EngineResultKind.conversion,
        // 中文：`unit_mismatch` —— 用户要了一次换算而引擎没做（原生侧 `conversionLanded` 判出来的）。
        //       与 `unit` 一样落在「不显示」那一支，理由见 [EngineResultKind.unitMismatch]。
        // English: `unit_mismatch` — a conversion was asked for and the engine did not perform it
        //          (judged natively by `conversionLanded`). Like `unit` it lands in the "do not
        //          display" branch; see [EngineResultKind.unitMismatch].
        'unit_mismatch' => EngineResultKind.unitMismatch,
        // 中文：`quantity` —— 一个量（数 × 单位），**可以显示**：单位是用户从面板插进去的，
        //       见 [EngineResultKind.quantity]。
        // English: `quantity` — a quantity (a number times a unit) and **displayable**: its units are
        //          ones the user inserted from the sheet; see [EngineResultKind.quantity].
        'quantity' => EngineResultKind.quantity,
        'unit' => EngineResultKind.unit,
        'structured' => EngineResultKind.structured,
        'number' => EngineResultKind.number,
        // 中文：`symbolic` —— 结果里有变量符号，而引擎一句话都没说（原生侧 `KIND_SYMBOLIC`）。
        //       它与 `arithmetic` 的差别就是「引擎算没算」；**配不配显示仍由
        //       [MathResult.isDisplayable] 一处回答**，而且那里还有一道应用侧的判据（见
        //       `_selectEngineResult`）。
        // English: `symbolic` — the result holds a variable symbol and the engine said nothing
        //          (the native `KIND_SYMBOLIC`). Its difference from `arithmetic` is exactly "did the
        //          engine compute"; **whether it belongs on screen is still answered in one place**,
        //          [MathResult.isDisplayable], which also applies an app-side judgement (see
        //          `_selectEngineResult`).
        'symbolic' => EngineResultKind.symbolic,
        _ => EngineResultKind.arithmetic,
      };

  /// 中文：Unicode 减号 → ASCII `-`、剥掉千分位、去首尾空白。这些脏东西都会让 `double.tryParse`
  ///       返回 null 而不抛异常——静默失败。
  ///
  ///       **逗号只在分组位置上才剥**，这是与「无条件剥逗号」的关键区别：逗号小数分隔符的语言环境
  ///       下，`5,656854` 里的逗号是**小数点**，无条件剥掉会把它变成 `5656854`——那不是 fail-closed，
  ///       是一个静默的错值。分组与小数点用形状就能分开：分组一定是「1–3 位开头，之后每组恰好 3 位」
  ///       （`1,234.5`），`5,656854` 不是这个形状，于是原样留着，调用点的
  ///       `MathResult.decimalTextIsFinite` 判它不是有限数，
  ///       这一次就没有十进制形态——**拿不准时宁可没有值，也不给一个错值**。
  ///
  ///       原生侧另有第一道保险：`Calculator.useDecimalPoint(true)` 把小数点钉成 `.`，于是逗号只可能
  ///       是分组；这里的位置规则是第二道，两道都对不上时仍然 fail-closed。
  ///
  ///       空格分隔符（U+2009 / U+00A0 / U+202F）可以无条件剥：空格在任何语言环境里都不是小数点。
  ///       它们写成转义而不是字面量——那三个字符在源码里**看不见**，摆在字符类里没法复查。
  /// English: Unicode minus to ASCII `-`, grouping separators stripped, surrounding whitespace
  ///          trimmed. All of them make `double.tryParse` return null without throwing — a silent
  ///          failure.
  ///
  ///          A comma is stripped *only in a grouping position*, which is the whole difference from
  ///          stripping commas unconditionally: under a comma-decimal locale the comma in
  ///          `5,656854` **is the decimal point**, and stripping it yields `5656854` — not a
  ///          fail-closed refusal but a silently wrong value. Grouping and decimal point are told
  ///          apart by shape: grouping is always "1-3 digits, then groups of exactly 3"
  ///          (`1,234.5`), while `5,656854` is not that shape, so it is left alone,
  ///          `MathResult.decimalTextIsFinite` finds it not a finite number, and this evaluation has
  ///          no decimal form —
  ///          **when in doubt, no value rather than a wrong one**.
  ///
  ///          The native side is the first line of defence: `Calculator.useDecimalPoint(true)` pins
  ///          the decimal point to `.`, so a comma can only be grouping. This positional rule is the
  ///          second, and when both say no it still fails closed.
  ///
  ///          The space separators (U+2009 / U+00A0 / U+202F) are stripped unconditionally: a space
  ///          is never a decimal point in any locale. They are written as escapes rather than
  ///          literals because those characters are *invisible* in source and cannot be reviewed
  ///          inside a character class.
  static String _normalizeDecimal(String raw) =>
      _appScientificSpelling(_washDecimal(raw));

  /// 中文：[_normalizeDecimal] 的清洗那一步：Unicode 减号、千分位、首尾空白。指数写法不在这里，
  ///       见 [_appScientificSpelling]。
  /// English: The washing step of [_normalizeDecimal]: Unicode minus, digit grouping, surrounding
  ///          whitespace. The exponent spelling is not here; see [_appScientificSpelling].
  static String _washDecimal(String raw) {
    var text = raw
        .replaceAll('\u2212', '-')
        .replaceAll(RegExp('[\\u2009\\u00a0\\u202f]'), '')
        .trim();
    final match = _decimalParts.firstMatch(text);
    if (match == null) return text;
    final integer = match.group(2)!;
    if (!integer.contains(',') || !_groupedIntegerPart.hasMatch(integer)) {
      // 中文：逗号不在分组位置上（或者根本没有）——不猜，原样交给调用点的
      //       `MathResult.decimalTextIsFinite` 判。
      // English: The comma is not in a grouping position (or there is none) — no guessing; hand it
      //          to `MathResult.decimalTextIsFinite` as it stands.
      return text;
    }
    return '${match.group(1)}${integer.replaceAll(',', '')}'
        '${match.group(3) ?? ''}${match.group(4) ?? ''}';
  }

  /// 中文：把科学计数法写成**应用自己的那一种拼法**——小写 `e`、指数带符号、无前导零。那是
  ///       `formatNumber` 印出来的样子（`1.071509e+301`，见 `number_formatter.dart` 的
  ///       `_trimScientific`），也是屏幕上一切别的数字的样子。引擎印的是
  ///       `1.148130695274255E602`（大写 `E`、没有 `+`），于是同一个显示区里出现两种写法：旧解析器
  ///       （经 `formatNumber`）一种，超出 double 量程、**原样显示引擎文本**的那一类结果另一种。
  ///
  ///       统一在这里、而不是改 `formatNumber`：`formatNumber` 是既有的那一种拼法，屏幕上绝大多数
  ///       数字都是它印的，改它等于为了迁就引擎去改所有别的东西。而这里是引擎文本变成应用文本的
  ///       那一个入口——边打边算与提交路径都从这里过，所以改一处两条路一起对上。
  ///
  ///       只改**拼法**，不动数值：`double.tryParse` 两种都认，[MathResult.decimalTextIsFinite]
  ///       两种都判为有限，写回表达式之后引擎也两种都认（`qalc` 5.12.0 实测：`…e+602`、`…E602`、
  ///       `…e602` 三种输入给出同一个结果）。整串不匹配科学计数法的形状时原样返回——这个函数
  ///       **绝不猜**，也绝不动别的东西。
  /// English: Spells a scientific number **the way this app spells it** — lowercase `e`, a signed
  ///          exponent, no leading zeros. That is what `formatNumber` prints (`1.071509e+301`; see
  ///          `_trimScientific` in `number_formatter.dart`) and what every other number on screen
  ///          looks like. The engine prints `1.148130695274255E602` (uppercase `E`, no `+`), so one
  ///          display region used to show two spellings: the legacy evaluator's through
  ///          `formatNumber`, and the one kind of result shown **verbatim from the engine** — the
  ///          values that do not fit a double.
  ///
  ///          Unifying here rather than in `formatNumber`: `formatNumber` owns the existing spelling
  ///          and prints the overwhelming majority of the numbers on screen, so changing it would
  ///          mean changing everything else to accommodate the engine. This, on the other hand, is
  ///          the entry point where the engine's text becomes the app's text — both the as-you-type
  ///          and submit paths go through it, so one change puts both in step.
  ///
  ///          Only the **spelling** changes, never the value: `double.tryParse` accepts either,
  ///          [MathResult.decimalTextIsFinite] calls either finite, and the engine accepts either
  ///          when it is written back into the expression (measured with `qalc` 5.12.0: `…e+602`,
  ///          `…E602` and `…e602` all produce the same result). A string that does not match the
  ///          scientific shape is returned untouched — this function **never guesses** and never
  ///          touches anything else.
  static String _appScientificSpelling(String text) {
    final match = _scientificNumber.firstMatch(text);
    if (match == null) return text;
    return '${match.group(1)}${match.group(2)}'
        'e${match.group(3) == '-' ? '-' : '+'}${match.group(5)}';
  }

  /// 中文：`[符号][有效数字][e/E][指数符号][指数前导零][指数数字]`。指数前导零单独成组，因为那正是
  ///       要被**丢掉**的部分，而不是被保留的部分。
  /// English: `[sign][significand][e/E][exponent sign][exponent leading zeros][exponent digits]`.
  ///          The leading zeros are a group of their own because that is exactly the part being
  ///          **dropped** rather than kept.
  static final RegExp _scientificNumber =
      RegExp(r'^([+-]?)(\d+(?:\.\d+)?)[eE]([+-]?)(0*)(\d+)$');

  /// 中文：`[符号][整数部分][小数部分][指数部分]`。整数部分允许逗号，因为要先看清它的形状。
  /// English: `[sign][integer part][fraction][exponent]`. The integer part may contain commas
  ///          because its shape has to be inspected first.
  static final RegExp _decimalParts =
      RegExp(r'^([+-]?)(\d[\d,]*)(\.\d+)?([eE][+-]?\d+)?$');

  /// 中文：千分位的形状：1–3 位开头，之后每组恰好 3 位。
  /// English: The shape of digit grouping: 1-3 leading digits, then groups of exactly three.
  static final RegExp _groupedIntegerPart = RegExp(r'^\d{1,3}(?:,\d{3})+$');
}
