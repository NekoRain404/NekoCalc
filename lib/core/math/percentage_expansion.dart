part of 'expression_parser.dart';

/// 中文：**「相对百分比」在归一化里怎么落地：把 `A ± B%` 折成 `(A)*(100±(B))/100`。**
///
///       厂商手册 12.0（`hipercalc-manual-12.0.pdf`，`pdftotext -layout` 后 574–591 行）把 `%`
///       的语义交给设置里的一项：*direct* 是「按除以 100 化成小数」，*relative* 是「按表达式里
///       前一个值来算」。手册里 relative 的四条实测值是 `50+10%` = 55、`50−10%` = 45、
///       `50×10%` = 5、`5÷50%` = 10，另加一条链式 `50+5%−5%` = 49.875；
///       FAQ（`https://hiperlabs.eu/help.html`，第 36–39 行）只把这两句话又说了一遍，
///       **两处都没有写默认值**，所以默认仍是 direct（见 `SettingsTokens.defaultPercentageMode`）。
///
///       **判据从哪来。** 参考实现是宿主 `qalc` 5.12.0——它同时是本应用的引擎
///       （`QalculateMathEngine`），而它自己的百分比设置默认就是 relative。逐条实测（全部写在
///       `test/core/math/percentage_expansion_test.dart` 的表里）：`50+10%` 55、`50-10%` 45、
///       `10%+10%` 0.2、`0.1+10%` 0.11、`50+10%*2` 50.2、`50+10%/2` 50.05、`50+50%` 75、
///       `2*(50+10%)` 110、`sqrt(50+10%)` 7.416198487、`50+(20+30)%` 75、`-50+10%` −55、
///       `50--10%` 55、`50%*2+10%` 1.1、`50+5%−5%` 49.875。手册那五条逐条对上。
///
///       **由此得到的三条规则，前两条是厂商写下的、第三条是实测补的：**
///
///       1. **`+`/`−` 的右操作数若是「一个裸的百分数字面量」（`B%`，`B` 是数字或括号组），
///          就按累计到此处的前一个值算**：`A ± B%` 读作 `A ± A·B/100`。累计值按左到右走
///          （`50+5%−5%` 的第二项是 52.5 的 5%，不是 50 的）——手册那条链式例子把这一点钉死了。
///       2. **右操作数不是裸百分数时不折**：`50+10%*2` = 50.2、`50+10%/2` = 50.05、
///          `50+2^10%` 都按 `/100` 直接算（qalc 实测）。`×`/`÷`/`^`/函数实参**一律不动**：
///          厂商在 relative 一节里给的两个 `×`/`÷` 例子（5 与 10）与 direct 的定义同值，
///          所以它们本来就没有第二条规则——这一条是厂商的文本**明确**给出的，不是我们猜的。
///          （「不动」说的是**折**不动；`÷` 的**展开式位置**另有一处错，见下一条。）
///       3. **一条链的首项自己就是百分数时不折**（`10%+10%` = 0.2、`50%+10%` = 0.6、
///          `(10%)+10%` = 0.2、`-10%+10%` = 0）。qalc 里 `%` 是一个**单位**，两个同单位量相加
///          就是普通加法；厂商手册对这条**一个字都没写**，我们是照参考实现补的，补法也是
///          本应用 direct 下今天的值（`10%+10%` 现在就是 0.2），所以这一族两种模式同值。
///
///       **除号那一族：展开式必须是一个原子（本轮修的缺陷）。** 上面三条说的都是**折**（相对模式
///       那一步）；`%` 的**展开**是另一处，也是本轮唯一动过的地方。手册 relative 一节里还印着一条
///       小题（`pdftotext -layout` 后 595–605 行）：
///
///       ```
///       » What percentage is 5 out of 50?
///             5       ÷     5    0    %         10
///       ```
///
///       而本应用**两种模式都答 0.001**——不是模式选错，是展开式的位置错：`_replacePercent` 写下的
///       `(50)/100` 在乘除层**不是一个原子**，它的除号与左边紧邻的除号左结合，读成 `5/50/100`。
///       direct 一节的定义同样给 10（`50%` 化成 0.5），所以这一条在两节里都不是 0.001；
///       **上一轮把这一行记成「既有分歧、不在本轮范围」并留在原地，那是错的**——厂商给了值的小题
///       答错，不能算「不改默认行为」。
///
///       修法只有一条：**`X%` 紧跟除号右边时整段括起来**，`((X)/100)`。判据落在展开式的左邻一格上，
///       因为另外三种左邻下两种写法**同值**：`*` 可结合（`a*(X)/100` 与 `a*((X)/100)` 都是 a·X/100）、
///       `+`/`-` 的优先级本就低于 `/`（`(X)/100` 自己就是一个项）、`^` 右边那个 `/100` 则按厂商的
///       读法**故意逃到幂外**（`2^3%` 实测 0.08 = `(2^3)/100`，qalc 同值）。紧跟其后的幂要一起括进去
///       （`5/50%^2` → `5/((50)/100^2)`），否则 `^` 会改去乘那个**值**而不是那个 100——`3%^2` 的既有
///       值 0.0003 正是 `3/(100^2)`，两件事是同一条约定。
///
///       逐条实测（本轮，direct 与 relative **同值**、修完之后与宿主 `qalc` 5.12.0 逐条相同；表在
///       `test/core/math/percentage_expansion_test.dart` 的 `÷ 与 %` 一组）：`5/50%` 0.001→**10**、
///       `(5+5)/50%` 0.002→**20**、`100/50%` 0.02→**200**、`5/50%*2` 0.002→**20**、`1/2/50%`
///       0.0001→**1**、`5/-50%` −0.001→**−10**、`5/50%/2` 0.0005→**5**、`1/(2/50%)` 2500→**0.25**、
///       `5/50%+1` 1.001→**11**、`10%/10%` 0.0001→**1**、`5/(50)%` 0.001→**10**、`5/50%^2`
///       0.00001→**1000**。唯一一条与谁都不同的形状是指数里再套一个百分数（`5/50%^50%`：修前
///       1.0000000000000001e-103、修后 56294995342131.2、qalc 1E101），它不是本轮的目标，钉住的是
///       「读得动 + 两种模式同值」——对幂的吞并带一条护栏，指数自己若是百分数字面量就不吞，
///       否则后面那个 `%` 会没有操作数、一个读得动的输入会变成一句错。
///
///       **折成乘法因子而不是加法，有两个具体理由。** 一、**不复制左操作数**：链上每多一个
///       百分数，加法形式要把整段累计文本再抄一遍（`50+10%+10%` 就抄两层，n 项是 2^n），
///       乘法形式只是一层层套括号，长度线性。二、**变量引用不变**：`x+10%` 折成
///       `(x)*(100+(10))/100` 之后 `x` 仍然出现一次，所以 `variable_references` 那一层看到的
///       名字集合规模不变（那一层不传模式，见 [ExpressionParser.normalizeExpressionInput]）。
///       写成 `*(100±B)/100` 而不是 `*(1±B/100)`：前者的中间量是整数倍再除，厂商手册那几条
///       例子（55 / 45 / 49.875 / 60.5）在 IEEE754 下**逐条精确**，后者会带出 55.00000000000001
///       这种尾数。
///
///       **文本随模式变，与 `°` 那一轮的做法不同——这不是自相矛盾，是问题形状不同。**
///       `°` 的规则是「这个角度在当前角度单位下是多少」，一个**只跟节点自己有关**的值，
///       所以那一轮把它做成应用自己的名字 `degangle(N)`，值由求值器按模式给，文本一辈子不变。
///       相对百分比要的是**左上下文**（"前一个值"），任何「名字」都得把左侧整段带进去，
///       而文本里没法不复制地表达「一路累计下来的那个值」。所以模式只能进这一层，
///       而它进的方式被限制在最小：**只有两个求值消费者传它**（`ExpressionParser` 的构造函数与
///       `engineExpressionFor`），其余消费者（名字层的 `canRead`/`canExpress`、变量引用、
///       图形标签、去重键）用的是默认值，看到的文本与今天逐字节相同。折法只把 `%` 改写成
///       `/100` 因子与括号，既不新增也不删除「读得懂 / 翻得过去」的构造，所以那两层的判断
///       在两种模式下仍然一致（`percentage_expansion_test.dart` 用一张表把这条钉住）。
/// English: **How "relative percentage" lands in normalisation: `A ± B%` folds to
///          `(A)*(100±(B))/100`.**
///
///          The vendor's manual 12.0 (lines 574–591 after `pdftotext -layout`) hands `%`'s meaning to a
///          setting: *direct* converts by dividing by 100, *relative* computes "based on the preceding
///          value in the expression". The manual's relative numbers are `50+10%` = 55, `50−10%` = 45,
///          `50×10%` = 5, `5÷50%` = 10, plus the chain `50+5%−5%` = 49.875; the FAQ
///          (`https://hiperlabs.eu/help.html`, lines 36–39) only repeats the two sentences.
///          **Neither states a default**, so the default stays direct (see
///          `SettingsTokens.defaultPercentageMode`).
///
///          **Where the judgement comes from.** The reference implementation is the host's `qalc`
///          5.12.0 — which is also this app's engine (`QalculateMathEngine`) and whose own percentage
///          setting defaults to relative. Measured one by one (all of them pinned in the table in
///          `test/core/math/percentage_expansion_test.dart`): `50+10%` 55, `50-10%` 45, `10%+10%` 0.2,
///          `0.1+10%` 0.11, `50+10%*2` 50.2, `50+10%/2` 50.05, `50+50%` 75, `2*(50+10%)` 110,
///          `sqrt(50+10%)` 7.416198487, `50+(20+30)%` 75, `-50+10%` −55, `50--10%` 55,
///          `50%*2+10%` 1.1, `50+5%−5%` 49.875. The manual's five lines agree line by line.
///
///          **Hence three rules — the first two written down by the vendor, the third measured:**
///
///          1. **When the right operand of `+`/`−` is a bare percentage literal** (`B%`, `B` a number
///             or a bracketed group), it is taken of the value accumulated so far: `A ± B%` reads as
///             `A ± A·B/100`. Accumulation is left to right (the second term of `50+5%−5%` is 5% of
///             52.5, not of 50) — the manual's chained example pins exactly that.
///          2. **No fold when the right operand is not a bare percentage**: `50+10%*2` = 50.2,
///             `50+10%/2` = 50.05, `50+2^10%` all divide by 100 (measured on qalc). `×`, `÷`, `^` and
///             function arguments are **never touched**: the vendor's two `×`/`÷` examples under
///             relative (5 and 10) have the same values as direct's definition, so they never had a
///             second rule — that one is **stated** by the vendor's text, not guessed by us. ("Never
///             touched" is about the **fold**; the **position of the expansion** for `÷` was wrong
///             separately — see the next paragraph.)
///          3. **No fold in a chain whose own first term is a percentage** (`10%+10%` = 0.2,
///             `50%+10%` = 0.6, `(10%)+10%` = 0.2, `-10%+10%` = 0). In qalc `%` is a **unit**, and two
///             quantities of the same unit simply add; the vendor says **nothing** about this one, so
///             it is taken from the reference implementation — and it agrees with this app's direct
///             value today (`10%+10%` is 0.2 now), making that family mode-invariant.
///
///          **The division family: the expansion has to be an atom (the defect this round repairs).**
///          The three rules above are all about the **fold** (the relative step); the **expansion** of
///          `%` is a different place, and the only one this round touched. The manual's relative section
///          also prints this worked example (lines 595–605 after `pdftotext -layout`):
///
///          ```
///          » What percentage is 5 out of 50?
///                5       ÷     5    0    %         10
///          ```
///
///          and this app answered **0.001 in both modes** — not a wrong mode but a misplaced expansion:
///          the `(50)/100` written by `_replacePercent` is **not an atom** in the multiplicative layer,
///          its division associates leftwards with the division on its left and it reads as
///          `5/50/100`. Direct's section defines it as 10 as well (`50%` is 0.5), so neither reading is
///          0.001; **the previous round recorded this line as "a known divergence, out of scope" and
///          left it standing, and that was wrong** — a worked example the vendor gives a value for
///          cannot be answered wrongly and called "not changing the default behaviour".
///
///          There is one repair: **when `X%` sits immediately to the right of a division, wrap the whole
///          expansion**, `((X)/100)`. The judgement lands on the single cell to the expansion's left
///          because with the other three left neighbours the two spellings have the **same value**: `*`
///          is associative (`a*(X)/100` and `a*((X)/100)` are both a·X/100), `+`/`-` already bind looser
///          than `/` (`(X)/100` is one term by itself), and to the right of `^` the `/100` **deliberately
///          escapes the power** under the vendor's reading (`2^3%` measures 0.08 = `(2^3)/100`, and qalc
///          agrees). A power that immediately follows goes inside the brackets too (`5/50%^2` →
///          `5/((50)/100^2)`), or the `^` would multiply the **value** instead of that 100 — the existing
///          0.0003 of `3%^2` **is** `3/(100^2)`, the same rule seen from the other side.
///
///          Measured line by line (this round; direct and relative have the **same** value, and after the
///          fix every row equals the host's `qalc` 5.12.0; the table is in the `÷ 与 %` group of
///          `test/core/math/percentage_expansion_test.dart`): `5/50%` 0.001→**10**, `(5+5)/50%`
///          0.002→**20**, `100/50%` 0.02→**200**, `5/50%*2` 0.002→**20**, `1/2/50%` 0.0001→**1**,
///          `5/-50%` −0.001→**−10**, `5/50%/2` 0.0005→**5**, `1/(2/50%)` 2500→**0.25**, `5/50%+1`
///          1.001→**11**, `10%/10%` 0.0001→**1**, `5/(50)%` 0.001→**10**, `5/50%^2` 0.00001→**1000**.
///          The one shape left agreeing with nobody is a percentage in the exponent (`5/50%^50%`:
///          1.0000000000000001e-103 before, 56294995342131.2 after, qalc 1E101); it is not this round's
///          target and what is pinned for it is "it reads, and both modes agree" — the power absorption
///          carries a guard rail, and an exponent that is itself a percentage literal is not absorbed,
///          because that would leave the following `%` without an operand and turn a readable input into
///          an error.
///
///          **Why fold into a multiplicative factor rather than an additive term — two concrete
///          reasons.** First, **the left operand is not copied**: additively, every further percentage
///          on the chain would re-copy the whole accumulated text (`50+10%+10%` copies two levels,
///          n terms means 2^n), while multiplicatively each step only wraps the previous text in
///          brackets — linear length. Second, **variable references are unchanged**: `x+10%` folds to
///          `(x)*(100+(10))/100` with `x` still appearing once, so `variable_references` sees the same
///          set of names (that layer takes no mode; see
///          [ExpressionParser.normalizeExpressionInput]). Written `*(100±B)/100` rather than
///          `*(1±B/100)` because the former multiplies by an integer multiple and divides once, which
///          makes the manual's own examples (55 / 45 / 49.875 / 60.5) **exact** in IEEE754 where the
///          latter leaves 55.00000000000001-style tails.
///
///          **The text varies with the mode, unlike the `°` round — not a contradiction, a different
///          shape of problem.** The `°` rule is "what is this angle in the current angle unit", a value
///          that depends on **the node alone**, so that round made it a name in this app's own language
///          (`degangle(N)`) whose value the evaluator supplies per mode, and the text never moves.
///          Relative percentage needs the **left context** (the "preceding value"), and any name would
///          have to carry the whole left side into itself — text cannot express "the value accumulated
///          so far" without copying. So the mode enters this layer, and it enters as narrowly as
///          possible: **only the two evaluating consumers pass it** (`ExpressionParser`'s constructor
///          and `engineExpressionFor`); every other consumer (the name layer's `canRead`/`canExpress`,
///          variable references, graph labels, the de-duplication key) takes the default and sees text
///          byte-for-byte as today. The fold only rewrites `%` into `/100` factors and brackets — it
///          neither adds nor removes readable/translatable constructs — so those two layers' verdicts
///          stay identical in both modes (`percentage_expansion_test.dart` pins that with a table).
String _expandRelativePercent(String text) => _foldRelativeGroups(text) ?? text;

