import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/platform/qalculate_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/qalculate');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('evaluates an expression through the qalculate platform channel',
      () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return <String, String>{
        'ok': 'true',
        'decimal': '5.6568542',
        'latex': r'4 \cdot \sqrt{2}',
      };
    });

    final result =
        await const QalculateChannel().evaluate('sqrt(32)', angleMode: 'RAD');

    expect(capturedCall?.method, 'evaluate');
    // 中文：角度模式必须和表达式一起过通道——原生侧的角度单位只从这条参数来。
    // English: The angle mode crosses the channel with the expression; the native side's angle
    //          unit comes from this argument and nowhere else.
    expect(capturedCall?.arguments, {
      'expression': 'sqrt(32)',
      'angleMode': 'RAD',
    });
    expect(result['ok'], 'true');
    expect(result['decimal'], '5.6568542');
    expect(result['latex'], r'4 \cdot \sqrt{2}');
  });

  test('sends the degree mode itself, not a translated value', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return <String, String>{'ok': 'true', 'decimal': '1', 'latex': '1'};
    });

    await const QalculateChannel().evaluate('sin(90)', angleMode: 'DEG');

    expect(capturedCall?.arguments, {
      'expression': 'sin(90)',
      'angleMode': 'DEG',
    });
  });

  test('yields an empty map rather than null when the engine reports nothing',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final result =
        await const QalculateChannel().evaluate('sqrt(32)', angleMode: 'RAD');

    expect(result, isEmpty);
  });
}
