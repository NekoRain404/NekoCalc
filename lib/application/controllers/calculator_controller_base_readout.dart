part of 'calculator_controller.dart';

/// 中文：**四个进制胶囊各自对应的那一个换算目标。** 键面文字（`BIN` 之类）、引擎认得的那个词、
///       以及那个进制本身，三样东西写在一处——它们是同一件事的三个说法，分开写必然漂。
///
///       **`engineWord` 是量出来的，不是想出来的。** 引擎按**字符串精确匹配**换算目标
///       （`Calculator-calculate.cc:1944`：`equalsIgnoreCase(to_str, "hex")` / `"bin"` / `"dec"` /
///       `"oct"`），所以目标必须是一个**裸词**，而且必须紧跟在 `to` 后面、不被括号包住。
///       宿主实测（libqalculate 5.12.0，与 AAR 同版本）：
///
///       | 输入 | 引擎印出来的 | 换算发生了吗 |
///       |---|---|---|
///       | `100 to hex` | `64` | 是 |
///       | `100 to binary` | `1100100`（`to_struct` 印成 `bin("ary")`——长拼法只是碰巧还能用） | 是 |
///       | `100 to (hex)` | `(100 / hex()) * hex()` | **否**，退化成除法 |
///       | `((100) to hex)` | `(100 / hex()) * hex()` | **否**，尾部那个 `)` 进了目标串 |
///
///       第四行是最险的一条：`to_struct` 照样非空，于是原生侧如实报 `conversion`，
///       **一个看起来像答案的东西于是通过了「能不能显示」那道判据**。所以下面拼查询时，
///       目标词两边一个括号都不加。
///
/// English: **the conversion target each of the four base pills stands for.** The key face (`BIN`
///          and friends), the word the engine recognises and the radix itself are written in one
///          place — three names for one thing, and separated they would drift.
///
///          **`engineWord` is measured, not imagined.** The engine matches a conversion target by
///          **exact string** (`Calculator-calculate.cc:1944`: `equalsIgnoreCase(to_str, "hex")` /
///          `"bin"` / `"dec"` / `"oct"`), so the target has to be a **bare word**, directly after
///          `to` and not wrapped in brackets. Measured on the host (libqalculate 5.12.0, the same
///          version as the AAR):
///
///          | input | what the engine prints | did the conversion happen |
///          |---|---|---|
///          | `100 to hex` | `64` | yes |
///          | `100 to binary` | `1100100` (`to_struct` prints as `bin("ary")` — the long spelling only happens to work) | yes |
///          | `100 to (hex)` | `(100 / hex()) * hex()` | **no**, it degrades to a division |
///          | `((100) to hex)` | `(100 / hex()) * hex()` | **no**, the trailing `)` lands in the target string |
///
///          The fourth row is the dangerous one: `to_struct` is still non-empty, so the native side
///          truthfully reports `conversion` and **something that looks like an answer passes the
///          "may this be displayed" judgement**. That is why nothing below puts a single bracket
///          around the target word.
enum CalculatorBase {
  /// 中文：二进制。`radix` 只用于给读数编号（显示与查询都用 `engineWord`）。
  /// English: binary. `radix` only labels the read-out; both display and query use `engineWord`.
  bin(2, 'BIN', 'bin'),
  oct(8, 'OCT', 'oct'),
  dec(10, 'DEC', 'dec'),
  hex(16, 'HEX', 'hex');

  const CalculatorBase(this.radix, this.label, this.engineWord);

  /// 中文：进制本身。
  /// English: the radix itself.
  final int radix;

  /// 中文：读数上那个前缀（`HEX 64` 里的 `HEX`），也是键面上的字。
  /// English: the prefix on the read-out (the `HEX` in `HEX 64`), and the key face's own text.
  final String label;

  /// 中文：写给引擎的那个裸目标词。
  /// English: the bare target word written for the engine.
  final String engineWord;
}

/// 中文：读数里最多印多少位。**多出来的位必须看得见地被截掉**（末尾一个 `…`），绝不悄悄少印——
///       一个被截短而没有任何记号的多位数就是「屏幕上的错值」。20 位够放一个 64 位整数的十进制、
///       也够放常见的浮点结果；真的更长的（`2^2000 to hex` 是 602 位）本来就放不进状态行。
/// English: how many digits a read-out may print. **What does not fit is visibly cut** (an `…` at
///          the end) and never silently dropped — a truncated multi-digit number with no mark on it
///          *is* a wrong value on screen. Twenty digits holds a 64-bit integer and any ordinary
///          floating-point result; anything longer (`2^2000 to hex` is 602 digits) cannot fit the
///          status row anyway.
const int kBaseReadoutMaxDigits = 20;

