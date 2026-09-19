/// 中文：**度分秒字面量（`3°30′0″`）的唯一一份文法。** 两个消费者：取值那条路
///       （`expression_input_normalization.dart` 把它改写成 `degangle(…)`）与显示那条路
///       （`expression_ast_parser.dart` 把它读成 [SexagesimalNode]，由 TeX 生成器排版）。
///       **判据写在一处**，所以「哪一串算字面量」在两个消费者眼里永远是同一个答案——两条路
///       各写一套正则的话，屏幕上排得出公式、求值那边却报错（或者反过来）这种分歧就迟早出现。
///
///       ## 文法
///
///       ```
///       字面量 := NUM ° [ 第二部分 ]
///       第二部分 := NUM ′ [ NUM ″? ]     -- 分，后面可以再跟秒
///                 | NUM ″                -- 只有秒（分缺席）
///                 | NUM                  -- 没带记号的数字：读作分
///       NUM    := \d+(?:\.\d+)?          -- 与 `°` 那条改写一直以来的数字形状相同
///       ```
///
///       **各部分必须紧挨着写**（不认空格）。三条理由：`°` 那条改写从修好 `°` 的那一轮起就要求
///       数字与 `°` 相连；键盘插入的分隔符两侧从来没有空格；而**今天每一个带空格的输入读法都
///       因此原样不变**（`30° 2` 仍是隐式乘法，见下面「与既有行为的关系」）。
///
///       ## 值：`度 + 分/60 + 秒/3600`，符号在外面
///
///       `-3°30′` 归一化写成 `-degangle(3+30/60)`——**负号留在字面量外面**，所以它是
///       3.5 度这个角度的相反数（-3.5），而不是「-3 度加 30 分」那种读法（-2.5）。判据是
///       `-(3°30′)` 必须恒等于 `-3°30′`：否则给字面量加一对括号就会**换一个值**，而屏幕上
///       看不出为什么。参考实现同向：宿主 `qalc` 5.12.0 `-set "angle deg"` 实测 `-3°30′` =
///       `−3.5°`。
///
///       ## 每一条决定，以及厂商文本在哪里说话、在哪里没有
///
///       **厂商定下的（HiPER 手册 v12.0，`DEGREES, MINUTES, SECONDS` 一节，`pdftotext -layout`
///       第 246–253 行）：**
///
///       > 「If you want to enter a number as degrees, minutes and seconds (a sexagesimal number),
///       > use `D°M′S` key.」`3 D°M′S 30 D°M′S 0 D°M′S` → **`3.5`**
///       > 「…key converts the result into degrees, minutes and seconds. **The key is not present
///       > on built-in keyboards** but you can place it on your own keyboard.」`3.5` → `3°30´ 0´´`
///
///       - **三段齐全时是度数**（`3°30′0″` = 3.5）——手册那行例子逐字定下。
///       - **`3°30′`（缺秒）= 3.5**：手册只给了三段齐全的例子，「缺席的那一段是 0」是**我补的**
///         读法；它与参考实现一致（宿主实测 `3°30′` = `3.5°`）。
///       - **`3°0′30″`（缺分）= 3.008333…、`3°30″`（只有秒）= 3.008333…**：**记号说了算**——
///         哪个记号在场就按哪个单位读，没带记号的那一段是 0。依据是参考实现：宿主实测
///         `3°0′30″` = `3.008333333°`、`3°30"` = `3.008333333°`（同一个数）。手册没有这两句。
///       - **小数可以出现在任何一段**（`3.5°30′` = 4、`3°30.5′` = 3.508333…、`3°90′` = 4.5）：
///         就是 `度 + 分/60 + 秒/3600` 这条算式，**不做「分必须小于 60」之类的校验**——手册与
///         参考实现都没有那道校验（宿主三条实测如上），而多一道自创的拒绝会把 `3°90′` 这种
///         「没有歧义、只是不常见」的输入变成报错。
///       - **数字前不能是名字字符/数字/小数点**：这条 lookbehind 逐字沿用被替换掉的那条
///         `°` 规则（`x30°`、`130°` 里的后一半都不算字面量的起点）。
///
///       **我决定的（厂商文本没有说，参考实现有别的读法或没有读法）：**
///
///       - **`3°30`（分不带记号）= 3.5**：**这一条与参考实现不同**。宿主 `qalc` 5.12.0 实测
///         `3°30` = `90°`（`°` 之后那个数按隐式乘法读）、`3°30′0` = **`0°`**（`3.5° × 0`）。
///         本应用**故意**改成「没带记号的尾数是下一段」。理由是那条路只有键盘会走，而键盘
///         按下 `D°M′S` 之后**必然**经过这两个中间态：`3` `D°M′S` `3` `0` 就是 `3°30`，
///         再按一次之前就是 `3°30′0`。应用是边打边算的，照参考实现读，屏幕上会先出现 90、
///         再跳成 0、最后才落到 3.5——**三个数里有俩是错的**，而它们出现在用户眼前。
///         改读之后这条路是 3 → 3.5 → 3.5 → 3.5 ——每一步都已经是要的那个角度。
///         （代价：`3°30` 不再等于 `3° × 30`。想乘的人写 `3°*30`，而 `°` 这条路上**本来就只有
///         一个权威**——`degangle` 是应用自己的名字，引擎一次都不被问——所以不存在
///         「同一个输入两个权威」那种危险。）
///       - **`30°2` 随之读作 30.0333…**（同一条规则的另一面）。
///       - **`30° 2`（有空格）不变**：仍然读作 `degangle(30) × 2`——**今天每一个带空格的
///         读法都没有被这一轮改到**，只有紧挨着的写法变了。
///       - **`3°30′0″5`**：`″` 之后紧跟着的数字是**另一个数**，与字面量是隐式乘法
///         （宿主实测 `17.5°`，同一条读法）。
///       - **`′`/`″` 单独出现（没有 `°`）不是字面量**，`3°′30″`、`3°30′″` 也不是：整串落到
///         两个解析器手里都是一个错误（fail-closed）。键盘造不出这些形状（它只会按
///         `°`→`′`→`″` 的顺序插），所以这是一条守卫，不是一条用户路径。
///       - **ASCII 的 `'`/`"` 不是记号**：本应用只认 `′`（U+2032）与 `″`（U+2033），也就是
///         结果行印出来、键盘插进去的那两个字符。`'`/`"` 在本应用的语法里从来没有含义，
///         这一轮不发明一个。
library;

