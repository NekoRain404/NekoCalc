import 'package:flutter/services.dart';

class BackupFileChannel {
  const BackupFileChannel._();

  static const _channel = MethodChannel('nekocalc/backup_file');

  static Future<bool> exportJson({
    required String fileName,
    required String content,
  }) async {
    final saved = await _channel.invokeMethod<bool>('exportJson', {
      'fileName': fileName,
      'content': content,
    });
    return saved ?? false;
  }

  static Future<String?> importJson() {
    return _channel.invokeMethod<String>('importJson');
  }
}
