import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**`lib/`、`test/`、`android/app/src/` 下任何源码文件都不得超过 800 行。**
///
///       ⚠️ **这条线是用户定的，而它此前只靠人记得。** 本会话我在同一个形状上栽了两次：一次把新测试加进
///       `notes_controller_test.dart`，那个文件被顶到 **817 行**；另一次 `calculator_controller_evaluation.dart`
///       长期停在 **798 行**——离边界只剩两行，**下一笔小改动随时撞上**。两次都是事后才发现的，
///       而"文件多大"这件事根本不需要事后发现。
///
///       体检（2026-10-12）：**没有任何文件越线**，但有 **36 个文件在 700 行以上**，最大的四个是
///       `graph_function_test.dart` 784、`engine_expression.dart` 783、`calculator_controller_persistence.dart`
///       783、`settings_page.dart` 781——压力与越线之间只隔一次小改动。
///
///       **判据故意窄**：只问行数，不问结构。与 `math_reachability_test.dart` 同一句——
///       **窄判据不会误报，而误报的护栏会被关掉，关掉之后就不会有第二次了。**
///
/// English: **no source file under `lib/`, `test/` or `android/app/src/` may exceed 800 lines.**
///
///          ⚠️ **That line is the user's, and until now it lived only in someone's memory.** Two slips of
///          mine this session came from one shape: a new test pushed `notes_controller_test.dart` to **817
///          lines**, and `calculator_controller_evaluation.dart` sat at **798** — two lines from the ceiling,
///          one small change away from crossing it. Both were found **after the fact**; file size is the last
///          thing that needs discovering after the fact.
///
///          Survey, 2026-10-12: **nothing is over the line**, yet **36 files sit above 700 lines**, the four
///          largest being `graph_function_test.dart` 784, `engine_expression.dart` 783,
///          `calculator_controller_persistence.dart` 783 and `settings_page.dart` 781 — one small change
///          between the pressure and the breach.
///
///          **Deliberately narrow**: it asks about line counts only, never about structure. Same sentence as
///          the reachability guard — **a narrow test cannot cry wolf, and a test that cries wolf gets
///          switched off, after which there is no second chance.**
void main() {
  test('800 行这条线：判据在 801 上会响、在 800 上不响', () {
    // 中文：**先证明这条护栏能响。** 边界值取在两处：800 是允许的（"不得超过 800"），801 不允许。
    // English: **first prove the guard can fire.** Both sides of the boundary: 800 is allowed ("must not
    //          exceed 800"), 801 is not.
    final sizes = <String, int>{
      'lib/ok.dart': 800,
      'lib/too_long.dart': 801,
      'test/ok_test.dart': 12,
    };
    expect(overlongFiles(sizes), ['lib/too_long.dart']);
  });

  test('全仓没有源码文件超过 800 行', () {
    final sizes = <String, int>{};
    for (final root in _roots) {
      final dir = Directory(root);
      expect(dir.existsSync(), isTrue, reason: '$root 不在，这条检查的前提就不成立');
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!_counted.any(entity.path.endsWith)) continue;
        sizes[entity.path] = fileLineCount(entity);
      }
    }

    // 中文：**先确认自己真的扫到了东西。** 一个"扫了零个文件"的检查与一个"全都没问题"的检查，
    //       在结果上长得一模一样——这正是 `math_reachability_test.dart` 那条教训的同一种形状。
    // English: **first confirm the walk found anything.** A check that scanned zero files and a check that
    //          found nothing wrong look identical in the result — the same shape as the reachability
    //          guard's own lesson.
    expect(sizes.length, greaterThan(300),
        reason: '扫到的文件太少（${sizes.length}），这条检查多半根本没走对路');

    expect(overlongFiles(sizes), isEmpty,
        reason: '有源码文件超过 800 行——按职责拆开，而不是删掉理由');
  });
}

const _roots = <String>['lib', 'test', 'android/app/src'];
const _counted = <String>['.dart', '.kt', '.java'];

/// 中文：**判据只有这一句**：给定行数表里超过 [limit] 的路径，按路径排序（输出稳定）。
///       提成纯函数，是为了让上面那条边界测试能直接喂它合成数据——**护栏本身也要能被验证**。
/// English: **the judgement is this one sentence**: the paths in the given size table that exceed [limit],
///          sorted so the output is stable. It is a pure function so the boundary test above can feed it
///          synthetic data — **the guard itself has to be verifiable**.
List<String> overlongFiles(Map<String, int> linesByPath, {int limit = 800}) {
  final over = linesByPath.entries
      .where((entry) => entry.value > limit)
      .map((entry) => entry.key)
      .toList()
    ..sort();
  return over;
}

/// 中文：行数的唯一读法，**与 `wc -l` 逐字一致**：只数换行符。这一点不是细节——本项目所有行数声明都是
///       `wc -l` 量的（"817 行"、"798 行"……），如果这里用 `readAsLinesSync().length`，那么一个
///       **末尾没有换行符**的文件就会多算一行，护栏会在一个按本项目口径**合法**的文件上误报。
///       **判据的读数必须与它执行的那条规矩说同一种语言**，否则误报，而误报的护栏会被关掉。
/// English: the single reading of "line count", **byte-for-byte the same as `wc -l`**: newline characters
///          only. That is not a detail — every line count stated in this project was measured with `wc -l`
///          ("817 lines", "798 lines", …), so `readAsLinesSync().length` would count one extra line for a
///          file **without a trailing newline** and fire on a file this project calls legal. **The
///          instrument has to speak the same language as the rule it enforces**, or it cries wolf — and a
///          guard that cries wolf gets switched off.
int fileLineCount(File file) =>
    '\n'.allMatches(file.readAsStringSync()).length;
