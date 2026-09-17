part of 'settings_page.dart';

extension _SettingsDialogs on _SettingsPageState {
  void _showAbout() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
                          : const [
                              BoxShadow(
                                  color: Color(0x1A5B47FF),
                                  blurRadius: 24,
                                  offset: Offset(0, 10))
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
                  const Text('个人全能计算工作台，覆盖科学计算、工程工具、单位换算、函数图形和计算笔记。'),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AboutChip('科学计算'),
                      _AboutChip('工程工具'),
                      _AboutChip('函数图形'),
                      _AboutChip('SQLite 本地记录'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined,
                          size: 18, color: Color(0xFF23B45D)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('数据当前仅保存在本机 SQLite，不上传网络服务。',
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
              onPressed: () => _showInfo('开源结构',
                  '项目采用 Feature-first + Clean Architecture 简化版：UI、Application、Domain、Data、Core 分层维护。'),
              child: const Text('架构')),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('完成')),
        ],
      ),
    );
  }

  Future<void> _showHelpAndFeedback() async {
    final report = _diagnosticReport();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('帮助与反馈'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    '计算页用于快速表达式；工具页可按分类检索工程工具；图形页用于函数分析；笔记页可保存计算结果和工程记录。'),
                const SizedBox(height: 16),
                const Text('诊断报告',
                    style: TextStyle(fontWeight: FontWeight.w800)),
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
                const SnackBar(content: Text('诊断报告已复制')),
              );
            },
            child: const Text('复制报告'),
          ),
          FilledButton(
            onPressed: () async {
              final opened =
                  await _openExternalUrl(GithubReleaseChecker.issueCreationUrl);
              if (opened && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('提交 GitHub Issue'),
          ),
        ],
      ),
    );
  }

  String _diagnosticReport() => [
        'NekoCalc 诊断报告',
        '应用：${AppInfo.name}',
        '版本：${AppInfo.version}',
        '发布通道：${AppInfo.channel}',
        '平台：${defaultTargetPlatform.name}',
        '生成时间：${DateTime.now().toIso8601String()}',
        '',
        '请补充：问题发生步骤、预期结果、实际结果；不要粘贴个人敏感数据。',
      ].join('\n');

  Future<bool> _openExternalUrl(String url) async {
    try {
      final opened = await _appLinkOpener.openExternalUrl(url);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接，请稍后重试')),
        );
      }
      return opened;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接，请稍后重试')),
        );
      }
      return false;
    }
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
              child: const Text('知道了')),
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
