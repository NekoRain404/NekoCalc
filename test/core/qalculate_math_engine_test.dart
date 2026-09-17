import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/platform/qalculate_math_engine.dart';
import 'package:nekocalc/core/utils/number_formatter.dart';

/// 中文：`QalculateMathEngine`（把平台通道包成 `MathEngine` 的那一层）的测试。全部用假的通道
///       回执跑，不需要设备、不需要引擎。
///
/// English: Tests for `QalculateMathEngine` — the layer that wraps the platform channel as a
///          `MathEngine`. Everything runs against fake channel receipts; no device, no engine.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/qalculate');
  const engine = QalculateMathEngine();

  void respondWith(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a successful receipt onto the three forms', () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '5.6568542',
          'latex': r'4 \cdot \sqrt{2}',
          'aborted': 'false',
          'messages': 'note',
        });

    final reply = await engine.evaluate('sqrt(32)', angleMode: 'RAD');

    expect(reply.ok, isTrue);
    expect(reply.error, isNull);
    expect(reply.aborted, isFalse);
    expect(reply.messages, 'note');
    final result = reply.result;
    expect(result, isNotNull);
    expect(result!.displayText, '5.6568542');
    expect(result.decimalText, '5.6568542');
    expect(result.displayTex, r'4 \cdot \sqrt{2}');
    expect(result.decimalValue, 5.6568542);
  });

  test('sends the angle mode the caller asked for', () async {
    MethodCall? capturedCall;
    respondWith((call) {
      capturedCall = call;
      return <String, String>{'ok': 'true', 'decimal': '1', 'latex': '1'};
    });

    await engine.evaluate('sin(30)', angleMode: 'DEG');
    expect(capturedCall?.method, 'evaluate');
    expect(capturedCall?.arguments, {
      'expression': 'sin(30)',
      'angleMode': 'DEG',
    });

    await engine.evaluate('sin(30)', angleMode: 'RAD');
    expect(capturedCall?.arguments, {
      'expression': 'sin(30)',
      'angleMode': 'RAD',
    });
  });

  test('reports ok:false without throwing when the engine failed', () async {
    respondWith((_) => <String, String>{
          'ok': 'false',
          'error': 'division by zero',
          'messages': 'Division by zero.',
        });

    final reply = await engine.evaluate('1/0', angleMode: 'RAD');

    expect(reply.ok, isFalse);
    expect(reply.result, isNull);
    expect(reply.error, contains('division by zero'));
    expect(reply.messages, 'Division by zero.');
  });

  test('turns a PlatformException into a failure receipt', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
          code: 'invalid_angle_mode', message: '缺少 angleMode 参数');
    });

    final reply = await engine.evaluate('sqrt(32)', angleMode: 'RAD');

    expect(reply.ok, isFalse);
    expect(reply.result, isNull);
    expect(reply.error, contains('invalid_angle_mode'));
  });

  test('turns a MissingPluginException into a failure receipt', () async {
    // 中文：一个 handler 都不注册——这就是桌面与 `flutter test` 的常态：没有原生侧，通道抛
    //       MissingPluginException。引擎必须把它变成一条回执，而不是让异常冒到提交路径上。
    // English: No handler is registered at all — the normal state on desktop and under
    //          `flutter test`: there is no native side and the channel throws
    //          MissingPluginException. The engine has to turn that into a receipt rather than
    //          letting the exception reach the submit path.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    final reply = await engine.evaluate('sqrt(32)', angleMode: 'RAD');

    expect(reply.ok, isFalse);
    expect(reply.result, isNull);
    expect(reply.error, contains('missing_plugin'));
  });

  test('refuses an aborted evaluation', () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '5.6568542',
          'latex': r'4 \cdot \sqrt{2}',
          'aborted': 'true',
        });

    final reply = await engine.evaluate('sqrt(32)', angleMode: 'RAD');

    // 中文：被中止的求值按定义是不完整的，不能当成答案。
    // English: An aborted evaluation is by definition incomplete and cannot count as an answer.
    expect(reply.ok, isFalse);
    expect(reply.aborted, isTrue);
    expect(reply.result, isNull);
  });

  test('refuses a receipt with no decimal at all', () async {
    respondWith((_) => <String, String>{'ok': 'true', 'latex': r'\pi'});

    final reply = await engine.evaluate('pi', angleMode: 'RAD');

    expect(reply.ok, isFalse);
    expect(reply.error, contains('engine_no_decimal'));
  });

  test('normalizes a grouped decimal with a Unicode minus before building it',
      () async {
    // 中文：原生侧的 `PrintOptions` 带 `setDigit_grouping` 与 `setUse_unicode_signs`，所以
    //       `5,656.854` 或 `−5.6`（U+2212）是「一个配置项之外」就能出现的真实形状。
    //       `double.tryParse` 对这两种输入都返回 null 而**不抛异常**——记忆寄存器会静默加 0、
    //       Ans/last 会静默失效。所以十进制形态必须在被构造的那一刻就是干净的。
    // English: The native `PrintOptions` carry `setDigit_grouping` and `setUse_unicode_signs`, so
    //          `5,656.854` and `−5.6` (U+2212) are real shapes that are one configuration option
    //          away. `double.tryParse` returns null for both *without throwing* — the memory
    //          register would silently add 0 and Ans/last would silently stop resolving. So the
    //          decimal form has to be clean the moment it is constructed.
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': ' 5,656.854 ',
          'latex': r'4 \cdot \sqrt{2}',
        });

    final grouped = await engine.evaluate('sqrt(32)', angleMode: 'RAD');
    expect(grouped.result!.decimalText, '5656.854');
    expect(grouped.result!.decimalValue, isNotNull);
    expect(grouped.result!.decimalValue, 5656.854);

    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '−5.6',
          'latex': '-5.6',
        });

    final unicodeMinus = await engine.evaluate('0-5.6', angleMode: 'RAD');
    expect(unicodeMinus.result!.decimalText, '-5.6');
    expect(unicodeMinus.result!.decimalValue, isNotNull);
    expect(unicodeMinus.result!.decimalValue, -5.6);

    // 中文：本地化分组用的空格（这里是 U+2009 薄空格）也是分隔符。用 `fromCharCode` 构造而不是
    //       写进源码：那类字符在编辑器里看不见，摆在字符串里没人能复查。
    // English: The space characters used by localised grouping (U+2009 thin space here) are
    //          separators too. Built with `fromCharCode` rather than written into the source: those
    //          characters are invisible in an editor and cannot be reviewed inside a literal.
    final thinSpace = String.fromCharCode(0x2009);
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1${thinSpace}234.5',
          'latex': '1234.5',
        });

    final spaced = await engine.evaluate('1234.5', angleMode: 'RAD');
    expect(spaced.result!.decimalText, '1234.5');
    expect(spaced.result!.decimalValue, 1234.5);
  });

  test(
      'a decimal that is not a number keeps its display form and no decimal form',
      () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1 m',
          'latex': r'1\ \mathrm{m}',
        });

    final reply = await engine.evaluate('1 m', angleMode: 'RAD');

    // 中文：`1 m` 算不出数字，但它是引擎给出的显示形态；十进制形态留空表示「这一次没有可解析
    //       的十进制表示」，调用方必须照常工作——而不是解析失败后静默取 0。
    // English: `1 m` does not yield a number, but it is the display form the engine produced; the
    //          decimal form stays empty, meaning "no parseable decimal this time". Callers have to
    //          keep working — rather than silently taking 0 after a failed parse.
    expect(reply.ok, isTrue);
    expect(reply.result!.displayText, '1 m');
    expect(reply.result!.decimalText, isEmpty);
    expect(reply.result!.decimalValue, isNull);
    expect(reply.result!.displayTex, r'1\ \mathrm{m}');
  });

  test('a decimal Dart cannot parse ends up with no decimal form', () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': 'infinity',
          'latex': r'\infty',
        });

    final reply = await engine.evaluate('1/0', angleMode: 'RAD');

    // 中文：Dart 只认 `Infinity` 这个写法，小写的 `infinity`（libqalculate 印出来的就是它）会被
    //       `tryParse` 拒绝：返回 null，不抛异常。于是它落进「没有十进制形态」，而不是一个假装
    //       是数字的东西——提交路径据此回落到旧解析器，`1/0` 于是仍然是今天那条错误。
    // English: Dart only accepts `Infinity`; the lowercase `infinity` that libqalculate prints is
    //          rejected by `tryParse`, which returns null without throwing. It therefore lands in
    //          "no decimal form" rather than pretending to be a number — the submit path falls
    //          back on that, keeping `1/0` on today's error.
    expect(reply.ok, isTrue);
    expect(reply.result!.displayText, 'infinity');
    expect(reply.result!.decimalText, isEmpty);
    expect(reply.result!.decimalValue, isNull);
  });

  test('a finite decimal beyond the double range stays finite, with no value',
      () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1e400',
          'latex': r'1 \times 10^{400}',
        });

    final reply = await engine.evaluate('1e400', angleMode: 'RAD');

    // 中文：这一条与上一条必须能分开。`1e400` 是一个**有限数**（只是超出 double 上限），所以
    //       `hasFiniteDecimal` 为真——提交路径据此采用它、照常显示；而需要 double 的消费者拿到
    //       null，于是显式处理「这一次存不下」，绝不会拿到 `Infinity`。
    // English: This case has to be distinguishable from the previous one. `1e400` is a *finite*
    //          number (it merely exceeds a double), so `hasFiniteDecimal` is true — which is what
    //          lets the submit path take it and display it — while consumers that need a double get
    //          null, so they handle "cannot store this" explicitly and never receive `Infinity`.
    //
    // 中文：**这一条改了期望值**，因为适配层现在把指数写成应用自己的拼法（`1e400` → `1e+400`：
    //       小写 `e`、带符号、无前导零），好让引擎这一路与旧求值器经 `formatNumber` 印出来的
    //       `1.071509e+301` 在同一个显示区里长得一样。判的东西一个没动：仍然是「有限、但没有
    //       double 值」。
    // English: **This expectation changed.** The adapter now spells the exponent the way the app
    //          does (`1e400` → `1e+400`: lowercase `e`, signed, no leading zeros) so that the engine
    //          path and the `1.071509e+301` the legacy evaluator prints through `formatNumber` look
    //          the same in one display region. What is being judged is untouched: still "finite, but
    //          with no double value".
    expect(reply.result!.decimalText, '1e+400');
    expect(reply.result!.hasFiniteDecimal, isTrue);
    expect(reply.result!.decimalValue, isNull);
  });

  test('a comma that is not a grouping separator is not stripped', () async {
    // 中文：逗号小数分隔符的语言环境下 `5,656854` 里的逗号是**小数点**，无条件剥掉会得到
    //       `5656854`——一个静默的错值。原生侧已由 `useDecimalPoint(true)` 把小数点钉成 `.`，
    //       这里是第二道：形状不像千分位就不剥，判不出来就没有十进制形态（fail-closed）。
    // English: Under a comma-decimal locale the comma in `5,656854` *is the decimal point*, and
    //          stripping it yields `5656854` — a silently wrong value. The native side already pins
    //          the point to `.` via `useDecimalPoint(true)`; this is the second layer: a shape that
    //          does not look like grouping is left alone, and something unreadable ends up with no
    //          decimal form (fail-closed).
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '5,656854',
          'latex': '5.656854',
        });

    final commaDecimal = await engine.evaluate('sqrt(32)', angleMode: 'RAD');
    expect(commaDecimal.result!.decimalText, isEmpty);
    expect(commaDecimal.result!.decimalValue, isNull);
    expect(commaDecimal.result!.displayText, '5,656854',
        reason: 'the display form the engine gave is kept as it is');

    // 中文：像千分位的照旧剥；指数部分不受影响。
    // English: What does look like grouping is still stripped, and exponents are untouched.
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1,234.5e-3',
          'latex': '1.2345',
        });

    final grouped = await engine.evaluate('1.2345', angleMode: 'RAD');
    expect(grouped.result!.decimalText, '1234.5e-3');
    expect(grouped.result!.decimalValue, 1.2345);
  });

  test('把指数写成应用自己的那一种拼法', () async {
    // 中文：引擎印的是 `1.148130695274255E602`（大写 `E`、没有 `+`；真机实测），而旧求值器经
    //       `formatNumber` 印的是 `1.071509e+301`（小写 `e`、带 `+`）。同一个显示区里两种写法，
    //       这里统一成 `formatNumber` 那一种——它印的是屏幕上绝大多数数字。
    //
    //       只改拼法：数值、有限性判定、`decimalValue` 全都一字不动。
    // English: The engine prints `1.148130695274255E602` (uppercase `E`, no `+`; measured on a real
    //          device) while the legacy evaluator prints `1.071509e+301` through `formatNumber`
    //          (lowercase `e`, signed). One display region, two spellings; this unifies on
    //          `formatNumber`'s, which prints the overwhelming majority of the numbers on screen.
    //
    //          Only the spelling moves: the value, the finiteness judgement and `decimalValue` are
    //          untouched.
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1.148130695274255E602',
          'latex': r'\num{1.148130695274255e602}',
        });

    final huge = await engine.evaluate('2^2000', angleMode: 'RAD');
    expect(huge.result!.displayText, '1.148130695274255e+602');
    expect(huge.result!.decimalText, '1.148130695274255e+602');
    expect(huge.result!.hasFiniteDecimal, isTrue);
    expect(huge.result!.decimalValue, isNull);

    // 中文：**两条路印出来的必须是同一个写法**，这条断言就是那句「统一」本身：一个来自 double
    //       （旧求值器那条路），一个来自引擎文本（这一层）。
    // English: **Both paths must print the same spelling**, and this assertion is that sentence: one
    //          comes from a double (the legacy route), the other from the engine's text (this layer).
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1.5E301',
          'latex': r'\num{1.5e301}',
        });
    final sameMagnitude = await engine.evaluate('1.5e301', angleMode: 'RAD');
    expect(sameMagnitude.result!.decimalText, formatNumber(1.5e301),
        reason: '引擎文本与 formatNumber 必须印成同一个样子');

    // 中文：负指数同样带符号；已经不是科学计数法的文本一个字都不许动。
    // English: a negative exponent is signed too, and text that is not scientific notation is not
    //          touched at all.
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '-8.709809816217217E-603',
          'latex': '-8.709809816217217e-603',
        });
    final tiny = await engine.evaluate('2^-2000', angleMode: 'RAD');
    expect(tiny.result!.decimalText, '-8.709809816217217e-603');

    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '5.656854249492380',
          'latex': r'4\times \sqrt{2}',
        });
    final plain = await engine.evaluate('sqrt(32)', angleMode: 'RAD');
    expect(plain.result!.decimalText, '5.656854249492380');
    expect(plain.result!.displayText, '5.656854249492380');
  });

  test('maps the native kind strings onto EngineResultKind, unit_mismatch included', () async {
    // 中文：`kind` 的取值是**原生侧写、这里读**的一份契约（`QalculateEngine.KIND_*`），所以五个
    //       取值逐个走一遍。`unit_mismatch` 是这一步新增的那一个：原生侧判出「用户要的换算没发生」
    //       （`conversionLanded`），Dart 侧把它归到「不显示」那一支。认不出的取值仍然落回
    //       `arithmetic`（不显示）——版本不匹配时整个 tier 2 退回放宽之前的行为。
    // English: the `kind` values are a contract written on the native side and read here
    //          (`QalculateEngine.KIND_*`), so all five go through one by one. `unit_mismatch` is the one
    //          this step adds: the native side judges "the conversion the user asked for did not
    //          happen" (`conversionLanded`) and Dart files it under "do not display". An unrecognised
    //          value still falls back to `arithmetic` (do not display), so a version mismatch returns
    //          tier 2 to the behaviour from before the relaxation.
    Future<EngineResultKind> kindOf(String nativeKind) async {
      respondWith((_) => <String, String>{
            'ok': 'true',
            'decimal': '3.106855961186670 mi',
            'latex': r'\qty{3.106855961186670}{mi}',
            'kind': nativeKind,
          });
      final reply = await engine.evaluate('5 km to mi', angleMode: 'RAD');
      return reply.result!.resultKind;
    }

    expect(await kindOf('conversion'), EngineResultKind.conversion);
    expect(await kindOf('unit_mismatch'), EngineResultKind.unitMismatch);
    expect(await kindOf('quantity'), EngineResultKind.quantity);
    expect(await kindOf('unit'), EngineResultKind.unit);
    expect(await kindOf('structured'), EngineResultKind.structured);
    expect(await kindOf('number'), EngineResultKind.number);
    expect(await kindOf('arithmetic'), EngineResultKind.arithmetic);
    expect(await kindOf('something_new'), EngineResultKind.arithmetic);
  });
}
