import 'dart:async';
// 中文：数据集落盘用 JSON 数组（见 `_datasetIdText` 上的注释：分隔符是**带内**约定，JSON 不是）。
// English: the dataset is persisted as a JSON array (see the note on `_datasetIdText`: a separator is
//          an **in-band** convention, JSON is not).
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/math/engine_expression.dart';
import '../../core/math/expression_parser.dart';
import '../../core/math/app_engine_vocabulary.dart';
import '../../core/math/math_engine.dart';
import '../../core/math/math_result.dart';
import '../../core/math/variable_references.dart';
import '../../core/platform/qalculate_channel.dart';
import '../../core/platform/qalculate_math_engine.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/usecases/calculator_paste_result.dart';
import '../../domain/usecases/calculator_save_result.dart';
import '../../domain/usecases/calculator_submit_result.dart';
import '../../domain/usecases/expression_editing.dart';
import '../app_settings.dart';
import 'expression_selection.dart';

part 'calculator_controller_state.dart';
part 'calculator_controller_editing.dart';
part 'calculator_controller_evaluation.dart';
part 'calculator_controller_persistence.dart';
part 'calculator_controller_base_readout.dart';
part 'calculator_controller_variables.dart';
part 'calculator_controller_dataset.dart';

/// 中文：边打边算用哪个结果上屏——**裁决 1 的那个开关**，做成可切换的常量而不是写死在流程里。
///
///       - [legacyFirstThenEngine]（B）：旧解析器的结果先上屏，引擎的结果到达后替换它。
///       - [engineOnly]（A）：只显示引擎的结果；引擎回话之前屏幕上留着上一个值（或不显示）。
///
///       选 (B) 的四条理由：
///       1. **即时反馈是边打边算的第一属性**——HiPER 的体验就是「边打边出结果」，砸掉它等于砸掉这
///          一步的意义；
///       2. 引擎往返在毫秒量级，**多数情况下替换发生在同一视觉帧内**，根本看不见；
///       3. 最常见的情形是两者**结果一致**（普通四则运算），此时没有任何可见变化；
///       4. **(B) 的回落路径本来就是必须存在的**——引擎失败要回落旧解析器。选 (A) 等于要维护两套
///          「什么时候显示什么」的逻辑（引擎成功时一套、引擎失败时另一套），(B) 只有一套。
///
///       代价（选 (B) 时可见）：精确形式（`4√2`）上会看到一次从旧值到引擎值的替换；`2^2000` 这类
///       会先闪一下旧求值器的「结果不是有限数值」再被纠正。
///
/// English: Which result goes on screen during as-you-type evaluation — *the switch ruling 1 asks
///          for*, a constant rather than a hardcoded flow.
///
///          - [legacyFirstThenEngine] (B): the legacy parser's result goes up first and is replaced
///            when the engine's answer arrives.
///          - [engineOnly] (A): only the engine's result is shown; the previous value stays on
///            screen until the engine answers.
///
///          (B) is chosen for four reasons: (1) instant feedback is as-you-type's first property —
///          the HiPER experience *is* "a result as you type", and losing it would lose the point of
///          this step; (2) the engine round trip is milliseconds, so the replacement usually lands
///          inside one visual frame and is invisible; (3) the common case is that both agree
///          (ordinary arithmetic), where nothing changes on screen at all; (4) (B)'s fallback path
///          has to exist regardless — a failed engine falls back to the legacy parser — whereas (A)
///          would need two sets of rules for "what is shown when" (one for engine success, one for
///          engine failure) where (B) has one.
///
///          The cost of (B), visible on screen: an exact form (`4√2`) shows one replacement from the
///          old value to the engine's, and `2^2000` briefly flashes the old evaluator's
///          "结果不是有限数值" before being corrected.
enum LiveResultPolicy {
  legacyFirstThenEngine,
  engineOnly;

  /// 中文：这个策略是不是「旧结果先上屏」——也就是 [_evaluateLegacy] 要不要跑。
  /// English: Whether this policy puts the legacy result on screen first — i.e. whether
  ///          [_evaluateLegacy] runs at all.
  bool get showsLegacyResult => this == LiveResultPolicy.legacyFirstThenEngine;
}

