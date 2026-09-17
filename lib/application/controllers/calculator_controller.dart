import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/math/expression_parser.dart';
import '../../core/math/math_engine.dart';
import '../../core/math/math_result.dart';
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
class CalculatorController extends ChangeNotifier {
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

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final SettingsRepository settingsRepository;

  /// 中文：求值引擎。默认就是真的那一个——生产接线不留「忘了注入于是功能静默不生效」的空档；
  ///       测试用替身换掉它，于是「引擎答不出来时回落」这条路径在 `flutter test` 里也能断言。
  /// English: The evaluation engine. The default is the real one, so production wiring has no gap
  ///          where a forgotten injection silently disables the feature; tests replace it with a
  ///          double, which makes the "the engine cannot answer, fall back" path assertable under
  ///          `flutter test`.
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
  final Duration engineTimeout;

  /// 中文：边打边算的上屏策略（裁决 1）。默认是 [kLiveResultPolicy]（旧结果先上屏），可注入，
  ///       好让另一条分支也有测试盯着——「做成可切换的常量」的意思就是它不许被写死在流程里。
  /// English: The as-you-type rendering policy (ruling 1). Defaults to [kLiveResultPolicy] (the
  ///          legacy result first) and is injectable so the other branch has tests watching it too —
  ///          "a switchable constant" means precisely that it is not hardcoded into the flow.
  final LiveResultPolicy liveResultPolicy;

  /// 中文：显示侧的合并窗口。取值与理由写在 [kLiveEvaluationDelay] 上；它与
  ///       [liveEngineFollowUpDelay] 一起决定「输入之后屏幕上什么时候出现什么」。
  /// English: The display-side coalescing window. Its value and reasoning live on
  ///          [kLiveEvaluationDelay]; together with [liveEngineFollowUpDelay] it decides what appears
  ///          on screen, and when, after an input.
  final Duration liveEvaluationDelay;

  /// 中文：边打边算的引擎跟进延迟（防抖）。取值理由写在 [kLiveEngineFollowUpDelay] 上；测试注入
  ///       `Duration.zero` 或一个很长的值来精确控制这一次跟进发不发生。
  /// English: The engine follow-up delay (debounce) for as-you-type evaluation. The reasoning lives
  ///          on [kLiveEngineFollowUpDelay]; tests inject `Duration.zero` or a very long value to
  ///          control exactly whether a follow-up happens.
  final Duration liveEngineFollowUpDelay;

  /// 中文：在飞的引擎请求，值与它的超时定时器成对。存在的唯一理由是 [dispose] 能把它们一起收掉
  ///       ——见 [_askEngine]。
  /// English: Engine requests in flight, each paired with its timeout timer. They exist so that
  ///          [dispose] can collect both — see [_askEngine].
  final Map<Completer<EngineReply>, Timer> _engineCalls = {};

  AppSettings _settings;
  String expression = '';

  /// 中文：当前结果的三形态（显示文本 / LaTeX / 十进制文本）。**数值消费者只许读 [resultDecimal]**：
  ///       精确引擎接入后显示文本是 `4√2` 这样的精确形式，对它做 `double.tryParse` 会静默失败。
  /// English: The current result in its three forms (display text / LaTeX / decimal text). Numeric
  ///          consumers may only read [resultDecimal]: once the exact engine lands, the display text
  ///          is an exact form such as `4√2`, and `double.tryParse` over it fails silently.
  MathResult _result = MathResult.zero;

  String angleMode;
  ExpressionSelection _selection = const ExpressionSelection.collapsed(0);
  double memoryValue = 0;
  bool hasError = false;
  String? errorMessage;
  _SubmittedCalculationSignature? _lastSavedSignature;
  String? _lastFiniteResult = '0';
  String? _ansSourceForExpression;
  String? _ansValueForExpression;
  Timer? _liveEvaluationTimer;

  /// 中文：边打边算那一发的引擎跟进定时器。与 [_liveEvaluationTimer]（32ms，旧解析器上屏）分开，
  ///       因为两者的性质不同：那一个是同步解析的合并窗口，这一个挡在「快速输入」和一队跨语言调用
  ///       之间。见 [kLiveEngineFollowUpDelay]。
  /// English: The engine follow-up timer for as-you-type evaluation. It is separate from
  ///          [_liveEvaluationTimer] (32 ms, the legacy result going on screen) because the two are
  ///          different in kind: that one coalesces a synchronous parse, this one stands between fast
  ///          typing and a queue of cross-language calls. See [kLiveEngineFollowUpDelay].
  Timer? _liveEngineTimer;

  /// 中文：边打边算的那一发引擎调用是否在飞。**这是「队不积压」的实现**：在飞上限恒为 1，再密的
  ///       输入只会把 [_liveEngineDirty] 立起来（「还欠一次」），不会排成第二发。
  /// English: Whether an as-you-type engine call is in flight. **This is what "no queue builds up"
  ///          is made of**: at most one call is ever outstanding, and denser typing merely raises
  ///          [_liveEngineDirty] ("one more is owed") instead of queueing a second one.
  bool _liveEngineInFlight = false;

  /// 中文：在飞期间表达式又变了（或者求值又发生过一次），于是回包落地之后还欠一次跟进。它是**一个
  ///       布尔，不是队列**——欠多少次都只记得「还欠一次」，且那一发问的永远是最新的表达式。
  /// English: The expression changed (or another evaluation happened) while a call was in flight, so
  ///          one more follow-up is owed once the reply lands. It is **a boolean, not a queue** — no
  ///          matter how many were owed, "one more is owed" is all that is remembered, and that one
  ///          always asks about the newest expression.
  bool _liveEngineDirty = false;

  bool _disposed = false;
  int _stateRevision = 0;
  int _restoreToken = 0;
  final List<_CalculatorSnapshot> _undoStack = [];
  final List<_CalculatorSnapshot> _redoStack = [];
  static const int _maxUndoDepth = 40;

  ExpressionSelection get selection => _selection;

  /// 中文：结果行的十进制读数——没有精确形式时它就是整行，有精确形式时它是 `≈` 后面那一半。
  ///       取整仍由 `formatNumber` 按 [AppSettings.precision] 完成，所以精度设置管的正是这一半。
  /// English: The result line's decimal reading — the whole line when there is no exact form, the
  ///          half after `≈` when there is one. `formatNumber` still does the rounding at
  ///          [AppSettings.precision], so the precision setting governs exactly this half.
  String get result => _result.displayText;

  /// 中文：结果行的 LaTeX 形态（不含 `$` 定界符），也就是引擎给出的**精确形式**。引擎未接入时
  ///       始终为空串，结果行整行纯文本；非空时结果行是否排版由 `CalculatorDisplay` 判定——还要
  ///       排得出来、且不是同一串十进制的另一种写法。
  /// English: The result line's LaTeX form (no `$` delimiters) — the **exact form** the engine
  ///          supplied. While no engine is involved it is always empty and the line stays plain
  ///          text; when it is not, `CalculatorDisplay` decides whether to typeset it — it must also
  ///          render, and be more than the same decimal written differently.
  String get resultTex => _result.displayTex;

  /// 中文：结果的十进制形态——Ans/last、记忆寄存器、继续使用、历史去重与报告里的机器可读值都从
  ///       这里取。空串表示「这一次没有十进制形态」，调用方必须照常工作而不是去解析 [result]。
  /// English: The result's decimal form — Ans/last, the memory register, continue-with-result,
  ///          history de-duplication and the report's machine-readable value all take it from here.
  ///          An empty string means "no decimal form this time"; callers must keep working and must
  ///          not parse [result] instead.
  String get resultDecimal => _result.decimalText;

  int get cursorIndex => _selection.end;

  set cursorIndex(int value) {
    _selection = ExpressionSelection.collapsed(value).clamp(expression.length);
  }

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

  void updateSettings(AppSettings settings) {
    _markStateEdited();
    final angleChangedBySettings = angleMode == _settings.angleMode;
    _settings = settings;
    if (angleChangedBySettings) angleMode = settings.angleMode;
    evaluate();
    notifyListeners();
  }

  Future<void> restoreIfEnabled() async {
    if (!_settings.restoreState) return;
    final token = ++_restoreToken;
    final revisionAtStart = _stateRevision;
    await _restorePersistedState(
      restoreToken: token,
      revisionAtStart: revisionAtStart,
    );
  }

  Future<void> reloadSettingsAndRestore() async {
    final token = ++_restoreToken;
    final revisionAtStart = _stateRevision;
    final settings = await settingsRepository.load();
    if (_disposed || token != _restoreToken) return;
    _settings = AppSettings.fromMap(settings);
    if (!_settings.restoreState) {
      if (revisionAtStart == _stateRevision) {
        angleMode = _settings.angleMode;
        _clearEditingHistory();
      }
      evaluate();
      notifyListeners();
      return;
    }
    final restored = await _restorePersistedState(
      loadedSettings: settings,
      restoreToken: token,
      revisionAtStart: revisionAtStart,
    );
    if (!restored && !_disposed && token == _restoreToken) {
      evaluate();
      notifyListeners();
    }
  }

  Future<bool> _restorePersistedState({
    Map<String, String>? loadedSettings,
    required int restoreToken,
    required int revisionAtStart,
  }) async {
    final settings = loadedSettings ?? await settingsRepository.load();
    if (_disposed ||
        restoreToken != _restoreToken ||
        revisionAtStart != _stateRevision) {
      return false;
    }
    expression = settings['calculator_expression'] ?? '';
    _selection = _restoredSelection(settings, expression.length);
    _result = _restoredResult(settings);
    angleMode = settings['calculator_angle'] ?? _settings.angleMode;
    // 中文：恢复时也过那道判定——历史数据里可能存着一个 `Infinity`（本轮之前是可以造出来的），
    //       它不该被信任着进寄存器；`decimalValueOf` 同时挡掉 `NaN` 与下溢。挡下来的按「没有可用的
    //       记忆值」处理（0），与键缺失、值不可解析时的行为一致。
    // English: The restore goes through the same judgement too — old data may hold an `Infinity`
    //          (which this code could produce before this round) and it must not be trusted into the
    //          register; `decimalValueOf` also rejects `NaN` and underflow. What it rejects is treated
    //          as "no usable memory value" (0), the same as a missing or unparseable one.
    memoryValue =
        MathResult.decimalValueOf(settings['calculator_memory'] ?? '') ?? 0;
    _lastFiniteResult =
        _result.decimalText.isEmpty ? null : _result.decimalText;
    if (expression.isNotEmpty) evaluate();
    _clearEditingHistory();
    if (_disposed) return false;
    notifyListeners();
    return true;
  }

  void setAngleMode(String mode) {
    if (angleMode == mode) return;
    _markStateEdited();
    _recordUndoSnapshot();
    angleMode = mode;
    evaluate();
    _persistState();
    notifyListeners();
  }

  void setSelection(ExpressionSelection value) {
    final next = value.clamp(expression.length);
    if (_selection == next) return;
    _markStateEdited();
    _selection = next;
    unawaited(_persistState());
    notifyListeners();
  }

