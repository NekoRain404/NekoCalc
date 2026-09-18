import 'package:flutter/material.dart';

import '../calculator_strings.dart';

/// 中文：**`STAT` 背后的数据集的编辑面板。** 它只做一件事：让「一组值」有个能被编辑、能被留下的
///       存放处。四个统计函数那几格仍然在 `STAT` 面板上（那里是 HiPER 的 `STATISTICS_MENU`），
///       这个面板**不重复它们**——一个按钮只有一个落点，是本仓库一贯的做法。
///
///       **它为什么存在**：上一轮把数据集放在表达式那串实参里，于是「存住一份数据、反复用」这件事
///       不存在——表达式一改，数据就没了。HiPER 自己的帮助文本（`help.statistics.contents`）把
///       这件事分成两个动作：「选一个函数，**插入一组值**」与「把一组值存下来以便反复用」。
///       这个面板就是后者。
///
///       **值只有一条进来的路**：[storableValue] 就是控制器那道判据（`storableDatasetValue`）
///       此刻的答案——屏幕上那个结果的十进制文本，且必须过 `MathResult.decimalValueOf`。所以这里
///       **没有输入框**：一个「把用户打的字切成若干个数」的解析器是这个应用里没有的东西，而它的
///       每一个判断（`1,5` 是一个数还是两个、`1 2 3` 怎么切、打错了怎么说）都要重新发明一遍，
///       而每一处发明都可能是一个静默的错值。所以数据集的值**只能**来自屏幕上那个已经被判过的
///       结果：**按下去的时候屏幕上写着什么，进去的就是什么**。
///
///       按钮的可用态与读数同亮同灭（与 `VariablePickerSheet` 同一条）：没有可加的值时「加入当前
///       结果」是灰的，而**看得见的拒绝**比按下去没反应好。
///
/// English: **the sheet that edits the dataset behind `STAT`.** It does one thing: give a "set of
///          values" a home that can be edited and that stays. The four statistics cells stay on the
///          `STAT` sheet (that is HiPER's `STATISTICS_MENU`); this sheet **does not repeat them** —
///          one button, one landing place, as this repository has it.
///
///          **Why it exists**: last round the dataset was the argument list written in the expression,
///          so "keep a set of data and reuse it" did not exist — edit the expression and the data is
///          gone. HiPER's own help text (`help.statistics.contents`) splits this into two actions:
///          "select a function and **insert a set of values**", and keeping a set of values so it can
///          be reused. This sheet is the second one.
///
///          **Values have exactly one way in**: [storableValue] is what the controller's judgement
///          (`storableDatasetValue`) answers right now — the decimal text of the result on screen, and
///          it must pass `MathResult.decimalValueOf`. So there is **no text field here**: a parser that
///          cuts typed characters into numbers is something this app does not have, and every
///          judgement it would need (`1,5` is one number or two, how `1 2 3` splits, what to say when
///          it is wrong) would have to be invented afresh — and each invention could be a silently
///          wrong value. A dataset value therefore **only** ever comes from the result on screen that
///          has already been judged: **what the screen says when the button is pressed is what goes
///          in**.
///
///          The buttons share one judgement with the reading (as in `VariablePickerSheet`): "add
///          current result" is grey while nothing is storable, and **a visible refusal** beats a dead
///          button.
class DatasetSheet extends StatelessWidget {
  const DatasetSheet({
    required this.values,
    required this.storableValue,
    required this.callArguments,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
    super.key,
    this.onClose,
  });

  /// 中文：数据集此刻的样子（十进制文本，按加入顺序）。
  /// English: how the dataset looks right now (decimal text, in insertion order).
  final List<String> values;

  /// 中文：**此刻可以加进数据集的那个值**（屏幕上结果的十进制文本），没有可加的值时是 `null`。
  /// English: **the value that could be added right now** (the decimal text of the result on screen),
  ///          or `null` when there is nothing addable.
  final String? storableValue;

