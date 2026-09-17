import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**「应用自己的求值器绑不绑定这个名字」这条判据的两侧证据。**
///
///       判据本身（`namesSomethingOutsideTheAppLanguage` 的函数名那一半，由
///       [AppEngineVocabulary.canExpress] 说出来）决定一个 [EngineResultKind.symbolic] 结果配不配
///       上屏：**应用自己答得了这个输入时，旧解析器依旧是权威**，引擎的那份文本不算。
///       判据那一轮把它与「变量名」那一半做成同一条——`ExpressionParser.functionNames` 之外的
///       调用名与一个 `VariableNode` 是同一类东西。
///
///       这个文件从 `calculator_symbolic_result_test.dart` 里**原样搬出来**（只为行数：那个文件
///       已经越过 800 行那条硬性上限），没有改一个字符的行为，测试替身也照那份文件自己的规矩
///       各自持有一份。
///
///       两侧都钉在**实测**上（宿主 libqalculate 5.12.0，按桥的调用序列与选项：
///       `unlocalizeExpression` → `calculate(normalized, APPROXIMATION_EXACT, parsed, to_struct, …)`
///       → 原生那一串种类判据 → `print`，精度 16、`INTERVAL_DISPLAY_MIDPOINT`、
///       `mixed_units_conversion=NONE`、`comma_as_separator=false`、角度单位弧度）：
///
///       - **不碰谁**：形状判据在前——矩阵回执（`structured`）与数字回执都在 `symbolic` 那一支
///         之外，判据收紧前后屏幕上的值逐字节相同；
///       - **新放行谁**：调用名在词表里（翻译得过去、引擎真的会被问到）而应用自己的求值器没有
///         实现它、实参里没有 `VariableNode`、引擎的答复含变量符号且队列为空 —— 这一批的每一个
///         实测回执都在这里，并且逐条要求排得出来。
/// English: **the evidence on both sides of "does this app's own evaluator bind this name".**
///
///          The judgement itself (the function-name half of `namesSomethingOutsideTheAppLanguage`,
///          spoken by [AppEngineVocabulary.canExpress]) decides whether an
///          [EngineResultKind.symbolic] result belongs on screen: **when this app can answer the input
///          itself, the legacy parser is still the authority** and the engine's text does not count.
///          The judgement round made it the same judgement as the variable half — a call name outside
///          `ExpressionParser.functionNames` is the same kind of thing as a `VariableNode`.
///
///          This file was **moved out of** `calculator_symbolic_result_test.dart` verbatim (for line
///          count alone: that file had gone past the hard 800-line cap), not one character of
///          behaviour changed, and the test doubles are held per file by that file's own rule.
///
///          Both sides are pinned to **measurements** (host libqalculate 5.12.0, through the bridge's
///          call sequence and options: `unlocalizeExpression` →
///          `calculate(normalized, APPROXIMATION_EXACT, parsed, to_struct, …)` → the native kind
///          predicates → `print`, precision 16, `INTERVAL_DISPLAY_MIDPOINT`,
///          `mixed_units_conversion=NONE`, `comma_as_separator=false`, angle radians):
///
///          - **who it does not touch**: the shape judgement runs first — a matrix receipt
///            (`structured`) and a number receipt are both outside the `symbolic` branch, and the
///            screen value is byte-for-byte identical before and after the tightening;
///          - **who it admits**: the call name is in the vocabulary (so it translates and the engine
///            really is asked) while this app's own evaluator does not implement it, no
///            `VariableNode` among the arguments, and the engine's answer holds a variable symbol with
///            an empty queue — every measured receipt of that class is here, and every one of them is
///            required to typeset.
void main() {
  group('这条判据不碰已经工作的那几支', () {
    test('`matrix(2,2,1,2,3,4)`：回执是矩阵，形状判据在这条判据之前', () async {
      // 中文：**这一条钉的是「这条判据不碰谁」。** `canExpress` 只在回执种类是 `symbolic` 时被
      //       读到（[CalculatorController] 的 `_selectEngineResult` 里那一行），而矩阵的种类是
      //       `structured`——宿主实测（libqalculate 5.12.0，按桥的选项：`calculate(normalized,
      //       APPROXIMATION_EXACT, parsed, to_struct, …)`，再按原生那一串判据
      //       `containsType(STRUCT_UNIT)` / `isMatrix()||isVector()` / `isNumber()` /
      //       `silent && containsType(STRUCT_VARIABLE)` 分类）：`matrix((2),(2),(1),(2),(3),(4))`
      //       印成 `[1  2; 3  4]`、消息队列空、结构里没有变量 ⇒ `structured`。
      //       所以这个输入在 `canExpress` 收紧前后都走 `isDisplayable` 那一支，屏幕上的值不变。
      //       （判据收紧之后它在这一条上为**假**——应用自己的求值器没有实现 `matrix`，
      //       实测 `matrix(1)` 抛 `Unknown function matrix`——而这里钉的是**屏幕上没有变化**。）
      // English: **this pins who this judgement does not touch.** `canExpress` is read only when the
      //          receipt kind is `symbolic` (that line in `_selectEngineResult`), while a matrix's kind
      //          is `structured` — measured on the host (libqalculate 5.12.0, through the bridge's
      //          options: `calculate(normalized, APPROXIMATION_EXACT, parsed, to_struct, …)`, then
      //          classified by the native predicates `containsType(STRUCT_UNIT)` /
      //          `isMatrix()||isVector()` / `isNumber()` / `silent && containsType(STRUCT_VARIABLE)`):
      //          `matrix((2),(2),(1),(2),(3),(4))` prints `[1  2; 3  4]`, the message queue is empty and
      //          the structure holds no variable ⇒ `structured`. So this input takes the
      //          `isDisplayable` branch before and after the tightening, and the screen value does not
      //          move. (After the tightening the judgement is **false** for it — this app's own
      //          evaluator does not implement `matrix`, measured: `matrix(1)` throws `Unknown function
      //          matrix` — and what is pinned here is that **nothing on screen changes**.)
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '[1  2; 3  4]',
          displayTex: r'\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}',
          kind: EngineResultKind.structured,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('matrix(2,2,1,2,3,4)');
      final submitted = await controller.submit();

      expect(engine.calls, isNotEmpty, reason: '`matrix` 在词表里，翻译得过去，引擎真的会被问到');
      expect(submitted.submitted, isTrue);
      expect(controller.hasError, isFalse);
      expect(controller.result, '[1  2; 3  4]');
      expect(controller.resultTex, contains('bmatrix'));
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue);

      controller.dispose();
    });

    test('`mean(1,2)`：引擎的数字答复走有限十进制那一级，与这条判据无关', () async {
      // 中文：这些名字（`mean`/`median`/`stdev`/`var`…）应用自己的求值器一个都没实现，所以判据
      //       收紧之后它们在 `canExpress` 上为**假**；实参全是数的时候引擎给的是一位数字，
      //       于是走的是 `decimalTextIsFinite` 那一级（tier 2），屏幕上的值与从前逐字节相同。
      //       实测（宿主同上）：`mean((1),(2),(3),(4))` 印成 `2.5`、队列空、没有变量 ⇒ `number`。
      // English: this app's own evaluator implements none of these names (`mean`/`median`/`stdev`/
      //          `var`…), so after the tightening `canExpress` is **false** for them; with numeric
      //          arguments the engine answers with a number, which takes the `decimalTextIsFinite`
      //          branch (tier 2) and the screen value is byte-for-byte what it was. Measured the same
      //          way: `mean((1),(2),(3),(4))` prints `2.5`, queue empty, no variable ⇒ `number`.
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '2.5',
          displayTex: '2.5',
          kind: EngineResultKind.number,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('mean(1,2,3,4)');
      final submitted = await controller.submit();

      expect(submitted.submitted, isTrue);
      expect(controller.hasError, isFalse);
      expect(controller.result, '2.5');
      expect(controller.resultDecimal, '2.5');

      controller.dispose();
    });
  });

  group('应用求值器没有的调用名：引擎答复放行的那几个实测实例', () {
    // 中文：**判据收紧之后真正新上屏的一类，逐条量过。** 这一类的形状是：调用名在应用的词表里
    //       （翻译得过去、引擎真的会被问到）、应用自己的求值器**没有实现**它（旧解析器只会给一句
    //       「Unknown function」）、实参里没有 [VariableNode]（`pi`/`e` 是应用自己的常量，语法树里
    //       是 `ConstantNode`）——而引擎的答复里**含变量符号**（在引擎里 `pi` 是一个变量），
    //       队列是空的，所以原生侧判 `symbolic`。收紧之前 `canExpress` 为真 ⇒ 引擎的答复被丢掉
    //       ⇒ 屏幕上是一句错误；收紧之后它留下。
    //
    //       回执是**量出来的**（宿主 libqalculate 5.12.0，按桥的调用序列与选项），不是编的：
    //       `decimal` 那一份是「同一个精确结构再按 APPROXIMATE 求值后印成机器可读」，
    //       `latex` 那一份是精确结构按 `TAG_TYPE_LATEX` 印的。
    // English: **the class the tightened judgement really admits, measured one by one.** Its shape:
    //          the call name is in this app's vocabulary (so it translates and the engine really is
    //          asked), this app's own evaluator does **not** implement it (the legacy parser only
    //          answers "Unknown function"), no [VariableNode] among the arguments (`pi`/`e` are this
    //          app's constants, `ConstantNode` in the tree) — and the engine's answer **holds a
    //          variable symbol** (`pi` is one of the engine's variables), with an empty message
    //          queue, so the native side kinds it `symbolic`. Before the tightening `canExpress` was
    //          true ⇒ the engine's answer was discarded ⇒ the screen held an error; after it, the
    //          answer stays.
    //
    //          The receipts are **measured** (host libqalculate 5.12.0, through the bridge's call
    //          sequence and options), not invented: the `decimal` half is the exact structure
    //          re-evaluated with APPROXIMATE and printed machine-readable, the `latex` half is the
    //          exact structure printed with `TAG_TYPE_LATEX`.
    test('`mean(pi,1)`：引擎的 `0.5 \\pi + 0.5` 上屏，排版排得出来', () async {
      // 中文：实测（宿主）：`mean((pi),(1))` → 精确结构印成 `0.5 \pi  + 0.5`、队列空、结构里有变量
      //       ⇒ 种类 `symbolic`；近似那一份印成 `2.070796326794897`（有限十进制，所以落地走的是
      //       tier 2：文本是取整后的 `2.070796`，TeX 是引擎的精确形态）。收紧之前这个输入在屏幕上
      //       是旧解析器那句「Unknown function mean」。
      // English: measured (host): `mean((pi),(1))` → the exact structure prints `0.5 \pi  + 0.5`, the
      //          queue is empty and the structure holds a variable ⇒ kind `symbolic`; the approximated
      //          half prints `2.070796326794897` (a finite decimal, so it lands through tier 2: the
      //          text is the rounded `2.070796` and the TeX is the engine's exact form). Before the
      //          tightening this input held the legacy parser's "Unknown function mean".
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '2.070796326794897',
          displayTex: r'0.5 \pi  + 0.5',
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('mean(pi,1)');
      final submitted = await controller.submit();

      expect(engine.calls, isNotEmpty,
          reason: '`mean` 在词表里、实参是常量与数字，翻译得过去——引擎真的会被问到');
      expect(engine.calls.single.expression, 'mean(pi,1)');
      expect(submitted.submitted, isTrue);
      expect(controller.hasError, isFalse, reason: '旧解析器给不出这个值，而这一个是引擎量出来的');
      expect(controller.result, '2.070796');
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue,
          reason: '新放行的排版形态必须排得出来（`${controller.resultTex}`）');

      controller.dispose();
    });

    test('`stdev(pi,1)`：TeX 是 `\\frac{\\pi - 1}{\\sqrt{2}}`，排得出来', () async {
      // 中文：实测（宿主）：`stdev((pi),(1))` → 精确 `\frac{\pi  - 1}{\sqrt{2}}`、队列空、有变量
      //       ⇒ `symbolic`；近似 `1.514334687892636`。`stdev` 是 `STAT` 面板那四格之一，所以这条
      //       路是**键位可达**的：插进去之后把一个数改成 `pi` 就是这个输入。
      // English: measured (host): `stdev((pi),(1))` → exact `\frac{\pi  - 1}{\sqrt{2}}`, queue empty,
      //          holds a variable ⇒ `symbolic`; approximated `1.514334687892636`. `stdev` is one of the
      //          `STAT` sheet's four cells, so this path is **keypad-reachable**: insert the call and
      //          change one number to `pi` and this is the input.
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '1.514334687892636',
          displayTex: r'\frac{\pi  - 1}{\sqrt{2}}',
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('stdev(pi,1)');
      final submitted = await controller.submit();

      expect(submitted.submitted, isTrue);
      expect(controller.hasError, isFalse);
      expect(controller.result, '1.514335');
      expect(controller.resultTex, r'\frac{\pi  - 1}{\sqrt{2}}');
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue,
          reason: '新放行的排版形态必须排得出来（`${controller.resultTex}`）');

      controller.dispose();
    });

    test('这一类的每一个实测回执都排得出来（TeX 逐条量自宿主）', () {
      // 中文：**新放行的排版形态逐条过渲染器。** 下面每一行左列是输入、右列是宿主实测的引擎输出
      //       （libqalculate 5.12.0，桥的打印选项：`TAG_TYPE_LATEX`、`FRACTION_DECIMAL`、无 unicode
      //       符号、区间取中点），也就是**屏幕上会印的东西**；这些输入在判据收紧之后 `canExpress`
      //       都是**假**，所以这一串就是「这一轮新放行、又会被印出来」的全部（`mean`/`median`/
      //       `stdev`/`var` 是 `STAT` 面板那四格的名字，`conj`/`re` 是 `CPLX` 面板的名字，
      //       `covar` 是两变量那一行——都在词表里，所以翻译得过去、引擎真的会被问到）。
      //       排不出来的那一类（`\num{…}`）由 `math_expression_view_test.dart` 钉着排不出来；
      //       这里逐条要求它们**排得出来**。
      // English: **every newly admitted typesetting form goes through the renderer.** Each row's left
      //          column is the input and its right column the engine output measured on the host
      //          (libqalculate 5.12.0, the bridge's print options: `TAG_TYPE_LATEX`,
      //          `FRACTION_DECIMAL`, no unicode signs, interval midpoint) — i.e. **what will be
      //          printed**; `canExpress` is **false** for every one of them after the tightening, so
      //          this list is the whole of "what this round admits and will print" (`mean`/`median`/
      //          `stdev`/`var` are the `STAT` sheet's four cells, `conj`/`re` are `CPLX`'s, `covar` is
      //          the two-variable row — all in the vocabulary, so they translate and the engine really
      //          is asked). The ones that cannot typeset (`\num{…}`) are pinned as failing in
      //          `math_expression_view_test.dart`; here every one of them is required to typeset.
      const measured = <String, (String decimal, String latex)>{
        'mean(pi,1)': ('2.070796326794897', r'0.5 \pi  + 0.5'),
        'median(pi,1)': ('2.070796326794897', r'0.5 \pi  + 0.5'),
        'stdev(pi,1)': ('1.514334687892636', r'\frac{\pi  - 1}{\sqrt{2}}'),
        'var(pi,1)': ('2.293209546954886', r'0.5 \pi ^{2} - \pi  + 0.5'),
        'mean(e,1)': ('1.859140914229523', r'0.5e + 0.5'),
        'conj(pi)': ('3.141592653589793', r'\pi '),
        're(pi)': ('3.141592653589793', r'\pi '),
        'covar(matrix(2,2,pi,1,2,3))': ('-0.5353981633974483', r'0.25 - 0.25 \pi '),
        // 中文：`linearfit` 还不在词表里（翻译层拒绝，引擎今天不会被问）——这一份是它**进了词表
        //       之后**的回执：判据这一轮之后它走 `symbolic` 那一支（没有有限十进制）→ 可显示 →
        //       上屏。它的两列是同一个 `2x`，所以排版这一条与仓库里已有的 `2x` 案例同形。
        // English: `linearfit` is not in the vocabulary yet (the translation refuses it, so the engine
        //          is not asked today) — this is its receipt **once it is in**: after this round it
        //          takes the `symbolic` branch (no finite decimal) → displayable → on screen. Both its
        //          columns are the same `2x`, so the typesetting case has the shape of the `2x` case
        //          already in this repository.
        'linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,10))': ('2x', '2x'),
      };
      measured.forEach((source, receipt) {
        expect(AppEngineVocabulary.canExpress(source), isFalse,
            reason: '`$source` 是这一轮新放行的那一类（应用自己的求值器没有绑定它的调用名）');
        expect(MathExpressionView.typesetsTex(receipt.$2), isTrue,
            reason: '`$source` 的排版形态排不出来：`${receipt.$2}`');
      });
    });
  });
}

/// 中文：一条引擎回执的固定装置。与 `calculator_engine_display_gate_test.dart` 里那一份同形——
///       两个文件各自持有一份是有意的：测试替身应当随测试走，共享它会让一次改动同时动到两条
///       不相干的测试。
/// English: a fixture for one engine receipt, the same shape as the one in
///          `calculator_engine_display_gate_test.dart` — each file keeping its own is deliberate: a
///          test double belongs with its test, and sharing it would make one edit touch two unrelated
///          tests.
class _Receipt {
  const _Receipt({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.symbolic,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        // 中文：`QalculateMathEngine._replyFrom` 自己的规矩：十进制形态只在它**是有限数**时才写。
        // English: `QalculateMathEngine._replyFrom`'s own rule: the decimal form is written only when
        //          it **is** a finite number.
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply? reply;

  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply ?? EngineReply.failure('no reply configured');
  }
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  Duration liveEvaluationDelay = const Duration(minutes: 10),
  Duration liveEngineFollowUpDelay = const Duration(minutes: 10),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: liveEvaluationDelay,
    liveEngineFollowUpDelay: liveEngineFollowUpDelay,
  );
}

class _FakeDatabase implements AppDatabase {
  final savedSettings = <String, String>{};

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(savedSettings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