/// 中文：**度分秒的三个记号，以及它们在 TeX 里的写法——各只有一份。**
///       终端记号用在文法与键盘插入上；TeX 记号同时被**表达式行**（字面量，`tex_emitter.dart`）
///       与**结果行**（引擎印出来的那一串，`result_presentation.dart` 的 `_dmsTex`）使用——
///       同一个角度在屏幕上两处排出来必须一模一样，所以记号也只有一份。
/// English: **the three sexagesimal marks and their TeX spellings — one copy each.** The terminal
///          marks serve the grammar and the keypad insertion; the TeX marks are used by **both the
///          expression line** (the literal, `tex_emitter.dart`) and **the result line** (the engine's
///          render, `_dmsTex` in `result_presentation.dart`) — one angle has to typeset identically in
///          both places, so there is one copy of the marks.
abstract final class SexagesimalMarks {
  /// 中文：度（U+00B0）。`3°30′0″` 的第一段记号。
  /// English: degrees (U+00B0), the first part's mark in `3°30′0″`.
  static const String degree = '°';

  /// 中文：分（U+2032 PRIME）。注意**不是** ASCII 撇号——理由在文件头最后一条。
  /// English: minutes (U+2032 PRIME) — **not** an ASCII apostrophe; the header's last item says why.
  static const String minute = '′';

  /// 中文：秒（U+2033 DOUBLE PRIME）。
  /// English: seconds (U+2033 DOUBLE PRIME).
  static const String second = '″';

  /// 中文：`°` 的 TeX 写法。
  /// English: `°` in TeX.
  static const String degreeTex = '^\\circ';

  /// 中文：`′` 的 TeX 写法。
  /// English: `′` in TeX.
  static const String minuteTex = "'";

  /// 中文：`″` 的 TeX 写法。
  /// English: `″` in TeX.
  static const String secondTex = "''";

