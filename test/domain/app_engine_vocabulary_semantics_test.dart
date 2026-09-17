import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

/// 中文：**名字逐个核对的第二半：取值。** 词表里「引擎对这个拼法的答案能不能用」那一列，
///       在修复轮 3 里是**每个名字一个样本**并且**应用侧的值是手写的**——这正是 `log` 与 `mod`
///       两次都漏掉的根本原因（各有一个样本恰好没踩到分歧）。
///
///       这个文件把它变成**可重复、覆盖面明确**的核对：
///
///       - **应用侧的值是算出来的**：`ExpressionParser(表达式)`，也就是应用自己的求值器，
///         不是谁手写的一个数；
///       - **引擎侧的值是量出来的**：由 `tool/qalculate_semantics_probe/probe.cc` 对
///         libqalculate 5.12.0 跑出来（它用的就是桥的调用序列），下面是它的**逐行输出**；
///       - **判据**：两边同一个值时，词表必须标「答案可用」；两边不同时，必须标「不可用」。
///         于是**再出现一个 `log`/`mod`，不管它落在哪个样本上，这张表都会红**——
///         而修法只有一条：把它标成不可信（或者改掉应用自己的语义）。
///
///       覆盖面（**用脚本数出来的，不是手写的**）：词表 **47 个标识符**（41 个函数名 + 6 个常量名，
///       常量在这一轮才进表，见词表文件头），本文的样本 **45 个**，覆盖其中 **33 个名字**，
///       **9 个名字有 2 个以上样本**（`atan2`/`ceil`/`exp`/`floor`/`mod`/`root`/`round`/`sin`/`sqrt`），
///       **未覆盖 14 个**：`deg`/`fact`/`ncr`/`npr`/`rad`（引擎压根没有对应函数，由下面第二条测试与
///       原生侧检查承担）、`matrix`/`sum`/`product`/`integrate`/`diff`/`limit`/`rand`（实参是变量与
///       范围，没有可直接比对的值，由形状判据承担）、`inf`/`infinity`（两边的取值都不是有限数，
///       这个表的数值比对放不下它们）。
///       重算方式：`python3 - <<'PY' …` 见报告第 3 条（脚本与输出都在那里）。
/// English: **the second half of the per-name check: values.** In fix round 3 the vocabulary's "may
///          the engine's answer for this spelling be used" column had **one sample per name and a
///          hand-written app-side value** — which is exactly why `log` and `mod` both slipped through
///          (each had one sample that happened to miss the divergence).
///
///          This file turns it into a **repeatable, explicitly-scoped** cross-check:
///
///          - **the app-side value is computed**: `ExpressionParser(expression)`, this app's own
///            evaluator, not a number somebody wrote down;
///          - **the engine-side values are measured**: by `tool/qalculate_semantics_probe/probe.cc`
///            against libqalculate 5.12.0 (the same call sequence the bridge uses, angle unit
///            included); the table below is its **verbatim output**;
///          - **a divergence is attributed before it is judged**: if this app's own normalisation
///            changes the *call shape*, the divergence is ours and this test goes red demanding a
///            parser fix (the `atan2(7,100)` case); only a faithful reading with a divergence marks
///            that name untrusted. The metric and its blind spot are described at `_callShapes`.
///
///          Scope (**concrete numbers, from the script in the step 5 fix-round-5 report**): the
///          vocabulary holds **47 identifiers** (41 function names + 6 constants — constants joined in
///          round 5), this table has **45 samples** covering **33 of those names**, **9 of them with
///          more than one sample** (`atan2`/`ceil`/`exp`/`floor`/`mod`/`root`/`round`/`sin`/`sqrt`), and
///          **14 are uncovered**: `deg`/`fact`/`ncr`/`npr`/`rad` (no engine counterpart at all, held by
///          the test below and the native check), `matrix`/`sum`/`product`/`integrate`/`diff`/`limit`/
///          `rand` (their arguments are variables and ranges, no comparable value), and `inf`/
///          `infinity` (neither side's value is a finite number, so this table cannot hold them).
///
///          **What this table is for, after round 7**: the runtime criterion is the **translation**
///          (`engine_expression.dart`: the expression is written the engine's way before the engine is
///          asked) plus this vocabulary's refusal at the name layer. That refusal **does change values
///          on screen** — round 7's header claimed it did not, and fix round 8 replaced that sentence
///          with two measurements (`log(8,2)`, `fact(171)`; see the vocabulary file header) — so this
///          file's job is what it always was: **keep the "may this answer be used" column honest**,
///          name by name, value by value. Round 6's value-agreement criterion, which replaced it for one
///          round, is gone (its premise — "this app's `double` is the truth" — is false in exactly the
///          cases the engine exists for); see the vocabulary file header for the measurement.
void main() {
  test('分歧先归因：我们自己读错了要修解析器，引擎读错了才让名字不可信', () {
    // 中文：**「任何分歧 ⇒ 该名字不可信」是好的探测器、错误的裁决者。** 反例是 `atan2(7,100)`：
    //       分歧的原因是**应用自己读错了**（`_startsFunctionArgument` 拒绝以数字结尾的函数名，
    //       逗号被当千分位剥掉，整条变成 `atan(7100)`），引擎那一边是对的。按老规则把 `atan2`
    //       标成不可信，屏幕上就会出现 `1.570655` 而不是正确的 `0.069886`——**规则会弄坏今天正确
    //       的行为**。
    //
    //       所以先**归因**，再决定：
    //
    //       - **我们自己读得忠实**（规范化之后的调用形状与原文一致）而两边仍分歧 ⇒ 是引擎把
    //         这个标识符读成了别的意思（`log`/`mod`/`phi`）⇒ **该名字不可信**；
    //       - **我们自己读得不忠实** ⇒ 分歧是**我们的**（解析器把输入改了）⇒ 这条测试**红**，
    //         要求修解析器，**不许**用「标成不可信」把它盖过去。
    //
    //       两条互斥且穷尽（忠实 ∨ 不忠实），所以这不是给 `atan2` 开例外，而是一条判据。
    //       度量是 **AST 的调用形状**（`名字/实参数`，用应用自己的 `ExpressionAstParser` 取）：
    //       解析器的 bug 正是把 `atan2/2` 变成了 `atan2/1`（逗号没了），这条度量看得见它
    //       （下面有一条专门钉它灵敏度的断言）。应用侧的值仍然是**算出来**的。
    // English: **"any divergence ⇒ untrust" is a good detector and the wrong oracle.** The
    //          counterexample is `atan2(7,100)`: the divergence is **our own misreading**
    //          (`_startsFunctionArgument` rejects a function name ending in a digit, the comma is
    //          stripped as a thousands separator and the whole thing becomes `atan(7100)`), while the
    //          engine is right. Following the old rule would mark `atan2` untrusted and put `1.570655`
    //          on the screen instead of the correct `0.069886` — **the rule would break behaviour that
    //          is right today**.
    //
    //          So attribute first, then decide:
    //
    //          - **our own reading is faithful** (the normalised text has the same call shapes as the
    //            source) and the two still differ ⇒ the engine read this identifier as something else
    //            (`log`/`mod`/`phi`) ⇒ **that name is untrusted**;
    //          - **our own reading is not faithful** ⇒ the divergence is **ours** (the parser changed the
    //            input) ⇒ this test goes **red**, demanding a parser fix, and "mark it untrusted" is
    //            **not** allowed to paper over it.
    //
    //          The two are mutually exclusive and exhaustive (faithful ∨ not), so this is a judgement
    //          rather than an exception for `atan2`. The metric is the **AST call shape**
    //          (`name/argCount`, from this app's own `ExpressionAstParser`): the parser bug turned
    //          `atan2/2` into `atan2/1` (the comma vanished), which this metric sees — there is an
    //          assertion below pinning its sensitivity. The app-side value is still **computed**.
    final byName = <String, List<String>>{};
    for (final entry in _engineValues.entries) {
      final expression = entry.key;
      final name = RegExp(r'^([A-Za-z][A-Za-z0-9]*)\(').firstMatch(expression)!.group(1)!;
      final appValue = ExpressionParser(expression, degreeMode: false).parse();
      final engineValue = _leadingNumber(entry.value);
      final same = (appValue - engineValue).abs() <= 1e-9 * (1 + appValue.abs());
      byName.putIfAbsent(name, () => <String>[]);
      if (same) continue;

      // 中文：先归因——我们自己读忠实了吗？
      // English: attribute first — is our own reading faithful?
      final normalised = ExpressionParser.normalizeExpressionInput(expression);
      expect(
        _callShapes(normalised),
        _callShapes(expression),
        reason: '$expression：**我们自己**把它读成了 `$normalised`（调用形状变了）——'
            '这是解析器的 bug，先修解析器；把 $name 标成不可信只会把这个错值留在屏幕上。',
      );
      byName[name]!.add('$expression（应用 $appValue / 引擎 ${entry.value}）');
    }

    for (final entry in byName.entries) {
      final name = entry.key;
      final divergences = entry.value;
      final trusted = !AppEngineVocabulary.unknownToEngine.contains(name);
      expect(
        trusted,
        divergences.isEmpty,
        reason: divergences.isEmpty
            ? '$name：这张表里的样本两边全一致，词表却说它不可用——一致的样本不该被拦。'
            : '$name：我们读得忠实、而两边取值不一致，词表却说引擎的答案可用——'
                'tier 1 会直接采用引擎的值。分歧：${divergences.join('；')}',
      );
    }
  });

  test('调用形状这条度量看得见那个解析器 bug 的指纹', () {
    // 中文：`_callShapes` 是上面那条归因判据的眼睛，所以它自己也要有测试：
    //       bug 的形状正是「`atan2` 的两个实参变成一个」（逗号被当千分位剥掉）。
    //       这条断言在度量失灵时会红——那时上一半会静默地变成「引擎的错」。
    // English: `_callShapes` is the eye of the attribution above, so it gets a test of its own: the
    //          bug's fingerprint is exactly "`atan2`'s two arguments become one" (the comma stripped
    //          as a thousands separator). This assertion turns red if the metric goes blind — at which
    //          point the half above would silently call it "the engine's fault".
    expect(_callShapes('atan2(7,100)'), <String>['atan2/2']);
    expect(_callShapes('atan2(7100)'), <String>['atan2/1']);
    expect(_callShapes('atan2(7,100)'), isNot(_callShapes('atan2(7100)')));
    expect(_callShapes('log(100)+sqrt(8)'), <String>['log/1', 'sqrt/1']);
    // 中文：常量域不再空转——`phi(2)` 现在收得出一个形状，所以「常量被当调用」这类改动看得见。
    // English: the constants domain is no longer vacuous — `phi(2)` now yields a shape, so a change to
    //          how a constant-as-call is read is visible.
    expect(_callShapes('phi(2)'), <String>['phi(call)']);
    expect(_callShapes('phi(2)'), isNot(_callShapes('3.236(2)')));
  });

  group('标识符层是封闭的（修复轮 8）', () {
    // 中文：修复轮 7 的复审在这里找到一条 low：`ExpressionParser` 接受 `lg`/`log10`/`c`/`p`/
    //       `arcsin`/`arccos`/`arctan`，**这些都不在词表里**，而 `engineNameFor` 把它们**原样透传**，
    //       实测 `lg(1,024)` 就这么送到了引擎（引擎把它读成二元素向量）。
    //       本组把那一层收成两句话：**表外的名字一律拒绝**；**别名先折到表里的键上再查**。
    test('ExpressionParser 接受的每一个函数名都在词表里', () {
      // 中文：名字清单不是手抄的，是解析器自己那份数据（`ExpressionParser.functionNames`，
      //       归一化的正则也由它拼出来）。往解析器里加一个函数名而忘了词表，这一条会红。
      // English: the name list is not transcribed by hand — it is the parser's own data
      //          (`ExpressionParser.functionNames`, which the normalisation regex is built from).
      //          Adding a function to the parser and forgetting the vocabulary turns this red.
      expect(ExpressionParser.functionNames, isNotEmpty);
      for (final name in ExpressionParser.functionNames) {
        expect(AppEngineVocabulary.identifiers, contains(name),
            reason: '解析器接受 `$name`，词表里却没有它——`engineNameFor` 会拒绝它，'
                '于是这个名字不再由引擎作答');
      }
    });

    test('每一个别名都折到词表里的键上，每一个常量也都在表里', () {
      for (final alias in ExpressionParser.functionAliases.keys) {
        expect(AppEngineVocabulary.canonicalIdentifier(alias), isNotNull,
            reason: '别名 `$alias` 折不进词表');
      }
      // 中文：常量同样能被写成调用（`phi(2)`、`pi(2)`），所以它们也必须在表里（`_parsePrimary`
      //       的常量那一支）。
      // English: constants can be written as calls too (`phi(2)`, `pi(2)`), so they have to be in the
      //          table as well (the constant branch of `_parsePrimary`).
      for (final constant in <String>[
        'pi',
        'e',
        'tau',
        'phi',
        'inf',
        'infinity',
      ]) {
        expect(AppEngineVocabulary.identifiers, contains(constant));
      }
    });

    test('词表里多出来的名字恰好是应用自己没有、只在引擎那边成立的那一批', () {
      // 中文：**这是「封闭」的另一半。** 词表比解析器接受的多出七个名字：应用自己的解析器
      //       没有实现它们（`matrix(1)` 会抛「未知函数」），它们本来就只能由引擎作答。
      //       用集合相等而不是「包含」写出来，所以**多一个少一个都会红**——多出来一个，
      //       就必须先想清楚它属于哪一类。
      // English: **the other half of "closed".** The vocabulary has seven names the parser does not
      //          accept: this app's own parser does not implement them (`matrix(1)` throws "unknown
      //          function") and they can only be answered by the engine. Written as a set equality
      //          rather than a containment, so **one more or one fewer turns it red** — a new name has
      //          to be classified before it can be added.
      final parserAccepted = <String>{
        ...ExpressionParser.functionNames,
        'pi',
        'e',
        'tau',
        'phi',
        'inf',
        'infinity',
      };
      const engineOnly = <String>{
        'matrix',
        'sum',
        'product',
        'integrate',
        'diff',
        'limit',
        'rand',
        // 中文：复数与统计那八个（本轮 `CPLX`/`STAT` 两颗键的入口）。它们与上面七个同类：应用自己的
        //       解析器没有实现（`conj(1)` 实测抛 `Unknown function conj`），只有引擎答得出来。
        // English: the eight complex and statistics names (this round's `CPLX`/`STAT` entrances). They
        //          are the same class as the seven above: this app's own parser does not implement
        //          them (`conj(1)` measured throwing `Unknown function conj`), so only the engine can
        //          answer.
        'conj',
        're',
        'im',
        'arg',
        'mean',
        'median',
        'stdev',
        'var',
        // 中文：双变量统计那三个（统计—回归那一轮）。同上：应用自己的解析器没有实现它们
        //       （`pearson(1)` 实测抛 `Unknown function pearson`），只有引擎答得出来。
        // English: the three two-variable statistics (the statistics/regression round). As above:
        //          this app's own parser does not implement them (`pearson(1)` measured throwing
        //          `Unknown function pearson`), so only the engine can answer.
        'pearson',
        'spearman',
        'covar',
      };
      expect(
        AppEngineVocabulary.identifiers.keys.toSet().difference(parserAccepted),
        engineOnly,
      );
      // 中文：反过来也要成立——解析器接受的名字一个都不能少。
      // English: and the other direction — no name the parser accepts may be missing.
      expect(
        parserAccepted.difference(AppEngineVocabulary.identifiers.keys.toSet()),
        isEmpty,
      );
    });

    test('求值器不绑定的那些名字，逐个当场调用：`Unknown function …`', () {
      // 中文：**这一条钉的是判据「函数名」那一半不做梦。** `canExpress` 现在把「应用自己的求值器
      //       没有绑定的调用名」与 `VariableNode` 同判（判据那一轮，见
      //       `namesSomethingOutsideTheAppLanguage`），而它读的是 `ExpressionParser.functionNames`
      //       那份**数据**——求值那个 `switch` 是另一处手写的清单，那份数据的 doc 自己就写着这一点。
      //       两个方向里**危险的那一个是「名字在 `switch` 里、却不在 `functionNames` 里」**：那样
      //       一个名字会被判成「没绑定」，于是应用明明答得出的输入被让给引擎的符号答复——错值方向。
      //
      //       所以这条不引注释、不引记忆：对词表里每一个不在 `functionNames` 里的名字，**当场调用
      //       应用自己的求值器**，要求它抛 `Unknown function <名字>`。词表是闭集（上面那条集合相等
      //       钉着），所以这个循环是穷尽的——加一个新名字进词表而求值器其实实现得了它，这里会红。
      // English: **this pins that the judgement's function-name half is not wishful.** `canExpress`
      //          now judges "a call name this app's own evaluator does not bind" the same as a
      //          `VariableNode` (the judgement round; see `namesSomethingOutsideTheAppLanguage`), and
      //          it reads the **data** list `ExpressionParser.functionNames` — the evaluation `switch`
      //          is a second hand-written list, and that data's own doc says so. Of the two
      //          directions, **the dangerous one is "a name in the `switch` but not in
      //          `functionNames`"**: such a name would be judged unbound, and an input this app can
      //          answer would be handed to the engine's symbolic reply — the wrong-value direction.
      //
      //          So this cites no comment and no memory: for every name in the vocabulary that is not
      //          in `functionNames`, this app's own evaluator is **called right here** and must throw
      //          `Unknown function <name>`. The vocabulary is a closed set (the set equality above
      //          pins that), so the loop is exhaustive — adding a name to the vocabulary that the
      //          evaluator does implement turns this red.
      final parserAccepted = <String>{
        ...ExpressionParser.functionNames,
        'pi',
        'e',
        'tau',
        'phi',
        'inf',
        'infinity',
      };
      final unbound = AppEngineVocabulary.identifiers.keys
          .where((name) => !parserAccepted.contains(name))
          .toList();
      expect(unbound, isNotEmpty, reason: '这一条不许空转——空转就什么也没钉');
      // 中文：词表之外的两类也在这一条里量过，因为判据同样把它们判成「没绑定」：
      //       **词表里没有的名字**（`linearfit`——回归拟合那三个的名字，翻译层会拒绝它；
      //       `zorkmid`——随手一个不存在的名字）与**被当成调用名的变量**（`x(2)` 在应用自己的
      //       语法树里是一个名为 `x` 的调用，而应用自己的求值器不认这个名字）。
      // English: the two classes outside the vocabulary are measured here as well, because the
      //          judgement calls them unbound too: **names the vocabulary lacks** (`linearfit` — the
      //          regression fits' real name, which the translation layer refuses; `zorkmid` — any
      //          nonexistent name) and **a variable used as a call name** (`x(2)` is a call named `x`
      //          in this app's tree, and this app's own evaluator does not know that name).
      for (final name in <String>[...unbound, 'linearfit', 'zorkmid', 'x']) {
        expect(
          () => ExpressionParser('$name(1)', degreeMode: false).parse(),
          throwsA(isA<FormatException>().having(
              (error) => error.message, 'message', 'Unknown function $name')),
          reason: '`canExpress` 把 `$name` 判成「应用自己没有绑定」，那它就必须真的没有绑定',
        );
      }
    });

    test('引擎认识的名字都写了引擎写法（engineNameFor 不会拒绝它们）', () {
      // 中文：`engineNameFor` 判的是 `engineFunction` 那一列，所以「引擎认识这个名字」的行
      //       **必须**都填了它——漏一个就等于让一个本来能由引擎作答的名字静默回落。
      // English: `engineNameFor` reads the `engineFunction` column, so every row whose
      //          `engineKnowsThisName` is true **must** fill it in — one omission silently sends a name
      //          the engine could have answered back to the legacy parser.
      for (final entry in AppEngineVocabulary.identifiers.entries) {
        if (!entry.value.engineKnowsThisName) continue;
        expect(entry.value.engineFunction, isNotNull,
            reason: '`${entry.key}`：引擎认识它，却没有写引擎写法');
      }
    });

    test('engineNameFor：未知标识符拒绝，别名折到规范名，没有引擎写法的拒绝', () {
      String textOf(String name) {
        final result = AppEngineVocabulary.engineNameFor(name);
        expect(result, isA<TranslatedExpression>(), reason: name);
        return (result as TranslatedExpression).text;
      }

      String reasonOf(String name) {
        final result = AppEngineVocabulary.engineNameFor(name);
        expect(result, isA<UntranslatableExpression>(), reason: name);
        return (result as UntranslatableExpression).reason;
      }

      // 中文：别名折到规范名那一行，再取那一行的引擎写法——`lg`/`log10` 都是 `log` 的别名，
      //       而 `log` 那一行写的是 `log10`（两列分开的例子）。`c` 折成 `ncr`，写法是 `binomial`。
      // English: the alias folds onto the canonical row and that row's engine spelling is used —
      //          `lg`/`log10` are both aliases of `log`, whose row says `log10` (the two-column case).
      //          `c` folds to `ncr`, spelled `binomial`.
      expect(textOf('lg'), 'log10');
      expect(textOf('log10'), 'log10');
      expect(textOf('log'), 'log10');
      expect(textOf('c'), 'binomial');
      expect(textOf('ncr'), 'binomial');
      expect(textOf('ARCsin'), 'asin');

      expect(reasonOf('nosuch'), contains('不在应用词汇表里'));
      for (final name in <String>['npr', 'p', 'mod', 'deg', 'rad', 'phi', 'inf']) {
        expect(reasonOf(name), contains('没有引擎写法'), reason: name);
      }
    });

    test('canRead：别名与大小写都折到规范名再判', () {
      // 中文：词表的键是规范名，而 `canRead` 读的是表达式里的调用名——不折的话别名拼法**穿过**这张
      //       表。实测过的后果：`lg(8,2)` 是 `log(8,2)` 的另一种写法，引擎对 `log10(8,2)` 的答复是
      //       一个二元素向量，只因为拼法不同就能上屏。（`c`/`p` 是同一种情形。）
      // English: the table's keys are canonical names while `canRead` reads call names out of the
      //          expression — without the fold, alias spellings **pass through** the table. The measured
      //          consequence: `lg(8,2)` is another spelling of `log(8,2)`, the engine's answer for
      //          `log10(8,2)` is a two-element vector, and the different spelling alone let it onto the
      //          screen. (`c`/`p` are the same case.)
      expect(AppEngineVocabulary.canRead('log(8,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('lg(8,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('log10(8,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('LOG(8,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('NCR(5,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('c(5,2)'), isFalse);
      // 中文：反例也要在——折别名不等于「一律拒绝」。
      // English: the counterexample matters too — folding aliases is not "refuse everything".
      expect(AppEngineVocabulary.canRead('arcsin(0.5)'), isTrue);
      expect(AppEngineVocabulary.canRead('asin(0.5)'), isTrue);
    });
  });

  test('引擎根本没有这个函数的名字一律不可信', () {
    // 中文：这一半靠 `getFunction` 量（`tool/…/probe.cc` 的姊妹脚本问过符号表）：
    //       `ncr`/`npr`/`fact` 在引擎里既不是函数、也不是变量、也不是单位。
    // English: this half is measured with `getFunction` (a sibling probe asks the symbol table):
    //          `ncr`/`npr`/`fact` are neither a function, nor a variable, nor a unit in the engine.
    for (final name in <String>['ncr', 'npr', 'fact']) {
      expect(AppEngineVocabulary.unknownToEngine, contains(name));
      expect(AppEngineVocabulary.identifiers[name]!.engineKnowsThisName, isFalse);
    }
  });
}

/// 中文：一段源码的**调用形状**——每个函数调用的 `名字/实参数`（排序后），用应用自己的语法树
///       （`ExpressionAstParser`）取。它不取值、不判断对错，只回答「这段文本被读成了哪些调用」，
///       于是「规范化把 `atan2(7,100)` 变成 `atan(7100)`」这类改动看得见。
/// English: the **call shape** of a piece of source — `name/argCount` per call, sorted, taken from
///          this app's own syntax tree (`ExpressionAstParser`). It judges no values and no
///          right-or-wrong; it only answers "which calls is this text read as", so a change like
///          "normalisation turns `atan2(7,100)` into `atan(7100)`" is visible.
List<String> _callShapes(String source) {
  final shapes = <String>[];
  void walk(ExprNode node) {
    // 中文：**常量/变量紧跟左括号**也算一种「调用形状」。修复轮 4 的这条度量只看 `FunctionNode`，
    //       于是常量域**结构性地空转**：`phi(2)` 在语法树里是「常量 × 分组」（`ImplicitProductNode`），
    //       两边都收出 `[]`，任何常量分歧都按构造被归因给引擎 ✗。这里用节点自带的源码区间把它读出来。
    // English: **a constant or variable immediately followed by a bracket** is a call shape too. Fix
    //          round 4's metric looked only at `FunctionNode`, so it was **structurally vacuous** on the
    //          constants domain: `phi(2)` is "constant × group" (`ImplicitProductNode`) in the tree, both
    //          sides collected `[]`, and every constant divergence was attributed to the engine by
    //          construction. Read it out of the node's own source span here.
    if ((node is ConstantNode || node is VariableNode) &&
        node.end < source.length &&
        source[node.end] == '(') {
      final name = node is ConstantNode ? node.name : (node as VariableNode).name;
      shapes.add('$name(call)');
    }
    // 中文：应用自己的归一化会把 `phi(2)` 写成 `phi*(2)`（显式乘号）——**读法没变**，所以这两种写法
    //       必须收出同一个形状，否则度量会把归一化本身当成「我们读错了」（实测到的假阳性）。
    // English: this app's own normalisation rewrites `phi(2)` as `phi*(2)` (an explicit `*`) — **the
    //          reading is unchanged**, so both spellings must yield the same shape, or the metric would
    //          call normalisation itself "our misreading" (a false positive, measured).
    if (node is BinaryNode && node.op == '*' && node.right is GroupNode) {
      final left = node.left;
      if (left is ConstantNode) shapes.add('${left.name}(call)');
      if (left is VariableNode) shapes.add('${left.name}(call)');
    }
    if (node is FunctionNode) {
      shapes.add('${node.name}/${node.args.length}');
      for (final arg in node.args) {
        walk(arg);
      }
    } else if (node is BinaryNode) {
      walk(node.left);
      walk(node.right);
    } else if (node is UnaryNode) {
      walk(node.operand);
    } else if (node is PostfixNode) {
      walk(node.operand);
    } else if (node is GroupNode) {
      walk(node.child);
    } else if (node is ImplicitProductNode) {
      walk(node.left);
      walk(node.right);
    }
  }
  walk(const ExpressionAstParser().parse(source));
  return shapes..sort();
}

/// 中文：从引擎的打印里取出前导数字。表里的值全部是数字：探针与桥接层一样钉了角度单位
///       （`parse_options.set_angle_unit(ANGLE_UNIT_RADIANS)`），所以反三角函数不再带 ` rad`
///       后缀——修复轮 4 的表里有四个样本带着桥接层永远不会产生的后缀，那是探针与桥不一致
///       造成的，已经修掉。
/// English: the leading number of the engine's printing. Every value in the table is a number: the
///          probe pins the angle unit just as the bridge does
///          (`parse_options.set_angle_unit(ANGLE_UNIT_RADIANS)`), so the inverse trigonometric results
///          no longer carry a ` rad` suffix — fix round 4's table had four samples carrying a suffix
///          the bridge never produces, caused by the probe disagreeing with the bridge, now fixed.
double _leadingNumber(String engineText) {
  final match = RegExp(r'^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?')
      .firstMatch(engineText.trim());
  expect(match, isNotNull, reason: '引擎的取值不是数字：$engineText');
  return double.parse(match!.group(0)!);
}

/// 中文：**引擎的值**——`tool/qalculate_semantics_probe/probe.cc` 在 libqalculate 5.12.0 上的
///       逐行输出（原样抄写）。
/// English: **the engine's values** — verbatim output of `tool/qalculate_semantics_probe/probe.cc`
///          against libqalculate 5.12.0.
const Map<String, String> _engineValues = <String, String>{
  'sin(1)': '0.8414709848078965',
  'sin(-1)': '-0.8414709848078965',
  'cos(0)': '1',
  'tan(0.5)': '0.5463024898437905',
  'asin(0.5)': '0.5235987755982989',
  'acos(0.5)': '1.047197551196598',
  'atan(1)': '0.7853981633974483',
  'atan2(7,100)': '0.06988600163464250',
  'sinh(1)': '1.175201193643801',
  'cosh(1)': '1.543080634815244',
  'tanh(1)': '0.7615941559557649',
  'cot(1)': '0.6420926159343307',
  'sec(1)': '1.850815717680926',
  'csc(1)': '1.188395105778121',
  'log(100)': '4.605170185988091',
  'log2(8)': '3',
  'ln(2)': '0.6931471805599453',
  'exp(1)': '2.718281828459045',
  'abs(-3)': '3',
  'sqrt(2)': '1.414213562373095',
  'cbrt(-8)': '-2',
  'floor(1.7)': '1',
  'floor(-1.7)': '-2',
  'ceil(1.2)': '2',
  'ceil(-1.2)': '-1',
  'round(1.5)': '2',
  'round(-1.5)': '-2',
  'round(2.5)': '3',
  'min(3,1)': '1',
  'max(3,1)': '3',
  'mod(7,3)': '1',
  'mod(7,-3)': '-2',
  'mod(-7,3)': '2',
  'mod(-7,-3)': '-1',
  'gcd(24,18)': '6',
  'lcm(4,6)': '12',
  'root(27,3)': '3',
  'root(3,27)': '1.041528498231435',
  'atan2(1,1)': '0.7853981633974483',
  'sqrt(9)': '3',
  'exp(0)': '1',
  'phi(2)': '1',
  'pi(2)': '6.283185307179586',
  'e(2)': '5.436563656918090',
  'tau(2)': '12.56637061435917',
};
