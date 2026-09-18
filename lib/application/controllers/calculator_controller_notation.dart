part of 'calculator_controller.dart';

/// 中文：**HiPER 的 `FSE` 那一维**，只留下引擎真的给得出的那几档。
///
///       **档位是从 HiPER 自己的字符串里读出来的，不是从任何转述里抄的**（厂商字符串表
///       `msgctxt "command.name.FSE"` 那六条今天仍能从
///       `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/`
///       取回自查，逐字抄本在 `.superpowers/backup/fse-report.md:33-40`，手册那一栏在同文件
///       `:45-51`；两个抽取文件 `/tmp/hiper_en.po` 与 `/tmp/hipercalc-manual.txt` 住在本机
///       `/tmp`，已不存在）：
///       `command.name.FSE` = "Number Notation"，它的五档是 `FSE_NORM` "Normal Notation"、
///       `FSE_FIX` "Fixed Notation"、`FSE_SCI` "Scientific Notation"、`FSE_ENG`
///       "Engineering Notation"、`FSE_ENG_SI` "Engineering SI Notation"。
///
///       **这里只有三档，因为引擎只给得出三档**（每一条都量过，见 `fse-report.md` 的对照表）：
///       - Normal：**就是本应用今天的结果行**，所以它没有读数——回到它就是撤掉读数。
///       - Scientific / Engineering：引擎有现成的换算目标词 `to sci` / `to eng`
///         （`Calculator-calculate.cc` 的 `to_str` 分支，与四个进制胶囊用的 `to hex` 同一个机制）。
///         实测（宿主 `qalc` 5.12.0，与本 AAR 同版本）：`12345.6789 to sci` → `1.23456789E4`、
///         `to eng` → `12.3456789E3`。**两者可区分，也与 Normal 可区分。**
///       - **Fixed 给不出**：引擎没有 `to fixed` 这一类目标词，它落在 `PrintOptions` 的
///         `min_decimals`/`max_decimals` 上，而这一对旋钮今天没有任何入口能带着"这一次打印"过去。
///         要接它得新开一条原生通道，不是拼一句表达式就能到的地方。
///       - **Engineering SI 更给不出**：HiPER 的手册例子是 `12 345` → `12.345 k`，一个**裸数字**
///         带 SI 前缀；而 libqalculate 的前缀只作用于**单位**（`MathStructure-print.cc` 的前缀分支
///         在 `Unit` 上）。实测三次：`prefixes on` 与 `prefixes off` 在八个裸数字上**逐字节相同**、
///         `to prefix` 在四个裸数字上**逐字节相同**、`to optimal` 同样。没有单位就没有前缀。
///
/// **它只改写法，绝不改值**：读数从 [MathResult.displayText] 来，绝不经过 `decimalText`——
/// 与 `BaseReadout` 同一条规矩、同一个理由（`Ans`/`last`/记忆/历史读的是 `decimalText`）。
///
/// English: **HiPER's `FSE` dimension**, keeping only the positions the engine really produces.
///
///          **The positions were read out of HiPER's own strings, not copied from any retelling**
///          (the six `msgctxt "command.name.FSE"` entries can still be fetched and checked today
///          from `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/`;
///          they are quoted verbatim in `.superpowers/backup/fse-report.md:33-40`, with the manual's
///          column at `:45-51`. The two extracted files `/tmp/hiper_en.po` and
///          `/tmp/hipercalc-manual.txt` were on this machine's `/tmp` and are no longer present):
///          `command.name.FSE` = "Number Notation",
///          whose five positions are `FSE_NORM` "Normal Notation", `FSE_FIX` "Fixed Notation",
///          `FSE_SCI` "Scientific Notation", `FSE_ENG` "Engineering Notation" and `FSE_ENG_SI`
///          "Engineering SI Notation".
///
///          **Only three are here, because the engine only produces three** (every claim measured;
///          the table is in `fse-report.md`):
///          - Normal: **this app's result line already**, so it carries no read-out — returning to it
///            means removing the read-out.
///          - Scientific / Engineering: the engine has ready-made conversion targets `to sci` /
///            `to eng` (the `to_str` branch of `Calculator-calculate.cc`, the same mechanism the four
///            base pills use for `to hex`). Measured (host `qalc` 5.12.0, the version this AAR
///            bundles): `12345.6789 to sci` → `1.23456789E4`, `to eng` → `12.3456789E3`. **Both are
///            distinguishable from each other and from Normal.**
///          - **Fixed is not available**: the engine has no `to fixed`-style target; it lives on
///            `PrintOptions`'s `min_decimals`/`max_decimals`, and today nothing can carry that pair
///            into one print. Wiring it means opening a new native channel, not assembling an
///            expression.
///          - **Engineering SI is even less available**: HiPER's manual example is `12 345` →
///            `12.345 k` — a **bare number** with an SI prefix — while libqalculate's prefixes act on
///            **units** only (the prefix branch of `MathStructure-print.cc` sits on a `Unit`).
///            Measured three times: `prefixes on` vs `prefixes off` are **byte-identical** across
///            eight bare numbers, `to prefix` is byte-identical across four, and so is `to optimal`.
///            No unit, no prefix.
///
///          **It changes the spelling only, never the value**: the read-out comes from
///          [MathResult.displayText] and never passes through `decimalText` — the same rule and the
///          same reason as `BaseReadout` (`Ans`/`last`/memory/history read `decimalText`).
enum ResultNotation {
  /// 中文：Normal——没有读数，因为结果行本来就是它。
  /// English: Normal — no read-out, because the result line already is it.
  normal('', ''),