  /// 中文：两段之间补的那个细空格（`12^\circ\,34'`）。结果行与表达式行用的是同一个。
  /// English: the thin space between two sections (`12^\circ\,34'`) — the same one on both lines.
  static const String texSeparator = '\\,';
}

/// 中文：一个读出来的度分秒字面量。[degrees] 是原样的数字文本（不换算、不去零），
///       [minutes]/[seconds] 为 `null` 表示那一段不在场（与「那一段是 0」是两件事：
///       `3°0′` 的分在场且是 `0`，`3°` 的分不在场）。
///       [start]/[end] 是它在源码里的区间，与 [ExprNode] 的约定一致（闭开区间）。
/// English: one literal as read. [degrees] is the digit text verbatim (no conversion, no zero
///          stripping) and a `null` [minutes]/[seconds] means that part is absent — not that it is
///          zero (`3°0′` has a minute part of `0`, `3°` has none). [start]/[end] is its span in the
///          source, under the same half-open convention as [ExprNode].
final class SexagesimalLiteral {
  const SexagesimalLiteral({
    required this.degrees,
    required this.start,
    required this.end,
    this.minutes,
    this.seconds,
  });

  final String degrees;
  final String? minutes;
  final String? seconds;
  final int start;
  final int end;

  /// 中文：**归一化写出来的那一段文本**：`degangle(度+分/60+秒/3600)`。
  ///
  ///       - **只有度时逐字节等于老写法**：`30°` 仍然写成 `degangle(30)`——那条路被 `cc6ce91`
  ///         （设备 `d87f1aa3` 验过）钉着，这一轮一个字节都没动它。
  ///       - **算式而不是算好的数**：`1°20′` 写出 `degangle(1+20/60)`，值由求值器按 double
  ///         算出来。写成 `degangle(1.3333333333333333)` 就等于在这一层替用户定精度，
  ///         而且文本会随数字位数变长——这里是**转写**，不是计算。
  ///       - **文本不随角度模式变化**（没有模式参数，也没有 `rad`/`deg` 两个字）：`°` 的值由
  ///         求值器按当前角度单位给（[ExpressionParser.degreeMode]），这一层只写「这些是度数」。
  ///         归一化有七个消费者，它们必须看到同一个字符串——那正是修复轮 8/9 的全部内容，
  ///         也是这条改写沿用 `degangle` 而不是按模式改写文本的原因。
  /// English: **the text normalisation writes**: `degangle(degrees+minutes/60+seconds/3600)`.
  ///
  ///          - **degrees only is byte for byte the old spelling**: `30°` is still written
  ///            `degangle(30)` — `cc6ce91` pins that road (verified on device `d87f1aa3`) and this
  ///            round does not move one byte of it.
  ///          - **an arithmetic expression, not a computed number**: `1°20′` is written
  ///            `degangle(1+20/60)` and the evaluator works out the double. Writing
  ///            `degangle(1.3333333333333333)` would pick a precision here on the user's behalf and
  ///            make the text grow with the digit count — this is a **transcription**, not a
  ///            computation.
  ///          - **the text does not vary with the angle mode** (no mode parameter, no `rad`/`deg`
  ///            words): `°`'s value comes from the evaluator in the current angle unit
  ///            ([ExpressionParser.degreeMode]) and this layer only writes "these are degrees".
  ///            Normalisation has seven consumers and they must see one string — that is the whole
  ///            content of fix rounds 8 and 9, and the reason this rewrite keeps `degangle` rather
  ///            than rewriting the text by mode.
  String get normalizedCall {
    final buffer = StringBuffer('degangle($degrees');
    final minutePart = minutes;
    if (minutePart != null) buffer.write('+$minutePart/60');
    final secondPart = seconds;
    if (secondPart != null) buffer.write('+$secondPart/3600');
    return (buffer..write(')')).toString();
  }
}

