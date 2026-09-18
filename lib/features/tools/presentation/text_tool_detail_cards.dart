import 'package:flutter/material.dart';

import '../../../application/controllers/text_tool_models.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'text_tool_strings.dart';
import 'tools_strings.dart';

/// 中文：**文本工具详情页那三块叶子。** 状态卡、校核卡、自定义公式用的那个窄输入框，原来长在
///       `text_tool_detail_screen.dart` 的状态类里（三个私有方法），本轮按「**哪一层**」搬出来：
///       它们只**画**拿到的东西——自己不读控制器、不排计算、不碰草稿、不弹提示，与那个屏幕的
///       状态机没有任何关系。屏幕留下的是状态、动作与整页的排版，三块叶子各自回答「我这一块画
///       成什么样」。
///
///       **搬的只是位置**：三块的结构、间距、配色与文字来源逐字相同。唯一变的是入参——原来它们
///       读状态类的私有字段（`_output` / `_strings` / `_insights`），现在由调用方显式传进来，
///       于是「这块画什么、素材从哪来」在构造处一眼可见。
///
/// English: **the three leaves of the text-tool detail screen.** The status card, the insights card
///          and the narrow field the custom-formula tool uses used to be private methods on that
///          screen's state class; this round moved them along the "**which layer**" seam: they only
///          **draw** what they are given — they read no controller, schedule no computation, touch no
///          draft and raise no message, so they have nothing to do with that screen's state machine.
///          What stays on the screen is state, actions and the page's layout; each leaf answers "what
///          does my block look like".
///
///          **Only the position moved**: all three keep their structure, spacing, colours and the
///          source of every string, character for character. The one change is the inputs — they used
///          to read the state class's private fields (`_output` / `_strings` / `_insights`) and now
///          receive them from the caller, so "what this block draws and where its material comes from"
///          is visible at the construction site.
class TextToolStatusCard extends StatelessWidget {
  const TextToolStatusCard({
    required this.output,
    required this.strings,
    super.key,
  });

  /// 中文：这次算出来的输出——它自己知道这次是不是一条错误（`hasError`）。
  /// English: this evaluation's output — it knows whether it is an error (`hasError`).
  final TextToolOutput output;

  /// 中文：输出那一族的文案表（状态标题与状态正文都从它来）。
  /// English: the output family's copy table (both the status title and the status body come from it).
  final TextToolOutputStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = output.hasError;
    final color = hasError ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasError ? Icons.error_outline : Icons.verified_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(output.statusTitle(strings),
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  output.statusMessage(strings),
                  style: TextStyle(
                      color:
                          hasError ? scheme.onSurface : scheme.onSurfaceVariant,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 中文：自定义公式那三格 a / b / c 用的窄输入框——数字键盘 + 密集布局，与主输入框不是一回事，
///       所以它是一个独立的小部件而不是主输入框的一个参数。
/// English: the narrow field behind the custom-formula tool's a / b / c cells — numeric keyboard and
///          a dense layout, which is not the main field's thing, hence a small widget of its own
///          rather than one more parameter on the main field.
class TextToolSmallField extends StatelessWidget {
  const TextToolSmallField({
    required this.label,
    required this.controller,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

/// 中文：校核卡——控制器给出的每一条提示一行（信息图标 + 那句话），没有提示时整块由调用方决定
///       不经由本部件（屏幕只在 `_insights` 非空时才把它放进列表）。
/// English: the insights card — one line per hint the controller produced (an info icon plus the
///          sentence); with no hints the block is left out by the caller rather than by this widget
///          (the screen only puts it in the list while `_insights` is non-empty).
class TextToolInsightCard extends StatelessWidget {
  const TextToolInsightCard({required this.insights, super.key});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(ToolsStrings.of(context).insights),
            ...insights.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 17, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
