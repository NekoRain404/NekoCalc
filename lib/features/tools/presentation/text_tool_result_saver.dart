import '../../../application/controllers/text_tool_models.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_save_result.dart';
import 'text_tool_strings.dart';

/// 中文：**一次「保存」从算好的输出到历史行 / 笔记之间要做的事。** 这一段原来长在
///       `text_tool_detail_screen.dart` 里（`_saveHistoryResult` 与 `_saveNoteResult`），本轮按
///       「**哪一层决定**」搬出来：那段代码回答的是「这次输出该不该落库、落成什么、落不成怎么
///       说」——是**领域**的问题，而它用的词汇（`ToolSaveResult` / `ToolSaveTarget`）本来就住在
///       `lib/domain/usecases/` 里。屏幕那一侧剩下的是**交互**：防重入、把回来的那句话显示出来。
///
///       **判据一条都没有动**：输出是错误时先拒（`inputInvalid`，附上 `statusMessage` 那句话），
///       写回 0 行算没写进去（`notWritten`），抛出来算失败（`failed`，把异常原样带上）。三条出口
///       与原来逐条相同，只是现在由这个类来回答。文案表由调用方传进来，所以这里不读
///       `BuildContext`、不读屏幕状态。
///
/// English: **what one "save" does between a computed output and a history row or a note.** This used
///          to be `_saveHistoryResult` and `_saveNoteResult` on `text_tool_detail_screen.dart`; the
///          round moved it along the "**which layer decides**" seam: that code answers "should this
///          output be persisted, as what, and what is said when it cannot be" — a **domain** question,
///          and the vocabulary it speaks (`ToolSaveResult` / `ToolSaveTarget`) already lives under
///          `lib/domain/usecases/`. What is left on the screen is the **interaction**: the re-entry
///          guard and showing the sentence that comes back.
///
///          **Not one judgement moved**: an erroring output is refused first (`inputInvalid`, carrying
///          `statusMessage`'s sentence), a write that returns 0 rows counts as not written
///          (`notWritten`), and a throw counts as a failure (`failed`, with the error passed through).
///          The three exits are the same three as before, now answered by this class. The copy table
///          arrives from the caller, so nothing here reads a `BuildContext` or screen state.
class TextToolResultSaver {
  const TextToolResultSaver({
    required this.historyRepository,
    required this.notesRepository,
  });

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;

  /// 中文：把这次输出存进工具历史。`input` 是「这次算的是什么」的那一串（调用方自己决定，
  ///       自定义公式工具与其余工具取的东西不一样）。
  /// English: save this output into the tool history. `input` is the string that says what was
  ///          computed (the caller decides it; the custom-formula tool takes a different one from
  ///          the rest).
  Future<ToolSaveResult> saveHistory({
    required ToolDefinition tool,
    required TextToolOutput output,
    required TextToolOutputStrings strings,
    required String input,
    required String result,
  }) async {
    if (output.hasError) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: output.statusMessage(strings),
      );
    }
    try {
      final historyId = await historyRepository.saveToolResult(
        expression: '${tool.title}: $input',
        result: result,
        toolId: tool.id,
      );
      if (historyId <= 0) {
        return ToolSaveResult.notWritten(ToolSaveTarget.history);
      }
      return ToolSaveResult.savedHistory(historyId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.history,
        error: error,
      );
    }
  }

  /// 中文：把这次输出存成一条笔记——正文就是复制用的那一份完整报告（`copyText`），所以笔记里
  ///       有输入、状态、主结果、详情与校核，而不只是主结果那一行。
  /// English: save this output as a note — the body is the same full report the copy button produces
  ///          (`copyText`), so the note carries the input, the status, the primary result, the detail
  ///          and the insights rather than the primary result's single line.
  Future<ToolSaveResult> saveNote({
    required ToolDefinition tool,
    required TextToolOutput output,
    required TextToolOutputStrings strings,
    required String input,
  }) async {
    if (output.hasError) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.note,
        summary: output.statusMessage(strings),
      );
    }
    try {
      final noteId = await notesRepository.create(
        title: tool.title,
        body: output.copyText(
          strings: strings,
          title: tool.title,
          input: input,
        ),
        description: tool.description,
      );
      if (noteId <= 0) return ToolSaveResult.notWritten(ToolSaveTarget.note);
      return ToolSaveResult.savedNote(noteId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.note,
        error: error,
      );
    }
  }
}
