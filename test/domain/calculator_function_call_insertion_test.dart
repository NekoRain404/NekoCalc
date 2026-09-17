import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/application/controllers/expression_selection.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：函数键插入文本的形状——**右括号**与光标落点。
///
///       单独立一个文件，是因为这几条测试钉的是 `_wrapTrailingValue` 的产物，
///       与「控制器求值」那一大类没有关系；`test/domain/calculator_controller_test.dart`
///       已经被其它工作改着，混进去只会让两边都难读。
/// English: The shape of what a function key inserts — its **closing bracket** and where the caret
///          lands. It lives in a file of its own because these tests pin the output of
///          `_wrapTrailingValue` and have nothing to do with the "controller evaluates" family;
///          `test/domain/calculator_controller_test.dart` is being changed by other work, and mixing
///          the two would only make both harder to read.
void main() {
  // 中文：右括号。以前 `_wrapTrailingValue` 在「空输入」与「光标停在 `(`/`,`/运算符之后」两条路上
  //       只插 `名字(`——右括号从来没出现过。用户接着输入实参，表达式里就永久留下 `sqrt(8`，而
  //       解析器**刻意**把未闭合的调用降级成字面文本（`_parseCall` 的 `_failure`），于是屏幕上
  //       显示灰色字母 `sqrt(8`、求值也永远是错的。真机复现路径就是「按 `√x`、再按 `8`」。
  // English: the closing bracket. `_wrapTrailingValue` used to insert only `name(` on two routes —
  //          an empty input, and a caret sitting after `(`/`,`/an operator — so the bracket never
  //          appeared. Whatever the user typed next left `sqrt(8` in the expression for good, and
  //          the parser **deliberately** degrades an unclosed call to literal text (`_parseCall`'s
  //          `_failure`), so the screen showed a grey `sqrt(8` in letters and the value stayed
  //          wrong. The device reproduction is "press `√x`, then `8`".
  group('函数调用的右括号与光标位置', () {
    test('空输入上按一元函数：补出整对括号，光标落在括号里', () {
      final controller = _controller(_FakeDatabase());

      controller.applyUnaryFunction('sqrt');

      expect(controller.expression, 'sqrt()');
      expect(controller.selection, const ExpressionSelection.collapsed(5));

      // 中文：接着按 `8` 得到的是**完整**的 `sqrt(8)`——这一条就是真机上那个缺陷的反面。
      // English: pressing `8` next produces a **complete** `sqrt(8)` — the exact opposite of the
      //          defect found on the device.
      controller.input('8');
      expect(controller.expression, 'sqrt(8)');
      controller.evaluate();
      expect(controller.result, '2.828427');

      controller.dispose();
    });

    test('光标停在运算符后：同样补出整对括号', () {
      final controller = _controller(_FakeDatabase());

      controller.setExpression('2+');
      controller.applyUnaryFunction('sqrt');

      expect(controller.expression, '2+sqrt()');
      expect(controller.selection, const ExpressionSelection.collapsed(7));

      controller.input('9');
      controller.evaluate();
      expect(controller.expression, '2+sqrt(9)');
      expect(controller.result, '5');

      controller.dispose();
    });

    test('左侧有值时一元调用与改动前逐字节相同（括号本来就补）', () {
      final controller = _controller(_FakeDatabase());

      controller.setExpression('8');
      controller.applyUnaryFunction('sqrt');

      expect(controller.expression, 'sqrt(8)');
      // 中文：实参已经填好，没有空槽——光标留在调用之后，与改动前一致。
      // English: the argument is already filled, so there is no empty slot and the caret stays
      //          after the call, exactly as before.
      expect(controller.selection, const ExpressionSelection.collapsed(7));

      controller.dispose();
    });

    test('空输入上按二元函数：补出 `(,)`，光标落在第一个空槽', () {
      final controller = _controller(_FakeDatabase());

      controller.applyBinaryFunction('log');

      expect(controller.expression, 'log(,)');
      expect(controller.selection, const ExpressionSelection.collapsed(4));

      controller.input('8');
      expect(controller.expression, 'log(8,)');

      controller.dispose();
    });

    test('二元函数套住左侧的值：补出 `,)`，光标落在逗号右边', () {
      final controller = _controller(_FakeDatabase());

      controller.setExpression('8');
      controller.applyBinaryFunction('log');

      expect(controller.expression, 'log(8,)');
      expect(controller.selection, const ExpressionSelection.collapsed(6));

      // 中文：光标在逗号右边，所以下一个字符正好落在第二个实参的位置上：`log(8,2)`。
      // English: the caret sits right of the comma, so the next character lands in the second
      //          argument's slot: `log(8,2)`.
      controller.input('2');
      expect(controller.expression, 'log(8,2)');
      controller.evaluate();
      expect(controller.result, '3');

      controller.dispose();
    });
  });

}

CalculatorController _controller(_FakeDatabase db) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
  );
}

class _FakeDatabase implements AppDatabase {
  final savedSettings = <String, String>{};

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(savedSettings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
