import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/platform/document_export_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/document_export');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends file metadata and binary content to the export channel',
      () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return true;
    });

    final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    final saved = await DocumentExportChannel.exportBytes(
      fileName: 'graph.png',
      mimeType: 'image/png',
      bytes: bytes,
    );

    expect(saved, isTrue);
    expect(capturedCall?.method, 'exportBytes');
    expect(capturedCall?.arguments, {
      'fileName': 'graph.png',
      'mimeType': 'image/png',
      'bytes': bytes,
    });
  });
}