/// 中文：**结果行旁边那一份进制读数**——纯显示，绝不是值。
///
///       它之所以是一个类型而不是一个字符串：它必须带上「**它描述的是哪一个结果**」
///       （[sourceDecimal]）与「**在状态的第几代**」（[revision]）。没有这两样，读数就有办法在
///       结果被换掉之后继续挂在屏幕上——那正是本项目一直在消灭的那类静默错值。
///
/// English: **the base read-out beside the result line** — pure display, never a value.
///
///          It is a type rather than a string because it has to carry **which result it describes**
///          ([sourceDecimal]) and **which generation of the state it belongs to** ([revision]).
///          Without those two, the read-out has a way of staying on screen after the result it
///          describes has been replaced — exactly the silent wrong value this project keeps deleting.
@immutable
class BaseReadout {
  const BaseReadout({
    required this.base,
    required this.digits,
    required this.sourceDecimal,
    required this.revision,
  });

  /// 中文：哪一个进制。
  /// English: which base.
  final CalculatorBase base;

  /// 中文：那个进制下的数字串（引擎印出来的那一段，必要时已按 [kBaseReadoutMaxDigits] 截断）。
  ///       **它从 [MathResult.displayText] 来，绝不从 `decimalText` 来**——理由见
  ///       [_CalculatorBaseReadout.showBaseReadout]。
  /// English: the digits in that base (the engine's own text, cut to [kBaseReadoutMaxDigits] when
  ///          needed). **It comes from [MathResult.displayText], never from `decimalText`** — see
  ///          [_CalculatorBaseReadout.showBaseReadout].
  final String digits;

  /// 中文：这次换算是从哪一份十进制形态算出来的。当前结果的十进制形态与它不同时，这个读数就
  ///       不再描述屏幕上的东西（见 [baseReadout]）。
  /// English: which decimal form this conversion was computed from. When the current result's
  ///          decimal form differs from it, this read-out no longer describes what is on screen (see
  ///          [baseReadout]).
  final String sourceDecimal;

  /// 中文：取到它时的状态代际。任何一次编辑都会把它推进（`_markStateEdited`），于是读数不会在
  ///       用户改过输入之后复活。
  /// English: the state generation when it was produced. Any edit advances it (`_markStateEdited`),
  ///          so a read-out cannot come back after the user changed the input.
  final int revision;

  /// 中文：状态行上那一格的字（`HEX 64`）。
  /// English: what the status row's cell says (`HEX 64`).
  String get label => '${base.label} $digits';