  void input(String token) {
    if (token == 'AC') {
      clear();
      return;
    }
    if (token == '⌫') {
      backspace();
      return;
    }
    if (token == '=') {
      _cancelLiveEvaluation();
      unawaited(submit());
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    if (token == '+/-') {
      _toggleSign();
    } else if (token == '%') {
      if (selection.isCollapsed) {
        _replaceAroundCursor(_applyPercent(expressionBeforeCursor));
      } else {
        _replaceSelectionWith('($_selectedExpression/100)');
      }
    } else if (_isOperator(token)) {
      final prefix = selection.isCollapsed
          ? _appendOperator(expressionBeforeCursor, token)
          : '$expressionBeforeCursor$token';
      _replaceAroundCursor(prefix);
    } else if (token == '.') {
      _replaceAroundCursor(_appendDecimal(expressionBeforeCursor));
    } else {
      _insert(token);
    }
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void setExpression(String value) {
    if (expression == value) return;
    _markStateEdited();
    _recordUndoSnapshot();
    expression = value;
    cursorIndex = expression.length;
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  CalculatorPasteResult applyPastedText(String value) {
    final paste = CalculatorPasteResult.fromText(value);
    final hasMetadata = paste.angleMode != null || paste.memoryValue != null;
    if (!paste.hasExpression && !hasMetadata) return paste;
    _markStateEdited();
    _recordUndoSnapshot();
    if (paste.hasExpression) {
      expression = paste.expression;
      cursorIndex = expression.length;
    }
    final angleChanged =
        paste.angleMode != null && angleMode != paste.angleMode;
    if (paste.angleMode != null) angleMode = paste.angleMode!;
    if (paste.memoryValue != null) memoryValue = paste.memoryValue!;
    if (paste.hasExpression || (angleChanged && expression.isNotEmpty)) {
      evaluate();
    }
    unawaited(_persistState());
    notifyListeners();
    return paste;
  }

  void append(String token) {
    _markStateEdited();
    _recordUndoSnapshot();
    final nextPrefix = _appendSmart(expressionBeforeCursor, token);
    _replaceAroundCursor(nextPrefix);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void applyUnaryFunction(String name) {
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      _replaceSelectionWith('$name($_selectedExpression)');
      _scheduleLiveEvaluation();
      notifyListeners();
      return;
    }
    final insertion = _wrapTrailingValue(expressionBeforeCursor, name);
    _replaceAroundCursor(insertion.text, cursorBack: insertion.cursorBack);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void applyBinaryFunction(String name) {
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      final selected = _selectedExpression;
      _replaceSelectionWith(
        '$name($selected,)',
        cursorOffset: name.length + selected.length + 2,
      );
      _scheduleLiveEvaluation();
      notifyListeners();
      return;
    }
    final insertion =
        _wrapTrailingValue(expressionBeforeCursor, name, binary: true);
    _replaceAroundCursor(insertion.text, cursorBack: insertion.cursorBack);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void backspace() {
    if (expression.isEmpty || (selection.isCollapsed && cursorIndex == 0)) {
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      expression = expression.substring(0, selection.start) +
          expression.substring(selection.end);
      cursorIndex = selection.start;
    } else {
      expression = expression.substring(0, cursorIndex - 1) +
          expression.substring(cursorIndex);
      cursorIndex--;
    }
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void continueWithResult() {
    if (hasError || result == '等待输入') return;
    _markStateEdited();
    _recordUndoSnapshot();
    expression = reusableResult;
    cursorIndex = expression.length;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
  }

  void clear() {
    if (expression.isEmpty &&
        result == '0' &&
        !hasError &&
        errorMessage == null) {
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    expression = '';
    cursorIndex = 0;
    _result = MathResult.zero;
    hasError = false;
    errorMessage = null;
    _ansSourceForExpression = null;
    _ansValueForExpression = null;
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：求值一次——**边打边算的入口**，也是这一步搬到引擎上的那一个。它做两件事：
  ///
  ///       1. **旧结果先上屏**（裁决 1 的策略 (B)，[liveResultPolicy]）：同步跑旧解析器，屏幕上
  ///          立刻有结果；策略 (A) 时这一步不做，屏幕留着上一个值。
  ///       2. **排一次引擎跟进**：延迟 [liveEngineFollowUpDelay] 之后问引擎，回包到达时替换。
  ///
  ///       这个方法**仍然是同步的**：它的所有调用方（`updateSettings`、`setAngleMode`、粘贴、
  ///       继续使用、记忆回填、恢复状态、以及 [_scheduleLiveEvaluation] 的定时器）都当它是同步的，
  ///       而界面在任何 await 上都不许被挡住。引擎那一发是它排出去的异步尾巴，用**提交路径同一个
  ///       代际守卫**（`_stateRevision`）保证过期回包不落地——这里不另写一份守卫。
  ///
  ///       引擎不可用（没有原生侧、超时、答不出有限的十进制）时**什么都不做**：屏幕上已经是旧解析器
  ///       的结果，回落对用户完全不可见。唯一的例外是策略 (A)——那里屏幕上没有旧结果，必须补上，
  ///       见 [_evaluateWithEngine]。
  ///
  /// English: Evaluate once — *the as-you-type entry point*, and the one this step moves onto the
  ///          engine. It does two things:
  ///
  ///          1. **The legacy result goes up first** (ruling 1's policy (B), [liveResultPolicy]): the
  ///             legacy parser runs synchronously so a result is on screen immediately; under policy
  ///             (A) this step is skipped and the previous value stays.
  ///          2. **An engine follow-up is scheduled**: the engine is asked after
  ///             [liveEngineFollowUpDelay], and its answer replaces the result when it lands.
  ///
  ///          The method itself **stays synchronous**: every caller (`updateSettings`,
  ///          `setAngleMode`, paste, continue-with-result, memory recall, state restore, and
  ///          [_scheduleLiveEvaluation]'s timer) treats it as synchronous, and the interface must
  ///          never be blocked on an await. The engine call is an asynchronous tail it schedules,
  ///          guarded against stale replies by **the submit path's own generation guard**
  ///          (`_stateRevision`) — no second guard is written here.
  ///
  ///          When the engine is unavailable (no native side, timeout, no finite decimal) this does
  ///          **nothing**: the legacy parser's result is already on screen, so the fallback is
  ///          invisible to the user. The one exception is policy (A), where no legacy result is on
  ///          screen and one has to be supplied — see [_evaluateWithEngine].
  void evaluate() {
    if (liveResultPolicy.showsLegacyResult) _evaluateLegacy();
    if (_liveEvaluationEngineBacked) _scheduleLiveEngineFollowUp();
  }

  /// 中文：旧求值器的那一次求值：同步、微秒级，写 [_result] / [hasError] / [errorMessage]。
  ///       它的行为**一字未改**——kill switch 关掉引擎跟进之后，边打边算就是它，与 3d 结束时逐字节
  ///       一致。
  /// English: One legacy evaluation: synchronous, microseconds, writing [_result], [hasError] and
  ///          [errorMessage]. Its behaviour is **unchanged** — with the engine follow-up switched off,
  ///          as-you-type evaluation is exactly this, byte-for-byte what it was at the end of 3d.
  void _evaluateLegacy() {
    if (expression.trim().isEmpty) {
      _result = MathResult.zero;
      hasError = false;
      errorMessage = null;
      return;
    }
    try {
      _result = _calculateResult(expression);
      hasError = false;
      errorMessage = null;
    } catch (error) {
      _result = MathResult.pending;
      hasError = true;
      errorMessage = _friendlyCalculationError(error);
    }
  }

  /// 中文：边打边算是否走引擎——**裁决 2 的 kill switch** 就是它，见
  ///       [kEngineBackedLiveExpressionDisplay]。切到另一个值，[_scheduleLiveEngineFollowUp] 再也
  ///       不会被调用，剩下的行为与 3d 结束时的边打边算逐字节一致。
  /// English: Whether as-you-type evaluation uses the engine — **ruling 2's kill switch**, see
  ///          [kEngineBackedLiveExpressionDisplay]. Flipping it means [_scheduleLiveEngineFollowUp]
  ///          is never called again and what remains is byte-for-byte the as-you-type behaviour of
  ///          the end of 3d.
  bool get _liveEvaluationEngineBacked =>
      _settings.expressionDisplayMode == kEngineBackedLiveExpressionDisplay;

  /// 中文：排一次引擎跟进，并**把上一次没发的取消掉**——这就是防抖：连续输入期间定时器一直被重排，
  ///       于是一次调用都不会发出，直到用户停下来。
  /// English: Schedule one engine follow-up and **cancel the one that has not fired yet** — that is
  ///          the debounce: while typing continues the timer keeps being reset, so no call is issued
  ///          at all until the user stops.
  void _scheduleLiveEngineFollowUp() {
    _liveEngineTimer?.cancel();
    _liveEngineTimer = Timer(liveEngineFollowUpDelay, () {
      if (_disposed) return;
      unawaited(_evaluateWithEngine());
    });
  }

  /// 中文：取消还没发的边打边算（两个定时器 + 「还欠一次」）。提交、撤销、重做都会走到这里：那一发
  ///       引擎跟进如果继续发出去，问的就是一条已经被提交路径接手的时间线。已在飞的那一发不在这里
  ///       收——它由代际守卫认出过期并丢弃。
  /// English: Cancel the as-you-type work that has not fired yet (both timers plus "one more is
  ///          owed"). Submit, undo and redo all reach here: letting that follow-up go would ask about
  ///          a timeline the submit path has already taken over. The call already in flight is not
  ///          collected here — the generation guard recognises it as stale and drops it.
  void _cancelLiveEvaluation() {
    _liveEvaluationTimer?.cancel();
    _liveEngineTimer?.cancel();
    _liveEngineDirty = false;
  }

  /// 中文：问引擎要边打边算的结果，并在回包到达时落地。四件事都在这里：
  ///
  ///       - **在飞上限为 1**。已经有一发在飞时不再发第二发，只把 [_liveEngineDirty] 立起来；
  ///         那一发回包落地之后再补一次（问的是最新的表达式）。于是无论用户打得多快，**控制器同时
  ///         等待的**引擎调用最多一发。
  ///
  ///         **但这不等于原生队列永远只有一发。** 超时会让 completer 完成、这里的槽位释放，
  ///         而那一发在原生侧**仍占着它的 FIFO 位置**——被放弃，但没有被取消。所以原生队列的真实
  ///         上界是 `1 + 被放弃的调用数`：引擎永久卡死时，每过一个 `engineTimeout` 就攒一条队列项，
  ///         **不需要用户做任何事**。后果是缓慢且无害的（不会产出错值），但**别把这个不变式当成会
  ///         自己报警的东西**——它恰恰在该报警的那种情形下不会报警。
  ///       - **过期的一律丢弃**。用的是提交路径同一个代际守卫：请求前记下 `_stateRevision`，落地前
  ///         再比一次；期间用户改过任何状态，这次回答描述的就是屏幕上已经不存在的那条时间线。
  ///         再比一次表达式，是为了堵住「表达式被换掉但没有走 [_markStateEdited]」的那条路
  ///         （状态恢复直接写 `expression`）。
  ///       - **回落是全覆盖的**。引擎答不出来（超时、没有原生侧、没有有限的十进制）时，策略 (B)
  ///         下屏幕上早就有旧解析器的结果，这里什么都不做；策略 (A) 下屏幕上没有旧结果，于是现在
  ///         补一次旧解析器——否则引擎一坏，结果行就永远停在旧值上。
  ///       - **采用引擎答案的判定与提交路径共用一处**（[_acceptedEngineResult]），不另写一份。
  ///
  /// English: Ask the engine for the as-you-type result and land it when the reply arrives. Four
  ///          things happen here:
  ///
  ///          - **At most one call in flight.** When one is already out, no second one is issued;
  ///            [_liveEngineDirty] is raised instead, and a further follow-up is made once that reply
  ///            lands (asking about the newest expression). However fast the user types, then, at most
  ///            one engine call is one this controller is *awaiting*.
  ///
  ///            **That is not the same as the native queue never holding more than one.** A timeout
  ///            completes the completer and frees the slot here, while the call itself **keeps its
  ///            FIFO place** on the native side — abandoned, not cancelled. So the real bound is
  ///            `1 + abandoned calls`: a permanently wedged engine accumulates one queued entry per
  ///            `engineTimeout`, with no user action required. The consequence is slow and harmless
  ///            (no wrong value is produced), but **do not treat this invariant as something that
  ///            announces itself** — it is precisely in the case that should trip it that it does not.
  ///          - **Stale replies are dropped.** It uses the submit path's own generation guard: the
  ///            generation is captured before the call and compared again before landing; if the user
  ///            changed any state in between, that answer describes a timeline that is no longer on
  ///            screen. The expression is compared as well, which closes the route where the
  ///            expression is replaced without going through [_markStateEdited] (state restore writes
  ///            `expression` directly).
  ///          - **The fallback is complete.** When the engine cannot answer (timeout, no native side,
  ///            no finite decimal) policy (B) does nothing, because the legacy parser's result is
  ///            already on screen; policy (A) has no legacy result on screen, so one is supplied now —
  ///            otherwise a broken engine would leave the result line stuck forever.
  ///          - **Accepting the engine's answer is shared with the submit path**
  ///            ([_acceptedEngineResult]); no second copy is written.
  Future<void> _evaluateWithEngine() async {
    if (_disposed) return;
    if (!_liveEvaluationEngineBacked) {
      // 中文：kill switch 是在**发这一发之前**被拨回去的（这一发的定时器早就排好了）。它必须在这里
      //       也拦一道，否则「切到旧路径」之后还会多问一次引擎——虽然那一发答什么都不会落地（代际
      //       已经变了），但开关要的是**一次都不问**。
      // English: The kill switch was flipped back *before this call went out* (its timer was scheduled
      //          earlier). It has to be checked here too, or "switched back to the legacy path" would
      //          still ask the engine one more time — that answer could not land (the generation has
      //          changed), but the switch promises not to ask at all.
      _liveEngineDirty = false;
      return;
    }
    final source = expression;
    if (source.trim().isEmpty) {
      // 中文：空表达式没有可问的东西，顺手把「还欠一次」清掉，免得它留到下一次输入。
      // English: There is nothing to ask about an empty expression; clear "one more is owed" while
      //          here so it cannot leak into the next input.
      _liveEngineDirty = false;
      return;
    }
    if (_liveEngineInFlight) {
      _liveEngineDirty = true;
      return;
    }
    _liveEngineInFlight = true;
    _liveEngineDirty = false;
    // 中文：与提交路径同一处守卫、同一个计数器。`Ans`/`last` 也要在这里先换成十进制数值，理由与
    //       提交路径一样：引擎不认识它们，直接问会把 `ans` 当成未知变量。
    // English: The same guard and the same counter the submit path uses. `Ans`/`last` are substituted
    //          here too, for the same reason as on the submit path: the engine does not know them and
    //          would read `ans` as an unknown variable.
    final generation = _stateRevision;
    final reply = await _askEngine(_resolveAnswerReferences(source));
    _liveEngineInFlight = false;
    if (_disposed) return;
    // 中文：先取出「还欠一次」再落地。不管落地与否都要还这一次：欠它的那一刻，用户已经改过输入，
    //       而那一发的答案永远只对**当前**表达式有效。它是一发，不是一队。
    // English: Take "one more is owed" out before landing anything. That one is owed regardless of how
    //          this landing goes: at the moment it was raised the user had already changed the input,
    //          and a follow-up answer is only ever good for the *current* expression. It is one call,
    //          not a queue.
    final owed = _liveEngineDirty;
    _liveEngineDirty = false;
    // 中文：**过期守卫必须在 `_selectEngineResult` 之前。** 取舍那一处可能走到旧解析器
    //       （`_tryLegacyResult` → `_calculateResult`），而那条路会写 `_lastFiniteResult`——
    //       那是 `Ans`/`last` 的取值处。守卫放在后面，一个**过期的**回包就能悄悄把它们挪到
    //       一条已经不在屏幕上的时间线上。提交路径一直守着这一点（`_submittedResult` 的第一件事
    //       就是问这一代对不对），边打边算这条以前靠「取舍不改状态」侥幸成立，放宽判据之后就
    //       不成立了。
    // English: **the staleness guard has to run before `_selectEngineResult`.** That selection may
    //          reach the legacy parser (`_tryLegacyResult` → `_calculateResult`), and that path writes
    //          `_lastFiniteResult` — where `Ans`/`last` read from. With the guard after it, a **stale**
    //          reply could quietly move them onto a timeline that is no longer on screen. The submit
    //          path has always guarded this (`_submittedResult`'s first act is to ask whether the
    //          generation still matches); the as-you-type path only held by the accident that
    //          selection touched no state, and relaxing the judgement ended that.
    if (generation != _stateRevision || expression != source) {
      if (owed) _scheduleLiveEngineFollowUp();
      return;
    }
    final accepted = _selectEngineResult(reply, source)?.result;
    if (accepted == null) {
      if (!liveResultPolicy.showsLegacyResult) {
        _evaluateLegacy();
        unawaited(_persistState());
        notifyListeners();
      }
    } else {
      _adoptEngineResult(accepted);
      unawaited(_persistState());
      notifyListeners();
    }
    if (owed) _scheduleLiveEngineFollowUp();
  }

  /// 中文：把引擎的结果落到屏幕上——与提交路径写的是同一组状态（结果、`_lastFiniteResult`、错误
  ///       状态），因此边打边算落地之后 `Ans`/`last` 引用的是引擎的十进制形态，而不是显示取整后
  ///       的那一份。
  /// English: Land the engine's result on screen — the same set of state the submit path writes
  ///          (the result, `_lastFiniteResult`, the error state), so that once an as-you-type result
  ///          lands, `Ans`/`last` resolve to the engine's decimal form rather than the display-rounded
  ///          one.
  void _adoptEngineResult(MathResult accepted) {
    _result = accepted;
    _lastFiniteResult =
        accepted.decimalText.isEmpty ? null : accepted.decimalText;
    hasError = false;
    errorMessage = null;
  }

  /// 中文：装上一次求值的三形态结果。**这是引擎接入时唯一的写入点**；在引擎接到求值路径之前，
  ///       只有测试用它来构造「精确形态与十进制形态并存」的结果。
  /// English: Install one evaluation's three-form result. This is the single write point the engine
  ///          will use when it is wired in; until the engine reaches the evaluation path, only tests
  ///          use it, to build a result whose exact and decimal forms coexist.
  ///
  /// 中文：`_lastFiniteResult` 在这里与十进制形态保持一致——没有十进制形态时置空，而不是退回显示
  ///       文本，否则 `Ans` 会把 `4√2` 当成数字塞进表达式。
  /// English: `_lastFiniteResult` is kept in step with the decimal form here — it becomes null when
  ///          there is no decimal form rather than falling back to the display text, which would make
  ///          `Ans` splice `4√2` into the expression as if it were a number.
  @visibleForTesting
  void applyMathResult(MathResult value) {
    _adoptEngineResult(value);
    notifyListeners();
  }

  Future<CalculatorSubmitResult> submit() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSubmitResult.emptyExpression();
    }
    _markStateEdited();
    _cancelLiveEvaluation();
    // 中文：本次提交的代际。`_stateRevision` 在每一次「状态被改过」时自增，也包括这次 submit 自己
    //       的 `_markStateEdited()`，所以在这之后取到的值就是「本次提交开始时的那一代」；回包落地
    //       之前再比一次，就能认出「用户在这次往返期间又动了什么」。
    // English: This submit's generation. `_stateRevision` is bumped whenever state is edited,
    //          including this submit's own `_markStateEdited()`, so the value taken after it is
    //          "the generation this submit started in"; comparing again before the reply lands is
    //          what recognises "the user touched something during this round trip".
    final generation = _stateRevision;
    try {
      final submittedExpression = expression;
      // 中文：只有「按下等号」这条路径问引擎。边打边算（`evaluate()`）一行未动，仍然完全走旧的
      //       同步解析器——把实时路径也搬过去的时序风险留给下一步。
      // English: Only "pressed =" asks the engine. As-you-type evaluation (`evaluate()`) is
      //          untouched and still runs entirely on the legacy synchronous parser; the timing
      //          risk of moving the live path stays out of this step.
      final calculated =
          await _submittedResult(submittedExpression, generation);
      // 中文：引擎往返期间用户又改了输入——或者控制器已经销毁。两种情况下这次的结果都不许落地：
      //       它描述的是一个已经不在屏幕上的表达式，落地会覆盖更新的边打边算结果，还会把
      //       `_lastFiniteResult` 与持久化内容一起带到那条过期的时间线上。
      //       启动后的第一次提交最容易触发（那一次包含懒加载 `loadGlobalDefinitions()`）。
      // English: The user edited during the engine round trip — or the controller is gone. Either
      //          way this result must not land: it describes an expression that is no longer on
      //          screen, and landing it would overwrite the newer as-you-type result and drag
      //          `_lastFiniteResult` and the persisted state onto that stale timeline. The first
      //          submit after launch is the likeliest trigger (it includes the lazy
      //          `loadGlobalDefinitions()`).
      if (calculated == null || _disposed) {
        return const CalculatorSubmitResult.superseded();
      }
      _result = calculated;
      hasError = false;
      errorMessage = null;
      final signature =
          _submittedCalculationSignature(submittedExpression, _result);
      final duplicate = _lastSavedSignature == signature;
      if (!_settings.autoSaveHistory) {
        // 中文：状态持久化不影响当前交互，失败也不应打断计算。
        // English: State persistence must not block the current interaction.
        unawaited(_persistState());
        notifyListeners();
        return CalculatorSubmitResult.calculated(
          expression: submittedExpression,
          result: result,
        );
      }
      if (duplicate) {
        unawaited(_persistState());
        notifyListeners();
        return CalculatorSubmitResult.historySkippedDuplicate(
          expression: submittedExpression,
          result: result,
        );
      }
      if (_settings.autoSaveHistory) {
        // 中文：先刷新结果，再后台写 SQLite，等号响应不被磁盘 IO 阻塞。
        // English: Show the result first and save to SQLite in the background so "=" stays instant.
        _lastSavedSignature = signature;
        notifyListeners();
        return _saveSubmittedResult(submittedExpression, result);
      }
      notifyListeners();
      return CalculatorSubmitResult.calculated(
        expression: submittedExpression,
        result: result,
      );
    } catch (error) {
      // 中文：过期或已销毁时错误同样不许落地——连错误状态也是那条过期时间线上的东西。
      // English: A stale or disposed submit must not land its error either — the error state
      //          belongs to that same stale timeline.
      if (_disposed || generation != _stateRevision) {
        return const CalculatorSubmitResult.superseded();
      }
      final message = _friendlyCalculationError(error);
      // 中文：错误文案只是显示文本，没有十进制形态——数值消费者据此不再解析它。
      // English: An error message is display text only and carries no decimal form, which is what
      //          stops numeric consumers from parsing it.
      _result = MathResult(displayText: message);
      hasError = true;
      errorMessage = message;
      notifyListeners();
      return CalculatorSubmitResult.invalidExpression(message);
    }
  }

  /// 中文：把当前表达式的结果保存成一条笔记。
  ///
  ///       **结果来源与「按下等号」完全一样**：[saveToNote] 曾经自己跑旧解析器重算一遍，于是引擎
  ///       辛苦算出的东西——超出 double 量程的值、精确形式——会在按下去的那一刻被旧求值器覆盖，
  ///       屏幕上的结果行当场翻脸，而笔记里写的是那个被覆盖后的值。现在两条路共用
  ///       [_submittedResult]：先问引擎，引擎答不出来才回落旧解析器（回落是与提交路径同一处的
  ///       判定，见 [_acceptedEngineResult]）。
  ///
  ///       代价是这一步变成了**真的异步**：以前重算是同步的，现在要等一次引擎往返，因此多出一条
  ///       提交路径早就有的分支——**过期**。往返期间用户又改了输入（`_stateRevision` 变了）或者
  ///       控制器已经销毁时，[CalculatorSaveNoteResult.superseded] 是唯一的正确答案：结果不许
  ///       落地，笔记也不许写，因为那两样都属于一条已经不在屏幕上的时间线。
  ///
  ///       `_markStateEdited()` 与 `_cancelLiveEvaluation()` 在等待之前发生：按「保存笔记」本身就
  ///       是一次状态编辑（撤销栈、代际），而还在排队的边打边算问的是一条即将被这一步接手的时间
  ///       线。已在飞的那一发不在这里收——代际守卫会认出它过期。
  ///
  /// English: Save the current expression's result as a note.
  ///
  ///          **The result comes from the same place "pressed =" uses**: [saveToNote] used to run the
  ///          legacy parser itself, so everything the engine had computed — values beyond a double's
  ///          range, exact forms — was overwritten the moment the button was pressed. The result line
  ///          then flipped in front of the user, and the note recorded the overwritten value. Both
  ///          paths now share [_submittedResult]: the engine is asked first and the legacy parser is
  ///          the fallback for when it cannot answer, judged in the one place the submit path uses
  ///          ([_acceptedEngineResult]).
  ///
  ///          The price is that this step is **genuinely asynchronous** now: the recomputation used
  ///          to be synchronous, and waiting on an engine round trip introduces the branch the submit
  ///          path already has — **staleness**. When the user edits during the round trip
  ///          (`_stateRevision` moves) or the controller is disposed,
  ///          [CalculatorSaveNoteResult.superseded] is the only right answer: the result must not
  ///          land and the note must not be written, because both belong to a timeline that is no
  ///          longer on screen.
  ///
  ///          `_markStateEdited()` and `_cancelLiveEvaluation()` happen before the wait: pressing
  ///          "save note" is itself a state edit (undo stack, generation), and any queued as-you-type
  ///          evaluation is asking about a timeline this step is about to take over. The call already
  ///          in flight is not collected here — the generation guard recognises it as stale.
  Future<CalculatorSaveNoteResult> saveToNote() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSaveNoteResult.emptyExpression();
    }
    _markStateEdited();
    _cancelLiveEvaluation();
    final generation = _stateRevision;
    try {
      final calculated = await _submittedResult(expression, generation);
      if (calculated == null) {
        return const CalculatorSaveNoteResult.superseded();
      }
      _result = calculated;
      hasError = false;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      final message = _friendlyCalculationError(error);
      _result = MathResult(displayText: message);
      hasError = true;
      errorMessage = message;
      notifyListeners();
      return CalculatorSaveNoteResult.invalidExpression(message);
    }

    try {
      final noteId = await notesRepository.create(
        title: '计算结果',
        body: noteBody(),
        description: '由计算器保存，${_angleModeLabel()}',
      );
      if (noteId <= 0) return const CalculatorSaveNoteResult.notWritten();
      unawaited(_persistState());
      return CalculatorSaveNoteResult.saved(noteId);
    } catch (error) {
      return CalculatorSaveNoteResult.failed(error);
    }
  }

  void memoryAdd() {
    // 中文：当前值放不进 double 时**不动寄存器**。以前这里会往寄存器里加一个 0——那是一个静默的
    //       错值（`2^-2000` 就是这样变成 0 的）；不加，寄存器至少还是用户上一次放进去的那个数。
    //       `memoryAdd()` 没有返回值，所以这一次拒绝对用户仍然不可见——要让它可见得先有一个
    //       能给界面看的返回值，那是界面层面的事，不在这一步里。
    // English: When the current value does not fit a double the register is left alone. This used
    //          to add a 0 — a silently wrong value (`2^-2000` is exactly how that happens); by not
    //          adding, the register at least still holds what the user last put there.
    //          `memoryAdd()` returns nothing, so the refusal is still invisible to the user; making
    //          it visible needs a return value the UI can show, which is a UI-layer matter and not
    //          part of this step.
    final value = _currentNumericValue();
    if (value == null) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue += value;
    unawaited(_persistState());
    notifyListeners();
  }

  void memorySubtract() {
    // 中文：与 [memoryAdd] 同理。
    // English: Same rule as [memoryAdd].
    final value = _currentNumericValue();
    if (value == null) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue -= value;
    unawaited(_persistState());
    notifyListeners();
  }

  void memoryRecall() {
    _markStateEdited();
    _recordUndoSnapshot();
    // 中文：记忆寄存器本身就是一个 double，写回表达式的是十进制文本（`formatNumber` 默认不加
    //       千分位），因此这一步与结果的三形态无关，也不需要经过显示文本。
    // English: The memory register is a plain double and what it writes back into the expression is
    //          decimal text (`formatNumber` adds no grouping separators by default), so this step is
    //          independent of the result's three forms and never touches the display text.
    expression = formatNumber(
      memoryValue,
      precision: _settings.precision,
    );
    cursorIndex = expression.length;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
  }

  void memoryClear() {
    if (memoryValue == 0) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue = 0;
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：「继续使用」写回表达式的那份文本：**十进制形态**优先，没有十进制形态时才退回显示
  ///       文本（去掉千分位）——与拆分前的 `result.replaceAll(',', '')` 逐字节一致，因此现有输入
  ///       的行为一字未变；而精确引擎接入后，写回的是十进制近似，不是 `4√2`。
  /// English: The text "continue with result" writes back into the expression: the decimal form
  ///          first, the display text with its grouping separators stripped only when there is no
  ///          decimal form — byte-for-byte what `result.replaceAll(',', '')` produced before the
  ///          split, so every existing input behaves exactly as it did. Once the exact engine lands,
  ///          what gets written back is the decimal approximation rather than `4√2`.
  String get reusableResult {
    if (hasError || result == '等待输入') return '0';
    return _result.reusableText;
  }

  bool get canContinueWithResult =>
      !hasError && result.trim().isNotEmpty && result != '等待输入';

  bool get canSaveCurrentExpression =>
      expression.trim().isNotEmpty && canContinueWithResult;

  String get resultStatusTitle {
    if (hasError) return '表达式需要修正';
    if (expression.trim().isEmpty) return '当前值可继续使用';
    return '结果可继续使用';
  }

  String get resultStatusMessage {
    if (hasError) {
      final message = errorMessage?.trim();
      return message == null || message.isEmpty ? '请检查表达式后重试。' : message;
    }
    if (expression.trim().isEmpty) {
      return '当前值 $result 可复制或作为下一次计算起点。';
    }
    final reusable = reusableResult;
    return '继续使用会把 $reusable 写回表达式，Ans/last 仍可引用上一次有限结果。';
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _markStateEdited();
    _cancelLiveEvaluation();
    _redoStack.add(_snapshot());
    _restoreSnapshot(_undoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _markStateEdited();
    _cancelLiveEvaluation();
    _undoStack.add(_snapshot());
    _restoreSnapshot(_redoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  String copyText() => _resultReportText();

  String noteBody() => _resultReportText(savedAt: DateTime.now());

  /// 中文：**提交路径**（只有「按下等号」会走到这里）的结果来源：先问引擎，问不到就回落旧解析器。
  ///
  ///       回落是硬要求，且引擎的失败对用户完全不可见：引擎未加载、没有原生侧、被中止、超时、
  ///       解析失败，用户看到的都是**今天那条结果或那条错误**，一字不差。所以这里接受引擎结果的
  ///       条件很紧——必须是一个**有限十进制**：
  ///
  ///       - 引擎没有十进制形态（`1 m` 这类带单位的结果）：回落到旧解析器；
  ///       - 十进制形态根本不是有限数（`infinity` / `NaN` 字面量）：同样回落，于是 `1/0` 仍然是
  ///         今天那条「结果不是有限数值」，而不是一个看起来像结果的 `无效`。
  ///
  ///       这个判断发生在**字符串层面**（[MathResult.hasFiniteDecimal]），**不借 double**：
  ///       `2^2000 ≈ 1.148e+602` 是一个完全正确的有限结果，只是超出 double 上限，用
  ///       `double.isFinite` 去判会把它当成无穷扔掉——那正是精确引擎存在的理由。同一根因的另一端
  ///       是下溢：`2^-2000 ≈ 9.3e-603` 会被 `double.tryParse` 变成 `0.0`，见
  ///       [MathResult.decimalValue]。
  ///
  ///       表达式先过 [_resolveAnswerReferences]，和旧路径一样：引擎不认识 `Ans`/`last`，问它
  ///       之前必须先换成十进制数值，否则它会把 `ans` 当成一个未知变量。回落分支故意把**原始**
  ///       表达式交给 [_calculateResult]，让它自己做同一件事——两次解析结果相同（`_ansValue…`
  ///       记下的正是第一次用的那个值），而跳过它会让 `_ansSource…` 被清空。
  ///
  ///       返回 null 表示**这次提交已经过期**（`generation` 不再是当前代际）：调用方什么都不许碰，
  ///       连回落计算也不许做——`_calculateResult` 会写 `_lastFiniteResult`，那也是过期时间线上的
  ///       状态。
  ///
  /// English: The result source for the *submit path* (only "pressed =" reaches it): ask the engine
  ///          first, fall back to the legacy parser when it cannot answer.
  ///
  ///          The fallback is a hard requirement, and the engine's failure is invisible to the
  ///          user: engine not loaded, no native side, aborted, timed out or failed to parse — the
  ///          user sees *today's* result or *today's* error, character for character. So the
  ///          condition for accepting the engine's answer is deliberately tight: it must be a
  ///          *finite decimal*, judged at the string level ([MathResult.hasFiniteDecimal]) and
  ///          never through a double:
  ///
  ///          - the engine has no decimal form (a result carrying a unit, say `1 m`): fall back;
  ///          - the decimal form is not a finite number at all (the `infinity` / `NaN` literals):
  ///            fall back too, so `1/0` still produces today's "result is not finite" rather than a
  ///            `无效` that looks like a result.
  ///
  ///          Judging finiteness at the string level matters because `2^2000 ≈ 1.148e+602` is a
  ///          perfectly correct finite result that merely overflows a double — `double.isFinite`
  ///          would throw the engine's right answer away, which is the very reason an exact engine
  ///          exists. The other end of the same root cause is underflow: `2^-2000 ≈ 9.3e-603`
  ///          becomes `0.0` through `double.tryParse`. See [MathResult.decimalValue].
  ///
  ///          The expression goes through [_resolveAnswerReferences] first, exactly as on the legacy
  ///          path: the engine does not know `Ans`/`last`, so they must be substituted before it is
  ///          asked, or it would treat `ans` as an unknown variable. The fallback branch hands the
  ///          *original* expression to [_calculateResult] on purpose, letting it do the same thing
  ///          itself — both resolutions produce the same string (`_ansValue…` holds exactly the
  ///          value the first one used), while skipping it would clear `_ansSource…`.
  ///
  ///          A null return means *this submit is stale* (its `generation` is no longer current):
  ///          the caller must touch nothing at all, not even run the fallback — `_calculateResult`
  ///          writes `_lastFiniteResult`, and that too belongs to the stale timeline.
  Future<MathResult?> _submittedResult(String source, int generation) async {
    final resolvedSource = _resolveAnswerReferences(source);
    final reply = await _askEngine(resolvedSource);
    // 中文：回包到手的**第一件事**是问一句「这还是当前那一代吗」，在碰任何状态之前——包括
    //       回落分支会写的那份 `_lastFiniteResult`。
    // English: The *first* thing to do with a reply is ask "is this still the current generation",
    //          before touching any state — including the `_lastFiniteResult` the fallback writes.
    if (_disposed || generation != _stateRevision) return null;
    final selected = _selectEngineResult(reply, source);
    if (selected != null) {
      final accepted = selected.result;
      // 中文：`_lastFiniteResult` 只在这一份结果**能当数字用**时才更新，规则与 [applyMathResult]
      //       相同——数值消费者依旧只认有限十进制，放宽的是「能不能显示」，不是这一条。矩阵、复数
      //       这类结果的 `decimalText` 本来是空的，写进去等于把 `Ans`/`last` 变成空串，所以这里
      //       连试都不试。
      //       能当数字用时，它与十进制形态保持一致：`Ans`/`last` 用的是引擎的精确值，而不是显示
      //       取整后的那一份。放不进 double 的值也一样——存的是**文本**，写回表达式时用的就是它。
      // English: `_lastFiniteResult` is updated only while this result is **usable as a number**,
      //          the same rule as [applyMathResult] — numeric consumers still accept nothing but a
      //          finite decimal; what was relaxed is "may it be shown", not this. A matrix or a
      //          complex number carries an empty `decimalText` anyway, and writing that would turn
      //          `Ans`/`last` into an empty string, so it is not even attempted here.
      //          When it is usable as a number it stays in step with the decimal form: `Ans`/`last`
      //          resolve to the engine's accurate value rather than the display-rounded one. A value
      //          that does not fit a double is no different — what is kept is *text*, and that text
      //          is what gets written back into the expression.
      if (selected.usableAsNumber) {
        _lastFiniteResult = accepted.decimalText;
      }
      return accepted;
    }
    // 中文：回落对用户不可见（这是要求），所以必须留下一条日志——否则「引擎其实一次都没答上来」
    //       在设备上和「引擎工作正常」长得一模一样。
    // English: The fallback is invisible to the user (that is the requirement), so it has to leave a
    //          log line behind — otherwise "the engine never answered once" looks exactly like "the
    //          engine works fine" on a device.
    debugPrint(
      '$qalculateLogTag 引擎没有可用结果，提交路径回落到旧解析器: '
      '${reply.error ?? '引擎给出的十进制形态不可用'}',
    );
    return _calculateResult(source);
  }

  /// 中文：问一次引擎，并给它一个上限。**提交路径与边打边算共用这一个入口。** 两件事都在这里做：
  ///
  ///       - **异常在这里停住**。[MathEngine] 的契约要求实现不抛异常，但调用方不能把「实现有
  ///         没有守约」当成本钱：守约失败时按「引擎没有可用结果」处理，而不是让一个只在设备上
  ///         出现的异常变成用户可见的错误。
  ///       - **等待在这里封顶**。[engineTimeout] 到点还没等到回执，就按「引擎没有可用结果」处理，
  ///         不是报错。没有它，原生一次卡死会让 `=` 从此静默失效到重启。
  ///
  ///       定时器是手写的而不是 `Future.timeout`：只有这样它才**属于控制器**，[dispose] 时能连
  ///       同还没回话的请求一起收掉。`Future.timeout` 的定时器拿不到句柄，控制器销毁后它还挂在
  ///       事件循环上（`flutter_test` 的「widget 树销毁后仍有定时器」正是查这个）。收掉时给在飞的
  ///       请求补一条失败回执，于是两边的 `await` 一定会返回——提交走既有的过期分支，边打边算走
  ///       [_evaluateWithEngine] 的 `_disposed` 分支——而不是永远悬着。
  ///
  ///       迟到的原生回包在这里被丢掉（completer 已经完成），所以它不会去覆盖任何已经落地的结果。
  ///
  /// English: Ask the engine once, with a bound. The submit path and as-you-type evaluation **share
  ///          this one entry point**. Two things happen here:
  ///
  ///          - **Exceptions stop here.** The [MathEngine] contract says implementations must not
  ///            throw, but a caller cannot stake its behaviour on the implementation keeping that
  ///            promise: a broken promise counts as "no usable result" instead of turning into a
  ///            user-visible error that only ever appears on a device.
  ///          - **The wait is capped here.** When [engineTimeout] elapses with no receipt the call
  ///            counts as "the engine has no usable result" — not an error. Without it one stuck
  ///            native call makes `=` silently dead until restart.
  ///
  ///          The timer is hand-rolled rather than `Future.timeout` precisely so that it *belongs to
  ///          the controller* and [dispose] can collect it together with the request still in
  ///          flight. A `Future.timeout` timer cannot be reached, so it stays on the event loop
  ///          after the controller is gone (which is exactly what flutter_test's "a timer is still
  ///          pending after the widget tree was disposed" catches). Collecting a pending request
  ///          hands it a failure receipt, so both `await`s always return — submit takes its existing
  ///          stale branch, as-you-type takes [_evaluateWithEngine]'s `_disposed` branch — instead of
  ///          hanging forever.
  ///
  ///          A late native reply is dropped here (the completer has already completed), so it can
  ///          never overwrite a result that has already landed.
  Future<EngineReply> _askEngine(String expression) {
    final completer = Completer<EngineReply>();
    final timer = Timer(engineTimeout, () {
      _engineCalls.remove(completer);
      if (completer.isCompleted) return;
      completer.complete(
        EngineReply.failure(
            'engine_timeout: ${engineTimeout.inMilliseconds}ms'),
      );
    });
    _engineCalls[completer] = timer;

    /// 中文：引擎回话（或抛出来）时的收尾，两条路共用。
    /// English: The wrap-up for whichever way the engine answers (or throws); both paths share it.
    void settle(EngineReply reply) {
      _engineCalls.remove(completer);
      if (completer.isCompleted) return;
      timer.cancel();
      completer.complete(reply);
    }

    try {
      unawaited(
        _engine.evaluate(expression, angleMode: angleMode).then(
              settle,
              onError: (Object error) =>
                  settle(EngineReply.failure('engine_threw: $error')),
            ),
      );
    } catch (error) {
      // 中文：`evaluate` 在返回 Future 之前就抛了出来——异步方法抛算是被拒绝的 Future（走
      //       `onError`），但一个同步实现可以在返回之前直接抛。这一条在修复轮 1 把引擎调用搬出
      //       原来那个 `try` 时丢掉了，`=` 于是从「回落旧解析器」变成「表达式错误」；这里补回来，
      //       并且顺手把定时器收掉。
      // English: `evaluate` threw before it returned a Future — an `async` method's throw becomes a
      //          rejected future (handled by `onError`), but a synchronous implementation can throw
      //          before it returns at all. Fix round 1 lost this when it moved the engine call out of
      //          the old `try`, which turned "=" from a legacy fallback into "表达式错误"; this puts
      //          it back and collects the timer while it is at it.
      settle(EngineReply.failure('engine_threw: $error'));
    }
    return completer.future;
  }

  /// 中文：把引擎的结果变成屏幕上的结果。引擎的十进制形态是**未取整**的（16 位有效数字），显示
  ///       形态仍然由 `formatNumber` 按 `AppSettings.precision`（小数位数）取整——取整只有这一处
  ///       实现，边打边算与提交路径共用，用户在设置里选的位数对两条路径含义完全相同。引擎负责
  ///       算得准，Dart 负责显示成什么样。
  ///
  ///       **放不进 double 的结果**（`2^2000 ≈ 1.148e+602`、`2^-2000 ≈ 9.3e-603`）原样显示引擎
  ///       那一份十进制文本：Dart 手里没有可以取整的数（`decimalValue` 为 null），硬要走
  ///       `formatNumber` 只能先把 `Infinity` 或 `0` 喂进去，而那两个都是假值。取整规则没有被搬到
  ///       引擎里，只是对超出取整能力的结果不假装能取整。
  /// English: Turns the engine's result into the one on screen. The engine's decimal form is
  ///          *unrounded* (16 significant digits) while the display form still comes from
  ///          `formatNumber` at `AppSettings.precision` (a count of decimal places) — rounding has
  ///          exactly one implementation, shared by as-you-type and submit, so the digit count the
  ///          user picked means the same thing on both paths. The engine computes accurately; Dart
  ///          decides what it looks like.
  ///
  ///          A result that does not fit a double (`2^2000 ≈ 1.148e+602`, `2^-2000 ≈ 9.3e-603`) is
  ///          shown as the engine's own decimal text: Dart has no number to round (`decimalValue` is
  ///          null), and forcing it through `formatNumber` would mean feeding it `Infinity` or `0` —
  ///          both false. Rounding has not moved into the engine; the code just does not pretend to
  ///          round what it cannot represent.
  /// 中文：**引擎这一次的回答能不能采用**——提交路径与边打边算共用这一处，不写第二份。
  ///       采用的条件只有一条：引擎给出了一个**有限十进制**（[MathResult.hasFiniteDecimal]，
  ///       判定在字符串层面，不借 double）。不满足就返回 null，调用方按「这一次没有引擎结果」处理。
  ///
  ///       为什么这必须是同一处：边打边算产生的结果**远多于**提交，是更大的风险面；判定写两份，
  ///       「显示文本 → 提交路径 → `_currentNumericValue`」那次漂移就会重演一遍。
  ///
  /// English: **Whether this engine answer may be adopted** — the submit path and as-you-type
  ///          evaluation share this one place, never a second copy. There is exactly one condition:
  ///          the engine produced a *finite decimal* ([MathResult.hasFiniteDecimal], judged at the
  ///          string level rather than through a double). When that fails it returns null and the
  ///          caller treats it as "no engine result this time".
  ///
  ///          Why it has to be one place: as-you-type evaluation produces far *more* results than
  ///          submission and is therefore the larger risk surface; with the judgement written twice,
  ///          the drift of "display text → submit path → `_currentNumericValue`" happens all over
  ///          again.
  MathResult? _acceptedEngineResult(EngineReply reply) {
    if (!reply.ok) return null;
    final engineResult = reply.result;
    if (engineResult == null || !engineResult.hasFiniteDecimal) return null;
    return _engineMathResult(engineResult);
  }

  /// 中文：**能不能显示**（第二个判据，与「能不能当数字用」分开）。矩阵、复数、解集、精确形式都没有
  ///       有限十进制，但它们是引擎算出来的值——「有十进制才配显示」会让它们永远上不了屏，
  ///       而它们正是引入引擎的理由。判据本身在 [MathResult.isDisplayable] 里，只有那一处实现。
  /// English: **Whether it may be shown** — the second judgement, kept apart from "can it be used as
  ///          a number". A matrix, a complex number, a solution set or an exact form has no finite
  ///          decimal, yet each is a value the engine computed; "only what has a decimal deserves to
  ///          be shown" would keep them off the screen forever, and they are why the engine is here.
  ///          The judgement itself lives in [MathResult.isDisplayable], the one implementation.
  MathResult? _displayableEngineResult(EngineReply reply) {
    if (!reply.ok) return null;
    final engineResult = reply.result;
    if (engineResult == null || !engineResult.isDisplayable) return null;
    return _engineMathResult(engineResult);
  }

  /// 中文：**引擎这一次的回答该怎么取舍**——提交路径与边打边算共用这一处，不写第二份。
  ///       两级，顺序不能反：
  ///
  ///       1. **能当数字用**（有限十进制）→ 用引擎的。与迁移引擎之前逐字节一致：数值消费者要的
  ///          就是它，`Ans`/`last` 拿到的是引擎的精确十进制。
  ///       2. **只能显示**（矩阵、复数、符号结果…）→ **先问旧解析器**。旧解析器认的是这个应用
  ///          自己的词汇表（`ncr`/`npr`/`fact`/`log2` 是应用的名字，引擎并不认识——设备实测
  ///          `ncr(5,10)` 被引擎解释成一串带单位的量 `[(1.49896229n'r' km/us) …]`）。那种情况下
  ///          引擎的「答案」是它把表达式理解成别的东西之后的产物，而旧解析器给的是这个应用一贯的
  ///          答案；**已经上线的键因此逐字节不变**。旧解析器答不出来（矩阵、复数、`solve`）时，
  ///          才用引擎的显示形态。
  ///
  ///       `usableAsNumber` 就是第 1 级与第 2 级的分界，调用方据此决定 `_lastFiniteResult`——
  ///       数值消费者依旧只认有限十进制，这一条**没有放宽**。
  /// English: **How this engine answer is to be taken** — the submit path and as-you-type evaluation
  ///          share this one place; no second copy. Two tiers, and the order matters:
  ///
  ///          1. **usable as a number** (a finite decimal) → take the engine's. Byte-for-byte what it
  ///             was before the engine was wired in: numeric consumers want exactly this, and
  ///             `Ans`/`last` get the engine's accurate decimal.
  ///          2. **displayable only** (a matrix, a complex number, a symbolic result, …) → **ask the
  ///             legacy parser first**. The legacy parser knows this app's own vocabulary
  ///             (`ncr`/`npr`/`fact`/`log2` are the app's names; the engine does not know them — on a
  ///             device `ncr(5,10)` came back as a list of unit-carrying quantities,
  ///             `[(1.49896229n'r' km/us) …]`). In that case the engine's "answer" is what it made of
  ///             an expression it read as something else, while the legacy parser gives the answer
  ///             this app has always given; **keys that already work are therefore unchanged**.
  ///             Only when the legacy parser cannot answer (matrices, complex numbers, `solve`) is the
  ///             engine's displayable form used.
  ///
  ///          `usableAsNumber` is the boundary between the two tiers, and the caller uses it to decide
  ///          `_lastFiniteResult` — numeric consumers still accept nothing but a finite decimal, and
  ///          that has **not** been relaxed.
  ({MathResult result, bool usableAsNumber})? _selectEngineResult(
    EngineReply reply,
    String source,
  ) {
    final numeric = _acceptedEngineResult(reply);
    if (numeric != null) return (result: numeric, usableAsNumber: true);
    final displayable = _displayableEngineResult(reply);
    if (displayable == null) return null;
    final legacy = _tryLegacyResult(source);
    if (legacy != null) return (result: legacy, usableAsNumber: true);
    return (result: displayable, usableAsNumber: false);
  }

  /// 中文：旧解析器**试一次**——答不出来时给 null 而不是抛异常。[_calculateResult] 是那条会抛的
  ///       出口，两者共用同一份实现：这里只是把异常收成 null。
  /// English: one **attempt** at the legacy parser — null instead of throwing when it cannot answer.
  ///          [_calculateResult] is the throwing exit; both share one implementation, this only turns
  ///          the exception into null.
  MathResult? _tryLegacyResult(String source) {
    try {
      return _calculateResult(source);
    } catch (_) {
      return null;
    }
  }

  MathResult _engineMathResult(MathResult engineResult) {
    final value = engineResult.decimalValue;
    if (value == null) return engineResult;
    return MathResult(
      displayText: formatNumber(
        value,
        precision: _settings.precision,
        groupThousands: _settings.groupThousands,
      ),
      displayTex: engineResult.displayTex,
      decimalText: engineResult.decimalText,
    );
  }

  /// 中文：旧求值器的唯一出口——它只产出一个 `double`，所以三形态里的 LaTeX 是空的，而显示文本
  ///       同时也是十进制文本。这是引擎缺席时（以及引擎答不出来时）用的那一条路。
  /// English: The legacy evaluator's only exit. It produces a bare `double`, so the LaTeX form is
  ///          empty and the display text doubles as the decimal text. This is the path used while
  ///          the engine is absent — and whenever it cannot answer.
  MathResult _calculateResult(String source) {
    final resolvedSource = _resolveAnswerReferences(source);
    final value =
        ExpressionParser(resolvedSource, degreeMode: angleMode == 'DEG')
            .parse();
    if (!value.isFinite) {
      throw const FormatException('Result is not finite');
    }
    final formatted = formatNumber(
      value,
      precision: _settings.precision,
      groupThousands: _settings.groupThousands,
    );
    final mathResult = MathResult.legacy(formatted);
    _lastFiniteResult =
        mathResult.decimalText.isEmpty ? null : mathResult.decimalText;
    return mathResult;
  }

  String _resultReportText({DateTime? savedAt}) {
    final lines = <String>[
      if (expression.trim().isEmpty) '当前值: $result' else '表达式: $expression',
      if (expression.trim().isNotEmpty) '结果: $result',
      // 中文：显示文本本身不是可解析的十进制时（引擎给出 `4√2` 这类精确形式），报告补一行十进制：
      //       粘贴路径优先读它，否则「复制结果再粘回计算器」这条往返会在精确形式上悄悄断掉。旧求值
      //       器下这一行永不出现，报告文本与拆分前逐字符一致。
      // English: When the display text is not itself a parseable decimal (the engine's exact forms
      //          such as `4√2`), the report adds a decimal line: the paste path reads it first, or
      //          the copy-a-result-and-paste-it-back round trip would quietly break on exact forms.
      //          Under the legacy evaluator this line never appears, so the report text stays
      //          character-for-character what it was.
      if (_result.decimalText.isNotEmpty && !_result.displayTextIsParseable)
        '十进制: ${_result.decimalText}',
      '状态: $resultStatusTitle',
      resultStatusMessage,
      '角度模式: ${_angleModeLabel()}',
      if (memoryValue != 0)
        '记忆值: ${formatNumber(memoryValue, precision: _settings.precision, groupThousands: _settings.groupThousands)}',
      if (hasError && errorMessage != null) '错误: $errorMessage',
      if (savedAt != null) '保存时间: ${_formatReportTime(savedAt)}',
    ];
    return lines.join('\n');
  }

  String _angleModeLabel() => angleMode == 'DEG' ? '角度 DEG' : '弧度 RAD';

  String _formatReportTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _friendlyCalculationError(Object error) {
    final message = error.toString().replaceFirst('FormatException: ', '');
    if (message.contains('Missing )')) return '缺少右括号';
    if (message.contains('Expected number')) return '需要输入数字';
    if (message.contains('Unexpected token')) return '存在无法识别的内容';
    if (message.contains('needs (')) return '函数需要括号';
    if (message.contains('Unknown function')) return '未知函数';
    if (message.contains('Factorial needs')) return '阶乘只支持 0 到 170 的整数';
    if (message.contains('Root degree cannot be 0')) return '根指数不能为 0';
    if (message.contains('Even root of negative')) return '负数不能开偶次根';
    if (message.contains('Result is not finite')) return '结果不是有限数值';
    return '表达式错误';
  }

  String get expressionBeforeCursor => expression.substring(0, selection.start);

  String get expressionAfterCursor => expression.substring(selection.end);

  void moveCursorLeft() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.start;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    if (cursorIndex == 0) return;
    _markStateEdited();
    cursorIndex--;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorRight() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.end;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    if (cursorIndex >= expression.length) return;
    _markStateEdited();
    cursorIndex++;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorByBlockBackward() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.start;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    final boundary = previousExpressionBoundary(expression, cursorIndex);
    if (boundary == cursorIndex) return;
    _markStateEdited();
    cursorIndex = boundary;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorByBlockForward() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.end;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    final boundary = nextExpressionBoundary(expression, cursorIndex);
    if (boundary == cursorIndex) return;
    _markStateEdited();
    cursorIndex = boundary;
    unawaited(_persistState());
    notifyListeners();
  }

  void selectAll() {
    final next = ExpressionSelection(0, expression.length);
    if (_selection == next) return;
    _markStateEdited();
    _selection = next;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorToStart() {
    if (selection.isCollapsed && cursorIndex == 0) return;
    _markStateEdited();
    cursorIndex = 0;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorToEnd() {
    if (selection.isCollapsed && cursorIndex == expression.length) return;
    _markStateEdited();
    cursorIndex = expression.length;
    unawaited(_persistState());
    notifyListeners();
  }

  Future<void> _persistState() async {
    if (!_settings.restoreState) return;
    await settingsRepository.setMany({
      'calculator_expression': expression,
      'calculator_result': result,
      // 中文：三形态一起落盘，否则重启后精确形式会丢掉十进制形态，Ans/last 又变成静默失效。
      // English: Land all three forms together; otherwise the exact form survives a restart without
      //          its decimal form and Ans/last silently stop resolving again.
      'calculator_result_tex': _result.displayTex,
      'calculator_result_decimal': _result.decimalText,
      'calculator_angle': angleMode,
      'calculator_memory': memoryValue.toString(),
      'calculator_cursor': cursorIndex.toString(),
      'calculator_selection_start': selection.start.toString(),
      'calculator_selection_end': selection.end.toString(),
    });
  }

  MathResult _restoredResult(Map<String, String> settings) {
    final displayText = settings['calculator_result'] ?? '0';
    // 中文：判别依据是**键在不在**，不是值空不空——`?? ''` 分不清两种空：
    //       「拆分之前存下的旧行」（没有这个键，十进制形态要从显示文本推导）与「十进制形态就是
    //       故意为空的新行」（键在、值是空串，代表引擎这一次没有给出十进制形态）。把它们混成
    //       一种，空十进制会在重启后被从显示文本重新推导出来——一个引擎从没给过的数字，于是
    //       `Ans`/`last` 又开始引用它。这个类型的全部意义就是「空表示没有十进制形态」，这条
    //       不变量必须能活过一次重启。
    // English: The discriminator is whether the *key exists*, not whether the value is empty —
    //          `?? ''` cannot tell two different empties apart: a row written before the split
    //          (no such key, so the decimal form is derived from the display text) and a new row
    //          whose decimal form is deliberately empty (the key is there with an empty value,
    //          meaning the engine produced no decimal form this time). Collapsing them re-derives
    //          the decimal from the display text after a restart — a number the engine never
    //          produced — and `Ans`/`last` start resolving from it again. The whole point of this
    //          type is that an empty string means "no decimal form"; that invariant has to survive
    //          a restart.
    final hasDecimalField = settings.containsKey('calculator_result_decimal');
    return MathResult(
      displayText: displayText,
      displayTex: settings['calculator_result_tex'] ?? '',
      decimalText: hasDecimalField
          ? (settings['calculator_result_decimal'] ?? '')
          : MathResult.decimalTextOf(displayText),
    );
  }

  ExpressionSelection _restoredSelection(
    Map<String, String> settings,
    int expressionLength,
  ) {
    final start = int.tryParse(settings['calculator_selection_start'] ?? '');
    final end = int.tryParse(settings['calculator_selection_end'] ?? '');
    if (start != null && end != null) {
      return ExpressionSelection(start, end).clamp(expressionLength);
    }
    return ExpressionSelection.collapsed(
      _restoredCursorIndex(settings['calculator_cursor'], expressionLength),
    );
  }

  int _restoredCursorIndex(String? value, int expressionLength) {
    return (int.tryParse(value ?? '') ?? expressionLength)
        .clamp(0, expressionLength);
  }

  Future<CalculatorSubmitResult> _saveSubmittedResult(
    String expression,
    String result,
  ) async {
    try {
      final historyId = await historyRepository.saveCalculation(
          expression: expression, result: result);
      await _persistStateSafely();
      if (historyId <= 0) {
        _clearLastSavedSignature();
        return CalculatorSubmitResult.historyNotWritten(
          expression: expression,
          result: result,
        );
      }
      return CalculatorSubmitResult.historySaved(
        expression: expression,
        result: result,
        historyId: historyId,
      );
    } catch (error) {
      // 中文：后台保存失败时释放去重缓存，用户下次按等号仍可重试保存。
      // English: Clear duplicate guards on background save failure so the next submit can retry.
      _clearLastSavedSignature();
      await _persistStateSafely();
      return CalculatorSubmitResult.historyFailed(
        expression: expression,
        result: result,
        error: error,
      );
    }
  }

  Future<void> _persistStateSafely() async {
    try {
      await _persistState();
    } catch (_) {}
  }

  /// 中文：记忆寄存器要加/减的数值。**给不出一个能放进 double 的值时返回 null**——调用方据此
  ///       显式拒绝，而不是往寄存器里加一个 0 或一个 `Infinity`。绝不解析显示文本。
  ///
  ///       取值的顺序，三条都共用既有的判定（[MathResult.decimalTextIsFinite] /
  ///       [MathResult.decimalValueOf] / [MathResult.decimalValue]，与提交路径、粘贴路径同一处
  ///       实现，不另写一份）：
  ///
  ///       1. 表达式**本身就是一个数**（「继续使用」写回之后正是这种形状）→ 按**文本**判定。文本里
  ///          还留着 double 已经丢掉的信息，这正是它能识破下溢的原因。
  ///       2. 其余表达式 → **屏幕上那个结果的十进制形态**，只要它是引擎算出来的（[_result] 带 LaTeX
  ///          形态）。注意这里加的不是屏幕上**显示**的那个数：[_result.displayText] 已经按
  ///          `AppSettings.precision` 取过整（屏幕上是 `5.656854`），而寄存器拿的是
  ///          [_result.decimalText]，也就是引擎那一串未取整的十进制（`5.656854249492380`）。
  ///          这正是 `Ans`/`last` 用的那一份，两者不能是两套口径；此处的判定是结果里那串
  ///          **十进制文本**，`2^-2000` 的 `0.0` 因此不会再被当成一个真值收下。
  ///       3. 引擎没有参与（没有原生侧、kill switch 关掉、超时、答不出有限的十进制）→ 旧解析器，
  ///          与迁移之前逐字节相同。这是硬性回落的另一半：`_currentNumericValue()` 是同步的，
  ///          没有引擎结果可用的那些情形只能由旧解析器兜着。
  ///
  ///       这条分支以前**无条件**走旧解析器，于是引擎算出的值在按下 `M+` 时被重算一遍：
  ///
  ///       - `2^-2000` → `=` →「继续使用」把 `8.7e-603` 写回表达式 → `M+`：解析器给 `0.0`，
  ///         寄存器里静默变成 0；
  ///       - `2^2000` → 同样的路 → 解析器给 `Infinity`，寄存器里是 `Infinity`，而且会持久化、
  ///         重启后还在；
  ///       - `2^-2000` → `=` → `M+`（**不经过**「继续使用」）：旧解析器自己就把 `9.3e-603` 算成了
  ///         `0.0`，[MathResult.usableDouble] 只能判非有限、判不了下溢——于是执行的是「加一个
  ///         0」。这一条现在也堵上了：引擎在屏幕上留下的是它的十进制文本，下溢在那里看得出来，
  ///         于是寄存器**不被改动**（与上面那条一样是值中性的，但不再是「拿一个错值去加」）。
  ///
  /// English: The value the memory register adds or subtracts. It returns null when nothing fits a
  ///          double, and the caller then refuses explicitly rather than adding a 0 or an
  ///          `Infinity`. The display text is never parsed.
  ///
  ///          The order, all three sharing the existing judgements
  ///          ([MathResult.decimalTextIsFinite] / [MathResult.decimalValueOf] /
  ///          [MathResult.decimalValue] — the *same* implementation the submit path and the paste
  ///          path use, never a second copy):
  ///
  ///          1. The expression **is itself a number** (exactly the shape "continue with result"
  ///             leaves behind) → judged as **text**. The text still carries what the double has
  ///             already lost, which is what lets it see the underflow.
  ///          2. Any other expression → **the result on screen**, as long as the engine produced it
  ///             ([_result] carries a LaTeX form). What the register adds is the number the user is
  ///             looking at, the same one `Ans`/`last` use; the judgement here is made on the
  ///             result's **decimal text**, so the `0.0` of `2^-2000` is no longer taken as a real
  ///             value.
  ///          3. No engine involved (no native side, kill switch off, timeout, no finite decimal) →
  ///             the legacy parser, byte-for-byte what it did before the migration. That is the other
  ///             half of the hard fallback rule: `_currentNumericValue()` is synchronous, so the
  ///             cases with no engine answer are exactly the ones only the legacy parser can cover.
  ///
  ///          This branch used to go through the legacy parser **unconditionally**, so pressing `M+`
  ///          recomputed what the engine had already computed:
  ///
  ///          - `2^-2000` → `=` → "continue with result" writes `8.7e-603` back into the expression
  ///            → `M+`: the parser yields `0.0` and the register silently becomes 0;
  ///          - `2^2000` → the same route → the parser yields `Infinity`, the register holds
  ///            `Infinity`, and it persists across a restart;
  ///          - `2^-2000` → `=` → `M+` (**without** "continue with result"): the legacy parser turns
  ///            `9.3e-603` into `0.0` by itself, and [MathResult.usableDouble] can only judge
  ///            non-finiteness, not underflow — so it performed "add a zero". That one is closed
  ///            now too: what the engine left on screen is its decimal text, the underflow is visible
  ///            in it, and the register is therefore **left alone** (value-neutral like the case
  ///            above, but no longer a wrong value being added).
  double? _currentNumericValue() {
    try {
      if (expression.trim().isEmpty) return _result.decimalValue;
      final source = _resolveAnswerReferences(expression);
      if (MathResult.decimalTextIsFinite(source)) {
        return MathResult.decimalValueOf(source);
      }
      // 中文：`hasTex` 就是「这个结果是引擎算出来的」——旧路径从不写 LaTeX 形态，而引擎路径总有
      //       一段（见 [MathResult.displayTex] 的 doc）。
      // English: `hasTex` is exactly "the engine computed this result": the legacy path never writes
      //          a LaTeX form and the engine path always carries one (see the doc on
      //          [MathResult.displayTex]).
      if (_result.hasTex) return _result.decimalValue;
      return MathResult.usableDouble(
        ExpressionParser(source, degreeMode: angleMode == 'DEG').parse(),
      );
    } catch (_) {
      return _result.decimalValue;
    }
  }

  void _clearLastSavedSignature() {
    _lastSavedSignature = null;
  }

  _SubmittedCalculationSignature _submittedCalculationSignature(
    String expression,
    MathResult result,
  ) {
    return _SubmittedCalculationSignature(
      normalizedExpression: ExpressionParser.normalizeExpressionInput(
        _expressionForSubmitSignature(expression),
      ),
      // 中文：去重键取十进制形态（缺失时退回显示文本），与拆分前的
      //       `result.replaceAll(',', '').trim()` 同值。
      // English: The de-duplication key takes the decimal form (the display text when it is
      //          missing), the same value as `result.replaceAll(',', '').trim()` before the split.
      result: result.reusableText,
      angleMode: angleMode,
    );
  }

  String _expressionForSubmitSignature(String source) {
    final answer = _isSameAnswerEditingSession(source)
        ? _ansValueForExpression
        : _lastFiniteResult;
    if (answer == null || answer.isEmpty) return source;
    final replacement = _answerReplacement(answer);
    return source.replaceAllMapped(
      RegExp(r'\b(?:ans|last)\b', caseSensitive: false),
      (_) => replacement,
    );
  }

  void _markStateEdited() {
    _stateRevision++;
  }

  void _clearEditingHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _clearLastSavedSignature();
    _ansSourceForExpression = null;
    _ansValueForExpression = null;
  }

  String _resolveAnswerReferences(String source) {
    if (!_hasAnswerReference(source)) {
      _ansSourceForExpression = null;
      _ansValueForExpression = null;
      return source;
    }
    final lastAnswer = _isSameAnswerEditingSession(source)
        ? _ansValueForExpression
        : _lastFiniteResult;
    if (lastAnswer == null || lastAnswer.isEmpty) return source;
    _ansSourceForExpression = source;
    _ansValueForExpression = lastAnswer;
    final replacement = _answerReplacement(lastAnswer);
    return source.replaceAllMapped(
      RegExp(r'\b(?:ans|last)\b', caseSensitive: false),
      (_) => replacement,
    );
  }

  bool _hasAnswerReference(String source) {
    return RegExp(r'\b(?:ans|last)\b', caseSensitive: false).hasMatch(source);
  }

  bool _isSameAnswerEditingSession(String source) {
    final previous = _ansSourceForExpression;
    if (previous == null || _ansValueForExpression == null) return false;
    final previousToken = _answerTokenIn(previous);
    final currentToken = _answerTokenIn(source);
    if (previousToken == null || currentToken == null) return false;
    return previousToken == currentToken;
  }

  String? _answerTokenIn(String source) {
    final match =
        RegExp(r'\b(?:ans|last)\b', caseSensitive: false).firstMatch(source);
    return match?.group(0)?.toLowerCase();
  }

  String _answerReplacement(String value) {
    return value.startsWith('-') ? '($value)' : value;
  }

  _CalculatorSnapshot _snapshot() {
    return _CalculatorSnapshot(
      expression: expression,
      // 中文：快照带的是整个三形态结果，否则撤销/重做会把精确形式还原成只剩显示文本，十进制形态
      //       一去不返，Ans/last 又静默失效。
      // English: The snapshot carries the whole three-form result; otherwise undo/redo would restore
      //          an exact form as display text alone, the decimal form would be gone for good and
      //          Ans/last would silently stop resolving again.
      result: _result,
      angleMode: angleMode,
      selection: selection,
      memoryValue: memoryValue,
      hasError: hasError,
      errorMessage: errorMessage,
      lastFiniteResult: _lastFiniteResult,
      ansSourceForExpression: _ansSourceForExpression,
      ansValueForExpression: _ansValueForExpression,
    );
  }

  void _recordUndoSnapshot() {
    final snapshot = _snapshot();
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) return;
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restoreSnapshot(_CalculatorSnapshot snapshot) {
    expression = snapshot.expression;
    _result = snapshot.result;
    angleMode = snapshot.angleMode;
    _selection = snapshot.selection.clamp(expression.length);
    memoryValue = snapshot.memoryValue;
    hasError = snapshot.hasError;
    errorMessage = snapshot.errorMessage;
    _lastFiniteResult = snapshot.lastFiniteResult;
    _ansSourceForExpression = snapshot.ansSourceForExpression;
    _ansValueForExpression = snapshot.ansValueForExpression;
  }

  /// 中文：**显示侧的防抖**：连续输入期间合并实时求值，输入立刻上屏、结果稍后统一刷新。窗口长度
  ///       [liveEvaluationDelay] 就是「第一个结果什么时候出现」，见 [kLiveEvaluationDelay]——它与
  ///       引擎跟进那一个延迟（[kLiveEngineFollowUpDelay]，针对跨语言调用）**不是同一件事**，所以
  ///       这一步不动它：裁决 1 要的即时反馈正是由它保证的。引擎调用也不在这个定时器里发——
  ///       [evaluate] 自己会排。
  ///
  /// English: The **display-side** debounce: live evaluation is coalesced during fast typing, the input
  ///          goes up at once and results refresh together. Its window [liveEvaluationDelay] *is*
  ///          "when the first result appears", see [kLiveEvaluationDelay] — it is **not the same
  ///          thing** as the engine follow-up delay ([kLiveEngineFollowUpDelay], which is about a
  ///          cross-language call), so this step leaves it alone: ruling 1's instant feedback is
  ///          exactly what it guarantees. The engine call is not issued from this timer either;
  ///          [evaluate] schedules it itself.
  void _scheduleLiveEvaluation() {
    _liveEvaluationTimer?.cancel();
    _liveEvaluationTimer = Timer(liveEvaluationDelay, () {
      if (_disposed) return;
      evaluate();
      unawaited(_persistState());
      notifyListeners();
    });
  }

  void _toggleSign() {
    if (!selection.isCollapsed) {
      _replaceSelectionWith('(-$_selectedExpression)');
      return;
    }
    final before = expressionBeforeCursor;
    final after = expressionAfterCursor;
    if (before.isEmpty) {
      expression = '-$after';
      cursorIndex = 1;
      return;
    }

    final trailingMinus = _trailingUnaryMinusStart(before);
    if (trailingMinus != null) {
      final nextPrefix = before.substring(0, trailingMinus) +
          before.substring(trailingMinus + 1);
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    if (_endsWithOpenInput(before)) {
      final nextPrefix = '$before-';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final range = _trailingValueRange(before);
    if (range == null) {
      final nextPrefix = '-($before)';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final value = before.substring(range.start, range.end);
    final unwrapped = _unwrappedParenthesizedNegative(value);
    if (unwrapped != null) {
      final nextPrefix =
          '${before.substring(0, range.start)}$unwrapped${before.substring(range.end)}';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final signStart = _unaryMinusStart(before, range.start);
    if (signStart != null) {
      final nextPrefix =
          before.substring(0, signStart) + before.substring(signStart + 1);
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final replacement = range.start == 0 ? '-$value' : '(-$value)';
    final nextPrefix =
        '${before.substring(0, range.start)}$replacement${before.substring(range.end)}';
    expression = nextPrefix + after;
    cursorIndex = nextPrefix.length;
  }

  int? _trailingUnaryMinusStart(String current) {
    if (current.isEmpty || current[current.length - 1] != '-') return null;
    return _unaryMinusStart(current, current.length);
  }

  int? _unaryMinusStart(String current, int valueStart) {
    final signIndex = valueStart - 1;
    if (signIndex < 0 || current[signIndex] != '-') return null;
    if (signIndex == 0) return signIndex;
    final beforeSign = current[signIndex - 1];
    return _isOperator(beforeSign) || beforeSign == '(' || beforeSign == ','
        ? signIndex
        : null;
  }

  String? _unwrappedParenthesizedNegative(String value) {
    if (!value.startsWith('(-') || !value.endsWith(')')) return null;
    final inner = value.substring(2, value.length - 1);
    return inner.isEmpty ? null : inner;
  }

  void _insert(String token) {
    final start = selection.start;
    expression = expressionBeforeCursor + token + expressionAfterCursor;
    cursorIndex = start + token.length;
  }

  /// 中文：把光标左侧的文本换成 [prefix]，并把光标放在它末尾之前 [cursorBack] 个字符处。
  ///       [cursorBack] 默认为 0（光标落在插入文本的末尾），也就是这个方法的原始行为——
  ///       函数调用那条路要的是「落在括号里 / 逗号右边」，见 [_wrapTrailingValue]。
  /// English: Replaces the text left of the caret with [prefix] and puts the caret [cursorBack]
  ///          characters before its end. The default of 0 — the caret at the end of what was
  ///          inserted — is this method's original behaviour; the function-call path is what needs
  ///          "inside the brackets" / "right of the comma", see [_wrapTrailingValue].
  void _replaceAroundCursor(String prefix, {int cursorBack = 0}) {
    expression = prefix + expressionAfterCursor;
    cursorIndex = prefix.length - cursorBack;
  }

  String get _selectedExpression =>
      expression.substring(selection.start, selection.end);

  void _replaceSelectionWith(String replacement, {int? cursorOffset}) {
    final prefix = expression.substring(0, selection.start);
    expression = '$prefix$replacement$expressionAfterCursor';
    cursorIndex = prefix.length + (cursorOffset ?? replacement.length);
  }

  bool _isOperator(String token) =>
      token == '+' ||
      token == '-' ||
      token == '×' ||
      token == '÷' ||
      token == '^';

  String _appendOperator(String current, String token) {
    if (current.isEmpty) return token == '-' ? '-' : current;
    if (_isOperator(current[current.length - 1])) {
      return '${current.substring(0, current.length - 1)}$token';
    }
    return current + token;
  }

  String _appendDecimal(String current) {
    final match = RegExp(r'(\d*\.?\d*)$').firstMatch(current);
    final tail = match?.group(0) ?? '';
    if (tail.contains('.')) return current;
    if (tail.isEmpty) return '${current}0.';
    return '$current.';
  }

  String _appendSmart(String current, String token) {
    if (current.isEmpty) return token;
    final last = current[current.length - 1];
    final endsValue = RegExp(r'[0-9A-Za-z)]').hasMatch(last);
    final startsValue = _startsValue(token);
    if (endsValue && startsValue) {
      return '$current×$token';
    }
    return current + token;
  }

  /// 中文：把光标左侧的值套进一次函数调用，并把光标放回**第一个空槽**。返回两样东西：要插入
  ///       光标左侧的文本，以及光标离该文本末尾的字符数（[cursorBack]）。
  ///
  ///       **右括号一定要补上。** 这条以前不成立：空输入或光标停在运算符/`(`/`,` 之后时插进去的
  ///       只有 `name(`，右括号从来没出现。用户接着输入实参，表达式里就永久留下 `sqrt(8` 这样的
  ///       形状——而解析器**刻意**把未闭合的调用降级成字面文本（`_parseCall` 的 `_failure`），
  ///       于是屏幕上显示的是灰色的字母 `sqrt(8`，求值也永远是错的。真机实测的复现路径是
  ///       「按 `√x`、再按 `8`」。
  ///
  ///       光标位置按同一条规则定：**落在第一个空槽里**。
  ///       - 空输入 / 尾部是开口结构：空槽就是 `(` 之后，于是光标停在 `name(|)`；
  ///       - 左侧有值：一元调用的实参已经填好，没有空槽，光标留在调用之后（与修改前一致）；
  ///         二元调用还欠第二个实参，空槽是 `,` 之后，光标停在 `name(值|,)` 的逗号右边。
  ///
  ///       English: Wraps the value left of the caret in a call and puts the caret back into the
  ///              **first empty slot**. Two things come back: the text to insert before the caret,
  ///              and how far from its end the caret sits ([cursorBack]).
  ///
  ///              **The closing bracket must always be written.** It used to be missing: for an
  ///              empty input, or with the caret after an operator / `(` / `,`, only `name(` was
  ///              inserted and the bracket never appeared. Whatever the user typed next left
  ///              `sqrt(8` in the expression for good — and the parser **deliberately** degrades an
  ///              unclosed call to literal text (`_parseCall`'s `_failure`), so the screen showed a
  ///              grey `sqrt(8` in letters and the value was wrong forever. The reproduction on a
  ///              device is "press `√x`, then `8`".
  ///
  ///              The caret follows one rule: **the first empty slot**.
  ///              - empty input / a dangling open construct: that slot is just after `(`, so the
  ///                caret sits at `name(|)`;
  ///              - a value on the left: a unary call has its argument filled, so there is no
  ///                empty slot and the caret stays after the call (unchanged); a binary call still
  ///                owes its second argument, so the slot is after the `,` and the caret sits to
  ///                the right of the comma in `name(value|,)`.
  ({String text, int cursorBack}) _wrapTrailingValue(String current, String name,
      {bool binary = false}) {
    // 中文：没有实参可套时的插入物：一元是 `name()`，二元是 `name(,)`——右括号在两种情况下
    //       都在。`cursorBack` 把光标放回第一个空槽：一元的空槽紧跟 `(`（退 1 格），二元的
    //       第一个空槽也在 `(` 之后（退 2 格，越过那个逗号）。
    // English: What goes in when there is no argument to wrap: `name()` for a unary call,
    //          `name(,)` for a binary one — the closing bracket is present either way.
    //          `cursorBack` puts the caret back into the first empty slot: for a unary call that
    //          slot follows `(` (one step back), and for a binary call the first empty slot is
    //          after the `(` too (two steps back, past the comma).
    final String emptySlot = binary ? '(,)' : '()';
    // 中文：左侧有值时的尾部：一元补右括号就完事，二元补的是「逗号 + 右括号」——第二个实参还空着。
    // English: The tail once a value is wrapped: a unary call only needs its bracket, a binary one
    //          needs "comma then bracket" because its second argument is still empty.
    final String tail = binary ? ',)' : ')';
    if (current.isEmpty || _endsWithOpenInput(current)) {
      return (
        text: '$current$name$emptySlot',
        cursorBack: binary ? 2 : 1,
      );
    }
    final range = _trailingValueRange(current);
    if (range == null) {
      return (
        text: '$current$name$emptySlot',
        cursorBack: binary ? 2 : 1,
      );
    }
    final value = current.substring(range.start, range.end);
    return (
      text: '${current.substring(0, range.start)}$name($value$tail',
      cursorBack: binary ? 1 : 0,
    );
  }

  bool _endsWithOpenInput(String current) {
    final last = current[current.length - 1];
    return _isOperator(last) || last == '(' || last == ',';
  }

  ({int start, int end})? _trailingValueRange(String current) {
    var end = current.length;
    while (end > 0 && current[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == 0) return null;
    final last = current[end - 1];
    if (last == ')') {
      final groupStart = _matchingGroupStart(current, end - 1);
      if (groupStart == null) return null;
      final functionStart = _functionNameStart(current, groupStart);
      return (start: functionStart ?? groupStart, end: end);
    }
    var start = end;
    while (start > 0 && RegExp(r'[A-Za-z0-9.]').hasMatch(current[start - 1])) {
      start--;
    }
    if (start == end) return null;
    return (start: start, end: end);
  }

  int? _matchingGroupStart(String current, int closeIndex) {
    var depth = 0;
    for (var i = closeIndex; i >= 0; i--) {
      if (current[i] == ')') depth++;
      if (current[i] == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  int? _functionNameStart(String current, int openIndex) {
    var start = openIndex;
    while (start > 0 && RegExp(r'[A-Za-z0-9]').hasMatch(current[start - 1])) {
      start--;
    }
    return start == openIndex ? null : start;
  }

  bool _startsValue(String token) {
    if (RegExp(r'^\d').hasMatch(token)) return true;
    if (token == 'pi' || token == 'e') return true;
    if (token.startsWith('(')) return true;
    const functionPrefixes = [
      'sqrt(',
      'cbrt(',
      'sin(',
      'cos(',
      'tan(',
      'asin(',
      'acos(',
      'atan(',
      'sinh(',
      'cosh(',
      'tanh(',
      'cot(',
      'sec(',
      'csc(',
      'log(',
      'log2(',
      'ln(',
      'exp(',
      'abs(',
      'fact(',
      'floor(',
      'ceil(',
      'round(',
      'deg(',
      'rad(',
      'min(',
      'max(',
      'mod(',
      'ncr(',
      'npr(',
      'gcd(',
      'lcm(',
      'root(',
      'atan2(',
      // 中文：`ran#`、Σ、Π、∫dx、lim、logₓy 插的调用与上面那些同类——紧跟在数值后面是隐式乘法，
      //       不是并排的两个符号，所以 `2` 之后按 Σ 得到 `2×sum(x,1,10,x)`。
      // English: the calls inserted by `ran#`, Σ, Π, ∫dx, lim and logₓy belong with the ids above —
      //          right after a number they are an implicit product rather than two symbols side by
      //          side, so `2` then Σ gives `2×sum(x,1,10,x)`.
      'rand(',
      'sum(',
      'product(',
      'integrate(',
      'limit(',
    ];
    return functionPrefixes.any(token.startsWith);
  }

  String _applyPercent(String current) {
    if (current.isEmpty) return current;
    final match = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(current);
    if (match == null) return '($current)/100';
    final value = match.group(1)!;
    return '${current.substring(0, match.start)}($value/100)';
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
        other.ansValueForExpression == ansValueForExpression;
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