/// 中文：模式为 relative 时先递归折括号里的链，再折本层的链；**括号不配对就整段原样返回**
///       （放弃折叠 = 落回 direct 的读法，绝不猜）。
/// English: In relative mode, fold the chains inside brackets first, then this level's; **an
///          unbalanced bracket returns the text unchanged** (giving up the fold means falling back to
///          the direct reading — never a guess).
String? _foldRelativeGroups(String text) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final character = text[index];
    if (character != '(') {
      buffer.write(character);
      index++;
      continue;
    }
    final close = _matchingParenthesis(text, index);
    if (close == null) return null;
    // 中文：**紧跟着 `%` 的括号组一个字都不动。** 那个形状是应用自己的百分数字面量
    //       （`(20+30)%`），而 `_replacePercent` 的判据正是「一对不含括号的括号组后面跟 `%`」；
    //       折了里面（`50+(20+10%)%` → `50+((20)*(100+(10))/100)%`）会让那条判据不再成立，
    //       于是相对模式反而比 direct 多出一句「读不懂」。留在原地，两边同值。
    // English: **A bracket group immediately followed by `%` is left alone.** That shape is this
    //          app's own percentage literal (`(20+30)%`), and `_replacePercent`'s test is precisely
    //          "a bracket pair with no brackets inside, followed by `%`"; folding its inside
    //          (`50+(20+10%)%` → `50+((20)*(100+(10))/100)%`) breaks that test, which would make
    //          relative mode answer "cannot read" where direct reads it fine. Left where it is, both
    //          modes agree.
    if (close + 1 < text.length && text[close + 1] == '%') {
      buffer.write('(${text.substring(index + 1, close)})');
      index = close + 1;
      continue;
    }
    final inner = _foldRelativeGroups(text.substring(index + 1, close));
    if (inner == null) return null;
    buffer.write('($inner)');
    index = close + 1;
  }

  // 中文：顶层逗号/分号把文本切成若干条独立实参，每条各自是一条加法链——`max(1,50+10%)` 里
  //       第二格的一条链从 `50` 起算。奇数下标是分隔符本身，原样留住。
  // English: top-level commas/semicolons cut the text into independent arguments, each its own
  //          additive chain — inside `max(1,50+10%)` the second slot's chain starts at `50`. Odd
  //          indices hold the separators themselves and are kept verbatim.
  final pieces = _splitTopLevelArguments(buffer.toString());
  for (var i = 0; i < pieces.length; i += 2) {
    pieces[i] = _foldRelativeChain(pieces[i]);
  }
  return pieces.join();
}

