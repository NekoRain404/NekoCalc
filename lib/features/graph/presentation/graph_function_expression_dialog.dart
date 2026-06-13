import 'package:flutter/material.dart';

import '../../../shared/presentation/app_chrome.dart';
import '../models/graph_models.dart';

class FunctionExpressionDialog extends StatefulWidget {
  const FunctionExpressionDialog({
    required this.title,
    required this.initialExpression,
    required this.confirmLabel,
  });

  final String title;
  final String initialExpression;
  final String confirmLabel;

  @override
  State<FunctionExpressionDialog> createState() =>
      _FunctionExpressionDialogState();
}

class _FunctionExpressionDialogState extends State<FunctionExpressionDialog> {
  late final TextEditingController _controller;
  String? _error;
  GraphFunctionInputPreview _preview = GraphFunctionInputPreview.empty();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialExpression);
    _preview = previewGraphFunctionInput(
      widget.initialExpression,
      color: const Color(0xFF1677FF),
    );
    _controller.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _preview = previewGraphFunctionInput(
        _controller.text,
        color: const Color(0xFF1677FF),
      );
      if (_error != null) _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: '例如 sin(x)、2x + 1、y = x^2 - 3x + 2',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: softPanel(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_preview.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    _preview.message,
                    style: TextStyle(
                      color: _preview.isValid
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
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final preview = previewGraphFunctionInput(
      _controller.text,
      color: const Color(0xFF1677FF),
    );
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