/// 中文：默认策略——裁决 1 选的是 (B)。改成 [LiveResultPolicy.engineOnly] 即切到 (A)；
///       它同时可以在构造时注入，好让两条分支都有测试盯着。
/// English: The default policy — ruling 1 chose (B). Switching the constant to
///          [LiveResultPolicy.engineOnly] selects (A); it can also be injected through the
///          constructor so both branches are covered by tests.
const LiveResultPolicy kLiveResultPolicy =
    LiveResultPolicy.legacyFirstThenEngine;

/// 中文：**显示侧的合并窗口**——「打完字之后多久看到第一个结果」就是这个值。它是给同步解析调的
///       （那时一次解析是微秒），职责没有变，所以这一步**不动它**：裁决 1 要的即时反馈正是由它保证
///       的。它与 [kLiveEngineFollowUpDelay] 不是同一件事：那一个挡在跨语言调用前面，决定的是「精确
///       形态什么时候到」；这一个决定的是「第一个结果什么时候出现」。
///
///       32ms ≈ 60Hz 下的两帧：最小到能把连续按键合并成一次解析，又短到看不出延迟。它在生产路径上
///       的取值一字未改——把它提成有名字的常量，是为了能注入一个别的值（测试里用来把「显示侧那一次
///       定时器」从竞态里拿掉），而不是为了改它。
///
/// English: The **display-side coalescing window** — "how long after typing the first result appears"
///          is this value. It was tuned for a synchronous parse (microseconds), its job has not
///          changed, and this step **does not touch it**: ruling 1's instant feedback is exactly what
///          it guarantees. It is not the same thing as [kLiveEngineFollowUpDelay], which stands in
///          front of a cross-language call and decides when the *exact form* arrives; this one decides
///          when the *first result* appears.
///
///          32 ms is about two frames at 60 Hz: the smallest window that still merges a burst of
///          keystrokes into one parse, and short enough to be imperceptible. Its production value is
///          unchanged — giving it a name is so that another value can be injected (tests use it to
///          take the display-side timer out of a race), not so that it can be changed.
const Duration kLiveEvaluationDelay = Duration(milliseconds: 32);

/// 中文：边打边算的**引擎跟进延迟**（防抖）。32ms 不能沿用——它是给同步解析调的，那时一次解析是
///       微秒；现在它挡在「快速输入」和「一队跨语言调用」之间，性质完全不同。取值理由：
///
///       1. **它必须长于最快的人类连续击键间隔**，否则一次连续输入会变成一串引擎调用。这一条是
///          针对按键重复（长按不放，Android 的默认重复间隔约 50ms）与快速连打（约 80–120ms）定的。
///          **但 120ms 是这条带的上沿，不是「高于」它**：压制成立的条件是按键间隔**严格小于**
///          120ms——跟进定时器在末键+152ms 触发，而下一次求值在下一键+32ms，所以只要下一键比
///          上一键晚超过 120ms，跟进就会落地，发出一整次引擎调用。**慢于 120ms/键的输入（含这段
///          区间的上半）每键都会发一次调用**；那种情形下不积压靠的是第 4 条，不是这一条。
///       2. **它不是「第一个结果」的延迟，只是「精确形式」的延迟**。裁决 1 的策略 (B) 下，旧解析器
///          的结果仍然在 32ms 那一次上屏——与今天完全一样——这个延迟只推迟引擎那份精确形态的到来
///          （而精确形态本来就是新增的信息，不是用户今天已有的东西）。所以取大一点的代价很小。
///       3. 上限由感知定：跟进定时器每收到一次求值就重排，而求值发生在最后一次击键之后 ≤32ms，
///          于是**从最后一次击键算起**、**且没有在飞调用时**，上限是 120+32≈152ms，低于「像卡顿」
///          的那条线（约 200ms）。**有在飞调用时这个上界不成立**——精确形式要先等那个调用让出
///          槽位，再加一个跟进周期，最坏情况是 `engineTimeout`（引擎卡死时）。
///       4. 就算这个值取错了，**也积压不了**：在飞上限是 1（见 [_evaluateWithEngine]），再密的输入
///          也只是记一个「还欠一次」，不会排成队。
///
/// English: The **engine follow-up delay** (debounce) for as-you-type evaluation. The old 32 ms
///          cannot be carried over: it was tuned for a synchronous parse that cost microseconds,
///          while it now stands between fast typing and a queue of cross-language calls. Why 120 ms:
///
///          1. **It must exceed the fastest human key interval**, or one continuous burst becomes a
///             stream of engine calls. That band is set by key repeat (holding a key down; Android's
///             default repeat interval is about 50 ms) and by fast two-thumb tapping (about
///             80-120 ms). **120 ms is the band's upper edge, not above it**: suppression needs the
///             key interval to be *strictly* under 120 ms — the follow-up fires at last-key+152 ms
///             while the next evaluation is at next-key+32 ms — so any key arriving more than 120 ms
///             after the previous one lets the follow-up land and issues a full engine call. **Input
///             slower than 120 ms/key (including the upper half of that band) calls the engine once
///             per keystroke**; there, not accumulating is reason 4's doing, not this one's.
///          2. **It is not the delay of the first result, only of the exact form.** Under ruling 1's
///             policy (B) the legacy parser's result still goes up at the 32 ms tick — exactly as
///             today — and this delay only defers the engine's exact form, which is new information
///             rather than something the user already had. Paying a little here is therefore cheap.
///          3. The ceiling comes from perception: the follow-up timer is restarted by every
///             evaluation, and an evaluation happens at most 32 ms after the last keystroke, so the
///             worst case measured **from the last keystroke** — and **with nothing in flight** — is
///             120+32 ≈ 152 ms, below the ~200 ms at which a delayed update starts to read as lag.
///             **With a call outstanding that ceiling does not hold**: the exact form waits for that
///             call to free the slot and then for another follow-up period — up to `engineTimeout`
///             when the engine is wedged.
///          4. Even if the value were wrong, it **cannot build a queue**: at most one call is in
///             flight (see [_evaluateWithEngine]), and denser typing merely records "one more is
///             owed" instead of enqueueing.
const Duration kLiveEngineFollowUpDelay = Duration(milliseconds: 120);

