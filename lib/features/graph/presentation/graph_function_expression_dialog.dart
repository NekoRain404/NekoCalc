import 'package:flutter/material.dart';

import '../../../shared/presentation/app_chrome.dart';
import '../models/graph_models.dart';
import '../models/graph_strings.dart';

class FunctionExpressionDialog extends StatefulWidget {
  const FunctionExpressionDialog({
    super.key,
    required this.title,
    required this.initialExpression,
    required this.confirmLabel,
    required this.degreeMode,
  });

  final String title;
  final String initialExpression;
  final String confirmLabel;

  /// 中文：预览那一次探测求值用的角度单位——**必填**，因为它必须是图形页正在用的那一个；
  ///       漏传该是编译错误，而不是悄悄按弧度制预览（那正是这个缺陷的形状）。
  /// English: the angle unit the preview's one probe evaluates under — **required**, because it must
  ///          be the very unit the graph page is using; omitting it should be a compile error rather
  ///          than silently previewing in radians (which is the shape of the defect this fixes).
  final bool degreeMode;

  @override
  State<FunctionExpressionDialog> createState() =>
      _FunctionExpressionDialogState();
}

class _FunctionExpressionDialogState extends State<FunctionExpressionDialog> {
  late final TextEditingController _controller;
  String? _error;
  GraphFunctionInputPreview? _preview;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialExpression);
    _controller.addListener(_updatePreview);
  }

  /// 中文：**预览在第一次 `build` 时才建。** 它要一张 `GraphStrings`，而表要等 `context` 可用；
  ///       `initState` 里没有 `context`。`_updatePreview` 同样只在 `context` 可用后被调用
  ///       （listener 在用户敲键时触发，那时一定已经挂载）。
  /// English: **The preview is built on the first `build`.** It needs a `GraphStrings`, and the table
  ///          needs an available `context`, which `initState` does not have. `_updatePreview` is also
  ///          only invoked once `context` is available (the listener fires on keystrokes, by which time
  ///          the widget is mounted).
  GraphFunctionInputPreview _previewFor(GraphStrings strings) {
    return previewGraphFunctionInput(
      _controller.text,
      color: const Color(0xFF1677FF),
      strings: strings,
      degreeMode: widget.degreeMode,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _preview = _previewFor(GraphStrings.of(context));
      if (_error != null) _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = GraphStrings.of(context);
    _preview ??= _previewFor(strings);
    final preview = _preview!;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'y =',
                hintText: strings.expressionHint,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              // 中文：这是**嵌套**在对话框内容里的面板 ⇒ 取嵌套层的 **12**（本应用 4 处嵌套色块全部是 12）。
              //       10 在本应用只属于"固定尺寸小方格"那一族（78dp 工具卡、`DetailMetric`），而这个不是——
              //       它宽度是 `double.infinity`，跟着对话框走。
              // English: this panel is **nested** inside a dialog's content ⇒ the nested tier's **12** (all four
              //          nested tinted blocks in this app are 12). The 10 belongs to the fixed-size tile family
              //          (the 78dp tool tile, `DetailMetric`); this is not one — its width is `double.infinity`.
              padding: const EdgeInsets.all(12),
              decoration: softPanel(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_preview!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    preview.message,
                    style: TextStyle(
                      color: preview.isValid
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final preview = _previewFor(GraphStrings.of(context));
    if (!preview.isValid) {
      setState(() {
        _preview = preview;
        _error = preview.errorMessage;
      });
      return;
    }
    Navigator.pop(context, preview.normalizedExpression);
  }
}
