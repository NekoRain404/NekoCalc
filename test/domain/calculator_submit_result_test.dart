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

  test('a superseded submit is not a submission and does not ask for attention',
      () {
    // 中文：结果被更新的输入取代时，既没有计算结果可以展示，也没有历史可以保存——`submitted`
    //       为假、`needsAttention` 为假（屏幕上已经是更新那条边打边算的结果，不该再弹提示）。
    // English: When newer input overtook the result there is no calculation to show and no history
    //          to save — `submitted` is false and `needsAttention` is false (the newer as-you-type
    //          result is already on screen, so no banner belongs there).
    const superseded = CalculatorSubmitResult.superseded();

    expect(superseded.status, CalculatorSubmitStatus.superseded);
    expect(superseded.submitted, isFalse);
    expect(superseded.needsAttention, isFalse);
    expect(superseded.savedToHistory, isFalse);
    expect(superseded.result, isNull);
    expect(superseded.expression, isNull);
    expect(superseded.message, '输入已更新，本次计算结果未采用');
  });
}
