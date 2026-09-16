import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';

void main() {
  group('KeypadDefinition 完整性', () {
    test('标签行与主键行等长', () {
      for (final row in hiperKeypad.rows) {
        expect(row.labels.length, row.keys.length,
            reason: '每一行都必须为每个键留出标签位（无标签时为 null）');
      }
    });

    test('键的 id 全局唯一', () {
      final ids = <String>[];
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          ids.add(k.base.id);
          if (k.shift != null) ids.add(k.shift!.id);
          if (k.hyp != null) ids.add(k.hyp!.id);
        }
      }
      final dup =
          ids.where((id) => ids.where((x) => x == id).length > 1).toSet();
      expect(dup, isEmpty, reason: '重复的键 id 会让 action 分派产生歧义: $dup');
    });

    test('禁用的键必须属于 disabled 分类', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (!k.base.enabled) {
            expect(k.category, KeyCategory.disabled,
                reason: '${k.base.id} 未启用却不是 disabled 分类');
          }
        }
      }
    });

    test('未禁用的键必须有非空 id 与 label', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (k.base.enabled) {
            expect(k.base.id, isNotEmpty);
            expect(k.base.label, isNotEmpty);
          }
        }
      }
    });

    test('SHIFT 变体存在时其 id 不得与基准 id 相同', () {
      for (final row in hiperKeypad.rows) {
        for (final k in row.keys) {
          if (k.shift != null) {
            expect(k.shift!.id, isNot(k.base.id),
                reason: '${k.base.id} 的 SHIFT 变体没有独立行为，应改为 null');
          }
        }
      }
    });
  });

  group('HiPER 网格形状', () {
    test('共 17 行：9 个主键行 + 8 个标签行交替', () {
      expect(hiperKeypad.rows.length, 17);
    });

    test('数字键与四则运算符永远在位', () {
      final all =
          hiperKeypad.rows.expand((r) => r.keys).map((k) => k.base.id).toSet();
      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(all, contains(d), reason: '数字键 $d 必须存在');
      }
      for (final op in ['+', '-', '*', '/']) {
        expect(all, contains(op), reason: '运算符 $op 必须存在');
      }
    });

    test('破坏性键分类正确', () {
      final destructive = hiperKeypad.rows
          .expand((r) => r.keys)
          .where((k) => k.category == KeyCategory.destructive)
          .map((k) => k.base.id)
          .toSet();
      expect(destructive, {'backspace', 'clear'});
    });
  });
}
