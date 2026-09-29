part of 'text_tool_controller.dart';

/// 中文：**日期计算工具的算法。** 从 `text_tool_controller.dart` 里那一个 `switch` 进来，
///       形状与其余十八个文本工具一样：吃一个字符串，吐一个 [TextToolOutput]。
///
///       **为什么它不经过引擎。** libqalculate 也能算日期（宿主实测 `"2026-09-20" + 30 days`
///       → `"2026-10-20"`），但那条路要求应用的**解析器先认识带引号的日期字面量**，而
///       `ExpressionParser` 是一个返回 `double` 的递归下降解析器，日期不是它的输出类型。
///       日期加减本来就是一个纯函数，**用 `DateTime` 算比绕一大圈去问引擎更短、更可测**——
///       而且这一段**不依赖引擎，所以单测就能证完**，不必等真机。
///
///       **全部算术走 UTC。** 本地时间在夏令时切换那一天不是 24 小时，`difference().inDays`
///       会在那两天少算一天（南北半球各一次）。取日期时只用年月日、构造 `DateTime.utc`，
///       天数差就永远精确。
/// English: **the date calculator's algorithm.** Entered from the one `switch` in
///          `text_tool_controller.dart`, shaped like the other eighteen text tools: it takes a string
///          and returns a [TextToolOutput].
///
///          **Why it does not go through the engine.** libqalculate can do dates too (measured on the
///          host: `"2026-09-20" + 30 days` → `"2026-10-20"`), but that road requires this app's
///          **parser to accept a quoted date literal first**, and `ExpressionParser` is a
///          recursive-descent parser returning a `double` — a date is not its output type. Date
///          arithmetic is a pure function anyway, so **computing it with `DateTime` is shorter and more
///          testable than routing a long way round to the engine** — and this piece **does not depend on
///          the engine, so unit tests settle it completely**; no device needed.
///
///          **All arithmetic runs in UTC.** A local day is not 24 hours on a daylight-saving switch, and
///          `difference().inDays` loses a day on those two days (one per hemisphere). Reading only the
///          year, month and day and constructing `DateTime.utc` keeps every day count exact.
TextToolOutput _dateCalc(TextToolDateStrings strings, String input, DateTime today) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return TextToolOutput(strings.emptyInput, strings.hint, hasError: true);
  }

  final normalized = _normalizeDateInput(trimmed, today);
  final from = _DateLiteral.today(today);

  // 中文：**先试「两个日期」，再试「一个日期加天数」，最后试「一个日期」。**
  //       顺序有讲究：`2026-01-01 到 2026-09-20` 里那个 `-` 也是日期分隔符，
  //       反过来先试加减就会把第一个日期切碎。
  // English: **two dates first, then a date plus a day count, then a single date.** The order matters:
  //          the `-` inside `2026-01-01 to 2026-09-20` is a date separator too, so trying the shift
  //          first would cut the first date in half.
  final pair = _splitPair(normalized);
  if (pair != null) {
    final left = _DateLiteral.parse(pair.$1);
    final right = _DateLiteral.parse(pair.$2);
    if (left == null || right == null) {
      return TextToolOutput(strings.unrecognized, strings.hint, hasError: true);
    }
    if (!left.isReal || !right.isReal) {
      return TextToolOutput(strings.invalidDate, strings.hint, hasError: true);
    }
    return _between(strings, left, right);
  }

  final shift = _splitShift(normalized);
  if (shift != null) {
    final base = _DateLiteral.parse(shift.$1);
    final days = int.tryParse(shift.$2);
    if (base == null || days == null) {
      return TextToolOutput(strings.unrecognized, strings.hint, hasError: true);
    }
    if (!base.isReal) {
      return TextToolOutput(strings.invalidDate, strings.hint, hasError: true);
    }
    return _shifted(strings, base, days);
  }

  final single = _DateLiteral.parse(normalized);
  if (single != null) {
    if (!single.isReal) {
      return TextToolOutput(strings.invalidDate, strings.hint, hasError: true);
    }
    return _single(strings, single);
  }

  // 中文：`+30` / `-30`：从**今天**起算。`+` 那一支要先判，否则 `-30` 会被上面当成日期。
  // English: `+30` / `-30` counts from **today**.
  final relative = RegExp(r'^([+-])\s*(\d{1,6})$').firstMatch(normalized);
  if (relative != null) {
    final days = int.parse(relative.group(2)!) * (relative.group(1) == '-' ? -1 : 1);
    return _shifted(strings, from, days);
  }

  return TextToolOutput(strings.unrecognized, strings.hint, hasError: true);
}

