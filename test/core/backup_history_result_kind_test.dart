import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';

/// 中文：**老备份照收。** `result_kind` 是 v7 才有的列，v6 及更早导出的备份里没有它。
///       校验器把它当**可选**，导入时由 `_normalizeHistoryRow` 按分类器补——这条测试钉住
///       "缺列的老备份仍然合法"，否则升级会把用户手里所有旧备份判成坏文件。
/// English: **old backups still import.** `result_kind` only exists from v7, so a backup exported on
///          v6 or earlier has no such column. The validator treats it as **optional** and import fills
///          it via `_normalizeHistoryRow`; this test pins "a column-less old backup is still valid",
///          without which the upgrade would call every old backup in a user's hands a corrupt file.
void main() {
  Map<String, Object?> snapshotWith(Map<String, Object?> historyRow) {
    return {
      'schema': backupSchemaVersion,
      'exported_at': '2026-05-26T09:00:00.000',
      'metadata': {'app_version': 'v1.1.0'},
      'tables': {
        'calculation_history': [historyRow],
        'notes': <Object?>[],
        'favorite_tools': <Object?>[],
        'recent_tools': <Object?>[],
        'app_settings': <Object?>[],
      },
    };
  }

  Map<String, Object?> baseRow() => {
        'id': 1,
        'expression': '2+3',
        'result': '5',
        'tool_id': null,
        'created_at': 1001,
      };

  test('v6 老备份：calculation_history 行里没有 result_kind 也合法', () {
    final snapshot = snapshotWith(baseRow());
    expect(() => validateBackupSnapshot(snapshot), returnsNormally);
  });

  test('带上 result_kind 也合法（它是可选文本）', () {
    final snapshot = snapshotWith({...baseRow(), 'result_kind': 'tool'});
    expect(() => validateBackupSnapshot(snapshot), returnsNormally);
  });

  test('result_kind 不是字符串时拒绝（与其余文本列同一口径）', () {
    final snapshot = snapshotWith({...baseRow(), 'result_kind': 7});
    expect(() => validateBackupSnapshot(snapshot), throwsFormatException);
  });

  test('走完整解析路径：老备份的 JSON 文本照收', () {
    final source = jsonEncode(snapshotWith(baseRow()));
    expect(() => parseBackupSnapshot(source), returnsNormally);
  });
}
