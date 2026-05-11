import 'package:flutter/material.dart';

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));
  }
}

class NekoAppMark extends StatelessWidget {
  const NekoAppMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: dark ? scheme.primary.withValues(alpha: 0.16) : const Color(0xFFEDEBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? scheme.primary.withValues(alpha: 0.34) : const Color(0xFFD8D3FF)),
      ),
      child: Icon(Icons.calculate_outlined, color: scheme.primary, size: 21),
    );
  }
}

class IconToolButton extends StatelessWidget {
  const IconToolButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.action, this.onActionTap, super.key});

  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        if (action != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
              child: Text(action!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class TabPill extends StatelessWidget {
  const TabPill({required this.label, this.selected = false, super.key});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softPanel(context: context),
      child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

BoxDecoration softPanel({BuildContext? context, bool highlight = false}) {
  final scheme = context == null ? null : Theme.of(context).colorScheme;
  final dark = context != null && Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme?.surface ?? Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: highlight
          ? (scheme?.primary.withValues(alpha: dark ? 0.42 : 0.24) ?? const Color(0xFFD8D3FF))
          : (scheme?.outlineVariant ?? const Color(0xFFE8ECF7)),
    ),
    boxShadow: dark ? const [] : const [BoxShadow(color: Color(0x1425405F), blurRadius: 22, offset: Offset(0, 10))],
  );
}
