part of 'calculator_controller.dart';

/// 中文：**数据集最多放多少个值。**
///
///       这是我定的上限，不是从来源抄来的——写下来是为了不让它被当成规格：HiPER 那一侧
///       「一组值」是一个行矩阵，它没有把个数写在帮助文本里。它存在的理由是**落盘**：数据集整份
///       写进设置表的**一个**键（`calculator_dataset`），而这个键会在每一次按键之后重写一遍
///       （`_persistState` 的老规矩），所以它必须有界。到顶时 [CalculatorController.addDatasetValue]
///       拒绝并**说出话来**（与记忆寄存器那三个键同一种做法），不是静默丢掉最后一个值。
///
///       40 是撤销栈深度（`_maxUndoDepth`）那个量级：够放下一份真正的样本，又不至于让每次落盘
///       都写一大串。改它可以，但要连同下面那条测试一起改。
///
/// English: **how many values the dataset may hold.**
///
///          This cap is my call, not a number copied from a source — it is written down here so it is
///          not mistaken for a specification: on HiPER's side a "set of values" is a row matrix, and
///          its help text states no size. What makes it necessary is **persistence**: the whole
///          dataset is written into **one** settings key (`calculator_dataset`) that is rewritten
///          after every keypress (the long-standing `_persistState` rule), so it has to be bounded. At
///          the cap [CalculatorController.addDatasetValue] refuses and **says so** (the shape the
///          three memory keys use) rather than silently dropping the value.
///
///          It sits at the order of the undo stack's depth (`_maxUndoDepth`): room for a real sample
///          without making every persist write a long string. Changing it is fine — change the test
///          that pins it along with it.
const int kMaxDatasetValues = 40;

/// 中文：**数据集里一个值都没有时，面板插进去的那串实参。** 它就是这一轮之前写死在
///       `ins:mean` 那几条 case 里的起手数据；放在这里是因为现在「插什么实参」由数据集决定
///       （[CalculatorController.datasetCallArguments] 是唯一那一处），而数据集为空时插的就是它。
///       于是「没有数据集」这一条路与本轮之前**逐字节相同**。
///
/// English: **the argument list the sheet inserts while the dataset holds nothing.** It is exactly the
///          starting sample that used to be hardcoded in the `ins:mean` cases; it lives here because
///          the dataset now decides what is inserted
///          ([CalculatorController.datasetCallArguments] is the single place that decides), and this
///          is what an empty dataset inserts. So the "no dataset" path is **byte for byte** what it
///          was before this round.
const List<String> _statisticsStartingSample = <String>['1', '2', '3', '4'];

/// 中文：**把数据集读成两行时，每行至少要有几个值。**
///
///       2 是**量出来的下限**，不是我挑的：一对值时 `covar(matrix(2,1,1,2))` 给一个没有信息的
///       `0`，而 `pearson(matrix(2,1,1,2))` 给的是**未求值的 `0 / 0`**（宿主 `qalc` 5.12.0，
///       与本 AAR 同版本）。`0 / 0` 是一个式子，不是数——引擎把它原样退回来，而这个应用对
///       「退回来的式子」那一支（`arithmetic`）是不显示的，所以屏幕上会是一句错误。两句都不是
///       用户要的答案，所以一对时**直接拒绝并说出来**（[CalculatorController.regressionCall]
///       返回 `null`、[CalculatorController.regressionUnavailableMessage] 给出那句话）。
///
///       两对（4 个值）起就是真的了：`pearson(matrix(2,2,1,3,2,4))` = `1`（实测）。
///
/// English: **how many values each row needs when the dataset is read as two rows.**
///
///          The 2 is a **measured floor**, not a choice: with one pair `covar(matrix(2,1,1,2))`
///          returns an uninformative `0` and `pearson(matrix(2,1,1,2))` returns the **unevaluated
///          `0 / 0`** (host `qalc` 5.12.0, the version this AAR bundles). `0 / 0` is an expression, not
///          a number — the engine hands it straight back, and this app does not display that branch
///          (`arithmetic`), so the screen would carry an error. Neither is the answer the user wants,
///          so one pair is **refused outright and said out loud**
///          ([CalculatorController.regressionCall] returns `null` and
///          [CalculatorController.regressionUnavailableMessage] gives the sentence).
///
///          Two pairs (four values) and up is real: `pearson(matrix(2,2,1,3,2,4))` = `1` (measured).
const int kMinRegressionPairs = 2;

