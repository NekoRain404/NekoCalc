import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/update/github_release_checker.dart';
import 'package:nekocalc/features/settings/presentation/settings_strings.dart';
import 'package:nekocalc/features/settings/presentation/update_check_message.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次检查更新是哪种结局」与「对话框里那句话」分家之后，两边都还对得上。**
///
///       `UpdateCheckResult` 原先自己拼那六句话并直接上屏（设置页「检查更新」对话框印
///       `result.message`），于是英文界面下印的仍是中文——结果对象从检查器活到对话框，界面那张按
///       语言切的表够不着它（`docs/verification.md` §5i）。这一轮把那六句话移进 `SettingsStrings`，
///       检查器只留令牌（[UpdateCheckOutcome] 六格），由 `updateCheckMessage` 在呈现边缘取。这份
///       测试是那次改动的锁，四段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[legacySentences]）：六个结局逐条渲染，中文侧必须与迁移前
///          源码里那句话**逐字节相同**；两个方向都查（枚举里每一格都有对照表条目，对照表里每一条
///          都命中一个真的枚举值）。这就是「产出方漏写令牌」与「令牌多出来」的唯一防线——两样都
///          不会抛，只会静默少一句或错一句。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含宽/全角
///          字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **判据没变**：`status`（对话框按钮与图标按它取）由 [UpdateCheckOutcome] 派生，六个
///          结局到三档状态的映射逐格钉住——`unavailable` 那一档合着四种原因，迁移前后一致。
///       4. **源码里那句话只有一份**：`github_release_checker.dart` 里**一个宽/全角字面量都不许
///          有**（这个文件能整份扫：六句话全搬走了，留下的是 URL、请求头、JSON 键与正则，都是
///          ASCII），且迁移前那六句句子连同带载荷的半句一个字都不许留。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：那张对照表就是迁移前
///       `github_release_checker.dart` 里那几条 `UpdateCheckResult.unavailable('…')` 与两条完整
///       构造的抄本，故意写死在测试里。**不要拿它去追新文案。**
/// English: **once "which outcome this update check reached" has parted from "the sentence in the
///          dialog", the two still line up.**
///
///          `UpdateCheckResult` used to compose those six sentences itself and print them straight (the
///          settings page's "Check for updates" dialog printed `result.message`), so an English
///          interface still printed Chinese — the result travels from the checker to the dialog and
///          outlives the UI, so a language-keyed interface table could not reach it
///          (`docs/verification.md` §5i). This round moved those six sentences into `SettingsStrings`,
///          leaving the checker with only the token ([UpdateCheckOutcome], six values), resolved at the
///          presentation edge by `updateCheckMessage`. This test is that change's lock, in four parts:
///
///          1. **Token and sentence correspond one to one** ([legacySentences]): all six outcomes
///             rendered, the Chinese side **byte-identical** to the sentence in the source before the
///             change, checked in both directions (every enum value has a table entry, every table entry
///             hits a real enum value). This is the only defence against "a producer forgot the token"
///             and "a token appeared from nowhere" — neither throws, they only silently drop or swap a
///             sentence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language).
///          3. **The verdicts have not moved**: `status` (the dialog picks its button and icon from it)
///             is derived from [UpdateCheckOutcome]; the six-to-three mapping is pinned cell by cell —
///             the `unavailable` level folds four of the reasons, exactly as it did before the move.
///          4. **The sentence exists once in the source**: `github_release_checker.dart` must hold
///             **not one wide/fullwidth literal** (the whole file can be swept: all six sentences moved
///             out, and what stays — URLs, request headers, JSON keys, a regex — is ASCII), and the six
///             pre-move sentences, together with the payload-carrying halves, must not survive.
///
///          **The byte-identity is measured, not asserted**: the table is a copy of those
///          `UpdateCheckResult.unavailable('…')` calls and the two full constructions in
///          `github_release_checker.dart` before the change, deliberately written out in the test.
///          **Do not bring it up to date with new copy.**
void main() {
  final zh = SettingsStrings.forLanguage(AppLanguage.zh);
  final en = SettingsStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那六句话本身**（结局 → 它从前印什么）。这张表**故意写在测试里**、不从
  ///       `SettingsStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**。载荷取固定值
  ///       （版本号 `v1.2.0`、状态码 503），句子里的其余部分因此逐字节可比。**不要拿它去追新文案。**
  /// English: **the six sentences from before the change** (outcome → what it used to print). This table
  ///          is **deliberately written in the test** rather than generated from `SettingsStrings`: its
  ///          whole value is being **a copy of the old knowledge**. The payloads take one fixed set
  ///          (version `v1.2.0`, status code 503), so the rest of the sentence is byte-comparable.
  ///          **Do not bring it up to date with new copy.**
  const legacySentences = <UpdateCheckOutcome, String>{
    UpdateCheckOutcome.updateAvailable: '发现新版本 v1.2.0。',
    UpdateCheckOutcome.upToDate: '当前已是最新版本。',
    UpdateCheckOutcome.versionUnreadable: '当前版本号无法识别。',
    UpdateCheckOutcome.httpError: 'GitHub 返回了 HTTP 503，请稍后再试。',
    UpdateCheckOutcome.noReleasesFound: '未找到可用的公开发布版本。',
    UpdateCheckOutcome.networkUnreachable: '无法连接 GitHub，请检查网络后重试。',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacySentences.entries) {
      expect(updateCheckMessage(_resultFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的回执与迁移前那句话不同了');
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目（漏了就是"令牌多出来"），对照表里每一条
    //       都要命中一个真的枚举值（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** Every enum value needs a table entry (a missing one means "a token
    //          appeared from nowhere"), and every table entry has to hit a real enum value (an extra one
    //          means "the token was deleted, the copy stayed").
    expect(legacySentences.keys.toSet(), UpdateCheckOutcome.values.toSet(),
        reason: '令牌与旧文案对照表对不上：'
            '${legacySentences.keys.toSet().difference(UpdateCheckOutcome.values.toSet())}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：版本号与状态码是调用方递进来的数据、本来就跟着调用方的语言，所以
    //       这里量的是**句子**那一层，不是载荷那一层。六种结局都过一遍。
    // English: **the payloads are ASCII here**: the version number and the status code are data handed
    //          in by the caller and already follow the caller's language, so what is measured here is
    //          the **sentence** layer, not the payload layer. All six outcomes go through.
    final results = [
      for (final outcome in UpdateCheckOutcome.values) _resultFor(outcome),
    ];
    for (final result in results) {
      final rendered = updateCheckMessage(result, en);
      expect(containsWideOrFullwidth(rendered), isFalse,
          reason: '${result.outcome.name} 的英文回执里还有宽/全角字符：$rendered');
      expect(rendered, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：六句里没有一句与中文那份相同。
    // English: **the English table is not the Chinese one copied twice**: not one of the six equals its
    //          Chinese counterpart.
    for (final result in results) {
      expect(updateCheckMessage(result, en), isNot(updateCheckMessage(result, zh)),
          reason: '${result.outcome.name} 在两种语言下印同一句话');
    }
  });

  test('载荷真的拼进句子：换一个版本号、换一个状态码，句子就跟着换', () {
    // 中文：载荷不是装饰：同一个令牌换一个版本号 / 状态码，句子里那半截必须跟着换；载荷原样留在
    //       结果上（呈现层读它用的是 `!`，由命名构造保证非空）。
    // English: the payload is not decoration: the same token with a different version number or status
    //          code has to move that half of the sentence; the payload stays on the result as-is (the
    //          presentation layer reads it with `!`, and the named constructors guarantee it is there).
    final available = UpdateCheckResult.updateAvailable(_release('v9.9.9'));
    expect(available.release!.version, 'v9.9.9');
    expect(updateCheckMessage(available, zh), '发现新版本 v9.9.9。');
    expect(updateCheckMessage(available, en), 'Version v9.9.9 is available.');

    const httpError = UpdateCheckResult.httpError(418);
    expect(httpError.httpStatusCode, 418);
    expect(updateCheckMessage(httpError, zh), 'GitHub 返回了 HTTP 418，请稍后再试。');

    final upToDate = UpdateCheckResult.upToDate(_release('v1.2.0'));
    expect(upToDate.release!.version, 'v1.2.0');
    expect(updateCheckMessage(upToDate, zh), '当前已是最新版本。');
  });

  test('结局那三档行为判据没有跟着文案一起动', () {
    // 中文：**`status` 是派生的**，不是第二个字段：六个结局到三档状态（对话框按它选按钮与图标）
    //       的映射逐格钉住，`unavailable` 那一档合着四种原因——迁移前后一致。
    // English: **`status` is derived**, not a second field: the mapping from the six outcomes to the
    //          three statuses (the dialog picks its button and icon from them) is pinned cell by cell,
    //          with `unavailable` folding four of the reasons — the same before and after the move.
    const expectedStatuses = <UpdateCheckOutcome, UpdateCheckStatus>{
      UpdateCheckOutcome.updateAvailable: UpdateCheckStatus.updateAvailable,
      UpdateCheckOutcome.upToDate: UpdateCheckStatus.upToDate,
      UpdateCheckOutcome.versionUnreadable: UpdateCheckStatus.unavailable,
      UpdateCheckOutcome.httpError: UpdateCheckStatus.unavailable,
      UpdateCheckOutcome.noReleasesFound: UpdateCheckStatus.unavailable,
      UpdateCheckOutcome.networkUnreachable: UpdateCheckStatus.unavailable,
    };
    expect(expectedStatuses.keys.toSet(), UpdateCheckOutcome.values.toSet(),
        reason: '状态映射表与令牌枚举对不上');
    for (final outcome in UpdateCheckOutcome.values) {
      expect(_resultFor(outcome).status, expectedStatuses[outcome],
          reason: '${outcome.name} 的行为状态与迁移前不同了');
    }
  });

  test('源码里那句话只有一份：检查器文件里一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这个文件里有没有给人看的字"**，不是"有没有整句相同"：六句话已经全搬进
    //       `SettingsStrings`，这个文件里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来
    //       （或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与计算器、工具、笔记、设置页
    //       那几条护栏**同一把**（`containsWideOrFullwidth`）。
    //
    //       **这个文件能整份扫**（别的路径要按段扫是因为界外文案还在）：搬走之后留下的是
    //       `api.github.com` 这类 URL、请求头、JSON 键与一个 SemVer 正则，都是 ASCII 记号。
    //       两条底线的第二条：迁移前那六句句子**一个字都不许留**，带载荷的两句连**半句**
    //       （前缀）一起查，免得模板被抄回来。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": all six sentences have moved into `SettingsStrings`, so any
    //          wide/fullwidth literal reappearing here means somebody copied copy back (or wrote a new
    //          sentence), and the copy will not follow the language. The ruler is **the same one** as
    //          the calculator, tools, notes and settings-page guards (`containsWideOrFullwidth`).
    //
    //          **This whole file can be swept** (other paths are measured stretch by stretch because
    //          out-of-scope copy remains there): what stays after the move is URLs such as
    //          `api.github.com`, request headers, JSON keys and a SemVer regex — all ASCII notation.
    //          The second floor: the six pre-move sentences must **not survive** by one word, and the
    //          two payload-carrying ones are checked by their **halves** (prefixes) as well, so a
    //          template copied back cannot slip through.
    final file = File('lib/application/update/github_release_checker.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final source = stripComments(file.readAsStringSync());

    final offenders =
        stringLiterals(source).where(containsWideOrFullwidth).toList();
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 SettingsStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');

    for (final sentence in legacySentences.values) {
      expect(source.contains(sentence), isFalse,
          reason: '检查器文件里还留着旧句子：$sentence');
    }
    const legacyFragments = <String>[
      '发现新版本 ',
      'GitHub 返回了 HTTP ',
    ];
    for (final fragment in legacyFragments) {
      expect(source.contains(fragment), isFalse,
          reason: '检查器文件里还留着旧句子的半截：$fragment');
    }
  });
}

/// 中文：对照表里的固定载荷。渲染前需要一个具体的 [UpdateCheckResult]，`status` 那两个结局还要
///       一个 [AvailableRelease]——它的构造是私有的，所以从 [AvailableRelease.tryParse] 这条公开
///       的路进来（与检查器自己解码发布时走的是同一条路）。
/// English: the fixed payloads of the legacy table. Rendering needs a concrete [UpdateCheckResult], and
///          the two "a release exists" outcomes need an [AvailableRelease] — its constructor is private,
///          so the way in is the public [AvailableRelease.tryParse] (the same road the checker itself
///          takes when it decodes a release).
UpdateCheckResult _resultFor(UpdateCheckOutcome outcome) {
  return switch (outcome) {
    UpdateCheckOutcome.updateAvailable =>
      UpdateCheckResult.updateAvailable(_release('v1.2.0')),
    UpdateCheckOutcome.upToDate =>
      UpdateCheckResult.upToDate(_release('v1.2.0')),
    UpdateCheckOutcome.versionUnreadable =>
      const UpdateCheckResult.versionUnreadable(),
    UpdateCheckOutcome.httpError => const UpdateCheckResult.httpError(503),
    UpdateCheckOutcome.noReleasesFound =>
      const UpdateCheckResult.noReleasesFound(),
    UpdateCheckOutcome.networkUnreachable =>
      const UpdateCheckResult.networkUnreachable(),
  };
}

AvailableRelease _release(String version) {
  final release = AvailableRelease.tryParse({
    'tag_name': version,
    'html_url': 'https://example.test/releases/$version',
  });
  return release!;
}
