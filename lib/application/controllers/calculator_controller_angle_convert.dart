part of 'calculator_controller.dart';

/// 中文：**`►DRG`（HiPER 的 `TO_DRG`）那一次角度换算。**
///
///       **厂商那一格是什么**：手册第 678 行把 `►DRG` 说全了——"►DRG key in compact layout opens
///       the menu to choose source and target angular units and converts the current display
///       number."，`command.name.TO_DRG` = "Convert Angular Units"。**两件事都在这里**：面板负责
///       「选源与目标」（`calculator_page_angle_sheet.dart`），这个混因负责「换算**当前显示的那个数**」。
///
///       ### 一、要换算的是哪个数：当前结果，判据与四个进制胶囊逐条相同
///
///       [angleConvertValue] 读的是 `_result.decimalText`，两条门槛：**没有错误**、**有有限十进制
///       形态**。这与 `showBaseReadout` 的 `hasError || !source.hasFiniteDecimal` 是**同一对判据**，
///       理由也同一套——「当前显示的那个数」在这个应用里就是结果行，而**唯一允许被解析成数字的字段
///       是 `decimalText`**（`MathResult` 那一段）。所以：
///       - 结果是一个**量**（`5 km`）或一个符号式（`2x`）时**换算不了**：它们没有有限十进制形态，
///         把 `5 km` 当成一个数去换算是把两件事混在一起；
///       - 出错时换算不了（那时结果行上的东西不是答案）；
///       - 表达式为空时结果是**屏幕上的那个 `0`**（`MathResult.zero`，状态行就写着"当前值 0"），
///         于是它换算得了——`0 deg to rad` 是一句真话，不是替用户编出来的默认值。
///
///       **没有可用的数时什么都不发生**：面板上那两行是灰的（同一句话写在面板里），这个方法返回
///       `false`，表达式、光标、结果**一个字节都不动**。
///
///       ### 二、做出来的动作：**整条表达式换成那一次换算**
///
///       HiPER 那一格换的是**显示的那个数**，所以这里换的是**整个表达式**：`5` → `5 deg to rad`。
///       为什么不是「往光标处插一段」——**插进去的文本会与已经在表达式里的东西粘成一个别的式子**：
///       `2+3` 后面插 ` deg to rad` 得到 `2+3 deg to rad`，而 `to` 比 `+` 松，那一步换算的是 `3`
///       而不是结果行上的 `5`（屏幕上看得出来，但那已经不是用户要的那件事了）。整条换掉没有这个
///       状态：表达式**就是**那一次换算，值就是刚才显示的那个数。
///
///       形状与 `continueWithResult` 逐条相同（那一条也是把结果写回表达式）：记撤销快照 →
///       写表达式 → 光标落到末尾 → `evaluate()` → 落盘 → 通知。所以**一次撤销就能拿回原来的
///       表达式**，与「继续使用」的代价一样。
///
///       ### 三、角度模式一个字节都不动
///
///       这个方法不读也不写 `angleMode`：那条 `'DEG'`/`'RAD'` 状态是 `DRG` 那颗键的事，而这里是
///       一次换算。两者在结果上也不互相干扰——**两侧单位都写出来时引擎的答案与角度模式无关**
///       （实测：`90 deg to rad` 在 `angle unit deg|rad|gra` 三档下都是 `1.570796327 rad`；
///       表在 `app_unit_catalog.dart` 的 `kAngleUnits` 上）。
///
/// English: **the angle conversion behind `►DRG` (HiPER's `TO_DRG`).**
///
///          **What the vendor's cell is**: manual line 678 states it in full — "►DRG key in compact
///          layout opens the menu to choose source and target angular units and converts the current
///          display number." — and `command.name.TO_DRG` = "Convert Angular Units". **Both halves live
///          here**: the sheet owns "choose a source and a target"
///          (`calculator_page_angle_sheet.dart`) and this mixin owns "convert **the number currently
///          displayed**".
///
///          ### 1. Which number gets converted: the current result, on the base pills' own two tests
///
///          [angleConvertValue] reads `_result.decimalText` behind two gates: **no error** and **a
///          finite decimal form**. That is the **same pair** `showBaseReadout` uses
///          (`hasError || !source.hasFiniteDecimal`), for the same reasons — "the number currently
///          displayed" is this app's result line, and **the only field allowed to be parsed as a
///          number is `decimalText`** (the `MathResult` note). So:
///          - a result that is a **quantity** (`5 km`) or a symbolic form (`2x`) **cannot be
///            converted**: neither has a finite decimal form, and treating `5 km` as a number to
///            convert would mix two different things;
///          - an error state cannot be converted (what is on the result line then is not an answer);
///          - with an empty expression the result is **the `0` on screen** (`MathResult.zero`, and the
///            status row reads "当前值 0"), so it *can* be converted — `0 deg to rad` is a true
///            sentence, not a default invented for the user.
///
///          **With no usable number nothing happens at all**: the sheet's two rows are grey (the same
///          sentence is written in the sheet), this method returns `false`, and the expression, the
///          caret and the result **do not move a byte**.
///
///          ### 2. What it does: **the whole expression becomes that one conversion**
///
///          HiPER's cell converts **the displayed number**, so what is replaced here is the **whole
///          expression**: `5` → `5 deg to rad`. Why not "insert a piece at the caret" — **inserted
///          text glues onto whatever is already in the expression and means something else**: `2+3`
///          plus ` deg to rad` gives `2+3 deg to rad`, and since `to` binds looser than `+` that
///          conversion converts the `3` rather than the `5` on the result line (visible on screen, but
///          no longer the thing the user asked for). Replacing the whole expression has no such state:
///          the expression **is** that one conversion, over the number that was just displayed.
///
///          Its shape is item-for-item `continueWithResult`'s (which also writes the result back into
///          the expression): record an undo snapshot → write the expression → put the caret at the
///          end → `evaluate()` → persist → notify. So **one undo brings the old expression back**, at
///          the same price "continue with result" charges.
///
///          ### 3. The angle mode does not move a byte
///
///          This method neither reads nor writes `angleMode`: that `'DEG'`/`'RAD'` state belongs to the
///          `DRG` key, while this is one conversion. Nor do the two interfere in the answer — **with
///          both units written out the engine's answer does not depend on the angle mode** (measured:
///          `90 deg to rad` gives `1.570796327 rad` under `angle unit deg|rad|gra` alike; the table is
///          on `kAngleUnits` in `app_unit_catalog.dart`).
mixin _CalculatorAngleConvert on _CalculatorState {
  /// 中文：**这次换算要换算的那个数**；没有可用的数时是 `null`（判据见文件头第 1 节）。
  ///
  ///       读它的有两处，判断只有这一处：面板拿它决定那两行按不按得动、并把值念给用户看；
  ///       [convertAngle] 拿它做最后一道守卫（面板开着的时候引擎跟进回来、结果换了，那一下就不该
  ///       再按着一个已经不在屏幕上的数换算）。
  /// English: **the number this conversion would convert**, or `null` when there is none (the tests
  ///          are in the file head's item 1).
  ///
  ///          Two readers, one judgement: the sheet uses it to decide whether its two rows can be
  ///          pressed and to read the value out to the user, and [convertAngle] uses it as the last
  ///          guard (if the engine's follow-up lands while the sheet is open and the result changes,
  ///          that press must not convert a number that is no longer on screen).
  String? get angleConvertValue {
    if (hasError) return null;
    final result = _result;
    if (!result.hasFiniteDecimal) return null;
    return result.decimalText;
  }

  /// 中文：把当前值从 `sourceUnit` 换算到 `targetUnit`——**整条表达式换成那一次换算**（文件头
  ///       第 2 节），随后照常求值。返回「这一次做成了没有」：`false` 表示**什么都没改**（没有可用的
  ///       数，或者单位拼法不在那张闭集里），调用方据此给用户一句解释。
  ///
  ///       两个单位拼法都必须在 [kAngleUnits] 里：面板只会递来表里的拼法，这一条是**边界上的守卫**
  ///       （到了这里就说明有一处没接住），而且它与翻译层那扇门读的是**同一张表**——就算这一步漏了，
  ///       翻译层也到不了引擎。
  /// English: converts the current value from `sourceUnit` to `targetUnit` — **the whole expression
  ///          becomes that one conversion** (file head item 2) — and then evaluates as usual. It
  ///          returns whether this one worked: `false` means **nothing changed at all** (no usable
  ///          number, or a spelling outside that closed set), and the caller turns that into one
  ///          sentence for the user.
  ///
  ///          Both spellings have to be in [kAngleUnits]: the sheet only hands over spellings from
  ///          that table, and this clause is the **guard at the boundary** (reaching it means something
  ///          upstream did not catch the case). It reads the **same table** the translation's door
  ///          does — so even if this step let something through, the translation would not reach the
  ///          engine.
  bool convertAngle(String sourceUnit, String targetUnit) {
    final value = angleConvertValue;
    if (value == null) return false;
    if (!isAngleUnit(sourceUnit) || !isAngleUnit(targetUnit)) return false;
    _markStateEdited();
    _recordUndoSnapshot();
    expression = angleConversionCall(value, sourceUnit, targetUnit);
    cursorIndex = expression.length;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
    return true;
  }
}