/// 中文：从 [index] 起读一个度分秒字面量；那里不是一个字面量时返回 `null`。
///
///       [index] 必须是**度数那一段数字的第一个字符**（不是 `°` 的位置）。数字之前那一个字符
///       不能是名字字符/数字/小数点——与 `°` 那条改写一直以来的 lookbehind 相同，逐字保留。
///
///       读到的区间是 [SexagesimalLiteral.end]（开区间），一路读到最后一个在场的记号为止：
///       `3°30′0″` 覆盖七个字符，`3°30′` 覆盖五个，`3°` 覆盖两个。
/// English: reads a sexagesimal literal starting at [index], or `null` when there is none there.
///
///          [index] must be the **first character of the degrees digits** (not the `°`). The character
///          before those digits may not be a name character, a digit or a dot — the lookbehind the
///          `°` rewrite has always carried, kept verbatim.
///
///          The span runs to [SexagesimalLiteral.end] (exclusive), i.e. through the last mark present:
///          `3°30′0″` covers seven characters, `3°30′` five, `3°` two.
SexagesimalLiteral? readSexagesimalLiteral(String source, int index) {
  if (index < 0 || index >= source.length) return null;
  if (index > 0 && _isWordOrNumberChar(source[index - 1])) return null;
  final degreesEnd = _readNumber(source, index);
  if (degreesEnd == null) return null;
  if (degreesEnd >= source.length ||
      source[degreesEnd] != SexagesimalMarks.degree) {
    return null;
  }
  var cursor = degreesEnd + 1;
  String? minutes;
  String? seconds;
  final firstEnd = _readNumber(source, cursor);
  if (firstEnd != null) {
    final mark = firstEnd < source.length ? source[firstEnd] : '';
    if (mark == SexagesimalMarks.minute) {
      minutes = source.substring(cursor, firstEnd);
      cursor = firstEnd + 1;
      final secondEnd = _readNumber(source, cursor);
      if (secondEnd != null) {
        seconds = source.substring(cursor, secondEnd);
        cursor = secondEnd;
        if (cursor < source.length &&
            source[cursor] == SexagesimalMarks.second) {
          cursor++;
        }
      }
    } else if (mark == SexagesimalMarks.second) {
      seconds = source.substring(cursor, firstEnd);
      cursor = firstEnd + 1;
    } else {
      // 中文：没带记号的尾数读作**分**（文件头那条「中间态」决定的全部内容）。
      // English: an unmarked trailing number reads as **minutes** (the whole of the header's
      //          "intermediate states" decision).
      minutes = source.substring(cursor, firstEnd);
      cursor = firstEnd;
    }
  }
  return SexagesimalLiteral(
    degrees: source.substring(index, degreesEnd),
    minutes: minutes,
    seconds: seconds,
    start: index,
    end: cursor,
  );
}

/// 中文：`NUM` —— `\d+(?:\.\d+)?`，与 `°` 那条改写一直以来的数字形状逐字相同（`_` 分隔符、
///       `e` 指数、`0x` 进制前缀都**不算**：那些形状下这条改写从前的正则也不认它们）。
///       返回数字之后的第一个下标；那里没有数字时返回 `null`。
/// English: `NUM` — `\d+(?:\.\d+)?`, byte for byte the digit shape the `°` rewrite has always used
///          (`_` separators, `e` exponents and `0x` prefixes do **not** count: the old regex did not
///          recognise them either). Returns the index just past the number, or `null` when no number
///          starts there.
int? _readNumber(String source, int index) {
  var cursor = index;
  final digitsStart = cursor;
  while (cursor < source.length && _isAsciiDigit(source[cursor])) {
    cursor++;
  }
  if (cursor == digitsStart) return null;
  if (cursor + 1 < source.length &&
      source[cursor] == '.' &&
      _isAsciiDigit(source[cursor + 1])) {
    cursor++;
    while (cursor < source.length && _isAsciiDigit(source[cursor])) {
      cursor++;
    }
  }
  return cursor;
}

/// 中文：数字之前那个字符的禁入集合，与被替换掉的那条规则里的 `(?<![a-z0-9_.])` 逐字相同——
///       **只排除小写字母**（大写不在里面），这个怪癖是刻意照抄的：它属于已经工作的那条路，
///       这一轮不顺手改它的口径。
/// English: the character before the digits may not be one of these — verbatim the
///          `(?<![a-z0-9_.])` of the rule this replaces, **lower-case letters only** (upper case is
///          not in it). That quirk is copied on purpose: it belongs to a road that already works, and
///          this round does not quietly change its scope.
bool _isWordOrNumberChar(String char) => RegExp(r'[a-z0-9_.]').hasMatch(char);

bool _isAsciiDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}
