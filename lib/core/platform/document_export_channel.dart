import 'package:flutter/services.dart';

class DocumentExportChannel {
  const DocumentExportChannel._();

  static const _channel = MethodChannel('nekocalc/document_export');

  static Future<bool> exportBytes({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final saved = await _channel.invokeMethod<bool>('exportBytes', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return saved ?? false;
  }
}
