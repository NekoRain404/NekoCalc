part of 'calculator_page.dart';

/// 中文：`FSE` 那一颗键的派发。**它单独一个文件，是因为 `calculator_key_dispatch.dart` 已经 794 行**
///       ——800 行的硬上限在那里只剩六行，而这条派发要带自己的理由。同一种拆法主会话已经用过一次
///       （`hiper_keypad.dart` 799 行时拆成功能区/数字区两个 part）。
///
///       形状与同一文件夹里的 `_showBaseReadout` 逐条相同：问控制器要一句话，有话说才交给用户。
///       走同一条通道的理由也一样——用户按了一个键，而这一次没成；不说的话屏幕上什么都没有，
///       看起来像按键失灵。成功（读数换好了，或者回到了 Normal）回 `null`，这里什么都不做。
///
/// English: the dispatch for the `FSE` key. **It lives in a file of its own because
///          `calculator_key_dispatch.dart` is already at 794 lines** — six lines short of the hard
///          800-line ceiling, and this dispatch wants to carry its reason. The same split was used
///          once before (`hiper_keypad.dart` at 799 lines became the function-rows / number-rows
///          parts).
///
///          Its shape is item-for-item `_showBaseReadout`'s in the same folder: ask the controller for
///          a sentence and hand it to the user only when there is one. It takes the same channel for
///          the same reason — the user pressed a key and this time it did not work; unsaid, the screen
///          shows nothing and it reads as a dead key. On success (the read-out was replaced, or Normal
///          removed it) the controller returns `null` and nothing happens here.
extension _CalculatorNotationDispatch on _CalculatorPageState {
  Future<void> _cycleNotation() async {
    final message = await _controller.cycleNotation();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
