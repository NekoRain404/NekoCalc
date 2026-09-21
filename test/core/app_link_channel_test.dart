import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/platform/app_link_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/app_link');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('opens an external URL through the app link platform channel', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return true;
    });

    final opened = await const AppLinkChannel().openExternalUrl(
      'https://github.com/NekoRain404/NekoCalc/issues/new/choose',
    );

    expect(opened, isTrue);
    expect(capturedCall?.method, 'openUrl');
    expect(capturedCall?.arguments, {
      'url': 'https://github.com/NekoRain404/NekoCalc/issues/new/choose',
    });
  });
}
