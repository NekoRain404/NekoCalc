import 'package:flutter/material.dart';

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));
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
        color: dark
            ? scheme.primary.withValues(alpha: 0.16)
            : const Color(0xFFEDEBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: dark
                ? scheme.primary.withValues(alpha: 0.34)
                : const Color(0xFFD8D3FF)),
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
      child: _PressScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          // 中文：**36 dp 的视觉 + 48 dp 的点击区。** 判据量的是 `InkWell` 那个语义节点，
          //       而它原来与视觉同为 36 ⇒ **全应用每一颗 `IconToolButton` 都低于平台的 48 dp**。
          // English: **a 36 dp visual with a 48 dp tap target.** The guideline measures the `InkWell`'s
          //          semantics node, which used to be 36 like the visual — so **every `IconToolButton` in
          //          the app** sat below the platform's 48 dp.
          child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ))),
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
      child: Text(text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {required this.title, this.action, this.onActionTap, super.key});

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
            // 中文：**点击区撑到 48 dp。** 这里原来是「文字高度 + 8 dp 下内边距」≈ **29 dp**，
            //       而它是可点的——实测：`androidTapTargetGuideline` 在工具首页与分类页上报的
            //       那个 `328 × 29` 就是它（走语义树才认出名字：`label=收藏工具`，带 tap 动作）。
            //
            //       ⚠️ **我第一次改这一处时写下的「文字一个像素没动」是错的，这里是更正后的版本。**
            //       原来那版只加了 `minHeight: 48`，而这一行是 `Row(crossAxisAlignment: center)`：
            //       行高由 29 变成 48 之后，**标题被居中**（往下挪了约 9.5dp），而**动作那一段的文字
            //       仍钉在自己那个被撑高的盒子的顶上**（往上挪了约 3.5dp）——两段文字因此差了约 13dp。
            //       实测（360×800，`SectionHeader(title: 收藏工具, action: 添加)`）：
            //
            //       | 量的是什么 | 第一次改完之后 |
            //       |---|---|
            //       | 整行 | `265.0..313.0`（h **48.0**）|
            //       | 标题那一格 | `274.5..303.5`（h 29.0，被居中）|
            //       | 动作那个 `Text` | `265.0..305.0`（h **40.0** —— 被 `minHeight` 撑高，文字在**顶**上）|
            //
            //       **修法**：把动作的文字 `Center` 到那 48dp 里（与标题同一套居中），并去掉那 8dp 下内边距
            //       ——它是为旧的 29dp 几何写的，留着会让文字偏上。点击区仍是 48dp，判据照过。
            //       **教训**：撑高一个居中对齐的行里的**一格**，改变的不只是那一格的盒子——同排别的格子
            //       会跟着重新居中。**"多出来的高度落在它下面"这句话在居中行里不成立。**
            // English: **the tap target is brought up to 48 dp.** This used to be "the text's height plus
            //          8 dp of bottom padding" ≈ **29 dp**, and it is tappable — measured: that is exactly
            //          the `328 × 29` node `androidTapTargetGuideline` reports on the tools home and the
            //          category screen (walking the semantics tree is what named it: `label=收藏工具`, with a
            //          tap action).
            //
            //          ⚠️ **The "the text does not move by a pixel" I wrote on the first attempt was wrong,
            //          and this is the corrected version.** That version only added `minHeight: 48`, and
            //          this row is a `Row(crossAxisAlignment: center)`: once the row went 29 → 48 the
            //          **title got centred** (moving down ≈ 9.5dp) while the **action's text stayed pinned
            //          to the top of its stretched box** (moving up ≈ 3.5dp) — leaving the two texts about
            //          13dp apart. Measured (360×800, `SectionHeader(title: 收藏工具, action: 添加)`):
            //
            //          | what | after the first attempt |
            //          |---|---|
            //          | the whole row | `265.0..313.0` (h **48.0**) |
            //          | the title cell | `274.5..303.5` (h 29.0, centred) |
            //          | the action `Text` | `265.0..305.0` (h **40.0** — stretched by `minHeight`, text at the **top**) |
            //
            //          **The repair**: `Center` the action's text in that 48dp band (the same centring the
            //          title gets) and drop the 8dp of bottom padding — it was written for the old 29dp
            //          geometry and would now push the text up. The tap target is still 48dp and the
            //          guideline still passes. **The lesson**: raising one cell of a centre-aligned row does
            //          not only change that cell's box — every other cell in the row re-centres. **"The
            //          extra height goes below it" is not true in a centre-aligned row.**
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: Text(action!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                ),
              ),
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
    return _PressScale(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
  });

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
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
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
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
      child: Text(message,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

BoxDecoration softPanel({BuildContext? context, bool highlight = false}) {
  final scheme = context == null ? null : Theme.of(context).colorScheme;
  final dark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme?.surface ?? Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: highlight
          ? (scheme?.primary.withValues(alpha: dark ? 0.42 : 0.24) ??
              const Color(0xFFD8D3FF))
          : (scheme?.outlineVariant ?? const Color(0xFFE8ECF7)),
    ),
    boxShadow: dark
        ? const []
        : const [
            BoxShadow(
                color: Color(0x1425405F), blurRadius: 22, offset: Offset(0, 10))
          ],
  );
}