/// 中文：交错的「表达式 / 分隔符」片段，偶数下标是表达式，奇数下标是 `,` 或 `;`。
/// English: Interleaved "expression / separator" pieces: even indices are expressions, odd indices
///          are the `,` or `;` themselves.
List<String> _splitTopLevelArguments(String text) {
  final pieces = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final character = text[i];
    if (character == '(') {
      depth++;
      continue;
    }
    if (character == ')') {
      depth--;
      continue;
    }
    if (depth != 0 || (character != ',' && character != ';')) continue;
    pieces.add(text.substring(start, i));
    pieces.add(character);
    start = i + 1;
  }
  pieces.add(text.substring(start));
  return pieces;
}

/// 中文：折**一条**加法链。链上第一个裸百分数之前的累计值就是它要乘的那个「前一个值」。
///       形状上不成立（项为空、只有一个项、首项自己是百分数）时原样返回——每一条都是上面
///       三条规则里的某一条，不是兜底。
/// English: Fold **one** additive chain. The values accumulated before each bare percentage are what
///          "the preceding value" means. Shapes that do not qualify (an empty term, a single term, a
///          first term that is itself a percentage) come back unchanged — each is one of the three
///          rules above, not a fallback.
String _foldRelativeChain(String text) {
  if (!text.contains('%')) return text;
  final terms = _splitChainTerms(text);
  if (terms.length < 2) return text;
  for (final term in terms) {
    if (term.text.trim().isEmpty) return text;
  }
  // 规则三：首项自己是百分数 → 整条链不折。
  if (_percentAmountOf(terms.first.text) != null) return text;

  final amounts = <String?>[
    for (final term in terms) _percentAmountOf(term.text),
  ];
  if (!amounts.skip(1).any((amount) => amount != null)) return text;

  var accumulated = terms.first.text.trim();
  for (var i = 1; i < terms.length; i++) {
    final amount = amounts[i];
    if (amount == null) {
      accumulated = '($accumulated)${terms[i].op}(${terms[i].text.trim()})';
      continue;
    }
    final factor = terms[i].op == '-' ? '100-($amount)' : '100+($amount)';
    accumulated = '($accumulated)*($factor)/100';
  }
  return accumulated;
}

