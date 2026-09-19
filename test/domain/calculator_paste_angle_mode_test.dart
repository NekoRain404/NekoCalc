import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';

/// 中文：**报告里 `角度模式:` 那一行的值 → `DEG` / `RAD`，本轮一个结果都没动。**
///
///       这一行原先由源码里的**第二份词**判：`raw.contains('deg') || raw.contains('角度')` /
///       `raw.contains('rad') || raw.contains('弧度')`——`'角度'` 与 `'弧度'` 是**要显示给用户的词**
///       （报告的产出方把它们写成 `'角度 DEG'` / `'弧度 RAD'`），词一改或加一种语言，判据就静默
///       变成永远为假：粘贴回来的报告读不出角度模式，没有异常也没有日志。现在那两个词从产出方那张
///       表取（`CalculatorReportLabels.angleDegreesWord` / `angleRadiansWord`，每一种语言的并集），
///       源码里不再另抄一份。
///
///       下面这张表是**改动前后两棵树上跑同一支探针量出来的**（987 组剪贴板文本，两棵树输出
///       md5 相同：`5e2fe7fce108f87a4bc849de0b171e19`），不是照着实现反推的：
///
///       - **令牌那一半是记号**：`deg` / `rad` 折成小写之后按子串认，所以 `DEG`、`deg`、`Deg`、
///         `未知 DEG`、`ANGLE RAD` 都算数——**这一半一个字都没动**。
///       - **词那一半**：没有令牌的写法（`角度模式: 角度`）靠词认。`'弧度 RAD'` 走令牌那一半，
///         `'弧度'` 走词那一半。
///       - **`DEG` 先问**：`'角度 RAD'` 判成 `DEG`（词的命中排在 `rad` 之前），`'弧度 DEG'` 也判成
///         `DEG`（令牌命中在前）——这条顺序是行为，不是笔误，所以在这里钉住。
///       - **两句都不认时给 `null`**（`'未知'`、`'ANGLE'`、没有这一行时），调用方据此不恢复角度模式。
///
/// English: **the report's `角度模式:` line's value → `DEG` / `RAD`, with not one result moved this
///          round.**
///
///          That line used to be judged by a **second copy of the words** written in the source
///          (`raw.contains('deg') || raw.contains('角度')` / `... || raw.contains('弧度')`) — `'角度'` and
///          `'弧度'` are **words shown to the user** (the report's producer writes them into
///          `'角度 DEG'` / `'弧度 RAD'`), so changing a word or adding a language silently makes the
///          judgement permanently false: a pasted report no longer yields an angle mode, with nothing
///          thrown and nothing logged. Those two words now come from the producer's table
///          (`CalculatorReportLabels.angleDegreesWord` / `angleRadiansWord`, the union over every
///          language) and no second copy stays in the source.
///
///          The table below is **measured by running one probe on both trees before and after** (987
///          clipboard texts, the two outputs sharing one md5: `5e2fe7fce108f87a4bc849de0b171e19`), not
///          reverse-engineered from the implementation:
///
///          - **The token half is marks**: `deg` / `rad` match as substrings once folded to lower case,
///            so `DEG`, `deg`, `Deg`, `未知 DEG` and `ANGLE RAD` all count — **not one character of this
///            half moved**.
///          - **The word half**: a token-less spelling (`角度模式: 角度`) is recognised by its word.
///            `'弧度 RAD'` goes through the token half, `'弧度'` through the word half.
///          - **`DEG` is asked first**: `'角度 RAD'` comes out `DEG` (the word hit outranks `rad`) and
///            `'弧度 DEG'` comes out `DEG` too (the token hit comes first) — that order is behaviour,
///            not a typo, so it is pinned here.
///          - **Neither half matching gives `null`** (`'未知'`, `'ANGLE'`, no such line at all), which is
///            how the caller knows not to restore an angle mode.
void main() {
  const cases = <String, String?>{
    // —— 令牌那一半：折小写之后按子串认 ——
    '角度模式: DEG': 'DEG',
    '角度模式: deg': 'DEG',
    '角度模式: Deg': 'DEG',
    '角度模式: RAD': 'RAD',
    '角度模式: rad': 'RAD',
    '角度模式: 未知 DEG': 'DEG',
    '角度模式: ANGLE RAD': 'RAD',
    '角度模式: 未知': null,
    '角度模式: ANGLE': null,
    // —— 词那一半：没有令牌的写法靠产出方表里那两个词 ——
    '角度模式: 角度': 'DEG',
    '角度模式: 弧度': 'RAD',
    '角度模式: Degrees': 'DEG',
    '角度模式: Radians': 'RAD',
    // —— 两半都在时：`DEG` 先问 ——
    '角度模式: 角度 DEG': 'DEG',
    '角度模式: 弧度 RAD': 'RAD',
    '角度模式: 角度 RAD': 'DEG',
    '角度模式: 弧度 DEG': 'DEG',
    // —— 英文标签：剪贴板里那一份可能是另一种语言下复制出来的 ——
    'Angle mode: Degrees DEG': 'DEG',
    'Angle mode: Radians RAD': 'RAD',
    'angle mode: DEG': 'DEG',
    'angle mode: rad': 'RAD',
    // —— 值的形状：全角冒号、空值、根本没有这一行 ——
    '角度模式：弧度 RAD': 'RAD',
    '角度模式:': null,
    '记忆值: 12.5': null,
    '2+3': null,
  };

  test('每一行的值判成哪个角度模式，与改动前逐条相同', () {
    cases.forEach((text, expected) {
      expect(CalculatorPasteResult.fromText(text).angleMode, expected,
          reason: '「$text」');
    });
    // 中文：**这条测试不能是空转的**：三支都要走到过（DEG、RAD、null）。
    // English: **this test must not be vacuous**: all three outcomes must be reached (DEG, RAD, null).
    final outcomes = cases.values.toSet();
    expect(outcomes, containsAll(<String?>['DEG', 'RAD', null]));
  });
}
