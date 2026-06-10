import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/tool_save_result.dart';

void main() {
  test('tool save result exposes target status and messages', () {
    final history = ToolSaveResult.savedHistory(3);
    expect(history.saved, isTrue);
    expect(history.target, ToolSaveTarget.history);
    expect(history.recordId, 3);
    expect(history.message, '结果已保存到历史记录');

    final note = ToolSaveResult.savedNote(7);
    expect(note.saved, isTrue);
    expect(note.target, ToolSaveTarget.note);
    expect(note.recordId, 7);
    expect(note.message, '已保存到笔记');

    final invalid = ToolSaveResult.inputInvalid(
      target: ToolSaveTarget.history,
      summary: '电阻 R（Ω）: 无法解析数值或表达式',
    );
    expect(invalid.saved, isFalse);
    expect(invalid.needsAttention, isTrue);
    expect(invalid.status, ToolSaveStatus.inputInvalid);
    expect(invalid.message, contains('请先修正输入参数'));

    final notWritten = ToolSaveResult.notWritten(ToolSaveTarget.note);
    expect(notWritten.status, ToolSaveStatus.notWritten);
    expect(notWritten.message, '笔记没有写入，请重试');
  });
}