/// 中文：`AppSettings.expressionDisplayMode` 里代表「边打边算走引擎」的那个值——**裁决 2 的 kill
///       switch 就是它**。在设备上把「设置 → 表达式显示」从 `数学符号` 切到 `数学表达式`，边打边算
///       立刻回到旧路径，不需要重新构建、不需要重启。
///
///       为什么用这个已存在的设置而不是新造一个：设计文档指定的缓解手段就是它，而新造一个开关等于
///       多一个用户看不见、也不会被拨动的旋钮。代价是它同时决定表达式行的自然排版（`数学符号`
///       才排版）——拨这个开关会顺带改变表达式行的样子，这是「用现成开关」的已知代价。
///
/// English: The value of `AppSettings.expressionDisplayMode` that means "as-you-type evaluation uses
///          the engine" — **this is ruling 2's kill switch**. Flipping 设置 → 表达式显示 from
///          `数学符号` to `数学表达式` on a device returns as-you-type evaluation to the legacy path
///          with no rebuild and no restart.
///
///          Why this existing setting rather than a new one: it is the mitigation the design document
///          names, and a new switch would be one more knob the user never sees and never turns. The
///          cost is that it also decides the expression line's natural typesetting (`数学符号` is
///          what turns that on), so flipping the switch changes that line's appearance too — a known
///          price of reusing the existing setting.
const String kEngineBackedLiveExpressionDisplay = '数学符号';
/// 中文：计算器页面的应用层状态控制器，负责表达式编辑、实时计算、历史保存和状态恢复。
/// English: Application-layer controller for the calculator page; owns expression editing, live evaluation, history saving, and state restore.
class CalculatorController extends ChangeNotifier
    with
        _CalculatorState,
        _CalculatorEditing,
        _CalculatorEvaluation,
        _CalculatorPersistence,
        _CalculatorBaseReadout,
        _CalculatorVariables,
        _CalculatorDataset {
  CalculatorController({
    required this.historyRepository,
    required this.notesRepository,
    required this.settingsRepository,
    required AppSettings settings,
    MathEngine engine = const QalculateMathEngine(),
    this.engineTimeout = const Duration(seconds: 5),
    this.liveResultPolicy = kLiveResultPolicy,
    this.liveEvaluationDelay = kLiveEvaluationDelay,
    this.liveEngineFollowUpDelay = kLiveEngineFollowUpDelay,
  })  : _settings = settings,
        _engine = engine,
        angleMode = settings.angleMode;

  @override
  final HistoryRepository historyRepository;
  @override
  final NotesRepository notesRepository;
  @override
  final SettingsRepository settingsRepository;
  /// 中文：求值引擎。默认就是真的那一个——生产接线不留「忘了注入于是功能静默不生效」的空档；
  ///       测试用替身换掉它，于是「引擎答不出来时回落」这条路径在 `flutter test` 里也能断言。
  /// English: The evaluation engine. The default is the real one, so production wiring has no gap
  ///          where a forgotten injection silently disables the feature; tests replace it with a
  ///          double, which makes the "the engine cannot answer, fall back" path assertable under
  ///          `flutter test`.
  @override
  final MathEngine _engine;
  /// 中文：等引擎的上限，**两条路径共用**（提交与边打边算），超时按「引擎没有可用结果」处理
  ///       （回落旧解析器，不是报错）。5 秒是给启动后第一次调用留的余量——那一次包含懒加载全局
  ///       定义。测试注入毫秒级的超时来走这条路径。
  ///
  ///       边打边算不另设一个更短的上限：一发卡住的调用最多占住「在飞」那一个名额 [engineTimeout]
  ///       这么久，期间旧解析器的结果照常随输入更新（裁决 1 的即时反馈不依赖引擎），超时之后自然
  ///       补发。再设一个预算只会多一个要维护的数。
  /// English: How long either path waits for the engine — **both the submit path and as-you-type use
  ///          it** — after which the call counts as "the engine has no usable result" (a fallback to
  ///          the legacy parser, not an error). Five seconds leaves room for the first call after
  ///          launch, which loads the global definitions lazily. Tests inject a millisecond-scale
  ///          timeout to exercise it.
  ///
  ///          As-you-type gets no shorter budget of its own: one stuck call occupies the single
  ///          in-flight slot [_engineTimeout] for that long, while the legacy parser's result keeps
  ///          updating with every keystroke (ruling 1's instant feedback does not depend on the
  ///          engine) and a follow-up goes out once it times out. A second budget would only be one
  ///          more number to maintain.
  @override
  final Duration engineTimeout;
  /// 中文：边打边算的上屏策略（裁决 1）。默认是 [kLiveResultPolicy]（旧结果先上屏），可注入，
  ///       好让另一条分支也有测试盯着——「做成可切换的常量」的意思就是它不许被写死在流程里。
  /// English: The as-you-type rendering policy (ruling 1). Defaults to [kLiveResultPolicy] (the
  ///          legacy result first) and is injectable so the other branch has tests watching it too —
  ///          "a switchable constant" means precisely that it is not hardcoded into the flow.
  @override
  final LiveResultPolicy liveResultPolicy;
  /// 中文：显示侧的合并窗口。取值与理由写在 [kLiveEvaluationDelay] 上；它与
  ///       [liveEngineFollowUpDelay] 一起决定「输入之后屏幕上什么时候出现什么」。
  /// English: The display-side coalescing window. Its value and reasoning live on
  ///          [kLiveEvaluationDelay]; together with [liveEngineFollowUpDelay] it decides what appears
  ///          on screen, and when, after an input.
  @override
  final Duration liveEvaluationDelay;
  /// 中文：边打边算的引擎跟进延迟（防抖）。取值理由写在 [kLiveEngineFollowUpDelay] 上；测试注入
  ///       `Duration.zero` 或一个很长的值来精确控制这一次跟进发不发生。
  /// English: The engine follow-up delay (debounce) for as-you-type evaluation. The reasoning lives
  ///          on [kLiveEngineFollowUpDelay]; tests inject `Duration.zero` or a very long value to
  ///          control exactly whether a follow-up happens.
  @override
  final Duration liveEngineFollowUpDelay;
  @override
  AppSettings _settings;
  @override
  String angleMode;
  @override
  void dispose() {
    _disposed = true;
    _liveEvaluationTimer?.cancel();
    _liveEngineTimer?.cancel();
    // 中文：还没回话的引擎请求连同它的超时定时器一起收掉，并补一条失败回执——`submit()` 的
    //       `await` 因此一定会返回，落到它自己的 `_disposed` 分支上，而不是永远悬着。
    // English: Requests still in flight are collected together with their timeout timers and handed
    //          a failure receipt — so `submit()`'s `await` always returns and lands on its own
    //          `_disposed` branch rather than hanging forever.
    for (final entry in _engineCalls.entries) {
      entry.value.cancel();
      if (!entry.key.isCompleted) {
        entry.key.complete(EngineReply.failure('engine_disposed'));
      }
    }
    _engineCalls.clear();
    super.dispose();
  }
}

