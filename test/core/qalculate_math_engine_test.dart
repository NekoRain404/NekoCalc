import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/platform/qalculate_math_engine.dart';

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

  test('a decimal that overflows to infinity still parses, and is not finite',
      () async {
    respondWith((_) => <String, String>{
          'ok': 'true',
          'decimal': '1e400',
          'latex': r'1 \times 10^{400}',
        });

    final reply = await engine.evaluate('1e400', angleMode: 'RAD');

    // 中文：这一条与上一条必须能分开：`decimalValue` 不是 null，而是 `double.infinity`。判「有
    //       没有十进制形态」与判「是不是有限数」是两件事，提交路径两个都要判。
    // English: This case has to be distinguishable from the previous one: `decimalValue` is not
    //          null but `double.infinity`. "Is there a decimal form" and "is it finite" are two
    //          separate questions, and the submit path asks both.
    expect(reply.result!.decimalText, '1e400');
    expect(reply.result!.decimalValue, double.infinity);
    expect(reply.result!.decimalValue!.isFinite, isFalse);
  });
}
