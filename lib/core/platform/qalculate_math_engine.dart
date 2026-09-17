import 'package:flutter/services.dart';

import '../math/math_engine.dart';
import '../math/math_result.dart';
import 'qalculate_channel.dart';

/// 中文：把 [QalculateChannel] 包成 [MathEngine]。这一层只做三件事：
///
///       1. **把异常吃掉**。通道在原生侧缺席时抛 [MissingPluginException]、原生侧用
///          `result.error` 回复时抛 [PlatformException]，两者都变成一条 `ok: false` 的回执。
///          引擎是新增能力，不是新的故障点，所以任何失败都必须能在这里停下来。
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
///             and not a new failure point, so every failure has to stop here.
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
        // 中文：`decimalTextOf` 是「显示文本 → 十进制形态」在全应用唯一的定义处，这里正好用它：
        //       洗干净的 decimal 是可解析的，就进十进制形态；不可解析（例如带单位的结果）就留空，
        //       表示「这一次没有十进制形态」，数值消费者据此不再解析，而不是解析失败后静默取 0。
        // English: `decimalTextOf` is the app's one definition of "display text → decimal form", and
        //          it is the right tool here: a washed decimal that parses becomes the decimal form;
        //          one that does not (a result carrying a unit, say) leaves it empty, meaning "no
        //          decimal form this time" so numeric consumers stop rather than silently taking 0.
        decimalText: MathResult.decimalTextOf(decimal),
      ),
      messages: messages,
    );
  }

  /// 中文：Unicode 减号 → ASCII `-`、剥掉千分位（逗号与三种作分隔用的空格）、去首尾空白。
  ///       这三种脏东西都会让 `double.tryParse` 返回 null 而不抛异常——静默失败。
  ///
  ///       分隔符一律写成转义而不是字面量：U+2009 / U+00A0 / U+202F 在源码里是**看不见的**，
  ///       放进字符类里读不出来也查不出来；ASCII 逗号只是 libqalculate 默认的那一种。
  /// English: Unicode minus to ASCII `-`, grouping separators stripped (commas and the three space
  ///          characters used as separators), surrounding whitespace trimmed. All three make
  ///          `double.tryParse` return null without throwing — a silent failure.
  ///
  ///          The separators are escaped rather than literal: U+2009 / U+00A0 / U+202F are
  ///          *invisible* in source, so a literal character class cannot be read or reviewed, and
  ///          the ASCII comma is only the one libqalculate uses by default.
  static String _normalizeDecimal(String raw) {
    return raw
        .replaceAll('\u2212', '-')
        .replaceAll(RegExp('[,\\u2009\\u00a0\\u202f]'), '')
        .trim();
  }
}
