import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

import '../shared/source_scan.dart';

/// 中文：**「把单位送进表达式」这条路的钉子**：语法（`to` 是一个词运算符）、翻译（译成引擎的写法，
///       而且**两侧必须带空格**）、词汇（哪些单位名放行）、以及端到端一次真正的换算。
///
///       所有引擎侧的取值都是宿主实测的（libqalculate 5.12.0，按桥的调用序列
///       `unlocalizeExpression` → `calculate` → `print`，精度 16、`mixed_units_conversion=NONE`、
///       `auto_post_conversion=POST_CONVERSION_OPTIMAL`）。量测程序与完整输出在步骤 6 的报告里。
///
/// English: **Pins for the "get a unit into the expression" route**: the grammar (`to` is a word
///          operator), the translation (written the engine's way, and **with spaces on both sides**),
///          the vocabulary (which unit names pass) and one real end-to-end conversion.
///
///          Every engine-side value here is measured on the host (libqalculate 5.12.0, through the
///          bridge's call sequence `unlocalizeExpression` → `calculate` → `print`, precision 16,
///          `mixed_units_conversion=NONE`, `auto_post_conversion=POST_CONVERSION_OPTIMAL`). The
///          measuring program and its full output are in the step 6 report.
void main() {
  group('语法：`to` 是一个词运算符', () {
    const parser = ExpressionAstParser();

    test('`5 km to mi` 读成换算，而不是三连乘', () {
      final node = parser.parse('5 km to mi');
      expect(node, isA<BinaryNode>());
      final binary = node as BinaryNode;
      expect(binary.op, 'to');
      expect(binary.left, isA<ImplicitProductNode>());
      expect(binary.right, isA<VariableNode>());
      expect((binary.right as VariableNode).name, 'mi');
    });

    test('词边界：`toto` 与 `2to` 都不是这个运算符', () {
      // 中文：`to` 是字母组成的，所以边界必须判。「`toto`」是一个标识符，`2to` 里前一格是名字
      //       字符——两者都不该被拆成 `to` + 别的东西。
      // English: `to` is made of letters, so its boundary has to be judged. `toto` is one identifier
      //          and in `2to` the preceding character is a name character — neither may be split.
      expect(parser.parse('toto'), isA<VariableNode>());
      expect(parser.parse('2to'), isNot(isA<BinaryNode>()),
          reason: '`2to` 里没有空格，`to` 不构成一个词');
    });

    test('`to` 单独出现仍然只是一个变量（旧行为没变）', () {
      final node = parser.parse('to');
      expect(node, isA<VariableNode>());
      expect((node as VariableNode).name, 'to');
    });

    test('括号与实参里也成立，右操作数是一整段表达式', () {
      final grouped = parser.parse('(5 km to mi)');
      expect(grouped, isA<GroupNode>());
      expect((grouped as GroupNode).child, isA<BinaryNode>());

      final binary = parser.parse('5 km to m/s') as BinaryNode;
      expect(binary.op, 'to');
      expect(binary.right, isA<BinaryNode>(),
          reason: '目标里的 `/` 属于目标自己');
      expect((binary.right as BinaryNode).op, '/');
    });
  });

  group('翻译：写出来的那串东西，引擎读得懂', () {
    test('`5 km to mi` 译成带空格的换算', () {
      // 中文：**两侧的空格是必须的，这是量出来的**：引擎把 `((5)*(km))to((mi))`（没有空格）读成
      //       `t`·`o` 的乘积——`8.04672 MB*t*m^2`，**不报错**；带空格的那一串才是那次换算
      //       （`3.106855961186670 mi`，`to_struct` 非空）。所以这里钉住的是逐字的字符串。
      // English: **The spaces on both sides are required, and that is measured**: the engine reads
      //          `((5)*(km))to((mi))` (no spaces) as the product `t`·`o` — `8.04672 MB*t*m^2`, with
      //          **no error**; the spaced string is the conversion (`3.106855961186670 mi`,
      //          `to_struct` defined). What is pinned here is the string verbatim.
      expect((engineExpressionFor('5 km to mi') as TranslatedExpression).text,
          '((((5)*(km))) to (mi))');
    });

    test('单位名原样透传，表外的一切自由变量仍然拒绝', () {
      expect((engineExpressionFor('5 km') as TranslatedExpression).text,
          '((5)*(km))');
      expect((engineExpressionFor('5 km + 3 s') as TranslatedExpression).text,
          '((((5)*(km)))+(((3)*(s))))');
      // 中文：`zorkmid` 是**不存在**的单位，引擎会给一个看似合理的值（实测 `5E-21 B`），所以它
      //       必须在翻译这一层就被拒绝——引擎根本不该被问到。
      // English: `zorkmid` is a unit that does **not exist** and the engine returns a plausible value
      //          for it (measured `5E-21 B`), so it has to be refused here at the translation layer —
      //          the engine must not be asked at all.
      expect(engineExpressionFor('5 zorkmid'), isA<UntranslatableExpression>());
    });

    test('词汇按原样查表：`KM` 不是 `km`', () {
      // 中文：引擎的单位名分大小写，折成小写等于把两个单位当成一个；`KM` 因此落回「表外的自由
      //       变量」，由旧解析器报错，而不是被当成 `km` 送过去。
      // English: the engine's unit names distinguish case, so folding would treat two units as one;
      //          `KM` therefore falls back to "a free variable outside the table", where the legacy
      //          parser reports an error, rather than being sent as `km`.
      expect(AppEngineVocabulary.variableUnknownToEngine('km'), isNull);
      expect(AppEngineVocabulary.variableUnknownToEngine('KM'), isNotNull);
      expect(AppEngineVocabulary.variableUnknownToEngine('zorkmid'), isNotNull);
      // 中文：**上面那两条只钉住了函数；「`KM` 落回表外」这句话在**这条路**上原来是不成立的。**
      //       归一化从前整段 `.toLowerCase()`，所以 `5 KM` 到手时已经是 `5 km`——函数按原样查表
      //       查不到 `KM`，可它压根没拿到 `KM`，于是屏幕上给出的是千米。这一轮把折叠改成「应用
      //       自己的名字折、单位拼法不折」（`expression_case_folding.dart` 的文件头），这句话
      //       才第一次在端到端这条路上成立。宿主实测：引擎读 `1 KM` 是 `1 K`（开尔文）。
      // English: **the two assertions above only pin the function; on *this* road the sentence "`KM`
      //          falls outside the table" did not hold.** Normalisation used to lower-case the whole
      //          text, so `5 KM` arrived as `5 km` — the verbatim lookup never saw `KM` at all and the
      //          screen gave kilometres. This round's fold (this app's own names fold, unit spellings do
      //          not — `expression_case_folding.dart`'s header) makes the sentence true end to end for
      //          the first time. Host measurement: the engine reads `1 KM` as `1 K` (kelvin).
      expect(engineExpressionFor('5 KM'), isA<UntranslatableExpression>());
      expect((engineExpressionFor('5 km') as TranslatedExpression).text,
          '((5)*(km))');
    });
  });

  group('译文里不许出现原生守卫会拒绝的「调用」', () {
    // 中文：**这一组盯的是一条 Dart 看不见的边界。**
    //
    //       原生侧 `QalculateEngine.firstCallNameUnknownToEngine` 拿一个正则扫**译文**，凡是
    //       「标识符紧跟左括号」的名字，都要在引擎自己的符号表里查得到，否则整条表达式按
    //       「引擎读不懂」丢掉、回落旧解析器。而 `flutter test` 跑的是**替身引擎**：那条守卫在测试
    //       里**一次都不会执行**，只有真机能看见它。换句话说，**Dart 这一侧拥有一个自己验证不了的
    //       契约**，唯一的防御就是把「写出去的形状」钉在它自己的规则上——下面用的就是那条规则的
    //       正则原文，不是它的转述。
    //
    //       真机上抓到的实例（本轮的根因）：翻译器把 `5 km to mi` 写成
    //       `((((5)*(km))) to (mi))`，而那条正则允许名字与 `(` 之间有空格，于是 `to (mi)` 被读成
    //       「一个叫 `to` 的调用」→ 引擎符号表里查不到 → 整条丢掉，屏幕上是「存在无法识别的内容」。
    //
    //       **这条测试怎么防住下一类**：它把译文中所有被那条正则认成「调用名」的名字收集起来，
    //       逐个要求它们要么是翻译器有权写出的词运算符（原生侧 [WORD_OPERATOR_TO] 逐个对应），
    //       要么是引擎认得的名字（词表的 `engineFunction` 那一列，量过）。译文里再多出一个形状
    //       像调用的词——新运算符、新的名字、括号放错位置——这条就红，而它跑在 `flutter test` 里。
    //       它**不能**替代真机验证（引擎到底认不认某个名字只有引擎知道），它替代的是「下一轮再
    //       靠真机发现同一个形状」。
    //
    // English: **this group watches a boundary Dart cannot see.**
    //
    //          The native side (`QalculateEngine.firstCallNameUnknownToEngine`) scans the
    //          **translation** with one regex: every name in "identifier immediately followed by a
    //          bracket" must be in the engine's own symbol table, or the whole expression is dropped as
    //          "the engine cannot read it" and the legacy parser answers. And `flutter test` runs a
    //          **fake engine**: that guard **never executes in the test suite**, only on a device. In
    //          other words **the Dart side owns a contract it cannot verify**, and the only defence is
    //          to pin the emitted shape against that rule — the pattern below is the rule's regex
    //          verbatim, not a paraphrase.
    //
    //          The instance caught on a device (this round's root cause): the translation writes
    //          `5 km to mi` as `((((5)*(km))) to (mi))`, and the pattern allows whitespace between a
    //          name and `(`, so `to (mi)` read as "a call to `to`" → not in the engine's symbol table →
    //          the whole thing dropped and the screen showed "unrecognised content".
    //
    //          **How this stops the next one**: it collects every name the pattern reads as a call name
    //          in the translation and requires each to be either a word operator the translation is
    //          entitled to write (one native `WORD_OPERATOR_TO` per entry) or a name the engine knows
    //          (the vocabulary's `engineFunction` column, measured). One more call-shaped token in the
    //          translation — a new operator, a new name, a misplaced bracket — turns this red, and it
    //          runs under `flutter test`. It **cannot** replace device verification (only the engine
    //          knows whether it knows a name); what it replaces is "discover the same shape on a device
    //          next round".
    //
    // 中文：这条正则逐字来自 `QalculateEngine.companion.CALL_NAME`。
    // English: this pattern is verbatim from `QalculateEngine.companion.CALL_NAME`.
    final nativeCallName = RegExp(r'([A-Za-z][A-Za-z0-9]*)\s*\(');

    // 中文：翻译器有权写在调用位置上的词——原生侧 `WORD_OPERATOR_TO` 逐个对应。
    // English: the words the translation may write in call position — one per native
    //          `WORD_OPERATOR_TO`.
    const wordOperators = <String>{'to'};

    // 中文：引擎认得的名字 = 词表 `engineFunction` 那一列（量过）∪ 单位表的符号（引擎当单位认，
    //       守卫也查 `getUnit`）。两个来源都是既有的表，这里不新增第三份清单。
    // English: names the engine knows = the vocabulary's `engineFunction` column (measured) ∪ the unit
    //          table's symbols (the engine knows them as units and the guard checks `getUnit`
    //          as well). Both come from tables that already exist; no third list is invented here.
    final engineKnown = <String>{
      for (final entry in AppEngineVocabulary.identifiers.entries)
        if (entry.value.engineFunction != null) entry.value.engineFunction!,
      ...kAppUnitSymbols,
    };

    test('每一串译文里的「调用名」都在白名单里', () {
      // 中文：样本要覆盖三类写法：裸单位、单位换算（右操作数带括号——正是真机红过的那一种）、
      //       以及函数调用复合的单位目标。
      // English: the samples have to cover three shapes: a bare unit, a unit conversion (whose right
      //          operand is parenthesised — the one that went red on the device), and a function call
      //          combined with a unit target.
      const samples = <String>[
        '5 km',
        '5 km to mi',
        '5 km to m/s',
        '1 km to m/s',
        'sqrt(8) km',
        '5 km + 3 s',
        '5 km to kg',
      ];
      for (final source in samples) {
        final translated = engineExpressionFor(source);
        if (translated is! TranslatedExpression) continue; // 翻译不了的样本由别的测试管
        final names = nativeCallName
            .allMatches(translated.text)
            .map((match) => match.group(1)!)
            .toSet();
        for (final name in names) {
          expect(wordOperators.contains(name) || engineKnown.contains(name), isTrue,
              reason: '`$source` 的译文 `${translated.text}` 里，`$name` 会被原生守卫读成调用名，'
                  '而它既不是词运算符，也不在「引擎认得」那一列——真机上整条表达式会被丢掉');
        }
      }
    });

    test('真机红过的那一串：`to (` 会被守卫读成调用，所以 `to` 必须在白名单里', () {
      // 中文：这一条是上面那条的**红证锚点**：把词运算符从白名单里去掉，这条立刻红——因为译文里
      //       确实会出现一个叫 `to` 的「调用名」。它记录的是这个形状**存在**，而不是假设它不存在。
      // English: this is the **red-proof anchor** for the test above: drop the word operator from the
      //          whitelist and this goes red immediately, because a "call name" `to` really does appear
      //          in the translation. It records that the shape **exists** rather than assuming it
      //          cannot.
      const translated = '((((5)*(km))) to (mi))';
      final names = nativeCallName
          .allMatches(translated)
          .map((match) => match.group(1)!)
          .toSet();
      expect(names, <String>{'to'});
      expect(wordOperators, containsAll(names));
    });
  });

  group('单位表', () {
    test('符号不重复，每一族都有单位', () {
      expect(kAppUnits.length, kAppUnitSymbols.length,
          reason: '重复的符号会让面板里出现两个一样的按钮，而它们是同一个单位');
      final families = <String>{for (final unit in kAppUnits) unit.family};
      expect(families, kAppUnitFamilies.toSet());
    });

    test('表里的每一个符号都过得了词汇这一关', () {
      // 中文：这条防的是「表里加了单位、词汇却没放行」（或反过来）——两边读的是同一张表，所以它
      //       今天必然成立，而它一旦不成立就说明有人把其中一处改成了第二份清单。
      // English: this guards against "a unit was added to the table but the vocabulary does not let it
      //          through" (or the reverse) — both read the same table, so it holds by construction
      //          today, and if it ever fails someone has made a second copy of the list.
      for (final unit in kAppUnits) {
        expect(AppEngineVocabulary.variableUnknownToEngine(unit.symbol), isNull,
            reason: '${unit.symbol} 在表里，却过不了词汇这一关');
      }
    });

    test('刻意不在表里的两类', () {
      // 中文：`m^2`/`m/s` 是**表达式**不是名字；`°C` 在应用这一侧根本不是摄氏度（`°` 被解析器
      //       改写成角度）。放进表里会让同一个写法两侧含义不同。
      // English: `m^2`/`m/s` are **expressions** rather than names; `°C` does not mean degrees Celsius
      //          on this side at all (`°` is rewritten as an angle by the parser). Listing them would
      //          give one spelling two meanings on the two sides.
      for (final absent in <String>['m^2', 'm/s', '°C', 'deg']) {
        expect(isAppUnit(absent), isFalse, reason: '「$absent」不该在可插入单位表里');
        expect(AppEngineVocabulary.variableUnknownToEngine(absent), isNotNull);
      }
    });

    test('每个单位都有英文名：非空、与中文名不同、不含宽/全角字符', () {
      // 中文：**这条量的是「英文界面上列的是汉字」那条缺陷的修法。** 面板按当前语言取显示名
      //       （`unit_picker_sheet.dart` 的 `unitDisplayLabel`），所以英文那一侧必须是**真正写过的
      //       英文**：
      //         · 一个都不能空着——空着在英文界面上就是一个没有名字的按钮；
      //         · 一个都不能与中文名逐字节相同——相同就是把汉字原样端给英文界面，正是要消灭的那件事；
      //         · 一个都不许含宽/全角字符——尺子与其余护栏**同一把**（`containsWideOrFullwidth`，
      //           那张表在 `test/shared/source_scan.dart`）。
      //       族名那张表逐个数：**与 [kAppUnitFamilies] 必须恰好是同一组键**（多一个少一个都红），
      //       值同样非空、同样不含宽/全角字符——少一族，英文界面上就会有一行中文标题。
      //
      //       **本表今天 120 条**（文件头那句 117 是步骤 6 那次量测时的条数，不是本轮的数）：这条
      //       断言遍历表本身，所以数目跟着表走，不写死。
      // English: **this is the measurement for the fix of the "an English interface lists Han
      //          characters" defect.** The sheet takes its display name by the active language
      //          (`unitDisplayLabel` in `unit_picker_sheet.dart`), so the English side has to be
      //          **English that was actually written**:
      //            · none may be empty — an empty one is a nameless button on the English interface;
      //            · none may be byte-identical to its Chinese name — that hands Han characters to the
      //              English interface, the very thing being deleted;
      //            · none may hold a wide/fullwidth character — the ruler is the **same one** every
      //              other guard uses (`containsWideOrFullwidth`, in `test/shared/source_scan.dart`).
      //          The family table is counted: its keys must be **exactly** `kAppUnitFamilies`' (one
      //          more or one fewer goes red), and its values are non-empty and equally free of
      //          wide/fullwidth characters — miss one family and a Chinese heading shows on the English
      //          interface.
      //
      //          **The table holds 120 entries today** (the 117 in the file head is the count at the
      //          step 6 measurement, not this round's): this assertion walks the table itself, so the
      //          number follows it rather than being written down.
      for (final unit in kAppUnits) {
        expect(unit.labelEn.trim(), isNotEmpty,
            reason: '${unit.symbol} 没有英文名，英文界面上会是一个没有名字的按钮');
        expect(unit.labelEn, isNot(unit.label),
            reason: '${unit.symbol} 的英文名与中文名逐字节相同，英文界面上写的还是汉字');
        expect(containsWideOrFullwidth(unit.labelEn), isFalse,
            reason: '${unit.symbol} 的英文名里有宽/全角字符：${unit.labelEn}');
      }
      expect(kAppUnitFamilyLabelsEn.keys.toSet(), kAppUnitFamilies.toSet(),
          reason: '英文族名表与 kAppUnitFamilies 必须是同一组键：多一个少一个都会有一族对不上号');
      for (final family in kAppUnitFamilies) {
        final labelEn = kAppUnitFamilyLabelsEn[family]!;
        expect(labelEn.trim(), isNotEmpty, reason: '「$family」没有英文名');
        expect(containsWideOrFullwidth(labelEn), isFalse,
            reason: '「$family」的英文名里有宽/全角字符：$labelEn');
      }
    });
  });

  group('端到端：面板按出来的第一件事 —— `5 km`', () {
    test('按 `5`、点 `km` 之后屏幕上是一个量，不是「存在无法识别的内容」', () async {
      // 中文：**这是这一轮修的第二件事。** 第一件是分隔符（`5kmtomi` 会粘成一个标识符）；修完分隔符
      //       之后，`5` + `km` 得到的是 `5 km`——它**翻译得了**，但引擎的答案带单位，而
      //       `EngineResultKind.unit` 那一支不显示，于是屏幕上是回落旧解析器的那句
      //       「存在无法识别的内容」。用户插了一个应用**自己提供**的单位，却得到一句说他不认识
      //       `km` 的报错——这正是要消灭的那类错值/错话。
      //
      //       现在原生侧把「一个量」与「带单位但算不出来」分开：`5 km` 是前者（数 × 单位），
      //       `5 km + 3 s` 是后者（加法，引擎原样退回来），判据是结构性的。
      //
      //       回执的字段逐字来自设备实测（§报告：`5 km` → `decimal=5 km kind=quantity`）。
      // English: **this is the second thing this round fixes.** The first was the separator
      //          (`5kmtomi` glues into one identifier); with separators fixed, `5` + `km` gives
      //          `5 km` — which **does** translate, but the engine's answer carries a unit and the
      //          `EngineResultKind.unit` branch refuses it, so the screen shows the fallback's
      //          "unrecognised content". The user inserted a unit **the app itself offers** and got told
      //          `km` was not recognised — exactly the kind of wrong message/value this work exists to
      //          delete.
      //
      //          The native side now separates "a quantity" from "carries a unit but cannot be
      //          evaluated": `5 km` is the former (a number times a unit), `5 km + 3 s` is the latter (an
      //          addition the engine hands back), and the test is structural.
      //
      //          The receipt's fields are verbatim from the device run (`5 km` →
      //          `decimal=5 km kind=quantity`).
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km',
          displayTex: r'\qty{5}{\km}',
          kind: EngineResultKind.quantity,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      // 中文：**这一串就是面板按出来的**（`5` 键 + `km` 按钮；分隔符由 `unitInsertionText` 决定，
      //       那一条有它自己的测试）。这里不写手写的空格版本——上一轮就是这么漏掉分隔符的。
      // English: **this is exactly what the keypad produces** (the `5` key plus the `km` button; the
      //          separator comes from `unitInsertionText`, which has tests of its own). No hand-written
      //          spaced string here — testing one is how the last round missed the separator.
      controller.setExpression('5 km');
      final submitted = await controller.submit();

      expect(controller.hasError, isFalse, reason: '插进去的是应用自己提供的单位');
      expect(controller.result, '5 km');
      expect(controller.result, isNot(contains('无法识别')));
      expect(submitted.submitted, isTrue);
      // 中文：**数值消费者这一半没有放宽**：`5 km` 不是有限十进制，`Ans`/记忆拿不到它。
      // English: the numeric half is **not** relaxed: `5 km` is not a finite decimal, so `Ans`/memory
      //          get nothing from it.
      expect(controller.resultDecimal, isEmpty);

      controller.dispose();
    });

    test('`quantity` 可显示，`unit`（量以外的一切带单位结果）仍然不可显示', () {
      expect(
        const MathResult(displayText: '5 km', resultKind: EngineResultKind.quantity)
            .isDisplayable,
        isTrue,
      );
      for (final kind in <EngineResultKind>[
        EngineResultKind.unit,
        EngineResultKind.unitMismatch,
      ]) {
        expect(MathResult(displayText: '5 km', resultKind: kind).isDisplayable, isFalse,
            reason: '$kind 不该上屏');
      }
    });
  });

  group('端到端：一次真正的换算', () {
    test('`5 km to mi` 送出去的是翻译后的串，屏幕上是引擎的换算结果', () async {
      // 中文：回执的三个字段逐字来自宿主实测（`5 km to mi`）。这条同时钉住三件事：引擎**被问到了**
      //       （单位名过得了词汇）、问出去的是**翻译后的**串、以及结果**上了屏**。
      // English: the receipt's three fields are verbatim from the host (`5 km to mi`). This pins three
      //          things at once: the engine **was asked** (unit names pass the vocabulary), what went
      //          out is the **translated** string, and the result **landed on screen**.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '3.106855961186670 mi',
          displayTex: r'\qty{3.106855961186670}{mi}',
          kind: EngineResultKind.conversion,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km to mi');
      final submitted = await controller.submit();

      expect(engine.calls.map((call) => call.expression).toList(),
          <String>['((((5)*(km))) to (mi))']);
      expect(controller.hasError, isFalse);
      // 中文：**这一条断言的事实在本轮改变了，这是有意的。** 它从前钉的是「带单位的结果原样上屏、
      //       数值部分不过 `formatNumber`」，理由写得很清楚——「要取整就得先在显示路径上把
      //       『数字 + 单位』拆开，那是在显示层发明一条解析规则，代价比它带来的整齐更大」。
      //       那个代价这一轮**被认下来并付掉了**，因为不付的代价更大：同一个屏幕上，
      //       `1÷3` 显示 6 位而 `-5deg to rad` 显示 16 位（设备实测），而用户在设置里选的那一栏
      //       叫「小数位数」，它不该对一种结果生效、对另一种不生效。拆开的规则不再是「发明」：
      //       它是 `quantity_display.dart` 里一条**形状明确**的规则（种类只认 `conversion`/
      //       `quantity`、整串必须吻合「数 + 空格 + 一整块单位」、数得装进一个 double），
      //       四条拒绝各自带着实测，且取整仍然只有 `formatNumber` 一处实现。
      //
      //       **值没有动**：屏幕上少的是位数，`Ans`/记忆/继续使用读的那一份（`quantityText`，
      //       未取整的引擎原文）逐字节不变，下一条断言的正是它。
      // English: **the fact this assertion recorded changed this round, deliberately.** It used to pin
      //          "a unit-carrying result lands on screen as it stands, its numeric part not passed
      //          through `formatNumber`", and its reason was explicit — "rounding it would mean
      //          splitting 'number + unit' in the display layer first, inventing a parse rule there, a
      //          bigger price than the tidiness is worth". That price **was accepted and paid** this
      //          round, because not paying it costs more: on one screen `1÷3` read 6 digits while
      //          `-5deg to rad` read 16 (measured on the device), and the setting the user picked is
      //          called "decimal places" — it cannot govern one kind of result and not another. The
      //          split is no longer an invention: it is a **shape-explicit** rule in
      //          `quantity_display.dart` (only the `conversion`/`quantity` kinds, the whole string must
      //          match "number, space, one block of unit", the number must fit a double), each of its
      //          four refusals carrying a measurement, with rounding still implemented once, in
      //          `formatNumber`.
      //
      //          **The value did not move**: what the screen lost is digits, while the copy `Ans`, the
      //          memory register and "continue with result" read (`quantityText`, the engine's
      //          unrounded text) is unchanged byte for byte — which is what the next assertion pins.
      expect(controller.result, '3.106856 mi');
      expect(controller.reusableResult, '3.106855961186670 mi');
      expect(controller.resultDecimal, isEmpty);
      expect(submitted.submitted, isTrue);

      controller.dispose();
    });

    test('换算不成立时屏幕上是那条「单位不匹配」，不是引擎退回来的输入', () async {
      // 中文：`5 km to kg` 在引擎那边**不报错**（宿主实测）、把输入原样退回；原生侧判出
      //       `unit_mismatch`（把结果除以目标还剩 `5 m/g`），Dart 侧据此报错。
      // English: `5 km to kg` **does not error** in the engine (measured) and hands the input back;
      //          the native side judges `unit_mismatch` (dividing the result by the target leaves
      //          `5 m/g`) and Dart reports the error on that basis.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km',
          displayTex: r'\qty{5}{\km}',
          kind: EngineResultKind.unitMismatch,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km to kg');
      await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.result, '单位不匹配：这两个单位不能互相换算');

      controller.dispose();
    });
  });
}

class EngineReplyFixture {
  const EngineReplyFixture({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.arithmetic,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        decimalText:
            decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  final EngineReply reply;
  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply;
  }
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
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
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
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