  @override
  bool operator ==(Object other) {
    return other is BaseReadout &&
        other.base == base &&
        other.digits == digits &&
        other.sourceDecimal == sourceDecimal &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(base, digits, sourceDecimal, revision);

  @override
  String toString() =>
      'BaseReadout(${base.name}, $digits, from $sourceDecimal, rev $revision)';
}

/// 中文：**进制换算：把当前结果换算到另一个进制，只为了显示。**
///
///       **交互（这一步做的选择）**：按 `▸BIN`/`▸OCT`/`▸HEX` → 问引擎要当前结果的该进制写法 →
///       在显示区的状态行上挂一个读数（`HEX 64`）。按 `▸DEC` 回到十进制（就是撤掉那个读数）。
///       读数**不写进结果行、不写进 `Ans`/`last`、不写进记忆寄存器、不进历史**：它是一次换算的
///       **显示**，不是这一次求值的值。
///
///       **为什么不把结果换成那个进制**（本步否掉的两个方案，理由都是量出来的）：
///
///       - **把 `-> hex` 插进表达式**（像 `CONV` 插 ` to ` 那样）会走进值通路：
///         `100 to hex` 在引擎那边是 `kind = conversion`、`decimal = 64`，而
///         `decimalTextIsFinite('64')` 为真——于是 `_selectEngineResult` 的第 1 级
///         会把它当成「能当数字用」，`Ans`/记忆/继续使用全都拿到 **64**（而用户要的是 100）。
///         同一条路上 `255 to hex` 是 `FF`、`100 to oct` 是 `144`、`0.5 to hex` 是 `0.8`：
///         一串**看着像十进制**的另一个进制的数字。这正是本项目花了十几轮在消灭的那类错值。
///         附带两处：引擎给这种表达式的 LaTeX 是**没求值的 to-表达式**
///         （`\frac{100}{\operatorname{hex}()} \operatorname{hex}()`），结果行会把它排版出来；
///         而 `hex` 这个词今天被封闭词表拒绝（`100 to hex` 连翻译都过不去，实测），要让它过去
///         就得放宽词表——于是**用户自己敲的** `to hex` 也会开始被引擎作答，同一个错值入口就开了。
///       - **进一个「以后所有结果都按这个进制显示」的模式**：它改的是结果行对**每一次**求值的
///         含义（那是这个应用最不能出错的一行），而键盘上没有 `A`–`F`，所以这个模式只能输出、
///         不能输入，还得自带指示与退出规则。精度设置（`AppSettings.precision`，小数位数）的
///         含义也会跟着变得含混。收益不比上面那个方案多一条，代价却是动一个已经在工作的东西。
///
///       **失败一律 fail closed**：没有可换算的十进制形态（出错态、矩阵这类结果）、引擎缺席/
///       超时/答不出来、引擎答的不是一次换算——三种情况都**不显示任何数字**，只给一句说明。
///       绝不在 Dart 侧自己算一份（那是第二个求值器，而且 `2^2000` 这类值根本放不进 double）。
///
/// English: **base conversion: show the current result in another base — for display only.**
///
///          **The interaction (the choice this step makes)**: pressing `▸BIN`/`▸OCT`/`▸HEX` asks the
///          engine for the current result in that base and puts a read-out on the display's status
///          row (`HEX 64`). `▸DEC` returns to decimal (which is exactly removing that read-out). The
///          read-out **never reaches the result line, `Ans`/`last`, the memory register or the
///          history**: it is the *display* of a conversion, not this evaluation's value.
///
///          **Why the result is not simply replaced by that base** (the two designs rejected, both
///          on measured grounds):
///
///          - **Inserting `-> hex` into the expression** (as `CONV` inserts ` to `) walks into the
///            value path: the engine answers `100 to hex` with `kind = conversion` and `decimal = 64`,
///            and `decimalTextIsFinite('64')` is true — so tier 1 of `_selectEngineResult`
///            takes it as **usable as a number** and `Ans`/memory/continue-with all receive **64**
///            where the user meant 100. Along the same path `255 to hex` is `FF`, `100 to oct` is
///            `144` and `0.5 to hex` is `0.8`: another base's digits, spelled like decimals. That is
///            precisely the wrong-value class this project has spent a dozen rounds deleting. Two
///            further costs: the engine's LaTeX for such an expression is the **unevaluated**
///            to-expression (`\frac{100}{\operatorname{hex}()} \operatorname{hex}()`), which the
///            result line would typeset; and `hex` is refused by the closed vocabulary today
///            (`100 to hex` does not even translate — measured), so letting it through would also
///            start answering **user-typed** `to hex`, opening the same wrong-value entrance.
///          - **Entering a "every later result is shown in this base" mode**: that changes what the
///            result line means for **every** evaluation (the one line in this app that may least
///            afford a mistake), and the keypad has no `A`–`F`, so the mode could only output and
///            never input — while needing its own indicator and exit rule. What
///            `AppSettings.precision` (a count of decimal places) means would blur as well. It buys
///            nothing the design above does not, and it moves something that already works.
///
///          **Every failure fails closed**: no convertible decimal form (error state, a matrix, …), an
///          absent/timed-out/silent engine, or an answer that is not a conversion — all three show
///          **no digits at all**, just one sentence. Nothing is ever computed on the Dart side (that
///          would be a second evaluator, and values like `2^2000` do not fit a double anyway).
mixin _CalculatorBaseReadout on _CalculatorState {
  /// 中文：当前读数。**读它的人拿到的永远是「此刻仍然成立」的那一个**：代际或来源十进制形态
  ///       对不上就当作没有——两道判据各管一件事，缺一不可。
  ///
  ///       - **代际**（`revision != _stateRevision`）：用户改过输入。于是读数不会在编辑之后
  ///         「复活」（把那一个数字删掉之后结果又变回 100，读数也不会自己回来）。
  ///       - **来源十进制形态**（`sourceDecimal != _result.decimalText`）：屏幕上那个结果换过了。
  ///         这一条管的是**不经过编辑**的那些替换——引擎跟进回来之后落地的结果
  ///         （`_adoptEngineResult` 不改代际）、以及 `applyMathResult`。少了它，一个描述旧值的读数
  ///         会继续挂在屏幕上，而它旁边就是新值：屏幕上于是同时有两个互相矛盾的数字。
  ///
  /// English: the current read-out. **Whoever reads it always gets the one that still holds**: a
  ///          mismatched generation or source decimal counts as absent — two judgements, one job
  ///          each, and neither may be dropped.
  ///
  ///          - **generation** (`revision != _stateRevision`): the user edited the input. So a
  ///            read-out cannot come back after an edit (deleting that digit so the result is 100
  ///            again does not resurrect it).
  ///          - **source decimal** (`sourceDecimal != _result.decimalText`): the result on screen was
  ///            replaced. This covers the replacements that **do not go through an edit** — the
  ///            engine follow-up landing (`_adoptEngineResult` does not touch the generation) and
  ///            `applyMathResult`. Without it, a read-out describing the old value would stay on
  ///            screen next to the new one, and the screen would carry two contradictory numbers.
  BaseReadout? get baseReadout {
    final readout = _baseReadout;
    if (readout == null) return null;
    if (readout.revision != _stateRevision) return null;
    if (readout.sourceDecimal != _result.decimalText) return null;
    return readout;
  }

  BaseReadout? _baseReadout;

  /// 中文：按下四个进制胶囊之一时走这一条。返回 `null` 表示**没有话要说**（换算成了，或者
  ///       `DEC` 把读数撤掉了）；返回一段文字表示这次没成，调用方把它交给用户（主屏用
  ///       `SnackBar`，与提交路径的 `needsAttention` 同一种做法）。
  ///
  ///       **问引擎的那一句是拼出来的，而且是有意的**：`(<十进制形态>) to hex`。它**不是**应用
  ///       自己的表达式，所以不经过 `engineExpressionFor`——那道翻译管的是「应用的语法在引擎里
  ///       怎么写」，而这里跨过去的东西是「一个十进制数 + 四个常量词之一」，没有任何应用语法参与，
  ///       封闭性是构造出来的（见 [CalculatorBase] 上那段实测：左操作数加括号无害，目标词加括号
  ///       就会把一次换算变成一次除法，而引擎照样报 `conversion`）。
  ///
  ///       **引擎的答案只取 [MathResult.displayText]，一字也不取 `decimalText`。** 真实回执里
  ///       两者常常**都是**那串另一个进制的数字（`100 to hex` 是 `64`、`100 to bin` 是 `1100100`），
  ///       对 `255 to hex`（`FF`）这类则只有 `displayText` 有东西。取 `decimalText` 就等于把那串
  ///       数字请进唯一允许被解析成数字的字段——读数的安全性正是建立在「它从不经过那个字段」上。
  ///
  ///       **采用它的判据是既有那一条**：`conversion` + [MathResult.isDisplayable]。不是换算
  ///       （`unit_mismatch` 之类）就不显示——一个「要了换算而引擎没做」的回执正是这条判据在挡。
  ///
  /// English: what a press on one of the four base pills runs. A `null` return means **nothing to
  ///          say** (the conversion happened, or `DEC` removed the read-out); a sentence means this
  ///          one did not work and the caller hands it to the user (the screen uses a `SnackBar`,
  ///          the same treatment the submit path's `needsAttention` gets).
  ///
  ///          **The sentence asked of the engine is assembled, deliberately**: `(<decimal>) to hex`.
  ///          It is **not** an expression of this app, so it does not go through
  ///          `engineExpressionFor` — that translation covers "how this app's syntax is written for
  ///          the engine", while what crosses here is "one decimal number plus one of four constant
  ///          words", with no app syntax involved, and the closure is by construction (see the
  ///          measurements on [CalculatorBase]: bracketing the left operand is harmless, bracketing
  ///          the target turns a conversion into a division **while the engine still reports
  ///          `conversion`**).
  ///
  ///          **Only [MathResult.displayText] is taken from the engine's answer; `decimalText` is
  ///          never touched.** In a real receipt the two are often the *same* other-base digits
  ///          (`100 to hex` is `64`, `100 to bin` is `1100100`), while for `255 to hex` (`FF`) only
  ///          `displayText` carries anything at all. Reading `decimalText` would be inviting those
  ///          digits into the one field allowed to be parsed as a number — and the read-out's safety
  ///          is exactly that it never passes through that field.
  ///
  ///          **The acceptance test is the existing one**: `conversion` plus
  ///          [MathResult.isDisplayable]. Anything that is not a conversion (`unit_mismatch` and
  ///          friends) is not shown — a "a conversion was asked for and the engine did not perform
  ///          it" receipt is precisely what that judgement exists to stop.
  Future<String?> showBaseReadout(CalculatorBase base) async {
    if (base == CalculatorBase.dec) {
      // 中文：`DEC` 的语义是「回到十进制」——结果行本来就是十进制，所以它做的是**撤掉读数**，
      //       而不是再画一个 `DEC 100`（那与结果行说的是同一件事，只是多占一格）。
      //       这一支不发引擎调用：屏幕已经回答了它。
      // English: `DEC` means "back to decimal" — the result line is already decimal, so it **removes
      //          the read-out** rather than drawing a `DEC 100` that says the same thing twice. This
      //          branch issues no engine call: the screen already answers it.
      if (_clearBaseReadout()) notifyListeners();
      return null;
    }
    final source = _result;
    // 中文：**先撤掉上一个读数**，再问。否则引擎卡住的那 5 秒里屏幕上会留着一个别的进制的读数，
    //       而用户刚按的是这个进制。
    // English: **remove the previous read-out first**, then ask. Otherwise a wedged engine leaves
    //          another base's read-out on screen for its whole timeout, right after the user asked
    //          for this base.
    final cleared = _clearBaseReadout();
    if (hasError || !source.hasFiniteDecimal) {
      if (cleared) notifyListeners();
      return strings.baseReadoutNoValue;
    }
    if (cleared) notifyListeners();
    final generation = _stateRevision;
    final reply = await _askEngine('(${source.decimalText}) to ${base.engineWord}');
    if (_disposed) return null;
    // 中文：与边打边算同一条过期判据、同一个计数器（`_stateRevision`）：往返期间用户改过输入，
    //       这一发答的就是一条已经不在屏幕上的时间线。**静默丢弃**——用户按下别的键之后，
    //       屏幕不该再冒出上一个问题的答案。
    // English: the same staleness rule and the same counter as as-you-type (`_stateRevision`): if the
    //          user edited during the round trip, this answer describes a timeline that is no longer
    //          on screen. **Dropped silently** — after pressing something else, the answer to the
    //          previous question must not pop up.
    if (generation != _stateRevision) return null;
    final converted = reply.result;
    if (!reply.ok ||
        converted == null ||
        converted.resultKind != EngineResultKind.conversion ||
        !converted.isDisplayable) {
      return strings.baseReadoutNoAnswer;
    }
    _baseReadout = BaseReadout(
      base: base,
      digits: _baseReadoutDigits(converted.displayText),
      sourceDecimal: source.decimalText,
      revision: generation,
    );
    notifyListeners();
    return null;
  }

  /// 中文：撤掉读数；返回「本来有没有」。有返回值是为了让调用方只在真变了的时候
  ///       `notifyListeners()`——空通知会让界面白重建一次。
  /// English: removes the read-out and reports whether there was one, so callers only call
  ///          `notifyListeners()` when something really changed (an empty notification rebuilds the
  ///          screen for nothing).
  bool _clearBaseReadout() {
    if (_baseReadout == null) return false;
    _baseReadout = null;
    return true;
  }

  /// 中文：读数里的位数上限（见 [kBaseReadoutMaxDigits]）。截断**必须留下痕迹**：末尾一个 `…`。
  /// English: the digit cap for a read-out (see [kBaseReadoutMaxDigits]). A cut **must leave a
  ///          mark**: an `…` at the end.
  String _baseReadoutDigits(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= kBaseReadoutMaxDigits) return trimmed;
    return '${trimmed.substring(0, kBaseReadoutMaxDigits)}…';
  }
}
