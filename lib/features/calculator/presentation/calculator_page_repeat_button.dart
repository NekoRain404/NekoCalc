part of 'calculator_page.dart';

/// 中文：`More...` 面板里那两个「按住连发」的光标键。它们从这里而不是 `calculator_page_sheets.dart`
///       出来，只有一个原因：那个文件正好压在**每文件 800 行**这条硬上限上（`wc -l` 实测 800），
///       往里加任何一行都会越线。这一对组件与面板的其余部分**没有任何耦合**（色值、图标、三个
///       回调全部由构造参数进来），所以它是那个文件里最干净的一刀——搬出来之后两边都宽裕。
///
/// English: the two hold-to-repeat cursor keys inside the `More...` sheet. They live here rather than
///          in `calculator_page_sheets.dart` for exactly one reason: that file sits precisely on the
///          **800-lines-per-file** hard cap (measured 800 by `wc -l`), so any added line would cross
///          it. This widget pair has **no coupling** to the rest of the sheet (the colours, the icon
///          and all three callbacks arrive as constructor parameters), which makes it the cleanest
///          cut in that file — both sides have room to breathe afterwards.
class _RepeatableCursorButton extends StatefulWidget {
  const _RepeatableCursorButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
    required this.onBlockMove,
    required this.onRepeat,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final VoidCallback onBlockMove;
  final VoidCallback onRepeat;

  @override
  State<_RepeatableCursorButton> createState() =>
      _RepeatableCursorButtonState();
}

class _RepeatableCursorButtonState extends State<_RepeatableCursorButton> {
  static const _repeatInterval = Duration(milliseconds: 80);
  Timer? _repeatTimer;

  void _startRepeat(LongPressStartDetails details) {
    widget.onBlockMove();
    _repeatTimer ??= Timer.periodic(_repeatInterval, (_) => widget.onRepeat());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      onLongPress: widget.onBlockMove,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPressStart: _startRepeat,
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.borderColor),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}
