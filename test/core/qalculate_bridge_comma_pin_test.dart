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
    final bridge = File(
      'android/app/src/main/kotlin/com/nekorain/nekocalc/qalculate/QalculateEngine.kt',
    );
    expect(bridge.existsSync(), isTrue,
        reason: '找不到原生桥文件，这条守卫就失去意义：${bridge.path}');
    final source = bridge.readAsStringSync();

    expect(source, contains('parse_options.setComma_as_separator(false)'),
        reason: 'libqalculate 的 ParseOptions::ParseOptions() 没有初始化 comma_as_separator'
            '（Calculator.cc:103），不显式钉住它，那个字节就是未初始化内存，'
            '用户写的逗号会被 unlocalizeExpression 当千分位删掉 → 多实参表达式的静默错值');

    // 中文：这一行必须与角度单位那一段在同一个 `evaluationOptions` 里——分开写会让「每个
    //       ParseOptions 都被钉过」这件事变成看图说话。
    // English: the line has to live in the same `evaluationOptions` as the angle unit; keeping the
    //          two apart would turn "every ParseOptions is pinned" into a matter of opinion.
    expect(source, contains('parse_options.setAngle_unit(angleUnit)'));
    expect(
      source.indexOf('parse_options.setComma_as_separator(false)'),
      greaterThan(source.indexOf('private fun evaluationOptions(')),
      reason: '钉住的那一行必须在 evaluationOptions 里（每个 ParseOptions 都经过它）',
    );
  });
}