  /// 中文：Scientific。`engineWord` 是量出来的裸目标词，不是想出来的。
  /// English: Scientific. `engineWord` is a measured bare target word, not an imagined one.
  scientific('SCI', 'sci'),

  /// 中文：Engineering。
  /// English: Engineering.
  engineering('ENG', 'eng');

  const ResultNotation(this.label, this.engineWord);

  /// 中文：读数上那个前缀（`SCI 1.23456789E4` 里的 `SCI`）。Normal 是空串。
  /// English: the prefix on the read-out (the `SCI` in `SCI 1.23456789E4`); empty for Normal.
  final String label;

  /// 中文：写给引擎的那个裸目标词，`to` 后面那一个。Normal 是空串（它不发引擎调用）。
  /// English: the bare target word written for the engine, the one after `to`. Empty for Normal,
  ///          which issues no engine call at all.
  final String engineWord;

  /// 中文：按一次 `FSE` 之后是哪一档。三档一圈，与 `DRG` 一样是循环键。
  /// English: which position one `FSE` press moves to. Three positions in a ring — a cycle key,
  ///          as `DRG` is.
  ResultNotation get next => switch (this) {
        ResultNotation.normal => ResultNotation.scientific,
        ResultNotation.scientific => ResultNotation.engineering,
        ResultNotation.engineering => ResultNotation.normal,
      };
}

/// 中文：**结果行旁边那一份记法读数**——纯显示，绝不是值。形状与 `BaseReadout` 逐条相同，
///       因为它要回答的是同一类问题：这一串描述的是哪一个结果（[sourceDecimal]）、它在状态的
///       第几代（[revision]）。少任何一条，读数就有办法在结果被换掉之后继续挂在屏幕上。
///
/// English: **the notation read-out beside the result line** — pure display, never a value. Its shape
///          is item-for-item `BaseReadout`'s, because it answers the same kind of question: which
///          result this string describes ([sourceDecimal]) and which generation of the state it
///          belongs to ([revision]). Drop either and a read-out can stay on screen after the result
///          it describes has been replaced.
@immutable
class NotationReadout {
  const NotationReadout({
    required this.notation,
    required this.spelling,
    required this.sourceDecimal,
    required this.revision,
  });

  /// 中文：哪一档记法。
  /// English: which notation.
  final ResultNotation notation;

