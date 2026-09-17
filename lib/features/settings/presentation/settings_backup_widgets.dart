part of 'settings_page.dart';

enum _BackupImportMode { merge, replace }

class _BackupImportPrompt extends StatelessWidget {
  const _BackupImportPrompt({
    required this.source,
    required this.local,
    required this.mergePlan,
    required this.replacePlan,
  });

  final BackupPreview source;
  final BackupPreview local;
  final BackupImportPlan mergePlan;
  final BackupImportPlan replacePlan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warnings = buildBackupPreviewWarnings(
      source,
      now: DateTime.now(),
      currentAppVersion: AppInfo.version,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackupPreviewBlock(title: '备份文件', preview: source),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BackupWarningsBlock(warnings: warnings),
          ],
          const SizedBox(height: 12),
          _BackupPreviewBlock(title: '本机当前', preview: local),
          const SizedBox(height: 12),
          _BackupPlanBlock(plan: mergePlan),
          const SizedBox(height: 10),
          _BackupPlanBlock(
            plan: replacePlan,
            blockedMessage: replacePlan.source.totalRows == 0
                ? emptyBackupReplaceErrorMessage
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_outlined,
                  color: scheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请确认文件来自可信备份。覆盖恢复会先清空本机数据；合并导入会保留本机数据，但设置和同一工具记录可能被备份内容更新。',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupPreviewBlock extends StatelessWidget {
  const _BackupPreviewBlock({
    required this.title,
    required this.preview,
  });

  final String title;
  final BackupPreview preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '版本：${preview.appVersion ?? '未知'}\n'
          '时间：${preview.exportedAt ?? '本机当前'}\n'
          '总计：${preview.totalLabel}\n'
          '${preview.summary}',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
        ),
      ],
    );
  }
}

class _BackupWarningsBlock extends StatelessWidget {
  const _BackupWarningsBlock({required this.warnings});

  final List<BackupPreviewWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highestSeverity = warnings.fold<BackupPreviewWarningSeverity>(
      BackupPreviewWarningSeverity.info,
      (current, warning) =>
          warning.severity.index > current.index ? warning.severity : current,
    );
    final color = switch (highestSeverity) {
      BackupPreviewWarningSeverity.danger => scheme.error,
      BackupPreviewWarningSeverity.warning => scheme.tertiary,
      BackupPreviewWarningSeverity.info => scheme.primary,
    };
    final icon = switch (highestSeverity) {
      BackupPreviewWarningSeverity.danger => Icons.error_outline,
      BackupPreviewWarningSeverity.warning => Icons.warning_amber_outlined,
      BackupPreviewWarningSeverity.info => Icons.info_outline,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text('备份提示',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                warning.message,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupPlanBlock extends StatelessWidget {
  const _BackupPlanBlock({
    required this.plan,
    this.blockedMessage,
  });

  final BackupImportPlan plan;
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = plan.replaceExisting ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan.replaceExisting
                    ? Icons.warning_amber_outlined
                    : Icons.merge_type_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${plan.modeLabel}后预计 ${plan.totalLabel}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in plan.tableCounts) ...[
            _BackupPlanRow(
              label: item.label,
              before: plan.beforeFor(item.name),
              source: plan.sourceFor(item.name),
              expected: plan.expectedFor(item.name),
              delta: plan.deltaFor(item.name),
            ),
            if (item.name != backupTableNames.last) const SizedBox(height: 4),
          ],
          if (plan.impacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BackupImpactList(impacts: plan.impacts),
          ],
          if (blockedMessage case final message?) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block_outlined, color: scheme.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupImpactList extends StatelessWidget {
  const _BackupImpactList({required this.impacts});

  final List<BackupImportImpact> impacts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final impact in impacts) ...[
          _BackupImpactRow(impact: impact),
          if (impact != impacts.last) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _BackupImpactRow extends StatelessWidget {
  const _BackupImpactRow({required this.impact});

  final BackupImportImpact impact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (impact.severity) {
      BackupImportImpactSeverity.danger => scheme.error,
      BackupImportImpactSeverity.warning => scheme.tertiary,
      BackupImportImpactSeverity.info => scheme.onSurfaceVariant,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_impactIcon(impact.icon), color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            impact.message,
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 1.3,
              fontWeight: impact.severity == BackupImportImpactSeverity.info
                  ? FontWeight.w600
                  : FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  IconData _impactIcon(BackupImportImpactIcon icon) {
    return switch (icon) {
      BackupImportImpactIcon.merge => Icons.merge_type_outlined,
      BackupImportImpactIcon.replace => Icons.change_circle_outlined,
      BackupImportImpactIcon.delete => Icons.delete_outline,
      BackupImportImpactIcon.blocked => Icons.block_outlined,
      BackupImportImpactIcon.settings => Icons.tune_outlined,
      BackupImportImpactIcon.tools => Icons.construction_outlined,
      BackupImportImpactIcon.history => Icons.history,
    };
  }
}

class _BackupPlanRow extends StatelessWidget {
  const _BackupPlanRow({
    required this.label,
    required this.before,
    required this.source,
    required this.expected,
    required this.delta,
  });

  final String label;
  final int before;
  final int source;
  final int expected;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deltaText = delta > 0 ? '+$delta' : delta.toString();
    final deltaColor = delta < 0
        ? scheme.error
        : delta > 0
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            '本机 $before · 文件 $source · 导入后 $expected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(deltaText,
            style: TextStyle(color: deltaColor, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _DataSummaryTile extends StatelessWidget {
  const _DataSummaryTile({
    required this.preview,
    required this.busy,
    required this.onRefresh,
  });

  final BackupPreview? preview;
  final bool busy;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = preview;
    return ListTile(
      leading: Icon(Icons.storage_outlined, color: scheme.primary),
      title: const Text('本机数据', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: current == null
          ? Text('统计中', style: TextStyle(color: scheme.onSurfaceVariant))
          : Text(
              current.summary,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null)
            Text(current.totalLabel,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '刷新数据统计',
            onPressed: onRefresh,
            icon: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