class _CalculatorSnapshot {
  const _CalculatorSnapshot({
    required this.expression,
    required this.result,
    required this.angleMode,
    required this.selection,
    required this.memoryValue,
    required this.hasError,
    required this.errorMessage,
    required this.lastFiniteResult,
    required this.ansSourceForExpression,
    required this.ansValueForExpression,
    required this.variables,
    required this.dataset,
  });

  final String expression;

  /// 中文：整份三形态结果。`==` 依赖 [MathResult] 的值相等，撤销栈的去重才仍然成立。
  /// English: The whole three-form result. `==` leans on [MathResult]'s value equality, which is
  ///          what keeps the undo stack's de-duplication working.
  final MathResult result;
  final String angleMode;
  final ExpressionSelection selection;
  final double memoryValue;
  final bool hasError;
  final String? errorMessage;
  final String? lastFiniteResult;
  final String? ansSourceForExpression;
  final String? ansValueForExpression;

  /// 中文：变量绑定也是**状态**，所以它也进撤销栈——`memoryValue` 早就在里面，理由相同：撤销一次
  ///       绑定之后，屏幕上的结果必须与那一次的绑定配套，否则「撤销」会留下一行与变量对不上的结果。
  ///       `Map` 在 Dart 里没有值相等，所以 `==` 用 `mapEquals`、`hashCode` 用一份**排序后**的
  ///       条目串——不排序的话，两张内容相同而插入顺序不同的表会算出两个不同的散列，去重就失效了。
  /// English: a variable binding is **state** too, so it goes into the undo stack — `memoryValue` has
  ///          been in there all along for the same reason: after undoing a binding the result on screen
  ///          has to belong to that binding, or "undo" leaves a result that does not match its
  ///          variables. Dart's `Map` has no value equality, so `==` uses `mapEquals` and `hashCode`
  ///          uses a **sorted** run of entries — unsorted, two maps with equal contents but different
  ///          insertion order would hash differently and the de-duplication would stop working.
  final Map<String, String> variables;

