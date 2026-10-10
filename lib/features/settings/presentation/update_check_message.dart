import '../../../application/update/github_release_checker.dart';
import 'settings_strings.dart';

/// 中文：**检查更新回执的翻译处——检查器给令牌，这里给字。**
///
///       `UpdateCheckResult` 从前自己拼那六句话并直接上屏（设置页「检查更新」对话框里的
///       `result.message`），于是英文界面下它照样印中文：**结果对象从检查器活到对话框**，界面那张
///       按语言切的表够不着它（`docs/verification.md` §5i）。现在那六句话住在 [SettingsStrings] 里，
///       由这个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///
///       **形状照的是已经转过的五条路径**（`calculatorSubmitMessage`、`calculatorSaveNoteMessage`、
///       `toolSaveMessage`、`notesImportMessage`、`recentToolActionMessage`）：令牌在产出层，字在
///       呈现层的表里。
///
///       **行为判据不在这里**：对话框的按钮与图标仍按 `result.status`（由令牌派生）选，这个函数只
///       回答「那句话怎么说」。表与令牌都由调用方给，所以这个文件里一个中文字面量都没有——它因此
///       落在 `settings_strings_test.dart` 那条源码扫描的范围里。
///
///       **加一种结局时这里编译不过**：`switch` 穷尽 [UpdateCheckOutcome]。
/// English: **where an update-check receipt is translated — the checker hands over the token, this
///          hands over the words.**
///
///          `UpdateCheckResult` used to compose those six sentences itself and print them straight (as
///          `result.message` in the settings page's "Check for updates" dialog), so an English
///          interface still printed Chinese: **the result travels from the checker to the dialog**, and
///          a language-keyed interface table cannot reach it (`docs/verification.md` §5i). Those six
///          sentences now live in [SettingsStrings], fetched **at the presentation edge** by this
///          function, keyed by the token — the language of the table is the language on screen.
///
///          **The shape is copied from the five converted paths** (`calculatorSubmitMessage`,
///          `calculatorSaveNoteMessage`, `toolSaveMessage`, `notesImportMessage`,
///          `recentToolActionMessage`): token in the producing layer, words in the presentation
///          layer's table.
///
///          **The behaviour verdict is not here**: the dialog still picks its button and icon from
///          `result.status` (derived from the token), while this function answers only "how the
///          sentence reads". Both the table and the token arrive as arguments, so this file holds not
///          one Chinese literal — which puts it inside `settings_strings_test.dart`'s source sweep.
///
///          **Adding an outcome breaks this at compile time**: the `switch` exhausts
///          [UpdateCheckOutcome].
String updateCheckMessage(
  UpdateCheckResult result,
  SettingsStrings strings,
) {
  return switch (result.outcome) {
    UpdateCheckOutcome.updateAvailable =>
      strings.updateAvailable(result.release!.version),
    UpdateCheckOutcome.upToDate => strings.updateUpToDate,
    UpdateCheckOutcome.versionUnreadable => strings.updateVersionUnreadable,
    UpdateCheckOutcome.httpError =>
      strings.updateHttpError(result.httpStatusCode!),
    UpdateCheckOutcome.noReleasesFound => strings.updateNoReleasesFound,
    UpdateCheckOutcome.networkUnreachable => strings.updateNetworkUnreachable,
  };
}
