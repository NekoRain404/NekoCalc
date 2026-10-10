import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../application/controllers/expression_selection.dart';
import '../calculator_strings.dart';

/// A native text editing surface whose value is owned by the calculator state.
class InlineExpressionEditor extends StatefulWidget {
  const InlineExpressionEditor({
    required this.expression,
    required this.selection,
    required this.onExpressionChanged,
    required this.onSelectionChanged,
    required this.onFocusLost,
    required this.onPastePointerDown,
    required this.onPasteGestureEnded,
    required this.onPasteCalculatorDetails,
    required this.style,
    this.requestFocus = false,
    super.key,
  });

  final String expression;
  final ExpressionSelection selection;
  final ValueChanged<String> onExpressionChanged;
  final ValueChanged<ExpressionSelection> onSelectionChanged;
  final VoidCallback onFocusLost;
  final VoidCallback onPastePointerDown;
  final VoidCallback onPasteGestureEnded;
  final Future<void> Function() onPasteCalculatorDetails;
  final TextStyle style;
  final bool requestFocus;

  @override
  State<InlineExpressionEditor> createState() => _InlineExpressionEditorState();
}

class _InlineExpressionEditorState extends State<InlineExpressionEditor> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late final FocusNode _pasteFocusNode;
  bool _updatingFromController = false;
  bool _focusWasRequested = false;
  bool _wasFocused = false;
  bool _suppressFocusLoss = false;
  bool _pasteGestureActive = false;
  bool _pasteActionStarted = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController.fromValue(_editingValue());
    _focusNode = FocusNode();
    _pasteFocusNode = FocusNode(canRequestFocus: false);
    _textController.addListener(_synchronizeToCalculator);
    _focusNode.addListener(_handleFocusChange);
    _requestFocusIfNeeded();
  }

  @override
  void didUpdateWidget(covariant InlineExpressionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_updatingFromController &&
        (_textController.text != widget.expression ||
            _textController.selection != _textSelection)) {
      _updatingFromController = true;
      _textController.value = _editingValue();
      _updatingFromController = false;
    }
    _requestFocusIfNeeded();
  }

  TextEditingValue _editingValue() => TextEditingValue(
        text: widget.expression,
        selection: _textSelection,
      );

  TextSelection get _textSelection => TextSelection(
        baseOffset: widget.selection.start,
        extentOffset: widget.selection.end,
      );

  void _requestFocusIfNeeded() {
    if (!widget.requestFocus || _focusWasRequested) return;
    _focusWasRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _synchronizeToCalculator() {
    if (_updatingFromController) return;
    final value = _textController.value;
    if (value.text != widget.expression) {
      widget.onExpressionChanged(value.text);
    }
    final selection = ExpressionSelection(
      value.selection.start < 0 ? 0 : value.selection.start,
      value.selection.end < 0 ? 0 : value.selection.end,
    );
    if (selection != widget.selection) widget.onSelectionChanged(selection);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _wasFocused = true;
    } else if (_wasFocused && !_suppressFocusLoss) {
      widget.onFocusLost();
    }
  }

  void _beginPasteGesture() {
    _suppressFocusLoss = true;
    _pasteGestureActive = true;
    _pasteActionStarted = false;
    widget.onPastePointerDown();
  }

  void _endPasteGesture() {
    if (!_pasteGestureActive) return;
    _pasteGestureActive = false;
    _suppressFocusLoss = false;
    widget.onPasteGestureEnded();
  }

  void _resolvePasteGesture() {
    scheduleMicrotask(() {
      if (mounted && !_pasteActionStarted) _endPasteGesture();
    });
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_synchronizeToCalculator)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _pasteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CalculatorStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('inline-expression-editor'),
            controller: _textController,
            focusNode: _focusNode,
            style: widget.style,
            textAlign: TextAlign.right,
            textAlignVertical: TextAlignVertical.center,
            maxLines: 2,
            minLines: 1,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Listener(
          onPointerDown: (_) => _beginPasteGesture(),
          onPointerCancel: (_) => _endPasteGesture(),
          onPointerUp: (_) => _resolvePasteGesture(),
          child: Tooltip(
            // 中文：提示语走 `CalculatorStrings`（`pasteDetailsTooltip`），不再在源码里写中文字面量——
            //       否则英文界面上这个 Tooltip 仍然是中文。
            // English: the tooltip goes through `CalculatorStrings` (`pasteDetailsTooltip`) rather than a
            //          Chinese literal here, which used to keep this Tooltip Chinese in the English UI.
            message: strings.pasteDetailsTooltip,
            child: IconButton(
              onPressed: () async {
                _pasteActionStarted = true;
                try {
                  await widget.onPasteCalculatorDetails();
                } finally {
                  _endPasteGesture();
                  if (mounted) _focusNode.requestFocus();
                }
              },
              focusNode: _pasteFocusNode,
              icon: const Icon(Icons.content_paste_outlined),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            ),
          ),
        ),
      ],
    );
  }
}