  /// 中文：数据集也是**状态**，所以它也进撤销栈——与 `variables` 同一条理由：撤销一次「加了一个值」
  ///       之后，存放处必须回到那一刻的样子，否则撤销会留下一份与刚才那一下对不上的数据。
  ///       与 `variables` 的分别有两点：表是**有序**的（数据集的顺序是它的一部分，所以散列不排序），
  ///       并且用 `listEquals` 而不是 `mapEquals`。
  /// English: the dataset is **state** too, so it goes into the undo stack — the same reason as
  ///          `variables`: after undoing "one value was added" the store has to be what it was at that
  ///          moment, or undo leaves data that does not match the press. Two differences from
  ///          `variables`: the list is **ordered** (a dataset's order is part of it, so nothing is
  ///          sorted before hashing) and it uses `listEquals` rather than `mapEquals`.
  final List<String> dataset;

  int get _variablesHash => Object.hashAll(
        variables.entries.map((entry) => '${entry.key}=${entry.value}').toList()
          ..sort(),
      );

  @override
  bool operator ==(Object other) {
    return other is _CalculatorSnapshot &&
        other.expression == expression &&
        other.result == result &&
        other.angleMode == angleMode &&
        other.selection == selection &&
        other.memoryValue == memoryValue &&
        other.hasError == hasError &&
        other.errorMessage == errorMessage &&
        other.lastFiniteResult == lastFiniteResult &&
        other.ansSourceForExpression == ansSourceForExpression &&
        other.ansValueForExpression == ansValueForExpression &&
        mapEquals(other.variables, variables) &&
        listEquals(other.dataset, dataset);
  }

  @override
  int get hashCode => Object.hash(
        expression,
        result,
        angleMode,
        selection,
        memoryValue,
        hasError,
        errorMessage,
        lastFiniteResult,
        ansSourceForExpression,
        ansValueForExpression,
        _variablesHash,
        Object.hashAll(dataset),
      );
}

class _SubmittedCalculationSignature {
  const _SubmittedCalculationSignature({
    required this.normalizedExpression,
    required this.result,
    required this.angleMode,
  });

  final String normalizedExpression;
  final String result;
  final String angleMode;

  @override
  bool operator ==(Object other) {
    return other is _SubmittedCalculationSignature &&
        other.normalizedExpression == normalizedExpression &&
        other.result == result &&
        other.angleMode == angleMode;
  }

  @override
  int get hashCode => Object.hash(normalizedExpression, result, angleMode);
}
