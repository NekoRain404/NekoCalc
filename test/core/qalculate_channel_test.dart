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

  test('evaluates an expression through the qalculate platform channel', () async {
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

    final result = await const QalculateChannel().evaluate('sqrt(32)');

    expect(capturedCall?.method, 'evaluate');
    expect(capturedCall?.arguments, {'expression': 'sqrt(32)'});
    expect(result['ok'], 'true');
    expect(result['decimal'], '5.6568542');
    expect(result['latex'], r'4 \cdot \sqrt{2}');
  });

  test('yields an empty map rather than null when the engine reports nothing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final result = await const QalculateChannel().evaluate('sqrt(32)');

    expect(result, isEmpty);
  });
}