/// 中文：把一条链按**二叉**的 `+`/`-` 切开。一元的正负号留在项里（`-50+10%` 的首项是 `-50`，
///       `50--10%` 的第二项是 `-10%`），判据是「符号前面最近的非空格字符是一个值的结尾」。
///       `e-5` 这类科学计数法在这一步之前已被 `_normalizeScientificNotation` 收掉。
/// English: Cut a chain at the **binary** `+`/`-`. A unary sign stays inside its term (`-50+10%`'s
///          first term is `-50`; `50--10%`'s second is `-10%`): the test is whether the nearest
///          non-space character before the sign ends a value. Scientific notation such as `e-5` was
///          already collected by `_normalizeScientificNotation` before this runs.
List<({String op, String text})> _splitChainTerms(String text) {
  final terms = <({String op, String text})>[];
  var depth = 0;
  var start = 0;
  var op = '';
  for (var i = 0; i < text.length; i++) {
    final character = text[i];
    if (character == '(') {
      depth++;
      continue;
    }
    if (character == ')') {
      depth--;
      continue;
    }
    if (depth != 0) continue;
    if (character != '+' && character != '-') continue;
    if (!_signIsBinary(text, i)) continue;
    terms.add((op: op, text: text.substring(start, i)));
    op = character;
    start = i + 1;
  }
  terms.add((op: op, text: text.substring(start)));
  return terms;
}