  /// 中文：**数据集为空时面板会插进去的实参**（`1,2,3,4`）。印出来是为了让「数据集是空的，插的将是
  ///       起手数据」这件事在屏幕上有据可查——不说，用户按下去就会凭空多出一串自己没打过的数字。
  /// English: **the arguments the sheet would insert while the dataset is empty** (`1,2,3,4`). It is
  ///          printed so "the dataset is empty, so the starting sample will be inserted" is on screen:
  ///          unsaid, a press would produce a run of digits the user never typed.
  final String callArguments;

  /// 中文：把当前值加进数据集。控制器有话要说时（没有可加的值 / 到顶了）返回那句话，面板把它显示出来。
  /// English: add the current value to the dataset. When the controller has something to say (nothing
  ///          addable / at the cap) it returns that sentence and the sheet shows it.
  final String? Function() onAdd;

  /// 中文：去掉第几个值。
  /// English: drop the value at this index.
  final ValueChanged<int> onRemove;

  final VoidCallback onClear;

  /// 中文：关闭面板；为 null 时不显示关闭按钮（测试里直接构造面板时就是这种）。
  /// English: closes the sheet; when null no close button is shown (which is the case when a test
  ///          builds the sheet directly).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = CalculatorStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.datasetSheetTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                values.isEmpty
                    ? strings.datasetEmptyReading(callArguments)
                    : strings.datasetValuesReading(values.length),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (values.isEmpty)
                Text(strings.noDatasetValues, style: theme.textTheme.bodyMedium)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < values.length; index++)
                      _valueChip(context, index),
                  ],
                ),
              const SizedBox(height: 12),
              // 中文：与变量面板那句逐字同一种做法：读数是**会加进去的那个数**的预览，所以它与按钮
              //       同亮同灭。值本身就是引擎那串未取整的十进制——这里不按精度取整，取整会让加进去
              //       的与屏幕上显示的不是同一个数。
              // English: byte for byte the device the variable sheet uses: the reading is a preview of
              //          **the number that would go in**, so it lights up and goes dark with the button.
              //          The value is the engine's unrounded decimal — nothing is rounded by precision
              //          here, since that would make what goes in differ from what is on screen.
              Text(
                storableValue == null
                    ? strings.noAddableValue
                    : strings.addCurrentResultReading(storableValue!),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed:
                        storableValue == null ? null : () => _add(context),
                    child: Text(strings.addCurrentResult),
                  ),
                  TextButton(
                    onPressed: values.isEmpty ? null : onClear,
                    child: Text(strings.clearDataset),
                  ),
                  const Spacer(),
                  if (onClose != null)
                    TextButton(onPressed: onClose, child: Text(strings.close)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 中文：一个值一格，点它就去掉——去值是**破坏性**动作，所以文案写成「去掉」，不用叉号：
  ///       键盘式的界面里一个没有文字的图标更容易被误按。
  /// English: one cell per value, and tapping it drops that value — removal is **destructive**, so the
  ///          label says "drop" rather than using a cross: an unlabelled icon in a keypad-shaped
  ///          interface is easier to hit by accident.
  Widget _valueChip(BuildContext context, int index) {
    final theme = Theme.of(context);
    return InputChip(
      label: Text(values[index]),
      onDeleted: () => onRemove(index),
      deleteButtonTooltipMessage:
          CalculatorStrings.of(context).removeValueTooltip,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.bodyMedium,
    );
  }

  /// 中文：加值。控制器的话（被拒时那句）显示在面板自己的 `SnackBar` 上——面板盖着屏幕底部，但那句
  ///       话要落在用户能看到的地方。成功时不说话（成功是常态）。
  /// English: add a value. The controller's sentence (the refusal) goes on the sheet's own
  ///          `SnackBar` — the sheet covers the bottom of the screen, but the sentence has to land
  ///          somewhere the user can see. On success it says nothing (success is the normal case).
  void _add(BuildContext context) {
    final message = onAdd();
    if (message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
