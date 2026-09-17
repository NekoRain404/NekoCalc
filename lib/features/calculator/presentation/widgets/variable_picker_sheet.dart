import 'package:flutter/material.dart';

/// 中文：**一个变量此刻的样子**——面板只读它，不自己去问控制器。名字是小写（`x`/`y`），
///       [value] 是它绑着的十进制文本，未赋值时是 `null`。
/// English: **how one variable looks right now** — the sheet only reads this and never asks the
///          controller itself. The name is lower case (`x`/`y`) and [value] is the decimal text it is
///          bound to, `null` while unassigned.
@immutable
class VariableReading {
  const VariableReading({required this.name, required this.value});

  final String name;
  final String? value;

  bool get isBound => value != null;
}

/// 中文：**`X` 键打开的那个面板**——变量的两个动作（插入那个字母、给它一个值）都在这里，
///       因为键盘上没有字母键，而且值总得有个入口。
///
///       **为什么是一个面板，而不是「`X` 直接插入 `x`」**：没有面板就没有任何地方能给 `x` 一个值，
///       于是 `X` 只会产出一类**永远答不出来的表达式**（`2x` 永远是符号式）——正是这个项目上一轮
///       为 `sum(` 那几颗键消灭掉的「只产出坏表达式的键」。这也正是 `CONV` 的形状：键盘产不出的
///       记号（那里是单位名，这里是变量的字母与它的值）由一颗键打开的面板送进表达式。
///
///       **为什么不是「`X` 插入 `x=`」**：这个键盘上的 `=` 是**提交**键，而赋值不是一次计算。要让
///       `=` 有时表示赋值，提交路径、历史、笔记、`Ans`/`last`、去重键全都要学会第二种输入形状，
///       而它们今天都只认「一条表达式算出一个结果」。赋值不是表达式语法的一部分，所以它不进表达式。
///
///       **面板不自动关闭**（与 `CONV` 一致）：一次「先插 `x`、再存一个值」要按两下，每按一下都关掉
///       面板的话用户要开两次。插入与「存入」都不关；点面板外或按返回键关闭。
///
///       **「存入当前值」在屏幕上没有可存的值时是灰的**，而那不是排版：控制器的
///       `storableVariableValue` 在结果没有十进制形态（符号结果、矩阵、复数、带单位）、不是有限数、
///       或者小到装不下时会给出 `null`，按钮跟着置灰。**看得见的拒绝**比按下去没反应好，也比存进去
///       一个 0 好——记忆寄存器以前就是那样静默地变成 0 的。
///
/// English: **the sheet the `X` key opens** — both of a variable's actions (insert the letter, give it a
///          value) live here, because the keypad has no letter keys and a value has to have an entrance
///          somewhere.
///
///          **Why a sheet rather than "`X` inserts `x` directly"**: without one there is nowhere to give
///          `x` a value, so `X` could only produce one kind of **permanently unanswerable expression**
///          (`2x` stays symbolic forever) — exactly the "key that only produces broken expressions"
///          this project removed for the `sum(` family a round ago. It is also `CONV`'s shape: a token
///          the keypad cannot produce (there a unit name, here the variable's letter *and* its value)
///          is delivered into the expression by a sheet a key opens.
///
///          **Why not "`X` inserts `x=`"**: on this keypad `=` is the **submit** key, and an assignment
///          is not a calculation. Making `=` sometimes mean "assign" would require the submit path,
///          history, notes, `Ans`/`last` and the de-duplication key to learn a second input shape,
///          while today they all understand exactly one thing: an expression that evaluates to a
///          result. An assignment is not part of the expression grammar, so it does not enter the
///          expression.
///
///          **The sheet does not close itself** (as with `CONV`): "insert `x`, then store a value" is
///          two presses, and closing after each would make the user open it twice. Neither the inserts
///          nor "store" close it; tapping outside or the back button does.
///
///          **"Store current value" is greyed out when the screen has nothing storable**, and that is
///          not decoration: the controller's `storableVariableValue` returns `null` when the result has
///          no decimal form (a symbolic result, a matrix, a complex number, a unit-carrying one), is
///          not a finite number, or is too small to fit, and the button follows. **A visible refusal**
///          beats a dead button, and it beats storing a 0 — which is how the memory register used to
///          turn into 0 without a word.
class VariablePickerSheet extends StatelessWidget {
  const VariablePickerSheet({
    required this.readings,
    required this.storableValue,
    required this.onInsert,
    required this.onAssign,
    required this.onClear,
    super.key,
    this.onClose,
  });

  /// 中文：两个变量此刻的样子（顺序就是显示顺序）。
  /// English: how the two variables look right now (in display order).
  final List<VariableReading> readings;

  /// 中文：**屏幕上此刻可以存进变量的那个值**（十进制文本），没有可存的值时是 `null`。
  /// English: **the value on screen that could be stored into a variable right now** (decimal text),
  ///          or `null` when there is nothing storable.
  final String? storableValue;

  /// 中文：把一个变量名（插入的是**字母**，不是值）插进表达式。
  /// English: insert a variable's **letter** (not its value) into the expression.
  final ValueChanged<String> onInsert;

  /// 中文：把某个变量绑到当前值上。
  /// English: bind a variable to the current value.
  final ValueChanged<String> onAssign;

  /// 中文：解绑某个变量。
  /// English: unbind a variable.
  final ValueChanged<String> onClear;

  /// 中文：关闭面板；为 null 时不显示关闭按钮（测试里直接构造面板时就是这种）。
  /// English: closes the sheet; when null no close button is shown (which is the case when a test
  ///          builds the sheet directly).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '变量',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            // 中文：当前值读数是**存进去的那个数**的预览，所以它与按钮同亮同灭：写着「没有可存入的
            //       数值」而按钮还亮着，就是两个判断点。
            // English: the reading is a preview of **the number that would be stored**, so it lights up
            //          and goes dark with the button: "nothing storable" beside a live button would be
            //          two judgement points.
            Text(
              storableValue == null
                  ? '当前没有可存入的数值（结果没有十进制形态，或者不是有限数）'
                  : '当前值 $storableValue',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final reading in readings) ...[
              _variableRow(context, reading),
              const SizedBox(height: 8),
            ],
            if (onClose != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClose,
                  child: const Text('关闭'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _variableRow(BuildContext context, VariableReading reading) {
    final theme = Theme.of(context);
    final canAssign = storableValue != null;
    return Row(
      children: [
        // 中文：名字按**数学排版**印（斜体变量），与表达式里那个 `x` 是同一种东西。
        // English: the name is printed as **mathematics** (an italic variable) — the same thing as the
        //          `x` in the expression.
        SizedBox(
          width: 28,
          child: Text(
            reading.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            reading.isBound ? '= ${reading.value}' : '未赋值',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: () => onInsert(reading.name),
          child: Text('插入 ${reading.name}'),
        ),
        TextButton(
          onPressed: canAssign ? () => onAssign(reading.name) : null,
          child: const Text('存入当前值'),
        ),
        TextButton(
          onPressed: reading.isBound ? () => onClear(reading.name) : null,
          child: const Text('清除'),
        ),
      ],
    );
  }
}