/// 中文：一个值的结尾字符。归一化到这一步已经是小写，所以字母表只列小写。
/// English: The characters that end a value. Normalisation has lower-cased by this point, so the
///          alphabet lists lower case only.
const String _valueEndCharacters = '0123456789abcdefghijklmnopqrstuvwxyz.)%!';

bool _signIsBinary(String text, int index) {
  for (var i = index - 1; i >= 0; i--) {
    final character = text[i];
    if (character == ' ') continue;
    return _valueEndCharacters.contains(character);
  }
  return false;
}

/// 中文：一个项若是裸的百分数字面量，返回它的**数量文本**（含符号，不含 `%`）；否则 null。
///       两种形状：`B%`（`B` 是数字或一对不含括号的括号组）与 **`(B%)`——括号里整个是一个
///       百分数字面量**。后一种不是装饰：qalc 里 `%` 是单位，所以 `(10%)+10%` 与 `10%+10%`
///       一样是**同单位相加**（实测都是 0.2），`50-(-10%)` 的减数也是一个百分数量（实测 55）。
///       括号组里的 `%` 一律返回 null（含 `%` 的括号组不是数量）——`(20+10%)%` 这种形状因此
///       两边都不折，落回 direct 的读法，与今天同值。
/// English: When a term is a bare percentage literal, its **amount text** (sign included, `%`
///          excluded); otherwise null. Two shapes: `B%` (`B` a number or one bracket pair with no
///          brackets inside) and **`(B%)` — a bracket whose whole content is a percentage literal**.
///          The second is not decoration: `%` is a unit in qalc, so `(10%)+10%` adds two quantities
///          of the same unit exactly as `10%+10%` does (both measured at 0.2), and the subtrahend of
///          `50-(-10%)` is a percentage quantity too (measured 55). A bracket containing `%` returns
///          null (a bracket with a `%` inside is not an amount) — so a shape like `(20+10%)%` folds
///          in neither place, falls back to the direct reading, and keeps today's value.
String? _percentAmountOf(String term) {
  var text = term.trim();
  var sign = '';
  if (text.startsWith('+') || text.startsWith('-')) {
    sign = text[0];
    text = text.substring(1).trim();
  }
  if (text.isEmpty) return null;

  if (text.endsWith('%')) {
    // 中文：`B%`：`B` 是数字或一对**不含括号也不含 `%`** 的括号组——与 `_replacePercent` 同口径。
    // English: `B%`, where `B` is a number or one bracket pair **with neither brackets nor `%`
    //          inside** — the same line `_replacePercent` draws.
    final body = text.substring(0, text.length - 1).trim();
    if (!RegExp('^(?:$_decimalNumberPattern|\\([^()%]*\\))\$').hasMatch(body)) {
      return null;
    }
    return '$sign$body';
  }

  if (text.startsWith('(') && text.endsWith(')')) {
    final inner = _percentAmountOf(text.substring(1, text.length - 1));
    // 中文：两层符号（`-(10%)` 一类）不在这里读——放弃折叠，落回 direct。
    // English: two layers of sign (`-(10%)` and the like) are not read here: give up the fold and
    //          fall back to direct.
    if (inner == null || (sign.isNotEmpty && _startsWithSign(inner))) return null;
    return '$sign$inner';
  }
  return null;
}

