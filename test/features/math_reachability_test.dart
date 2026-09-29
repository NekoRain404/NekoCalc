import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**`lib/core/math/` 下每一个文件都必须有调用方。**
///
///       ⚠️ **这条护栏是被我自己的一次错误逼出来的。** 本会话我在同一个形状上栽了**四次**：
///
///       1. 拿 `qalc`（CLI）当 libqalculate（库）；
///       2. 登记脚本在更早的一条 `assert` 上中止了，我当成"后面都跑了"；
///       3. 没读 `docs/release_checklist.md` 就下结论说"本仓没有发布流程"；
///       4. **`str.replace` 找不到锚点时一声不响，我当成"改上了"**（一条测试因此没被加进去）。
///
///       **四次的共同点：一个"什么都没做"的动作，与一个"做了但没用"的动作，
///       在结果上长得一模一样。**
///
///       而其中第 2、4 次的具体形态是**写好一个纯函数就忘了接出去**——
///       `arithmetic_steps.dart` 就这样放了一整轮，`convertToBase`、`toRoman`、`derive_steps`
///       各手写了一遍 `grep` 才发现。**手写的检查会忘；护栏不会。**
///
///       所以它从脚本（`tool/check_math_reachability.py`）搬到了这里：
///       **脚本要人去跑，而这条每次 `flutter test` 都会跑。**
///       （一份判据只留一个拼法——搬过来就把脚本删了。）
///
///       **判据故意窄：只查文件名有没有被提到。** 语义级的可达性分析是另一个量级的东西，
///       而这里要挡的**只有一种错**：新文件写完之后没有任何地方提到它。
///       **窄判据不会误报，而误报的护栏会被关掉——关掉之后就再也不会有第二次了。**
/// English: **every file under `lib/core/math/` must have a caller.**
///
///          ⚠️ **This guard exists because of a mistake of mine.** Four times in one session I failed the
///          same way (see the list above): **the common shape is that "did nothing" and "did it, and it had
///          no effect" look identical in the result.** Two of those four had the concrete form **write a
///          pure function, then forget to wire it up** — `arithmetic_steps.dart` sat unreachable for a
///          whole round after `convertToBase`, `toRoman` and `derive_steps` each needed a hand-written
///          grep. **A hand-written check gets forgotten; a guard does not.**
///
///          So it moved here from a script (`tool/check_math_reachability.py`): **a script needs someone to
///          run it, while this runs on every `flutter test`.** (One judgement, one spelling — the script was
///          deleted when this landed.)
///
///          **The test is deliberately narrow: it only asks whether the file name is mentioned.** Semantic
///          reachability analysis is a different order of thing, and the one error to stop here is **a new
///          file that nothing mentions at all**. **A narrow test cannot cry wolf, and a test that cries wolf
///          gets switched off — after which there is no second chance.**
void main() {
  test('lib/core/math 下每个文件都有调用方：写好纯函数忘了接出去，这里会红', () {
    final math = Directory('lib/core/math');
    expect(math.existsSync(), isTrue, reason: '目录都不在，这条测试的前提就不成立');

    // 中文：**只扫两个消费方目录**——`lib/core/math` 自己内部的互相引用不算"接出去了"。
    // English: **only the two consumer directories are scanned** — references *within* `lib/core/math`
    //          do not count as "wired up".
    final consumers = <String>[];
    for (final base in <String>['lib/application', 'lib/features']) {
      for (final entity in Directory(base).listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          consumers.add(entity.readAsStringSync());
        }
      }
    }
    final haystack = consumers.join('\n');

    final unreachable = <String>[];
    for (final entity in math.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：`part of` 的文件不是独立的库（它们由宿主文件被引用），跳过。
      // English: a `part of` file is not a library of its own (its host file carries the reference).
      if (RegExp(r'^\s*part of ', multiLine: true)
          .hasMatch(entity.readAsStringSync())) {
        continue;
      }
      if (!haystack.contains(name)) unreachable.add(name);
    }

    expect(unreachable, isEmpty,
        reason: '这些文件在 lib/application 与 lib/features 里没有任何引用——'
            '写好纯函数之后忘了接出去，是本项目反复踩的一类（见本文件头）：\n'
            '${unreachable.join('\n')}');
  });
}
