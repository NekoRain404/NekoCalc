import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**源码级守卫**——原生桥必须显式把 `comma_as_separator` 钉成 `false`。
///
///       它守的是一个**真机实测过的缺陷**：libqalculate 的 `ParseOptions::ParseOptions()`
///       （`Calculator.cc:103`）的初始化列表里漏了 `comma_as_separator`，于是每个 `ParseOptions`
///       的那一个字节是**未初始化内存**，而它决定 `Calculator::unlocalizeExpression` 会不会把用户
///       写的逗号当千分位**删掉**（`Calculator-parse.cc:1373-1383`）。真机上 `matrix(2,2,1,2,3,4)`
///       曾被解析成 `matrix(221234)`（一个参数、五位数字），引擎随即报「至少需要 3 个参数」——
///       而 `nCr`/`nPr`/`root`/`gcd` 这些**已经上线**的多实参键走的是同一条路，用户拿到的是静默的错值。
///       钉住之后同一串调用返回 `[1  2; 3  4]`。
///
///       **这条测试能证明什么、不能证明什么**（写清楚，免得被当成行为测试）：
///
///       - 能：那一行被删掉时它**变红**（这正是它存在的理由——那个缺陷唯一的现状守卫就是这行代码）。
///       - 不能：它不验证运行时行为。行为在 libqalculate 里，而 `flutter test` 跑在宿主 x86_64 上，
///         AAR 里只有 arm64-v8a 的 `.so`，装不进这个进程；宿主即使装了同版本的 libqalculate，
///         那也不是这个项目的依赖（CI 上没有）。所以**行为证据是真机日志**，见
///         `.superpowers/backup/qalculate-step5-fix2-report.md`。
/// English: **A source-level guard** — the native bridge must pin `comma_as_separator` to `false`
///          explicitly.
///
///          What it guards is a **device-measured defect**: libqalculate's
///          `ParseOptions::ParseOptions()` (`Calculator.cc:103`) omits `comma_as_separator` from its
///          initializer list, so that one byte of every `ParseOptions` is **uninitialized memory** —
///          and it decides whether `Calculator::unlocalizeExpression` treats the user's commas as
///          digit separators and **deletes** them (`Calculator-parse.cc:1373-1383`). On a device
///          `matrix(2,2,1,2,3,4)` was parsed as `matrix(221234)` (one argument, five digits) and the
///          engine reported "needs at least 3 arguments" — and the already-shipped multi-argument keys
///          (`nCr`, `nPr`, `root`, `gcd`) travel the same path, handing the user a silently wrong
///          value. With the pin the same call returns `[1  2; 3  4]`.
///
///          **What this test does and does not prove** (spelled out so it cannot be mistaken for a
///          behavioural test):
///
///          - it does: turn red when that line is deleted, which is the whole point — that one line is
///            the only standing guard over this defect;
///          - it does not: verify runtime behaviour. That behaviour lives in libqalculate, and
///            `flutter test` runs on the host x86_64 while the AAR ships arm64-v8a `.so` files only,
///            so they cannot be loaded into this process; and even where the same library version is
///            installed on the host, it is not a dependency of this project (CI does not have it).
///            The behavioural evidence is therefore the device log, recorded in
///            `.superpowers/backup/qalculate-step5-fix2-report.md`.
void main() {
  test('原生桥显式钉住 comma_as_separator=false（源码级守卫）', () {
    // 中文：**扫整个目录，不写死文件名**。这一条曾经写死 `QalculateEngine.kt`，而 2026-09-18 的
    //       拆分把 `evaluationOptions` 连同 pin 一起搬到了 `QalculateOptions.kt`——**守卫当场变红，
    //       而拆分本身是纯净的搬移**。写死文件名会让「代码搬到哪」变成「守卫失不失效」，
    //       那不是它该守的东西。它要守的是「这一行**存在，且在正确的函数体里**」。
    // English: **scan the directory rather than naming one file.** This used to hard-code
    //          `QalculateEngine.kt`, and the 2026-09-18 split moved `evaluationOptions` — and the pin
    //          with it — into `QalculateOptions.kt`, turning the guard red for a change that was a
    //          pure move. Naming a file makes "where the code lives" into "whether the guard holds",
    //          which is not what this guards. What it guards is that the line **exists, and sits in
    //          the right function body**.
    final dir = Directory(
      'android/app/src/main/kotlin/com/nekorain/nekocalc/qalculate',
    );
    expect(dir.existsSync(), isTrue, reason: '找不到原生桥目录，这条守卫就失去意义：${dir.path}');
    final sources = <String, String>{
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.kt')) f.path: f.readAsStringSync(),
    };
    expect(sources, isNotEmpty, reason: '目录里一个 .kt 都没有：${dir.path}');

    final withPin = sources.entries
        .where((e) =>
            e.value.contains('parse_options.setComma_as_separator(false)'))
        .toList();
    expect(withPin, hasLength(1),
        reason:
            'libqalculate 的 ParseOptions::ParseOptions() 没有初始化 comma_as_separator'
            '（Calculator.cc:103），不显式钉住一次——且只钉一次——那个字节就是未初始化内存，'
            '用户写的逗号会被 unlocalizeExpression 当千分位删掉 → 多实参表达式的静默错值。'
            '实际命中的文件：${withPin.map((e) => e.key).toList()}');

    // 中文：这一行必须与角度单位那一段在同一个 `evaluationOptions` 里——分开写会让「每个
    //       ParseOptions 都被钉过」这件事变成看图说话。
    // English: the line has to live in the same `evaluationOptions` as the angle unit; keeping the
    //          two apart would turn "every ParseOptions is pinned" into a matter of opinion.
    final withOptions = sources.entries
        .where(
            (e) => e.value.contains('parse_options.setAngle_unit(angleUnit)'))
        .toList();
    expect(withOptions, hasLength(1),
        reason: '角度单位必须恰好在一处设置；实际：${withOptions.map((e) => e.key).toList()}');
    expect(withOptions.single.key, withPin.single.key,
        reason: '角度单位与 comma pin 必须在同一个文件里（它们同属 evaluationOptions）');

    // 中文：不绑死可见性修饰符——`private` 在单文件里成立，跨文件必须放宽成 `internal`，
    //       而**那不是这条守卫该管的事**。只要求 `evaluationOptions` 这个函数存在。
    // English: do not bind to the visibility modifier — `private` works within one file and has to
    //          relax to `internal` across files, and **that is not this guard's business**. Require
    //          only that the function exists.
    expect(
      bodyOf(withPin.single.value, 'fun evaluationOptions('),
      contains('parse_options.setComma_as_separator(false)'),
      reason: '钉住的那一行必须在 evaluationOptions 的**函数体**里'
          '（每个 ParseOptions 都经过它；挪到别处就不再钉住任何东西）',
    );
  });
}

/// 中文：`header` 那个声明的**函数体**原文——从它之后的第一个 `{` 到与之配对的那个 `}`。
///
///       这条曾经写成「pin 的下标大于函数头的下标」，那个断言**没有作用域**：把那一行挪到后面
///       任何一个函数里（例如 `drainMessages`）它照样通过。要真的钉住作用域，就得把花括号配平。
/// English: the **body** of the declaration at `header` — from the first `{` after it to the matching
///          `}`.
///
///          This used to be "the pin's index is greater than the header's index", which has **no
///          scope**: moving the line into any later function (say `drainMessages`) kept it green.
///          Pinning the scope for real means balancing the braces.
String bodyOf(String source, String header) {
  final start = source.indexOf(header);
  expect(start, isNot(-1), reason: '找不到声明：$header');
  final open = source.indexOf('{', start);
  expect(open, isNot(-1), reason: '声明后面没有函数体：$header');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  fail('花括号没有配平：$header');
}