bool _startsWithSign(String text) =>
    text.startsWith('+') || text.startsWith('-');

/// 中文：与 `(` 配对的 `)` 在哪；不配对时 null。
/// English: Where the `)` matching the `(` at [open] is; null when there is none.
int? _matchingParenthesis(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == '(') {
      depth++;
    } else if (text[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

/// 中文：**展开这一半——`X%` 怎么写成一串纯算术。** 折（相对模式那一步）在上面，展开在这里，
///       两者是 `%` 语义的全部；本文件原先只放折法，本轮把展开法从
///       `expression_input_normalization.dart` 搬了过来——那边的归一化管线因此回到 726 行，
///       而 `%` 的两半在同一份文件里（两份都是 `expression_parser.dart` 的 part，同一个库，
///       搬家不改任何调用点）。
/// English: **the expansion half — how `X%` is written out as plain arithmetic.** The fold (the
///          relative step) is above and the expansion is here; together they are all of `%`'s meaning.
///          This file used to hold the fold alone, and this round moved the expansion over from
///          `expression_input_normalization.dart` — that normalisation pipeline goes back to 726 lines
///          and both halves of `%` sit in one file (both are parts of `expression_parser.dart`, one
///          library, so the move changes no call site).

/// 中文：**`X%` 展开成 `(X)/100`；紧跟在除号右边时整段括起来，写成 `((X)/100)`。**
///
///       那对括号修的是一个错值：`(X)/100` 在乘除层**不是一个原子**，它的除号会与左边紧邻的除号
///       左结合——`5÷50%` 于是读成 `5/50/100` = **0.001**，而厂商手册 12.0 的 relative 一节把
///       `5 ÷ 50% → 10` 印成一条小题（direct 的定义也给 10：`50%` 是 0.5）。加括号之后读
///       `5/((50)/100)` = 10。整段理由、厂商原文行号与逐条实测在**本文件的文件头**（`%` 语义的
///       唯一一份；展开这一半本轮从 `expression_input_normalization.dart` 搬到这里，两者同一份
///       文件里）。
///
///       括号**只在除号右边**加：另外三种左邻下两种写法同值，而 `^` 右边那个 `/100` 按厂商的读法
///       故意逃到幂外（`2^3%` 实测 0.08）。判据因此只问左边一格，不改别处一个字节。
///
///       紧跟其后的幂（`X%^N`）要一起括进去：`^` 比 `/` 紧，`3%^2` 的既有值 0.0003 就是
///       `3/(100^2)`（与 qalc 逐条相同）——只括 `(X)/100` 而不带幂的话，`5/50%^2` 的幂会改去乘
///       **值** 0.5 而不是那个 100，得到一个谁都不给的数。括进去之后它是 `5/((50)/100^2)`
///       = 1000，与 qalc 同值。**这条幂里有一条不许吞**：指数自己若是百分数字面量（`X%^Y%`
///       的 `^Y`），把 `Y` 吞掉会让后面那个 `%` 没有操作数，一个读得动的输入变成一句错——
///       所以 [_percentPowerTailPattern] 的数字那一支带一个负向前瞻。
/// English: **`X%` expands to `(X)/100`, and when it sits immediately to the right of a division the
///          whole thing is wrapped: `((X)/100)`.**
///
///          Those brackets repair a wrong value: `(X)/100` is **not an atom** in the multiplicative
///          layer — its division associates leftwards with a division on its left, so `5÷50%` read as
///          `5/50/100` = **0.001** while the vendor's manual 12.0 prints `5 ÷ 50% → 10` as a worked
///          example in its relative section (direct's own definition gives 10 as well: `50%` is 0.5).
///          Wrapped, it reads `5/((50)/100)` = 10. The full argument, the manual's line numbers and the
///          measurements are in **this file's header** (the one copy of `%`'s meaning; the expansion
///          half moved here from `expression_input_normalization.dart` this round, so both halves now
///          sit in one file).
///
///          The brackets go in **only to the right of a division**: with the other three left
///          neighbours the two spellings have the same value, and to the right of `^` the `/100`
///          deliberately escapes the power under the vendor's reading (`2^3%` measures 0.08). The test
///          therefore asks about one cell to the left and moves not a byte anywhere else.
///
///          A power that immediately follows (`X%^N`) is wrapped along with it: `^` binds tighter than
///          `/`, so the existing value of `3%^2` — 0.0003 — **is** `3/(100^2)` (line for line with
///          qalc). Wrapping only `(X)/100` would leave the power of `5/50%^2` multiplying the **value**
///          0.5 instead of that 100 and answer a number nobody gives; wrapped, it is
///          `5/((50)/100^2)` = 1000, the same as qalc. **One thing in that power must not be
///          swallowed**: when the exponent is itself a percentage literal (the `^Y` of `X%^Y%`),
///          eating `Y` would leave the following `%` without an operand and turn a readable input into
///          an error — so [_percentPowerTailPattern]'s number arm carries a negative lookahead.
///
///          中文：展开式后面能一起括进去的幂。符号那一格不是装饰——`5/50%^-1` 的指数是 −1，
///          实测 qalc 给 0.001（= `5/(50·100)`），而只吞数字不吞符号会读成 `5/((50)/100)^-1`
///          = 2.5。数字那一支的 `(?![\d.%])` 与括号那一支的 `(?!%)` 是上面那条护栏：它们让正则
///          **不许**把一个百分数字面量的数量吞掉（`^50` 里的 `50` 后面跟着 `%`），同时也不许在
///          必要时退到 `5` 这种半截匹配上去——两条路都堵着，那一支就整体失败，指数留在原地，
///          后面那个 `%` 照旧有操作数。
/// English: the power that may be wrapped along with the expansion. The sign slot is not decoration —
///          the exponent of `5/50%^-1` is −1 and qalc measures 0.001 (= `5/(50·100)`), while eating
///          digits without the sign would read `5/((50)/100)^-1` = 2.5. The negative lookaheads —
///          `(?![\d.%])` on the number arm and `(?!%)` on the bracket arm — are the guard rail above:
///          they stop the regex from swallowing the amount of a percentage literal (the `50` of `^50`,
///          which is followed by `%`) and equally stop it backing off to a half match like `5`; with
///          both roads closed that arm fails as a whole, the exponent stays where it is, and the `%`
///          after it still has an operand.
const String _percentPowerTailPattern =
    r'(?:(?:\d+(?:\.\d+)?|\.\d+)(?![\d.%])|\([^()]+\)(?!%))';

String _replacePercent(String source) {
  var text = source;
  final pattern = RegExp(
      '(($_decimalNumberPattern)|\\([^()]+\\))%(\\^\\s*[+-]?\\s*(?:$_percentPowerTailPattern))?');
  while (pattern.hasMatch(text)) {
    text = text.replaceAllMapped(pattern, (match) {
      final expansion = '(${match.group(1)})/100${match.group(3) ?? ''}';
      return _percentFollowsDivision(text, match.start)
          ? '($expansion)'
          : expansion;
    });
  }
  return text;
}

/// 中文：`%` 字面量左边紧邻的是不是一个除号——中间可以隔空白与一元正负号（`5/-50%` 的减号是
///       符号，`5-50%` 的减号是减号，但两者都往左找到同一个答案：后者看到的是 `5`，返回 false）。
///       与 `_startsFunctionArgument` 同一种读法：只看文本，不问语法树。
/// English: is the character immediately to the left of a `%` literal a division — whitespace and a
///          unary sign may sit in between (the minus in `5/-50%` is a sign, the one in `5-50%` is a
///          subtraction, and both walk left to the same verdict: the latter sees `5` and returns
///          false). Read the same way `_startsFunctionArgument` reads: from the text, not from a tree.
bool _percentFollowsDivision(String text, int start) {
  var index = start - 1;
  while (true) {
    while (index >= 0 && text[index].trim().isEmpty) {
      index--;
    }
    if (index < 0) return false;
    final character = text[index];
    if (character == '/') return true;
    if (character != '+' && character != '-') return false;
    index--;
  }
}