/// 中文：把一个日期问题切成「两个日期」。分隔符收 `到`/`至`/`to`/`~`/`→`/`->`/`..`/`—`。
/// English: cuts a date question into two dates. Separators: `到`/`至`/`to`/`~`/`→`/`->`/`..`/`—`.
(String, String)? _splitPair(String source) {
  final match = RegExp(r'^(.+?)\s*(?:到|至|to|~|→|->|\.\.|—|–)\s*(.+)$',
          caseSensitive: false)
      .firstMatch(source);
  if (match == null) return null;
  return (match.group(1)!.trim(), match.group(2)!.trim());
}

/// 中文：切成「一个日期 + 天数」。日期在前，加减在后——反过来那个 `+`/`-` 会被吸进日期里。
/// English: cuts into "a date plus a day count". The date comes first; the other way round the
///          `+`/`-` gets swallowed into the date.
(String, String)? _splitShift(String source) {
  final match = RegExp(r'^(\d{4}\s*[-/.年]\s*\d{1,2}\s*[-/.月]\s*\d{1,2}\s*日?)\s*([+-])\s*(\d{1,6})\s*天?$')
      .firstMatch(source);
  if (match == null) return null;
  final sign = match.group(2) == '-' ? '-' : '+';
  return (match.group(1)!.trim(), '$sign${match.group(3)}');
}

/// 中文：`今天` / `today` / `now` 换成**今天那一串**，于是后面三条路都不必再认识它们。
///       替换发生在最前面一次，**没有第二处**。
/// English: `今天` / `today` / `now` are replaced by **today's own string**, so none of the three paths
///          below has to know about them. The substitution happens once, at the front, and nowhere else.
String _normalizeDateInput(String source, DateTime today) {
  final todayText = _DateLiteral.today(today).text;
  return source
      .replaceAll(RegExp(r'\b(?:today|now)\b', caseSensitive: false), todayText)
      .replaceAll('今天', todayText)
      .replaceAll('今日', todayText)
      .trim();
}

TextToolOutput _between(TextToolDateStrings strings, _DateLiteral a, _DateLiteral b) {
  final days = b.utc.difference(a.utc).inDays;
  final abs = days.abs();
  final ordered = days >= 0 ? (a, b) : (b, a);
  final calendar = _calendarGap(ordered.$1, ordered.$2);

  final insights = <String>[
    strings.weekCount(abs ~/ 7, abs % 7),
    strings.monthDayCount(calendar.$1, calendar.$2, calendar.$3),
    strings.labelled(
        strings.dayOfYearLabel,
        strings.arrow(ordered.$2.text, '${ordered.$2.dayOfYear}')),
    strings.labelled(
        strings.weekdayLabel,
        strings.arrow(ordered.$2.text,
            _weekdayName(strings, ordered.$2.utc.weekday))),
  ];

  if (days == 0) {
    return TextToolOutput(
      strings.dayCount(0),
      strings.labelled(strings.between(a.text, b.text), strings.sameDay),
      insights: insights,
    );
  }
  return TextToolOutput(
    strings.dayCount(abs),
    strings.between(ordered.$1.text, ordered.$2.text),
    insights: insights,
  );
}

TextToolOutput _shifted(TextToolDateStrings strings, _DateLiteral base, int days) {
  final result = base.utc.add(Duration(days: days));
  final resultLiteral = _DateLiteral.fromUtc(result);
  return TextToolOutput(
    strings.resultDate(resultLiteral.text),
    strings.shifted(base.text, days),
    insights: <String>[
      strings.labelled(
          strings.weekdayLabel, _weekdayName(strings, result.weekday)),
      strings.labelled(
          strings.dayOfYearLabel, '${resultLiteral.dayOfYear}'),
      strings.labelled(strings.isoWeekLabel, '${resultLiteral.isoWeek}'),
    ],
  );
}

TextToolOutput _single(TextToolDateStrings strings, _DateLiteral date) {
  return TextToolOutput(
    strings.readAsDate(date.text),
    strings.labelled(
        strings.weekdayLabel, _weekdayName(strings, date.utc.weekday)),
    insights: <String>[
      strings.labelled(strings.dayOfYearLabel, '${date.dayOfYear}'),
      strings.labelled(strings.isoWeekLabel, '${date.isoWeek}'),
      strings.labelled(
          strings.leapYearLabel, date.isLeapYear ? strings.yes : strings.no),
    ],
  );
}

