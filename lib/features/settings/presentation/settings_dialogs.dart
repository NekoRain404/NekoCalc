part of 'settings_page.dart';

extension _SettingsDialogs on _SettingsPageState {
  void _showAbout() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) {
        final s = SettingsStrings.of(context);
        return AlertDialog(
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.72),
                    scheme.secondaryContainer.withValues(alpha: 0.58)
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.24)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? const []
                          : [
                              BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10))
                            ],
                    ),
                    child: Icon(Icons.calculate_rounded,
                        color: scheme.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(AppInfo.name,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('${AppInfo.version}  ${AppInfo.channel}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.aboutTagline),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AboutChip(s.aboutChipScience),
                      _AboutChip(s.aboutChipEngineering),
                      _AboutChip(s.aboutChipGraph),
                      _AboutChip(s.aboutChipSqlite),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s.aboutPrivacyNote,
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  _showInfo(s.openSourceTitle, s.openSourceBody),
              child: Text(s.openSourceAction)),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: Text(s.done)),
        ],
        );
      },
    );
  }

  Future<void> _showHelpAndFeedback() async {
    final report = _diagnosticReport();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final s = SettingsStrings.of(dialogContext);
        return AlertDialog(
          title: Text(s.helpFeedbackTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.helpIntro),
                  const SizedBox(height: 16),
                  Text(s.diagnosticReportTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SelectableText(
                    report,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.reportCopied)),
                );
              },
              child: Text(s.copyReport),
            ),
            FilledButton(
              onPressed: () async {
                final opened = await _openExternalUrl(
                    GithubReleaseChecker.issueCreationUrl);
                if (opened && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(s.submitIssue),
            ),
          ],
        );
      },
    );
  }

  /// 中文：诊断报告是**用户要粘贴到 Issue 里的文本**，所以它跟着界面语言走——报告里那些
  ///       `应用：`/`版本：` 前缀是给人看的标签，不是机器解析的字段（没有解析方，`backup_snapshot`
  ///       那一套 JSON 才是机器格式）。报告正文里的 App 名、版本号、平台名都是标识符，不翻。
  /// English: The diagnostic report is **text the user pastes into an issue**, so it follows the UI
  ///          language: the `应用：` / `版本：` prefixes are human labels, not machine-parsed fields
  ///          (nothing parses them; the `backup_snapshot` JSON is the machine format). The app name,
  ///          version and platform inside it are identifiers and stay untranslated.
  String _diagnosticReport() {
    final s = SettingsStrings.of(context);
    return [
      s.diagnosticHeading,
      s.diagnosticApp(AppInfo.name),
      s.diagnosticVersion(AppInfo.version),
      s.diagnosticChannel(AppInfo.channel),
      s.diagnosticPlatform(defaultTargetPlatform.name),
      s.diagnosticGeneratedAt(DateTime.now().toIso8601String()),
      '',
      s.diagnosticPrompt,
    ].join('\n');
  }

  Future<bool> _openExternalUrl(String url) async {
    try {
      final opened = await _appLinkOpener.openExternalUrl(url);
      if (!opened && mounted) {
        _showLinkOpenFailure();
      }
      return opened;
    } catch (_) {
      if (mounted) {
        _showLinkOpenFailure();
      }
      return false;
    }
  }

  void _showLinkOpenFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SettingsStrings.of(context).linkOpenFailed)),
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(SettingsStrings.of(context).gotIt)),
        ],
      ),
    );
  }
}


class _AboutChip extends StatelessWidget {
  const _AboutChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(label,
          style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}
