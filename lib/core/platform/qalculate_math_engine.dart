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
        decimalText: MathResult.decimalTextIsFinite(decimal) ? decimal : '',
      ),
      messages: messages,
    );
  }

  /// 中文：Unicode 减号 → ASCII `-`、剥掉千分位、去首尾空白。这些脏东西都会让 `double.tryParse`
  ///       返回 null 而不抛异常——静默失败。
  ///
  ///       **逗号只在分组位置上才剥**，这是与「无条件剥逗号」的关键区别：逗号小数分隔符的语言环境
  ///       下，`5,656854` 里的逗号是**小数点**，无条件剥掉会把它变成 `5656854`——那不是 fail-closed，
  ///       是一个静默的错值。分组与小数点用形状就能分开：分组一定是「1–3 位开头，之后每组恰好 3 位」
  ///       （`1,234.5`），`5,656854` 不是这个形状，于是原样留着，`decimalTextOf` 判它不可解析，
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
  ///          `decimalTextOf` finds it unparseable, and this evaluation simply has no decimal form —
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
  static String _normalizeDecimal(String raw) {
    var text = raw
        .replaceAll('\u2212', '-')
        .replaceAll(RegExp('[\\u2009\\u00a0\\u202f]'), '')
        .trim();
    final match = _decimalParts.firstMatch(text);
    if (match == null) return text;
    final integer = match.group(2)!;
    if (!integer.contains(',') || !_groupedIntegerPart.hasMatch(integer)) {
      // 中文：逗号不在分组位置上（或者根本没有）——不猜，原样交给 `decimalTextOf` 判。
      // English: The comma is not in a grouping position (or there is none) — no guessing; hand it
      //          to `decimalTextOf` as it stands.
      return text;
    }
    return '${match.group(1)}${integer.replaceAll(',', '')}'
        '${match.group(3) ?? ''}${match.group(4) ?? ''}';
  }

  /// 中文：`[符号][整数部分][小数部分][指数部分]`。整数部分允许逗号，因为要先看清它的形状。
  /// English: `[sign][integer part][fraction][exponent]`. The integer part may contain commas
  ///          because its shape has to be inspected first.
  static final RegExp _decimalParts =
      RegExp(r'^([+-]?)(\d[\d,]*)(\.\d+)?([eE][+-]?\d+)?$');

  /// 中文：千分位的形状：1–3 位开头，之后每组恰好 3 位。
  /// English: The shape of digit grouping: 1-3 leading digits, then groups of exactly three.
  static final RegExp _groupedIntegerPart = RegExp(r'^\d{1,3}(?:,\d{3})+$');
}
