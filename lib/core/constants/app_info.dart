/// 中文：这里只放**标识符**（应用名、版本号）。**给人看的通道名不在这里**——`'预览版 / Prerelease'`
///       是一句界面文案，按语言分放在 `SettingsStrings.channelName`
///       （`lib/features/settings/presentation/settings_strings.dart`）。留在这里的旧写法让英文界面
///       的关于框与诊断报告都印出了中文：常量在界面之下，**它没有语言可跟**。
/// English: Only **identifiers** (the app name, the version number) live here. **The human-readable
///          channel name does not** — `'预览版 / Prerelease'` is interface copy and lives per language in
///          `SettingsStrings.channelName`. Keeping it here made both the About box and the diagnostic
///          report print Chinese in an English interface: a constant sits below the interface and
///          **has no language to follow**.
class AppInfo {
  const AppInfo._();

  static const name = 'NekoCalc';
  static const version = 'v1.2.0-beta.1';
}
