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
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
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
          _BackupPreviewBlock(title: s.backupFileTitle, preview: source),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BackupWarningsBlock(warnings: warnings),
          ],
          const SizedBox(height: 12),
          _BackupPreviewBlock(title: s.localCurrentTitle, preview: local),
          const SizedBox(height: 12),
          _BackupPlanBlock(plan: mergePlan),
          const SizedBox(height: 10),
          _BackupPlanBlock(
            plan: replacePlan,
            // 中文：这句与 `BackupImportImpact.emptySource` 那格**同一句话**（校验器里那个
            //       `emptyBackupReplaceErrorMessage` 常量本轮已取消，改抛一枚令牌
            //       `emptyBackupReplaceErrorToken`，被拒绝导入的失败详情由
            //       `backupImportFailureMessage` 取同一格）——所以这里也走表，英文界面下才不是中文。
            // English: this is **the same sentence** as the `BackupImportImpact.emptySource` cell (the
            //          validator's `emptyBackupReplaceErrorMessage` constant is gone this round, replaced
            //          by the token `emptyBackupReplaceErrorToken`, and the rejected import's failure
            //          detail fetches the same cell through `backupImportFailureMessage`) — so this site
            //          reads the table too, or an English interface would print Chinese here.
            blockedMessage:
                replacePlan.source.totalRows == 0 ? bs.backupImpactEmptySource : null,
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
                  s.importWarning,
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
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          // 中文：版本、导出时间、总计与表清单四段载荷都是记号/内容，句子的骨架由这条缝隙拼
          //       （`backupPreviewTableSummary` 与 `BackupPreview` 上留下的读数）。
          // English: the four payloads — version, export time, total and the table list — are
          //          notation/content; the sentence's skeleton is spliced here (via
          //          `backupPreviewTableSummary` and the readings left on `BackupPreview`).
          s.backupPreviewSummary(
            preview.appVersion ?? bs.backupUnknownVersion,
            preview.exportedAt ?? bs.backupLocalCurrent,
            bs.backupTotalRecords(preview.totalRows),
            backupPreviewTableSummary(preview, bs),
          ),
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
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
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
              Text(s.backupWarningsTitle,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                // 中文：那句话由呈现层按令牌取（`settings_backup_messages.dart`）。
                // English: the sentence is read at the presentation edge from the token
                //          (`settings_backup_messages.dart`).
                backupPreviewWarningMessage(warning, bs),
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
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
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
                  // 中文：模式词与总数那两句按令牌/读数在呈现边缘取（`settings_backup_text.dart`）。
                  // English: the mode word and the total are read at the presentation edge from the
                  //          token/readings (`settings_backup_text.dart`).
                  s.backupPlanHeadline(
                    backupPlanModeLabel(plan, bs),
                    backupPlanTotalLabel(plan, bs),
                  ),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in plan.tableCounts) ...[
            _BackupPlanRow(
              // 中文：行首那格印的是标签，由呈现边缘按表名（键）查（`backupTableLabel`）。
              // English: the leading cell prints the label, looked up from the table name (key) at the
              //          presentation edge (`backupTableLabel`).
              label: backupTableLabel(item.name, bs),
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
    final bs = SettingsBackupStrings.of(context);
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
            // 中文：那句话由呈现层按令牌取（`settings_backup_messages.dart`）——多张表的连接符也
            //       跟着语言走。
            // English: the sentence is read at the presentation edge from the token
            //          (`settings_backup_messages.dart`) — the separator between several table names
            //          follows the language as well.
            backupImportImpactMessage(impact, bs),
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
    final s = SettingsStrings.of(context);
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
            s.backupPlanRow(before, source, expected),
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
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
    final current = preview;
    return ListTile(
      leading: Icon(Icons.storage_outlined, color: scheme.primary),
      title:
          Text(s.localDataTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: current == null
          ? Text(s.counting, style: TextStyle(color: scheme.onSurfaceVariant))
          : Text(
              // 中文：表清单那句由呈现边缘拼（`settings_backup_text.dart`），数字与表名是载荷。
              // English: the table-list sentence is spliced at the presentation edge
              //          (`settings_backup_text.dart`); the numbers and table names are payload.
              backupPreviewTableSummary(current, bs),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null)
            Text(bs.backupTotalRecords(current.totalRows),
                style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: s.refreshDataStats,
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
