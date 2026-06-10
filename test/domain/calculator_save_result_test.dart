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
}