  /// 中文：那一档下的写法（引擎印出来的那一段）。**它从 [MathResult.displayText] 来，绝不从
  ///       `decimalText` 来。**
  /// English: the spelling in that notation (the engine's own text). **It comes from
  ///          [MathResult.displayText], never from `decimalText`.**
  final String spelling;

  /// 中文：这次读的是哪一份十进制形态。当前结果的十进制形态与它不同时，读数就不再描述屏幕上的
  ///       东西（见 [notationReadout]）。
  /// English: which decimal form this was read from. When the current result's decimal form differs,
  ///          the read-out no longer describes what is on screen (see [notationReadout]).
  final String sourceDecimal;

  /// 中文：取到它时的状态代际。任何一次编辑都会把它推进（`_markStateEdited`）。
  /// English: the state generation when it was produced; any edit advances it (`_markStateEdited`).
  final int revision;

  /// 中文：状态行上那一格的字（`SCI 1.23456789E4`）。
  /// English: what the status row's cell says (`SCI 1.23456789E4`).
  String get label => '${notation.label} $spelling';

  @override
  bool operator ==(Object other) {
    return other is NotationReadout &&
        other.notation == notation &&
        other.spelling == spelling &&
        other.sourceDecimal == sourceDecimal &&
        other.revision == revision;
  }

  @override
  int get hashCode =>
      Object.hash(notation, spelling, sourceDecimal, revision);

  @override
  String toString() =>
      'NotationReadout(${notation.name}, $spelling, from $sourceDecimal, rev $revision)';
}