/// 中文：**统计数据集住在应用这一侧**——一份十进制文本的表，与变量（`x`/`y`）和记忆寄存器同一
///       种货币（[MathResult.decimalText]），因此也与它们走同一套判据、撤销栈、落盘与代际守卫。
///
///       为什么不是引擎那一侧（把数据集放进引擎的变量表 / 让它持有一个矩阵）：变量那一轮已经量过
///       这条路，理由逐字相同——引擎的表不参与撤销/重做、不参与 `_persistState`、不参与代际守卫，
///       而且**它能装下矩阵、单位与未求值的式子**，那些都没有十进制形态（硬性边界 5 要的是
///       「一个能装进 double 的数」）。把数据集放进去，屏幕上那个「一组值」与引擎算出来的那个
///       迟早来自两个时刻。
///
///       为什么数据集**不是**「表达式里那串实参」（上一轮的做法）：那样一来它随表达式一起被改、
///       一起被清空，「存住一份数据、反复用」这件事本身就不存在了——而那是这个数据集唯一的用处。
///       面板插入的调用因此是**一份副本**（见 [CalculatorController.statisticsCall] 上的注释）：
///       数据集是存放处，表达式里那一条是用户自己在编辑的调用。两者不是同一个东西，所以不是
///       第二个真相源。**HiPER 自己的帮助文本就是这么说的**（`help.statistics.contents`，
///       取法见报告）：「选一个函数，**插入一组值**」；而「把一组值存成变量反复用」是另一个动作。
///
///       一句话说清它与 `Ans`/记忆的关系：**值只进不出**。数据集里的值永远来自屏幕上那一次结果
///       （[storableDatasetValue]，与变量的 `storableVariableValue` 是同一道判据），而数据集
///       从不往结果行、`Ans`/`last`、记忆寄存器里放任何东西——所以它不可能被当成一个结果。
///
/// English: **the statistics dataset lives on this app's side** — a table of decimal text, the same
///          currency as the variables (`x`/`y`) and the memory register
///          ([MathResult.decimalText]), and therefore sharing their judgement, their undo stack, their
///          persistence and their generation guard.
///
///          Why not the engine's side (a dataset in the engine's variable table, or a matrix it holds):
///          the variables round already measured that road and the reasons are byte for byte the same —
///          the engine's table takes no part in undo/redo, in `_persistState` or in the generation
///          guard, and **it can hold matrices, units and unevaluated expressions**, none of which has a
///          decimal form (hard boundary 5 asks for "a number that fits in a double"). Put the dataset
///          there and the set on screen and the set the engine computed would sooner or later come
///          from two different moments.
///
///          Why the dataset is **not** "the argument list written in the expression" (last round's
///          answer): that one is edited and cleared along with the expression, so "keep a set of data
///          and reuse it" — the only thing a dataset is for — does not exist at all. What the sheet
///          inserts is therefore a **copy** (see the note on
///          [CalculatorController.statisticsCall]): the dataset is the store, and the call in the
///          expression is a call the user is editing. They are not the same object, so this is not a
///          second source of truth. **HiPER's own help text says exactly this**
///          (`help.statistics.contents`; how it was fetched is in the report): "select a function and
///          **insert a set of values**"; and "keep a set of values in a variable to reuse it" is a
///          *different* action.
///
///          One sentence for its relation to `Ans`/memory: **values only go in, never out**. A dataset
///          value always comes from the result on screen ([storableDatasetValue], the same judgement
///          the variables' `storableVariableValue` makes), and the dataset never puts anything on the
///          result line, into `Ans`/`last` or into the memory register — so it can never be taken for
///          a result.
mixin _CalculatorDataset on _CalculatorState {
  /// 中文：数据集此刻的样子（十进制文本，按加入顺序）。**只读**——改它走下面四个方法，否则撤销栈、
  ///       落盘与通知就会漏掉。
  /// English: how the dataset looks right now (decimal text, in insertion order). **Read only** —
  ///          changing it goes through the four methods below, or the undo stack, persistence and
  ///          notifications would all miss it.
  List<String> get datasetValues => List<String>.unmodifiable(_dataset);

  /// 中文：数据集里此刻有几个值（面板的读数用）。
  /// English: how many values the dataset holds right now (what the sheet reads).
  int get datasetLength => _dataset.length;

  /// 中文：**可以被加进数据集的那个值**：屏幕上这一次结果的十进制文本，`null` 表示「这一次没有可加的
  ///       数」。判据是 [MathResult.decimalValueOf]——全应用唯一的「这段文本能不能当数字用」
  ///       （提交路径、粘贴路径、记忆寄存器、变量都从它过，硬性边界 6：不给求值侧写第二份判据）。
  ///
  ///       它同时挡掉四样东西：没有十进制形态（符号结果、矩阵、复数、带单位）、不是有限数
  ///       （`Infinity`/`NaN`）、下溢（`2^-2000` 的 `9.3e-603` 解析出来是 `0.0`，那是一个静默的
  ///       错值），以及空。**所以数据集里永远只有有限、可解析、不是下溢的数**——「它能装非数」
  ///       这一条在结构上不成立。
  ///
  ///       取的是**屏幕上那个结果**（[_result]），不是重新解析表达式：「按下去的时候屏幕上写着
  ///       什么」与「进了数据集的是什么」因此是同一句话，与变量的 `storableVariableValue` 逐字
  ///       同一条理由。
  ///
  /// English: **the value that may be added to the dataset**: the decimal text of this evaluation's
  ///          result, or `null` for "nothing addable this time". The judgement is
  ///          [MathResult.decimalValueOf] — the app's single "may this text be used as a number"
  ///          (the submit path, the paste path, the memory register and the variables all come through
  ///          it; hard boundary 6: no second copy of an evaluator-facing judgement).
  ///
  ///          It rejects four things at once: no decimal form at all (symbolic results, matrices,
  ///          complex numbers, unit-carrying results), not a finite number (`Infinity`/`NaN`),
  ///          underflow (`2^-2000`'s `9.3e-603` parses to `0.0`, a silent wrong value) and empty. **So
  ///          the dataset only ever holds finite, parseable, non-underflowed numbers** — "it can hold
  ///          non-numbers" is structurally impossible here.
  ///
  ///          It takes **the result on screen** ([_result]) rather than re-parsing the expression:
  ///          "what the screen says when the button is pressed" and "what went into the dataset" are
  ///          therefore the same sentence, byte for byte the reason `storableVariableValue` gives.
  String? get storableDatasetValue {
    final text = _result.decimalText;
    return MathResult.decimalValueOf(text) == null ? null : text;
  }

  /// 中文：**把屏幕上那个结果加进数据集**。返回值与那三个记忆键同一种形状：`null` = 加进去了，
  ///       一段文字 = 这一次没加，调用方把它交给用户。
  ///
  ///       两个可能的拒绝各有各的话（没有可存的数 / 到顶了），都由这里给出——**判定在这里、界面
  ///       在别处**（那段理由写在 [CalculatorController.memoryAdd] 上），界面拿到一个布尔就只能
  ///       写死一句自己的话，而那句话迟早会与这里的判定漂开。
  ///
  ///       加进去之后**不重新求值**：数据集不是求值的输入（它不进表达式、不进 `_resolveAnswerReferences`），
  ///       所以同一条表达式在加值前后是同一个意思，结果行不该动。这与 `assignVariable` 的分别正在
  ///       这里——那一个必须 `evaluate()`，因为变量**是**求值的输入。
  ///
  ///       但**照样过代际守卫**（`_markStateEdited()`）：那是「状态被改过」的唯一记号，而
  ///       `_restorePersistedState` 用它判断「我读盘期间用户动过没有」——数据集是状态，所以它必须
  ///       把那个记号推一格，否则一次正在进行的恢复会把用户刚加的值覆盖掉。光标键
  ///       （`moveCursorLeft`/`moveCursorRight`）是同一条先例：也不影响求值，也推这一格。
  ///
  /// English: **add the result on screen to the dataset.** The return value has the shape the three
  ///          memory keys use: `null` means it went in, a sentence means it did not and the caller
  ///          hands it to the user.
  ///
  ///          The two possible refusals each have their own sentence (nothing storable / at the cap),
  ///          and both are worded here — **the judgement is here and the screen is elsewhere** (that
  ///          argument is on [CalculatorController.memoryAdd]), so a bool would leave the screen
  ///          hard-coding a sentence of its own that would sooner or later drift from this judgement.
  ///
  ///          Nothing is **re-evaluated** afterwards: the dataset is not an input to evaluation (it
  ///          enters neither the expression nor `_resolveAnswerReferences`), so one and the same
  ///          expression means the same thing either side of adding a value and the result line must
  ///          not move. That is exactly where this differs from `assignVariable` — that one has to
  ///          `evaluate()`, because a variable **is** an input to evaluation.
  ///
  ///          It **does go through the generation guard** (`_markStateEdited()`), though: that is the
  ///          one marker for "the state has been edited", and `_restorePersistedState` uses it to ask
  ///          "did the user touch anything while I was reading from disk" — the dataset is state, so it
  ///          has to move that marker or a restore in flight would overwrite a value the user just
  ///          added. The cursor keys (`moveCursorLeft`/`moveCursorRight`) are the precedent: they do
  ///          not affect evaluation either, and they move it too.
  String? addDatasetValue() {
    final value = storableDatasetValue;
    if (value == null) return _datasetValueRefusalMessage;
    if (_dataset.length >= kMaxDatasetValues) return _datasetFullMessage;
    _markStateEdited();
    _recordUndoSnapshot();
    _dataset.add(value);
    unawaited(_persistState());
    notifyListeners();
    return null;
  }

  /// 中文：从数据集里去掉第 [index] 个值。越界时是空操作（不写撤销栈、不落盘、不通知），与
  ///       `clearVariable` 的「没事可做就什么都不做」同一条。
  /// English: drop the [index]-th value. Out of range it is a no-op (no undo row, no write to disk, no
  ///          notification), the same rule `clearVariable` follows.
  void removeDatasetValueAt(int index) {
    if (index < 0 || index >= _dataset.length) return;
    _markStateEdited();
    _recordUndoSnapshot();
    _dataset.removeAt(index);
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：清空数据集。空的时候是空操作（同上）。
  /// English: clear the dataset. A no-op while it is already empty (as above).
  void clearDataset() {
    if (_dataset.isEmpty) return;
    _markStateEdited();
    _recordUndoSnapshot();
    _dataset.clear();
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：**这一次插进表达式的实参串**——数据集为空时是起手数据，否则是数据集里那几个值按顺序用
  ///       逗号接起来。面板的读数与 [statisticsCall] 都读这一处，所以「面板上写着什么」与
  ///       「按下去插进去什么」不可能漂开。
  ///
  ///       值逐字来自 [MathResult.decimalText]（引擎那一串未取整的十进制），**不做任何取整**：
  ///       按 `AppSettings.precision` 取整会让插进去的调用与数据集里存的那个数不是同一个数——
  ///       那正是这个项目最不想要的那种「看起来合理的错值」。
  ///
  /// English: **the argument string inserted this time** — the starting sample while the dataset is
  ///          empty, otherwise the dataset's values in order, comma-separated. Both the sheet's
  ///          reading and [statisticsCall] read this one place, so "what the sheet says" and "what
  ///          lands in the expression" cannot drift apart.
  ///
  ///          The values come verbatim from [MathResult.decimalText] (the engine's unrounded decimal),
  ///          with **no rounding at all**: rounding by `AppSettings.precision` would make the inserted
  ///          call hold a different number from the one stored in the dataset — exactly the kind of
  ///          plausible-looking wrong value this project is built to avoid.
  String get datasetCallArguments => _dataset.isEmpty
      ? _statisticsStartingSample.join(',')
      : _dataset.join(',');

  /// 中文：**`STAT` 面板四格插进表达式的那一整条调用**（`mean(5,12,13)`）。
  ///
  ///       形状与上一轮逐字相同——完整、立刻可求值、把引擎的实参顺序摆在屏幕上；变的只是实参从
  ///       哪里来（见 [datasetCallArguments]）。数据集为空时它与本轮之前**逐字节相同**。
  ///
  ///       为什么是**副本**而不是引用：数据集不是表达式语法的一部分，引擎只认得出「一串数」。
  ///       这也正是 HiPER 的做法（`help.statistics.contents`：「选一个函数，插入一组值」）。用户在
  ///       表达式里改那串数**改的是那一条调用，不是数据集**——两者从插入那一刻起就是两样东西，
  ///       与「继续使用」把结果写回表达式之后「结果」与「表达式」的关系逐字相同。数据集这边一样：
  ///       改它不会回头去改任何已经插入的调用。
  ///
  /// English: **the whole call the four `STAT` cells insert** (`mean(5,12,13)`).
  ///
  ///          The shape is byte for byte last round's — complete, immediately evaluable, and it puts
  ///          the engine's argument order on screen; what changed is where the arguments come from
  ///          (see [datasetCallArguments]). With an empty dataset it is **byte for byte** what it was
  ///          before this round.
  ///
  ///          Why a **copy** rather than a reference: the dataset is not part of the expression grammar
  ///          and the engine only understands "a run of numbers". This is also HiPER's own behaviour
  ///          (`help.statistics.contents`: "select a function and insert a set of values"). Editing
  ///          those numbers in the expression **edits that call, not the dataset** — the two are
  ///          different objects from the moment of insertion, byte for byte the relation between "the
  ///          result" and "the expression" after "continue with result" writes one into the other. The
  ///          dataset behaves the same way round: editing it never reaches back into a call that was
  ///          already inserted.
  String statisticsCall(String function) =>
      '$function($datasetCallArguments)';

  /// 中文：**同一个数据集按两行读时每行有几个值**；读不成两行时是 `0`。
  ///
  ///       一个存放处、两种读法，这不是第二个真相源：读的还是 [datasetValues] 那一串，
  ///       变的只是它被切成什么形状。两种读法都来自来源，不是我发明的：
  ///       HiPER 的帮助文本一句话里就写着两种形状——「A set is represented by a **row matrix**
  ///       … or **two-row matrix** (with frequencies in the second row)」，而它的回归错误文本
  ///       又把两行说死：「Regression parameter must have two rows: the first one with X values,
  ///       the second one with Y values」。所以：
  ///
  ///       - `mean`/`median`/`stdev`/`var` 读**一行**（`matrix(1,n,…)`，见 [statisticsCall]）；
  ///       - `pearson`/`covar`/`spearman` 读**两行**（`matrix(2,n,…)`，见 [regressionCall]）。
  ///
  ///       切法就是 `matrix(2,n,…)` 自己的填法（**按行**）：前 n 个是第一行（X），后 n 个是第二行
  ///       （Y）。这也正是 HiPER 那个两行矩阵摊平之后的顺序，所以这里没有多出任何一条约定。
  ///
  ///       奇数个值读不成两行（[datasetPairCount] 因此是 0）：**拒绝，不是四舍五入**。
  /// English: **how many values each row holds when this one dataset is read as two rows**; `0` when
  ///          it cannot be.
  ///
  ///          One store, two readings — and that is not a second source of truth: what is read is
  ///          still [datasetValues], only the shape it is cut into changes. Both readings come from
  ///          the source rather than from me: HiPER's help text names both in one sentence — "A set is
  ///          represented by a **row matrix** … or **two-row matrix** (with frequencies in the second
  ///          row)" — and its regression error text pins the two rows down: "Regression parameter must
  ///          have two rows: the first one with X values, the second one with Y values". So:
  ///
  ///          - `mean`/`median`/`stdev`/`var` read **one row** (`matrix(1,n,…)`, see [statisticsCall]);
  ///          - `pearson`/`covar`/`spearman` read **two rows** (`matrix(2,n,…)`, see [regressionCall]).
  ///
  ///          The cut is `matrix(2,n,…)`'s own fill order (**row by row**): the first n values are the
  ///          first row (X), the last n are the second row (Y). That is also the order HiPER's two-row
  ///          matrix flattens to, so no new convention is introduced here.
  ///
  ///          An odd number of values cannot be read as two rows ([datasetPairCount] is then `0`):
  ///          **refused, not rounded**.
  int get datasetPairCount =>
      _dataset.length.isEven ? _dataset.length ~/ 2 : 0;

  /// 中文：**这个数据集此刻能不能读成两行**。至少两对（4 个值）——下限是量出来的，不是我挑的：
  ///       一对时 `covar` 给一个没有信息的 `0`，而 `pearson` 给的是**未求值的 `0 / 0`**
  ///       （宿主实测 `qalc -t 'pearson(matrix(2,1,1,2))'` → `0 / 0`）。
  /// English: **whether this dataset can be read as two rows right now.** At least two pairs (four
  ///          values) — the floor is measured, not chosen: with one pair `covar` gives an
  ///          uninformative `0` while `pearson` gives the **unevaluated `0 / 0`** (measured on the
  ///          host, `qalc -t 'pearson(matrix(2,1,1,2))'` → `0 / 0`).
  bool get canReadDatasetAsTwoRows => datasetPairCount >= kMinRegressionPairs;

  /// 中文：**`pearson`/`covar`/`spearman` 那三格插进表达式的那一整条调用**
  ///       （`pearson(matrix(2,3,1,2,3,4,5,6))`），读不成两行时是 `null`。
  ///
  ///       实参是**一个**两行矩阵，不是一个行矩阵加另一个行矩阵：那是 HiPER 的形状
  ///       （「two-row matrix … the first one with X values, the second one with Y values」），
  ///       也是引擎实测收得下的形状。宿主实测（`qalc` 5.12.0）——**两行矩阵与两个行矩阵给的
  ///       是同一个数**，逐对量过：
  ///
  ///       | 两行矩阵 | 两个行矩阵 | 两者 |
  ///       |---|---|---|
  ///       | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` = `0.9958932065` | `pearson(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,11))` = `0.9958932065` | 同 |
  ///       | `covar(matrix(2,3,1,2,3,4,5,6))` = `0.6666666667` | `covar(matrix(1,3,1,2,3),matrix(1,3,4,5,6))` = `0.6666666667` | 同 |
  ///       | `spearman(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` = `1.000000000` | `spearman(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,11))` = `1.000000000` | 同 |
  ///
  ///       为什么用两行那一个：它是来源里那个形状，而且**一个实参**比两个短——屏幕上那串数是
  ///       用户自己要改的，少一半长度不是小事。它靠的是引擎那条「形参声明是向量、拿到的是矩阵
  ///       就拆开用」的机制（`MathStructure-calculate.cc`），只有**行数等于形参数**时才成立；
  ///       这两族函数恰好都是两个形参。**万一那条机制哪天不成立，引擎会把调用原样退回来**，
  ///       结果是 `arithmetic` 那一支（不显示）→ 一句错误。**失败是关上的，不是一个错值。**
  ///
  ///       值与 [statisticsCall] 同一条：逐字来自 [MathResult.decimalText]，不按精度取整。
  /// English: **the whole call the `pearson`/`covar`/`spearman` cells insert**
  ///          (`pearson(matrix(2,3,1,2,3,4,5,6))`), or `null` when the dataset cannot be read as two
  ///          rows.
  ///
  ///          The argument is **one** two-row matrix rather than two one-row matrices: that is HiPER's
  ///          shape ("two-row matrix … the first one with X values, the second one with Y values") and
  ///          it is the shape the engine was measured to take. Measured on the host (`qalc` 5.12.0) —
  ///          **the two-row matrix and the two row-matrices give the same number**, pair by pair:
  ///
  ///          | two-row matrix | two row-matrices | |
  ///          |---|---|---|
  ///          | `pearson(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` = `0.9958932065` | `pearson(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,11))` = `0.9958932065` | same |
  ///          | `covar(matrix(2,3,1,2,3,4,5,6))` = `0.6666666667` | `covar(matrix(1,3,1,2,3),matrix(1,3,4,5,6))` = `0.6666666667` | same |
  ///          | `spearman(matrix(2,5,1,2,3,4,5,2,4,6,8,11))` = `1.000000000` | `spearman(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,11))` = `1.000000000` | same |
  ///
  ///          Why the two-row one: it is the source's shape, and **one argument** is shorter than two —
  ///          the numbers on screen are what the user edits, and halving that length is not a small
  ///          thing. It rests on the engine's "an argument declared a vector that receives a matrix is
  ///          taken apart" mechanism (`MathStructure-calculate.cc`), which holds only while the row
  ///          count equals the arity; both these families have exactly two parameters. **Should that
  ///          mechanism ever stop holding, the engine hands the call straight back**, the result kinds
  ///          as `arithmetic` (not displayable) and the screen shows an error. **Failure is closed,
  ///          not a wrong value.**
  ///
  ///          The values are the same as [statisticsCall]'s: verbatim from [MathResult.decimalText],
  ///          never rounded by the precision setting.
  String? regressionCall(String function) {
    if (!canReadDatasetAsTwoRows) return null;
    final rows = datasetPairCount;
    return '$function(matrix(2,$rows,${_dataset.join(',')}))';
  }

  /// 中文：**读不成两行时对用户说的那一句话**——说清两行读法要什么、数据集此刻有几个值。
  ///       不说的话，用户看到的只是三格灰键，而灰键不解释自己为什么灰。
  ///       **拒绝不是静默的**（与 [addDatasetValue] 的返回值同一条）。
  /// English: **what the user is told when the dataset cannot be read as two rows** — what that
  ///          reading needs and how many values there are right now. Without it the user sees three
  ///          grey cells, and a grey cell does not say why it is grey. **The refusal is not silent**
  ///          (the same rule as [addDatasetValue]'s return value).
  String get regressionUnavailableMessage => _dataset.isEmpty
      ? '两变量函数把数据集读成两行（前一半 X、后一半 Y），'
          '现在数据集是空的，先加至少 $kMinRegressionPairs 对值'
      : _dataset.length.isOdd
          ? '两变量函数把数据集读成两行，需要偶数个值，'
              '现在有 ${_dataset.length} 个'
          : '两变量函数把数据集读成两行，每行至少 $kMinRegressionPairs 个值，'
              '现在有 ${_dataset.length} 个';

  /// 中文：数据集拒绝一个值时的两句话。它们是**说给用户听的**（与记忆寄存器那句同一种），所以
  ///       说的是真正的原因与后果，不是「错误」两个字。
  /// English: the two sentences the dataset gives when it refuses a value. They are **written for the
  ///          user** (the same kind as the memory register's), so they name the real cause and the
  ///          consequence rather than saying "error".
  String get _datasetValueRefusalMessage =>
      '当前值放不进数据集（需要一个有限的十进制结果），数据集未改动';

  String get _datasetFullMessage =>
      '数据集最多 $kMaxDatasetValues 个值，这一个没有加进去';
}

/// 中文：数据集**落盘的那一串文本**，以及**读回来**的那一处（两处都只有一份）。
///
///       用 JSON 数组而不是用某个分隔符接起来：分隔符是一条**在带内**的约定，于是「值里万一带了
///       那个字符怎么办」要靠一句关于值形状的断言撑着；JSON 没有这个问题（转义由编码器负责），
///       而它是这个仓库已经在用的东西（备份快照那一侧）。
///
///       读回来时**逐条过 [MathResult.decimalValueOf]**——磁盘上的东西同样是输入，同样可能是
///       `Infinity`、`NaN`、一个下溢成 0 的值，或者根本不是一个字符串（键被别的东西改过）。
///       挡下来的按「没有这个值」处理，与变量恢复那边逐字同一条；整串读不动（不是 JSON、不是数组）
///       时按「没有数据集」处理，也就是清空——**失败一律关上**，绝不猜一个数出来。
///
/// English: **the text the dataset is persisted as**, and **the one place that reads it back**.
///
///          A JSON array rather than joining on some separator: a separator is an **in-band**
///          convention, so "what if a value happens to contain that character" has to be held up by an
///          assertion about the shape of values; JSON has no such question (escaping is the encoder's
///          job), and it is already used in this repository (the backup snapshot side).
///
///          Reading back runs **every entry through [MathResult.decimalValueOf]** — what is on disk is
///          input too, and it may just as well be an `Infinity`, a `NaN`, a value that underflows to 0,
///          or not a string at all (the key edited by something else). What is rejected is treated as
///          "this value is not there", byte for byte what the variables' restore does; when the whole
///          string is unreadable (not JSON, not an array) it is treated as "no dataset", i.e. cleared —
///          **fail closed**, and never guess a number into existence.
String _datasetIdText(List<String> values) => jsonEncode(values);

void _readDataset(String? stored, List<String> into) {
  into.clear();
  if (stored == null || stored.isEmpty) return;
  List<dynamic> entries;
  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return;
    entries = decoded;
  } catch (_) {
    return;
  }
  for (final entry in entries) {
    if (into.length >= kMaxDatasetValues) break;
    if (entry is! String) continue;
    if (MathResult.decimalValueOf(entry) == null) continue;
    into.add(entry);
  }
}
