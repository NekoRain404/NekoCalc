import 'package:flutter/material.dart';

import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'category_visuals.dart';

class HorizontalToolList extends StatelessWidget {
  const HorizontalToolList({
    required this.tools,
    required this.onTap,
    super.key,
  });

  final List<ToolDefinition> tools;
  final ValueChanged<ToolDefinition> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return InkWell(
            onTap: () => onTap(tool),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 78,
              padding: const EdgeInsets.all(10),
              decoration: softPanel(context: context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, color: tool.color),
                  const SizedBox(height: 8),
                  Text(tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurface)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
    super.key,
  });

  final ToolCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: category.color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('$count 个工具',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToolListTile extends StatelessWidget {
  const ToolListTile({
    required this.tool,
    required this.favorite,
    required this.onTap,
    this.onFavoriteToggle,
    this.matchLabel,
    this.trailing,
    super.key,
  });

  final ToolDefinition tool;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final String? matchLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tool.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(tool.icon, color: tool.color),
      ),
      title:
          Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          matchLabel == null
              ? tool.description
              : '${tool.description} · $matchLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: trailing ??
          (onFavoriteToggle == null
              ? favorite
                  ? const Icon(Icons.star, color: Colors.amber, size: 18)
                  : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
              : IconButton(
                  tooltip: favorite ? '取消收藏' : '收藏',
                  onPressed: onFavoriteToggle,
                  icon: Icon(favorite ? Icons.star : Icons.star_border,
                      color: favorite ? Colors.amber : scheme.onSurfaceVariant),
                )),
    );
  }
}

class ToolSearchEmptyState extends StatelessWidget {
  const ToolSearchEmptyState({
    required this.message,
    required this.suggestions,
    required this.examples,
    required this.onQuerySelected,
    this.alternatives = const <Widget>[],
    super.key,
  });

  final String message;
  final List<String> suggestions;
  final List<String> examples;
  final ValueChanged<String> onQuerySelected;
  final List<Widget> alternatives;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestionTexts = suggestions
        .map((suggestion) => suggestion.trim().toLowerCase())
        .toSet();
    final visibleExamples = examples
        .where((example) =>
            !suggestionTexts.contains(example.trim().toLowerCase()))
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search_off, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty || visibleExamples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...suggestions.map(
                  (suggestion) => ActionChip(
                    avatar: const Icon(Icons.manage_search, size: 16),
                    label: Text(suggestion),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuerySelected(suggestion),
                  ),
                ),
                ...visibleExamples.map((example) => ActionChip(
                      label: Text(example),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onQuerySelected(example),
                    )),
              ],
            ),
          ],
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '其它分类',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            ...alternatives,
          ],
        ],
      ),
    );
  }
}

class DetailMetric extends StatelessWidget {
  const DetailMetric({required this.result, this.onCopy, super.key});

  final ToolResult result;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(result.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ),
              if (onCopy != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    tooltip: '复制此项',
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(Icons.copy_outlined,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(result.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          Text(result.unit,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
