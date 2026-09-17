import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';

void main() {
  test('calculator save note result exposes status messages', () {
    final saved = CalculatorSaveNoteResult.saved(42);
    expect(saved.saved, isTrue);
    expect(saved.noteId, 42);
    expect(saved.message, '已保存到笔记');

    const empty = CalculatorSaveNoteResult.emptyExpression();
    expect(empty.saved, isFalse);
    expect(empty.status, CalculatorSaveNoteStatus.emptyExpression);
    expect(empty.message, '请输入有效表达式后再保存');

    final invalid = CalculatorSaveNoteResult.invalidExpression('缺少右括号');
    expect(invalid.status, CalculatorSaveNoteStatus.invalidExpression);
    expect(invalid.message, '表达式需要修正：缺少右括号');

    const notWritten = CalculatorSaveNoteResult.notWritten();
    expect(notWritten.status, CalculatorSaveNoteStatus.notWritten);
    expect(notWritten.message, '笔记没有写入，请重试');
  });

  // 中文：保存在引擎往返期间被更新的输入取代时走这一条：结果没有落地，笔记也没有写。它是一条独立
  //       的状态而不是复用「没有写入」，因为原因不同——用户该做的是再按一次，而「为什么这一次没写」
  //       不该被一个刚好也说得通的文案掩盖过去。
  // English: This is the case where a save is overtaken by newer input during the engine round trip:
  //          the result did not land and no note was written. It is its own status rather than a reuse
  //          of "not written", because the cause differs — pressing the button again is what the user
  //          should do, and "why this attempt wrote nothing" should not be papered over with a message
  //          that happens to also be true.
  test('a superseded save writes nothing and says so', () {
    const superseded = CalculatorSaveNoteResult.superseded();
    expect(superseded.saved, isFalse);
    expect(superseded.status, CalculatorSaveNoteStatus.superseded);
    expect(superseded.noteId, isNull);
    expect(superseded.message, isNotEmpty);
  });
}
