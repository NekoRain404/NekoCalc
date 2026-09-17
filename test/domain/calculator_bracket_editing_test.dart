import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/application/controllers/expression_selection.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**函数键补出的右括号与「用户自己那一颗右括号」相遇时的两个缺陷**（真机实测）。
///
///       1. **`√x`、`8`、`)` 打出一条应用自己都读不懂的表达式。** 实测的按键流是
///          `sqrt()`（光标在括号里）→ `sqrt(8)`（光标在 `8` 右边）→ 再按 `)` 得到
///          `sqrt(8))`，`ExpressionParser` 抛 `Unexpected token at 7`，屏幕上是一句
///          「存在无法识别的内容」。**历史对比**：`b046b53` 之前 `√x` 只插 `sqrt(`（右括号
///          从来不出现），同样这三颗键得到的是 `sqrt(8)`——**同一串按键、不同的字符串**。
///          解析器一字未改（`Unexpected token` 从 `7c8e7b9` 起就在），变的是编辑器的产物。
///       2. **`√x` 之后按退格删不掉补出来的括号。** 光标停在 `sqrt(|)` 里，右边的 `)`
///          在退格的作用范围之外，一路删下去会停在光标 0、屏幕上留一个删不掉的 `)`。
///
///       本文件只钉这两条交互；求值那一侧一个字都没动——两条修法都发生在编辑层，判据是
///       **不把任何东西放宽给求值路径**（一条多余右括号被容忍下来，是让应用接受它自己
///       本该拒绝的输入；而「跳过」只移动光标，字符串一个字节都不变）。
///
/// English: **the two defects that meet when a function key's auto-written closing bracket meets
///          the user's own `)`** (measured on a device).
///
///          1. **`√x`, `8`, `)` produce an expression this app cannot read.** The measured keystroke
///             flow is `sqrt()` (caret inside) → `sqrt(8)` (caret right of the `8`) → another `)`
///             gives `sqrt(8))`; `ExpressionParser` throws `Unexpected token at 7` and the screen
///             shows 「存在无法识别的内容」. **The historical comparison**: before `b046b53` the `√x`
///             key inserted `sqrt(` alone (the bracket never appeared), so the same three keys gave
///             `sqrt(8)` — **same keystrokes, different string**. The parser never changed (the
///             `Unexpected token` check has been there since `7c8e7b9`); the editor's output did.
///          2. **After `√x`, backspace cannot remove the bracket that was written for it.** The
///             caret sits inside `sqrt(|)`, the `)` on its right is out of backspace's reach, and
///             deleting all the way stops at caret 0 with an undeletable `)` left on screen.
///
///          This file pins those two interactions only; nothing on the evaluation side changed —
///          both repairs live in the editing layer, on the criterion that **nothing is widened for
///          the evaluation path** (tolerating a redundant bracket teaches the app to accept input it
///          should refuse, while "skip over it" moves the caret and leaves the string byte-identical).
void main() {
  group('再按一次 `)` 跳过已经在那里的右括号', () {
    test('按 `√x`、`8`、`)`：表达式是 sqrt(8)，求值给出 2.828427', () {
      final controller = _controller(_FakeDatabase());

      controller.applyUnaryFunction('sqrt');
      expect(controller.expression, 'sqrt()');

      controller.input('8');
      expect(controller.expression, 'sqrt(8)');

      // 中文：这就是缺陷。修复前这里是 `sqrt(8))`——应用自己写出的括号，应用自己读不懂。
      // English: this is the defect. Before the fix this read `sqrt(8))` — a bracket the app wrote
      //          and the app cannot read.
      controller.input(')');
      expect(controller.expression, 'sqrt(8)');
      // 中文：光标移到了右括号**外面**——用户按完右括号，下一个字符该落在调用之后。
      // English: the caret moves **past** the bracket — after pressing `)` the next character
      //          belongs after the call.
      expect(controller.selection, const ExpressionSelection.collapsed(7));

      controller.evaluate();
      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.result, '2.828427');

      // 中文：光标在右括号外面，所以紧接着的 `+2` 落在调用之后而不是括号里面。
      // English: the caret is outside the bracket, so a following `+2` lands after the call rather
      //          than inside it.
      controller.input('+');
      controller.input('2');
      expect(controller.expression, 'sqrt(8)+2');
      controller.evaluate();
      expect(controller.result, '4.828427');

      controller.dispose();
    });

    test('光标右边没有右括号时，`)` 照旧写进去', () {
      final controller = _controller(_FakeDatabase());

      controller.input('(');
      controller.input('2');
      controller.input('+');
      controller.input('3');
      expect(controller.expression, '(2+3');

      controller.input(')');
      expect(controller.expression, '(2+3)');

      controller.evaluate();
      expect(controller.result, '5');

      controller.dispose();
    });

    test('光标右边那颗 `)` 已经闭合了它左边的组时，第一次按是「跨过去」，第二次才写', () {
      final controller = _controller(_FakeDatabase());

      // 中文：`(` 开的是外层组（`(` 键不补右括号），`√x` 在里面补出 `()`。此刻 `(sqrt()` 里
      //       只有**一颗**右括号，光标停在它前面。
      // English: `(` opens the outer group (the `(` key writes no bracket of its own) and `√x`
      //          writes `()` inside it. At this point `(sqrt()` holds **one** closing bracket and
      //          the caret sits just before it.
      controller.input('(');
      controller.applyUnaryFunction('sqrt');
      expect(controller.expression, '(sqrt()');
      expect(controller.selection, const ExpressionSelection.collapsed(6));

      // 中文：第一次 `)` 跨过它——**字符串一个字节都不变**，光标移到它外面。这不是丢按键：
      //       左边那颗 `)` 本来就已经闭合了紧挨着的组，跨过去之后光标右边再也没有括号，
      //       所以下一次 `)` 一定会写进去。代价是这里要按两次，换来的是「这个键永远写不出
      //       `sqrt(8))` 那种应用自己读不懂的东西」。
      // English: the first `)` steps over it — **not one byte of the string changes** — and the
      //          caret lands outside. No keystroke is lost: the bracket on the left already closes
      //          the group next to it, and once the caret is past it there is no bracket on the
      //          right, so the next `)` is bound to be written. The price is a second press here;
      //          what it buys is that this key can never write `sqrt(8))` — something the app
      //          itself cannot read.
      controller.input(')');
      expect(controller.expression, '(sqrt()');
      expect(controller.selection, const ExpressionSelection.collapsed(7));

      // 中文：第二次写进去，外层组由这一颗闭合。
      // English: the second press writes it, and the outer group is what it closes.
      controller.input(')');
      expect(controller.expression, '(sqrt())');
      expect(controller.selection, const ExpressionSelection.collapsed(8));

      controller.dispose();
    });

    test('跳过只动光标：表达式与结果都不变', () {
      final controller = _controller(_FakeDatabase());

      controller.setExpression('sqrt(8)');
      controller.setSelection(const ExpressionSelection.collapsed(6));
      controller.evaluate();
      final before = controller.result;

      controller.input(')');

      expect(controller.expression, 'sqrt(8)');
      expect(controller.selection, const ExpressionSelection.collapsed(7));
      expect(controller.result, before);

      controller.dispose();
    });
  });

  group('退格删得掉函数键补出来的括号', () {
    test('按 `√x` 之后按退格：整条 sqrt() 一起走，回到空表达式', () {
      final controller = _controller(_FakeDatabase());

      controller.applyUnaryFunction('sqrt');
      expect(controller.expression, 'sqrt()');
      expect(controller.selection, const ExpressionSelection.collapsed(5));

      // 中文：光标停在这对括号**里面**，右边的 `)` 在退格的作用范围之外。修复前这一下删的是
      //       `(`，得到 `sqrt)`；一路删下去会停在光标 0、屏幕上留一个删不掉的 `)`。
      // English: the caret sits **inside** the pair, so the `)` on its right is out of backspace's
      //          reach. Before the fix this removed the `(` and left `sqrt)`; deleting onwards
      //          stopped at caret 0 with an undeletable `)` on screen.
      controller.backspace();

      expect(controller.expression, isEmpty);
      expect(controller.selection, const ExpressionSelection.collapsed(0));
      expect(controller.hasError, isFalse);
      expect(controller.result, '0');

      // 中文：按错一颗键 = 退格一次，然后这个键盘照常可用。
      // English: pressing a key by mistake costs one backspace, and the keypad still works.
      controller.input('9');
      expect(controller.expression, '9');
      controller.evaluate();
      expect(controller.result, '9');

      controller.dispose();
    });

    test('按 `√x`、`8` 之后连按 25 次退格：表达式真的空了，不会卡在 `)` 上', () {
      final controller = _controller(_FakeDatabase());

      controller.applyUnaryFunction('sqrt');
      controller.input('8');
      expect(controller.expression, 'sqrt(8)');

      for (var i = 0; i < 25; i++) {
        controller.backspace();
      }

      // 中文：修复前 25 次退格之后表达式是 `)`、光标 0——`backspace()` 在光标 0 直接返回，
      //       那一颗右括号再也删不掉，唯一的出口是长按 AC（真机实测的形状）。
      // English: before the fix, 25 backspaces left the expression as `)` at caret 0 — `backspace()`
      //          returns immediately at caret 0, that bracket can never be removed, and the only
      //          way out is a long-press on AC (the shape measured on a device).
      expect(controller.expression, isEmpty);
      expect(controller.selection, const ExpressionSelection.collapsed(0));
      expect(controller.hasError, isFalse);

      controller.dispose();
    });

    test('二元键 `log` 补出的 `log(,)` 也一起走', () {
      final controller = _controller(_FakeDatabase());

      controller.applyBinaryFunction('log');
      expect(controller.expression, 'log(,)');

      controller.backspace();

      expect(controller.expression, isEmpty);
      expect(controller.selection, const ExpressionSelection.collapsed(0));

      controller.dispose();
    });

    test('实参已填的调用一次删一个字符，空了之后才整条走', () {
      final controller = _controller(_FakeDatabase());

      // 中文：光标停在 `8` 右边、右括号**里面**——这正是函数键留下的光标位置。
      // English: the caret sits right of the `8` and **inside** the bracket — exactly where the
      //          function key leaves it.
      controller.setExpression('sqrt(8)');
      controller.setSelection(const ExpressionSelection.collapsed(6));

      controller.backspace();
      expect(controller.expression, 'sqrt()');

      // 中文：实参空了，光标也在括号里——这一下删的是整个调用，而不是留下一根 `sqrt`。
      // English: the slot is empty and the caret is inside the pair — this press removes the whole
      //          call rather than leaving a bare `sqrt` behind.
      controller.backspace();
      expect(controller.expression, isEmpty);

      controller.dispose();
    });

    test('用户自己的括号不受影响：`(2+3)` 照旧一次删一个字符', () {
      final controller = _controller(_FakeDatabase());

      controller.setExpression('(2+3)');
      controller.backspace();
      expect(controller.expression, '(2+3');

      controller.setExpression('2×()');
      controller.setSelection(const ExpressionSelection.collapsed(3));
      controller.backspace();

      // 中文：没有名字可删，删的就是这一对括号本身（`2×` 与按 `√x` 之前的状态同型）。
      // English: there is no name to remove, so the pair itself goes (`2×` is the same shape as the
      //          state before a function key was pressed).
      expect(controller.expression, '2×');
      expect(controller.selection, const ExpressionSelection.collapsed(2));

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
      haptics: false,
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
