import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_submit_result.dart';

void main() {
  test('calculator submit result exposes calculation and history statuses', () {
    const empty = CalculatorSubmitResult.emptyExpression();
    expect(empty.submitted, isFalse);
    expect(empty.needsAttention, isTrue);
    expect(empty.message, '请输入表达式后再计算');

    final invalid = CalculatorSubmitResult.invalidExpression('缺少右括号');
    expect(invalid.submitted, isFalse);
    expect(invalid.status, CalculatorSubmitStatus.invalidExpression);
    expect(invalid.message, '表达式需要修正：缺少右括号');

    const calculated = CalculatorSubmitResult.calculated(
      expression: '1+2',
      result: '3',
    );
    expect(calculated.submitted, isTrue);
    expect(calculated.savedToHistory, isFalse);
    expect(calculated.needsAttention, isFalse);

    const saved = CalculatorSubmitResult.historySaved(
      expression: '6×7',
      result: '42',
      historyId: 7,
    );
    expect(saved.savedToHistory, isTrue);
    expect(saved.historyId, 7);
    expect(saved.message, '已计算并保存到历史');

    const duplicate = CalculatorSubmitResult.historySkippedDuplicate(
      expression: '6*7',
      result: '42',
    );
    expect(duplicate.submitted, isTrue);
    expect(duplicate.needsAttention, isFalse);
    expect(duplicate.message, '已计算，重复历史已跳过');
  });
}