/// 中文：**数字记法：把当前结果换一种写法显示出来。** 它做的事与四个进制胶囊是同一件——
///       问引擎要当前结果的另一种写法，挂在状态行上——所以失败与过期的判据逐条照搬：
///
///       - 引擎缺席、超时、报错、答的不是一次换算：**不显示任何数字**，只给一句说明；
///       - 往返期间用户改过输入（代际变了）、或按键时压根没有可读的十进制形态：什么都不说；
///       - 读数带着来源十进制形态，结果一换它就自己失效，不会与新值同屏。
///
///       引擎那一句同样是**拼出来的**：`(<十进制形态>) to sci`。它**不是**应用的表达式，所以
///       不经过 `engineExpressionFor`——跨过去的是「一个十进制数 + 两个常量词之一」，与
///       `(…) to hex` 逐字同形，封闭性由构造保证（目标词是裸词、两边不加括号，理由见
///       `CalculatorBase` 上那段实测）。
///
/// English: **number notation: show the current result in another spelling.** It does what the four
///          base pills do — ask the engine for another spelling of the current result and hang it on
///          the status row — so the failure and staleness tests are copied item for item:
///
///          - an absent, timed-out or erroring engine, or an answer that is not a conversion: **no
///            digits at all**, just one sentence;
///          - the user edited during the round trip (the generation moved), or there was no readable
///            decimal form to start with: nothing is said;
///          - the read-out carries its source decimal, so it expires by itself the moment the result
///            changes and never sits beside a different value.
///
///          The sentence asked of the engine is assembled too: `(<decimal>) to sci`. It is **not** an
///          expression of this app, so it does not go through `engineExpressionFor` — what crosses is
///          "one decimal number plus one of two constant words", character-for-character the shape of
///          `(…) to hex`, with the closure guaranteed by construction (a bare target word, no brackets
///          on either side; the measurements are on `CalculatorBase`).
mixin _CalculatorNotation on _CalculatorState {
  /// 中文：当前读数。**读它的人拿到的永远是「此刻仍然成立」的那一个**：代际或来源十进制形态对不上
  ///       就当作没有——两道判据各管一件事，缺一不可，与 `baseReadout` 逐条相同。
  /// English: the current read-out. **Whoever reads it always gets the one that still holds**: a
  ///          mismatched generation or source decimal counts as absent — two judgements, one job each,
  ///          exactly as on `baseReadout`.
  NotationReadout? get notationReadout {
    final readout = _notationReadout;
    if (readout == null) return null;
    if (readout.revision != _stateRevision) return null;
    if (readout.sourceDecimal != _result.decimalText) return null;
    return readout;
  }

  NotationReadout? _notationReadout;

  /// 中文：当前选中的那一档。`FSE` 循环时从这里往下走，所以它是一份持久的选择，而不是一次性的动作。
  /// English: the position currently selected. `FSE` cycles from here, so it is a lasting choice
  ///          rather than a one-shot action.
  ResultNotation get notation => _notation;

  ResultNotation _notation = ResultNotation.normal;

  /// 中文：按一次 `FSE`。返回 `null` 表示**没有话要说**（读数换好了，或者回到了 Normal）；
  ///       返回一段文字表示这一次没成，调用方把它交给用户（主屏用 `SnackBar`，与进制胶囊同一条）。
  /// English: one `FSE` press. A `null` return means **nothing to say** (the read-out was replaced,
  ///          or Normal removed it); a sentence means this one did not work and the caller hands it
  ///          to the user (the screen uses a `SnackBar`, the same channel as the base pills).
  Future<String?> cycleNotation() => showNotation(_notation.next);

  /// 中文：切到某一档并取回它的读数。**先撤掉上一个读数**，再问——否则引擎卡住的那 5 秒里屏幕上
  ///       会留着一个别的记法的读数，而用户刚按的是这一档。
  /// English: move to one position and fetch its read-out. **The previous read-out is removed
  ///          first**, then the question is asked; otherwise a wedged engine leaves another notation's
  ///          read-out on screen for its whole timeout, right after the user asked for this one.
  Future<String?> showNotation(ResultNotation target) async {
    // 中文：Normal 的语义是「回到结果行本来的写法」——它做的是**撤掉读数**，而不是再画一个
    //       `NOR 12345.6789`（那与结果行说的是同一件事，只是多占一格）。这一支不发引擎调用：
    //       屏幕已经回答了它。与 `DEC` 对四个进制胶囊是同一个决定。
    // English: Normal means "back to how the result line already writes it" — it **removes the
    //          read-out** rather than drawing a `NOR 12345.6789`. This branch issues no engine call:
    //          the screen already answers it. The same decision `DEC` makes for the base pills.
    _notation = target;
    final cleared = _clearNotationReadout();
    if (target == ResultNotation.normal) {
      if (cleared) notifyListeners();
      return null;
    }
    final source = _result;
    if (hasError || !source.hasFiniteDecimal) {
      if (cleared) notifyListeners();
      return '当前没有可换记法的数值结果';
    }
    if (cleared) notifyListeners();
    final generation = _stateRevision;
    final reply = await _askEngine(
      '(${source.decimalText}) to ${target.engineWord}',
    );
    if (_disposed) return null;
    // 中文：与进制读数、与边打边算同一条过期判据、同一个计数器（`_stateRevision`）：往返期间用户改过
    //       输入，这一发答的就是一条已经不在屏幕上的时间线。**静默丢弃。**
    // English: the same staleness rule and the same counter as the base read-out and as-you-type
    //          (`_stateRevision`): if the user edited during the round trip, this answer describes a
    //          timeline no longer on screen. **Dropped silently.**
    if (generation != _stateRevision) return null;
    final converted = reply.result;
    if (!reply.ok ||
        converted == null ||
        converted.resultKind != EngineResultKind.conversion ||
        !converted.isDisplayable) {
      return '引擎没有给出这一档记法';
    }
    final spelling = converted.displayText.trim();
    if (spelling.isEmpty) return '引擎没有给出这一档记法';
    _notationReadout = NotationReadout(
      notation: target,
      spelling: spelling,
      sourceDecimal: source.decimalText,
      revision: generation,
    );
    notifyListeners();
    return null;
  }

  /// 中文：撤掉读数；返回「本来有没有」，好让调用方只在真变了的时候通知。
  /// English: removes the read-out and reports whether there was one, so callers only notify when
  ///          something really changed.
  bool _clearNotationReadout() {
    if (_notationReadout == null) return false;
    _notationReadout = null;
    return true;
  }
}
