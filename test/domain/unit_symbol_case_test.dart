import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

/// 中文：**单位拼法的大小写，与函数名的大小写——归一化这一层同时要伺候的两个主子。**
///
///       这一组钉的是一件已经坏掉的事：归一化整段文本 `.toLowerCase()`，于是**表里 120 个拼法里
///       凡是带大写字母的（50 个）**在归一化之后都不再是表里的拼法，翻译层那一句
///       「`isAppUnit(name)` 按原样查表」永远查不到它们。litre（`L`）、pascal（`Pa`）、joule（`J`）、
///       watt（`W`）、byte（`B`）、ampere（`A`）、kilo-watt-hour（`kWh`）——`CONV` 面板列着它们，
///       按下去每一格都报「引擎不认识这个自由变量」。
///
///       修法（`expression_parser.dart` 的 `_foldAppNames`）：**折叠照旧，但单位拼法一个字节都不动。**
///       折叠存在的理由是函数名大小写不敏感（`SIN(30)` = `Sin(30)`），那不是单位名的规则——
///       单位名分大小写，而**这份大小写是引擎的数据，不是排版**。下面第二组钉住折叠那一半不许退。
///
///       宿主实测（`/usr/bin/qalc` 5.12.0，与打包进 AAR 的同版本）说明「折了会怎样」不是风格问题：
///       折大小写会把用户打的字**读成另一个单位**，而屏幕上没有任何提示。
///
///       | 用户打的 | 引擎读出来的 | 折成小写之后应用读到的 | |
///       |---|---|---|---|
///       | `1 KM` | `1 K`（开尔文） | `1 km`（千米） | 错值 |
///       | `1 M` | `1E6`（兆前缀） | `1 m`（米） | 错值 |
///       | `1 T` | `1 T`（特斯拉） | `1 t`（吨） | 错值 |
///       | `1 S` | `1 S`（西门子） | `1 s`（秒） | 错值 |
///       | `1 H` | `1 H`（亨利） | `1 h`（小时） | 错值 |
///       | `1 B` | `1 B`（字节） | `1 b`（靶恩） | 错值 |
///       | `1 MBAR` | `1 megabar` | `1 millibar` | 错值（差 10⁹） |
///       | `1 CAL` | `1 L·s·A²` | `1 cal`（卡） | 错值 |
///       | `1 MOL` | `1E6 mm³` | `1 mol`（摩尔） | 错值 |
///       | `1 IN` | `1 N`（牛顿） | `1 in`（英寸） | 错值 |
///       | `1 HZ` | `1 H`（亨利） | `1 Hz`（赫兹） | 错值 |
///       | `1 KWH` | `1 J·K·s/F` | `1 kWh`（千瓦时） | 错值 |
///
///       这些**今天**都在折：它们全都在 50 个「按下去就报错」的拼法之外，却在同一条规则里——
///       所以修法必须同时对两边都对：表里的拼法原样留着，**可能**是单位拼法的字（大小写不敏感地
///       像某个拼法）也原样留着，交给那句按原样查表的判据去拒绝——报错，而不是一个看着合理的值。
///
/// English: **the case of unit spellings, and the case of function names — the two masters this one
///          normalisation serves.**
///
///          What this group pins was already broken: the whole text goes through `.toLowerCase()`, so
///          **50 of the table's 120 spellings** (every one holding a capital) are no longer table
///          spellings after normalisation, and the translation layer's "`isAppUnit(name)` looks the
///          name up verbatim" can never find them: litre (`L`), pascal (`Pa`), joule (`J`), watt
///          (`W`), byte (`B`), ampere (`A`), kilowatt-hour (`kWh`) — the `CONV` sheet lists them and
///          every cell errors with "the engine does not know this free variable" when pressed.
///
///          The fix (`_foldAppNames` in `expression_parser.dart`): **the fold stays, but a unit
///          spelling does not move a byte.** The fold exists because function names are
///          case-insensitive (`SIN(30)` = `Sin(30)`), and that is not the units' rule — unit names
///          distinguish case, and **that case is the engine's data, not typography**. The second group
///          below pins that the folding half must not regress.
///
///          Host measurements (`/usr/bin/qalc` 5.12.0, the version bundled in the AAR) show that
///          folding is not a style question: it makes the user's keystrokes **mean another unit** with
///          nothing on screen to say so — the table above.
///
///          All of those are folded **today**: every one of them sits outside the 50 "errors when
///          pressed" spellings, yet inside the same rule — so the fix has to be right on both sides at
///          once: a table spelling survives verbatim, and so does a token that could **be** a unit
///          spelling (case-insensitively similar to one), handed to the verbatim lookup to refuse — an
///          error rather than a plausible value.
void main() {
  group('单位拼法：表里 120 个，一个都不许被归一化改掉', () {
    test('逐个走一遍：归一化、翻译、名字层，三处都认得出表里那个拼法', () {
      // 中文：三处一起断言，是因为它们读的是**同一个字符串**（归一化的七个消费者那条规矩）：
      //       `engineExpressionFor` 拒绝时给出的正是「引擎不认识这个自由变量：`pa`」——名字已经被
      //       折过，所以这条断言在修复前会把 50 个拼法一个一个点出来。
      // English: all three are asserted together because they read **one string** (the seven-consumer
      //          rule): when `engineExpressionFor` refuses, its reason reads "the engine does not know
      //          this free variable: `pa`" — the name has already been folded, so before the fix this
      //          assertion names the 50 spellings one by one.
      final broken = <String>[];
      for (final unit in kAppUnits) {
        final source = '1 ${unit.symbol}';
        final translated = engineExpressionFor(source);
        if (translated is! TranslatedExpression) {
          broken.add('${unit.symbol}（翻译不了：$translated）');
          continue;
        }
        if (translated.text != '((1)*(${unit.symbol}))') {
          broken.add('${unit.symbol}（译出来的是 `${translated.text}`）');
        }
        if (!AppEngineVocabulary.canRead(source)) {
          broken.add('${unit.symbol}（名字层判引擎读不了）');
        }
      }
      expect(broken, isEmpty,
          reason: '这些拼法在归一化之后已经不是表里的那个拼法了：\n${broken.join('\n')}');
    });

    test('归一化之后的文本里，单位名逐字就是表里的拼法', () {
      // 中文：这一条是上一条的**根**：不在归一化那一处钉一根，下一轮同样的东西还会从旁边漏过去。
      // English: this is the **root** of the assertion above: without a pin at normalisation itself the
      //          same thing leaks in from the side next round.
      expect(ExpressionParser.normalizeExpressionInput('5 Pa'), '5 Pa');
      expect(ExpressionParser.normalizeExpressionInput('1 bar to Pa'), '1 bar to Pa');
      expect(ExpressionParser.normalizeExpressionInput('2 L'), '2 L');
      expect(ExpressionParser.normalizeExpressionInput('3 kWh'), '3 kWh');
      expect(ExpressionParser.normalizeExpressionInput('1 KiB'), '1 KiB');
      expect(ExpressionParser.normalizeExpressionInput('5 mA'), '5 mA');
      expect(ExpressionParser.normalizeExpressionInput('sin(30) mH'), 'sin(30) mH');
      // 中文：语法树读到的名字与文本是同一个（区间取自同一份文本，见 `variable_references.dart`
      //       的规则一）。
      // English: the name the tree reads is the one in that text (the spans come from it — rule one in
      //          `variable_references.dart`).
      final node = const ExpressionAstParser().parse('5 Pa');
      expect(node, isA<ImplicitProductNode>());
      final product = node as ImplicitProductNode;
      expect((product.right as VariableNode).name, 'Pa');
    });

    test('`to` 换算的两侧同样：拼法原样，译文才带得上正确的单位', () {
      expect(
          (engineExpressionFor('1 bar to Pa') as TranslatedExpression).text,
          '((((1)*(bar))) to (Pa))');
      expect((engineExpressionFor('60 mph to kph') as TranslatedExpression).text,
          '((((60)*(mph))) to (kph))');
      expect(
          (engineExpressionFor('1 kWh to J') as TranslatedExpression).text,
          '((((1)*(kWh))) to (J))');
    });
  });

  group('表里那一对只差大小写的拼法：`h` 是小时、`H` 是亨利', () {
    test('它们折一步就撞成同一个名字，所以折叠不许碰单位拼法', () {
      // 中文：**这一对是整件事的缩影，而且它是表里的，不是举例编的。** `kAppUnits` 里 `h`（小时）
      //       与 `H`（亨利）只差一个字母的大小写——整段 `.toLowerCase()` 一跑，两个单位在归一化
      //       之后就变成同一个拼法，而它们在引擎那边是两个不同的量（宿主实测：`1 h` = `3.6E3 s`、
      //       `1 H` = `1 H`）。所以下面这两条断言不是「顺便也钉一下」，它们是这一轮所有改动的根。
      // English: **this pair is the whole thing in miniature, and it is in the table rather than made
      //          up as an example.** `h` (hour) and `H` (henry) differ by one letter's case — one
      //          `.toLowerCase()` over the whole text merges them into one spelling after
      //          normalisation, while they are two different quantities to the engine (measured on the
      //          host: `1 h` = `3.6E3 s`, `1 H` = `1 H`). So the two assertions below are not "also
      //          pinned while we are here"; they are the root of every change this round makes.
      expect(
          kAppUnits
              .where((unit) => unit.symbol.toLowerCase() == 'h')
              .map((unit) => unit.symbol)
              .toSet(),
          <String>{'h', 'H'},
          reason: '这一对真的在表里（`h` 小时 / `H` 亨利）');
      expect(ExpressionParser.normalizeExpressionInput('1 h'), '1 h');
      expect(ExpressionParser.normalizeExpressionInput('1 H'), '1 H');
      expect((engineExpressionFor('1 h') as TranslatedExpression).text,
          '((1)*(h))');
      expect((engineExpressionFor('1 H') as TranslatedExpression).text,
          '((1)*(H))');
    });
  });

  group('大小写变体：像某个单位拼法、但不是它的，一律拒绝（实测的静默错值）', () {
    test('`KM`/`M`/`T`/`S`/`G`/`MBAR`/`CAL`/`MOL`/`IN`/`RAD` 这些不再折成表里的单位', () {
      // 中文：**这一组是修法的另一半，而且是收紧方向的。** 它们今天全都折成一个小写拼法、
      //       得到一个「看着合理」的值（上面那张宿主实测表），修完之后它们原样送去按原样查表，
      //       查不到 ⇒ 拒绝 ⇒ 旧解析器报「存在无法识别的内容」。**报错比错值好**是这个项目最老的
      //       那条规矩，而这里每一次误读都换了一个单位（开尔文→千米、特斯拉→吨、字节→靶恩）。
      // English: **this group is the other half of the fix, and it tightens.** Today every one of these
      //          folds onto a lower-case spelling and gets a "plausible" value (the host table above);
      //          after the fix they travel verbatim to the verbatim lookup, are not found ⇒ refused ⇒
      //          the legacy parser says "unrecognised content". **An error beats a wrong value** — this
      //          project's oldest rule — and every one of these misreadings swaps the unit (kelvin →
      //          kilometre, tesla → tonne, byte → barn).
      // 中文：前一半**今天折成另一个单位**（上面那张宿主实测表），后一半今天折成表外的小写、
      //       本来就已经是拒绝——两类现在走同一条路，都由按原样查表的那一句回答。
      // English: the first half **folds onto another unit today** (the host table above) while the
      //          second already folds onto a lower-case spelling outside the table and was refused
      //          anyway — both kinds now take one road, answered by the verbatim lookup.
      for (final spelling in <String>[
        'KM',
        'M',
        'T',
        'S',
        'G',
        'MOL',
        'MBAR',
        'CAL',
        'IN',
        'In',
        'Gal',
        'RAD',
        'MPH',
        'HZ',
        'KWH',
        'PA',
        'WH',
        'AH',
      ]) {
        expect(isAppUnit(spelling), isFalse, reason: '「$spelling」不该在表里');
        expect(engineExpressionFor('1 $spelling'), isA<UntranslatableExpression>(),
            reason: '「$spelling」不是表里的拼法，不该被折成表里的某一个');
      }
      // 中文：**`B` 是反方向的例子**（表里真的有 `B` 这个拼法）：它今天折成 `b`、而 `b` 表里没有
      //       ——所以 `.toLowerCase()` 把一个**表里有的**拼法变成了拒绝，与 `Pa` 是同一类。
      // English: **`B` is the reverse example** (`B` really is a table spelling): today it folds to `b`
      //          which is not in the table — so `.toLowerCase()` turned a **listed** spelling into a
      //          refusal, the same class as `Pa`.
      expect(isAppUnit('B'), isTrue);
      expect(engineExpressionFor('1 B'), isA<TranslatedExpression>());
    });

    test('引擎碰巧读得一样的那几个也拒绝——这是有意选的一边，写在这里免得成为意外', () {
      // 中文：**代价**：有几个变体引擎读得与表里那个拼法**完全相同**（宿主实测：`1 MPH` 与
      //       `1 mph` 都是 `447.04 mm/s`；`1 Cup`/`1 Ton` 同样一致）。它们现在也拒绝。选这一边是
      //       因为「引擎碰巧同意」是一个开放面（下一个版本未必同意），而单位身份是**用户的输入**，
      //       不该由折叠替他说。要那个单位，`CONV` 面板上按一下给的正是表里的拼法。
      // English: **the price**: a few variants are read by the engine **exactly** as the table spelling
      //          (measured: `1 MPH` and `1 mph` are both `447.04 mm/s`; `1 Cup` and `1 Ton` agree
      //          likewise). They are refused now. That side is chosen because "the engine happens to
      //          agree" is an open surface (the next version need not) while unit identity is **the
      //          user's input**, which the fold must not speak for. The `CONV` sheet hands over the
      //          table's own spelling.
      for (final spelling in <String>['MPH', 'Cup', 'Ton']) {
        expect(engineExpressionFor('1 $spelling'), isA<UntranslatableExpression>());
      }
      for (final spelling in <String>['mph', 'cup', 'ton']) {
        expect(engineExpressionFor('1 $spelling'), isA<TranslatedExpression>());
      }
    });

    test('同一个拼法的小写原型仍然照旧（表里没有 `mbar` 的变体被误伤）', () {
      // 中文：反例——表里的拼法本身一个字节都没动，包括那些**看起来像**大小写变体的
      //       （`mbar`/`kWh`/`Pa` 全在表里，`M`/`KWH`/`PA` 不在）。
      // English: the counter-examples — the table's own spellings do not move a byte, including the
      //          ones that **look like** case variants (`mbar`/`kWh`/`Pa` are in the table,
      //          `M`/`KWH`/`PA` are not).
      for (final spelling in <String>['mbar', 'kWh', 'Pa', 'mol', 'cal', 'in', 'Hz']) {
        expect(isAppUnit(spelling), isTrue);
        expect(engineExpressionFor('1 $spelling'), isA<TranslatedExpression>());
      }
    });
  });

  group('一个字母两副面孔：`C(…)` 是 nCr 调用，`5 C` 是库仑', () {
    test('调用位置上的名字是应用自己的语言，照旧大小写不敏感', () {
      // 中文：**`C` 是本应用唯一一个既是别名又是单位拼法的名字**（`C` 是键上的 nCr 别名，
      //       `C` 也是库仑）。归一化这一层用**解析器自己的那条判据**分开它们：名字后面跟着 `(`
      //       就是一次调用（`ExpressionAstParser._parseName`），否则是一个裸词
      //       （`ExpressionParser._parsePrimary` 的那一句 `Function $name needs (`）。调用名折小写
      //       ——所以 `C(1,234)` 逐字就是今天那条路（`ncr(1, 234)`，逗号是实参分隔符），而
      //       `5 C` 原样留给按原样查表的那一句。
      // English: **`C` is this app's only name that is both an alias and a unit spelling** (the keypad's
      //          nCr alias, and the coulomb). Normalisation tells them apart with **the parsers' own
      //          test**: a name followed by `(` is a call (`ExpressionAstParser._parseName`), otherwise
      //          it is a bare word (`ExpressionParser._parsePrimary`'s "Function $name needs ("). A call
      //          name folds — so `C(1,234)` is byte-for-byte today's road (`ncr(1, 234)`, the comma an
      //          argument separator) — while `5 C` is left verbatim for the verbatim lookup.
      expect(ExpressionParser.normalizeExpressionInput('C(1,234)'), 'ncr(1,234)');
      expect(ExpressionParser.normalizeExpressionInput('5 C'), '5 C');
      expect((engineExpressionFor('5 C') as TranslatedExpression).text, '((5)*(C))');
      expect(
          ExpressionParser('C(1,234)', degreeMode: false).parse(), closeTo(0, 1e-9),
          reason: '`C(1,234)` 是 nCr：1 里挑 234 个，一个都挑不出来');
    });
  });

  group('函数名的大小写不敏感：这一半一个字都不许退', () {
    test('同一种拼法的三种大小写归一化成同一个字符串', () {
      // 中文：**折叠存在的理由就是这一组。** 归一化的七个消费者读的是同一个字符串，所以「大小写
      //       不敏感」在这一层只要钉住「归一化之后逐字相同」——值那一条由旧解析器另测。
      // English: **this group is why the fold exists.** The seven consumers read one string, so
      //          "case-insensitive" only needs pinning as "identical after normalisation" here; the
      //          values are measured separately, on the legacy parser.
      const spellings = <String, List<String>>{
        'sin(30)': ['SIN(30)', 'Sin(30)', 'sIn(30)'],
        'ncr(5,2)': ['NCR(5,2)', 'Ncr(5,2)', 'c(5,2)'],
        'npr(5,2)': ['NPR(5,2)', 'Npr(5,2)', 'p(5,2)'],
        'log(1000)': ['LOG(1000)', 'Log(1000)', 'lg(1000)', 'LG(1000)'],
        'asin(0.5)': ['ASIN(0.5)', 'ArcSin(0.5)', 'arcsin(0.5)'],
        'sqrt(16)': ['SQRT(16)', 'Sqrt(16)'],
        'fact(5)': ['FACT(5)', 'Fact(5)'],
        'abs(-7)': ['ABS(-7)', 'Abs(-7)'],
        'pi': ['PI', 'Pi'],
        'e': ['E'],
        'tau': ['TAU', 'Tau'],
        '2to': ['2TO'],
      };
      for (final entry in spellings.entries) {
        final canonical = ExpressionParser.normalizeExpressionInput(entry.key);
        for (final variant in entry.value) {
          expect(ExpressionParser.normalizeExpressionInput(variant), canonical,
              reason: '`$variant` 与 `${entry.key}` 必须是同一个字符串');
        }
      }
    });

    test('值也相同（旧解析器这一条路）', () {
      double parse(String source, {bool degreeMode = false}) =>
          ExpressionParser(source, degreeMode: degreeMode).parse();
      expect(parse('SIN(30)', degreeMode: true), closeTo(0.5, 1e-12));
      expect(parse('Sin(30)', degreeMode: true), closeTo(0.5, 1e-12));
      expect(parse('NCR(5,2)'), closeTo(10, 1e-12));
      expect(parse('LOG(1000)'), closeTo(3, 1e-12));
      expect(parse('LG(100)'), closeTo(2, 1e-12));
      expect(parse('SQRT(16)+ABS(-7)+FACT(5)'), closeTo(4 + 7 + 120, 1e-9));
      expect(parse('0X1F'), closeTo(31, 1e-12),
          reason: '进制前缀与十六进制数字同样在折叠那一半里（`X`/`F` 不是单位拼法）');
      expect(parse('2E3'), closeTo(2000, 1e-9));
    });
  });
}