/// 中文：**日历差**——「A 到 B 差几年几个月几天」，按人们数日子的方式算，不是把天数除以 30。
///       做法是先把年差推过去，再把月差推过去，余下的才是天。
/// English: **the calendar gap** — "how many years, months and days from A to B", counted the way people
///          count, not by dividing the day total by 30. Push the years across first, then the months;
///          the remainder is days.
(int, int, int) _calendarGap(_DateLiteral a, _DateLiteral b) {
  var years = b.utc.year - a.utc.year;
  var months = b.utc.month - a.utc.month;
  var days = b.utc.day - a.utc.day;

  if (days < 0) {
    months -= 1;
    days += DateTime.utc(b.utc.year, b.utc.month, 0).day;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  return (years, months, days);
}

/// 中文：**星期几的名字从表里取。** 控制器只做下标换算——`DateTime.weekday` 是 1=周一，
///       而表是 0=周一，所以减一。**名字本身一个字节都不在这里。**
/// English: **weekday names come from the table.** The controller does only the index arithmetic —
///          `DateTime.weekday` is 1 = Monday and the table is 0 = Monday, hence the minus one. **Not a
///          byte of the names themselves is here.**
String _weekdayName(TextToolDateStrings strings, int weekday) =>
    strings.weekdayNames[(weekday - 1).clamp(0, 6)];

/// 中文：一个已经校验过的日期字面量。**`utc` 永远是 UTC 零点**——见文件头那条。
/// English: a validated date literal. **`utc` is always UTC midnight** — see the note at the head.
class _DateLiteral {
  const _DateLiteral(this.utc, this.isReal);

  final DateTime utc;
  final bool isReal;

  factory _DateLiteral.today(DateTime now) =>
      _DateLiteral(DateTime.utc(now.year, now.month, now.day), true);

  factory _DateLiteral.fromUtc(DateTime value) =>
      _DateLiteral(DateTime.utc(value.year, value.month, value.day), true);

  /// 中文：**月份与日都不许补零。** `2026-9-2` 与 `2026-09-02` 是同一天，两种写法都收；
  ///       但 `2026-13-01` 与 `2026-02-30` 要挡下来——用的办法是**构造回去再比一次**
  ///       （`DateTime` 会把 2 月 30 日滚到 3 月 2 日，比一下就知道原文不合法）。
  /// English: **neither month nor day needs a leading zero.** `2026-9-2` and `2026-09-02` are the same
  ///          day and both are accepted; `2026-13-01` and `2026-02-30` are not — caught by
  ///          **constructing the date back and comparing** (`DateTime` rolls 30 February into 2 March,
  ///          and the comparison shows the original was not a real day).
  static _DateLiteral? parse(String source) {
    final match = RegExp(r'^(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?$')
        .firstMatch(source.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year < 1 || year > 9999) return null;

    final utc = DateTime.utc(year, month, day);
    final isReal =
        utc.year == year && utc.month == month && utc.day == day;
    return _DateLiteral(utc, isReal);
  }

  /// 中文：**回写成 `YYYY-MM-DD`**——补零，因为这是输出给人看的，不是回显输入。
  /// English: **written back as `YYYY-MM-DD`**, zero-padded, because this is output for a person to read
  ///          rather than an echo of the input.
  String get text =>
      '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';

  int get dayOfYear =>
      utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;

  bool get isLeapYear =>
      DateTime.utc(utc.year, 2, 29).month == 2;

  /// 中文：ISO 8601 周号——**周从星期一开始，且第一周必须含星期四**。
  ///       常见的错法是直接 `dayOfYear / 7`，那会在年初年末各错一周。
  /// English: the ISO 8601 week number — **weeks start on Monday and week 1 is the one holding
  ///          Thursday**. The usual mistake is `dayOfYear / 7`, which is off by one week at both ends of
  ///          the year.
  int get isoWeek {
    final thursday = utc.add(Duration(days: 4 - (utc.weekday)));
    final firstThursday = DateTime.utc(thursday.year, 1, 1)
        .add(Duration(days: (4 - DateTime.utc(thursday.year, 1, 1).weekday + 7) % 7));
    return 1 + thursday.difference(firstThursday).inDays ~/ 7;
  }
}
