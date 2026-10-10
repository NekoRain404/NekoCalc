import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 中文：更新检查只由设置页的显式用户操作触发。
/// English: Update checks are invoked only by an explicit Settings action.
class GithubReleaseChecker {
  GithubReleaseChecker({ReleaseHttpClient? client})
      : _client = client ?? IoReleaseHttpClient();

  static final releasesUri = Uri.https(
    'api.github.com',
    '/repos/NekoRain404/NekoCalc/releases',
    {'per_page': '30'},
  );
  static const releasesPageUrl =
      'https://github.com/NekoRain404/NekoCalc/releases';
  static const issueCreationUrl =
      'https://github.com/NekoRain404/NekoCalc/issues/new/choose';

  final ReleaseHttpClient _client;

  Future<UpdateCheckResult> check({required String currentVersion}) async {
    final installed = SemanticVersion.tryParse(currentVersion);
    if (installed == null) {
      return const UpdateCheckResult.versionUnreadable();
    }

    try {
      final response = await _client.get(releasesUri);
      if (response.statusCode != HttpStatus.ok) {
        return UpdateCheckResult.httpError(response.statusCode);
      }
      final releases = _decodeReleases(response.body);
      if (releases.isEmpty) {
        return const UpdateCheckResult.noReleasesFound();
      }
      final newest = releases.reduce(
        (current, item) =>
            item.semanticVersion.compareTo(current.semanticVersion) > 0
                ? item
                : current,
      );
      if (newest.semanticVersion.compareTo(installed) > 0) {
        return UpdateCheckResult.updateAvailable(newest);
      }
      return UpdateCheckResult.upToDate(newest);
    } catch (_) {
      return const UpdateCheckResult.networkUnreachable();
    }
  }

  List<AvailableRelease> _decodeReleases(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          if (AvailableRelease.tryParse(Map<String, Object?>.from(item))
              case final release?)
            release,
    ];
  }
}

abstract interface class ReleaseHttpClient {
  Future<ReleaseHttpResponse> get(Uri uri);
}

class ReleaseHttpResponse {
  const ReleaseHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class IoReleaseHttpClient implements ReleaseHttpClient {
  IoReleaseHttpClient({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  @override
  Future<ReleaseHttpResponse> get(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers
          .set(HttpHeaders.userAgentHeader, 'NekoCalc update checker');
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      return ReleaseHttpResponse(statusCode: response.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }
}

enum UpdateCheckStatus { updateAvailable, upToDate, unavailable }

/// 中文：**一次更新检查是哪一种结局——它既是判据，也是呈现层取那句话用的令牌。**
///
///       六格与 `SettingsStrings` 里的六格一一对应（`updateAvailable` / `updateUpToDate` /
///       `updateVersionUnreadable` / `updateHttpError` / `updateNoReleasesFound` /
///       `updateNetworkUnreachable`），由 `settings/presentation/update_check_message.dart` 的
///       `updateCheckMessage(result, strings)` 那个穷尽 `switch` 接上；版本号与 HTTP 状态码是
///       **载荷**，留在结果上由呈现层拼进句子。
///
///       **这六格从前是在这里拼的句子**（`UpdateCheckResult.message`，由设置页的「检查更新」对话框
///       直接印）：结果对象从检查器活到对话框，界面那张按语言切的文案表够不着它，所以英文界面下它
///       照样是中文——`docs/verification.md` §5i 记着这条层次性缺陷。这一格比
///       [UpdateCheckStatus] 细：那是**行为**判据（按钮印「查看发布」「查看发布说明」还是
///       「打开发布页」），`unavailable` 一格在那边合着四种原因，这一边分开了。
///
///       **六格互斥**：`updateAvailable` 与 `upToDate` 由「线上最新版比本机新没有」分开；
///       `versionUnreadable` 是入口处本机版本号解析失败，与网络那几步无关（不可能走到后面的分支）；
///       `httpError`、`noReleasesFound` 与 `networkUnreachable` 三段同在 `try` 里，但一个对应
///       非 200 的响应、一个对应 200 但一个可用版本都没有、一个只在抛异常时才写，三者的条件
///       互不重叠。**`status` 是派生出来的**（下面那个穷尽 `switch`），不是第二个字段，所以
///       「令牌说 A、按钮却是 B」没有落点。
/// English: **which outcome one update check reached — a verdict, and the token the presentation layer
///          resolves the sentence with.**
///
///          The six values correspond one for one with six cells in `SettingsStrings`
///          (`updateAvailable` / `updateUpToDate` / `updateVersionUnreadable` / `updateHttpError` /
///          `updateNoReleasesFound` / `updateNetworkUnreachable`), wired up by the exhaustive `switch`
///          in `updateCheckMessage(result, strings)` under `settings/presentation/`. The version
///          number and the HTTP status code are **payload** and stay on the result for the presentation
///          layer to splice into the sentence.
///
///          **These six used to be sentences composed right here** (`UpdateCheckResult.message`, printed
///          straight by the settings page's "Check for updates" dialog): the result travels from the
///          checker to the dialog and outlives the UI, so a language-keyed interface table could not
///          reach it and an English interface still printed Chinese — the layering defect recorded in
///          `docs/verification.md` §5i. This value is finer than [UpdateCheckStatus]: that one is the
///          **behaviour** verdict (whether the button reads "View release", "View release notes" or
///          "Open releases page") and folds four of these reasons into its `unavailable`, while this one
///          keeps them apart.
///
///          **The six are mutually exclusive**: `updateAvailable` against `upToDate` is "is the newest
///          published version ahead of this build"; `versionUnreadable` is the local version string
///          failing to parse at the door and has nothing to do with the network steps (it cannot reach
///          the branches below); `httpError`, `noReleasesFound` and `networkUnreachable` live inside the
///          same `try`, but one is a non-200 response, one is a 200 carrying no usable release, and one
///          is only written from the catch — their conditions never overlap. **`status` is derived**
///          (the exhaustive `switch` below), not a second field, so "the token says A while the button
///          says B" has nowhere to land.
enum UpdateCheckOutcome {
  updateAvailable,
  upToDate,
  versionUnreadable,
  httpError,
  noReleasesFound,
  networkUnreachable,
}

class UpdateCheckResult {
  /// 中文：**无名构造是私有的**：`httpError` 要求一个状态码、两个「有发布版本」的结局要求一个
  ///       `AvailableRelease`，而呈现层读载荷时用的是 `!`（见 `update_check_message.dart`）。
  ///       公开的无名构造会留下「令牌说 httpError、状态码却是 null」这样的路，同
  ///       `CalculatorSubmitResult` 那条理由。
  /// English: **the unnamed constructor is private**: `httpError` requires a status code and the two
  ///          "a release exists" outcomes require an `AvailableRelease`, while the presentation layer
  ///          reads those payloads with `!` (see `update_check_message.dart`). A public unnamed
  ///          constructor would leave roads like "the token says httpError while the status code is
  ///          null" — the same reasoning as `CalculatorSubmitResult`.
  const UpdateCheckResult._({
    required this.outcome,
    this.release,
    this.httpStatusCode,
  });

  UpdateCheckResult.updateAvailable(AvailableRelease release)
      : this._(
          outcome: UpdateCheckOutcome.updateAvailable,
          release: release,
        );

  const UpdateCheckResult.upToDate(AvailableRelease release)
      : this._(
          outcome: UpdateCheckOutcome.upToDate,
          release: release,
        );

  const UpdateCheckResult.versionUnreadable()
      : this._(outcome: UpdateCheckOutcome.versionUnreadable);

  const UpdateCheckResult.httpError(int statusCode)
      : this._(
          outcome: UpdateCheckOutcome.httpError,
          httpStatusCode: statusCode,
        );

  const UpdateCheckResult.noReleasesFound()
      : this._(outcome: UpdateCheckOutcome.noReleasesFound);

  const UpdateCheckResult.networkUnreachable()
      : this._(outcome: UpdateCheckOutcome.networkUnreachable);

  final UpdateCheckOutcome outcome;
  final AvailableRelease? release;

  /// 中文：`httpError` 的载荷：GitHub 回的那个状态码。
  /// English: the payload of `httpError`: the status code GitHub answered with.
  final int? httpStatusCode;

  /// 中文：**行为判据**（对话框按钮与图标按它取），由 [outcome] 派生——见 [UpdateCheckOutcome] 上
  ///       那段「令牌比状态细」的说明。
  /// English: the **behaviour verdict** (the dialog picks its button and icon from it), derived from
  ///          [outcome] — see the "the token is finer than the status" note on [UpdateCheckOutcome].
  UpdateCheckStatus get status => switch (outcome) {
        UpdateCheckOutcome.updateAvailable => UpdateCheckStatus.updateAvailable,
        UpdateCheckOutcome.upToDate => UpdateCheckStatus.upToDate,
        UpdateCheckOutcome.versionUnreadable ||
        UpdateCheckOutcome.httpError ||
        UpdateCheckOutcome.noReleasesFound ||
        UpdateCheckOutcome.networkUnreachable =>
          UpdateCheckStatus.unavailable,
      };
}

class AvailableRelease {
  const AvailableRelease._({
    required this.version,
    required this.url,
    required this.semanticVersion,
  });

  final String version;
  final String url;
  final SemanticVersion semanticVersion;

  static AvailableRelease? tryParse(Map<String, Object?> json) {
    if (json['draft'] == true) return null;
    final version = json['tag_name']?.toString().trim();
    final url = json['html_url']?.toString().trim();
    if (version == null || version.isEmpty || url == null || url.isEmpty) {
      return null;
    }
    final semanticVersion = SemanticVersion.tryParse(version);
    if (semanticVersion == null) return null;
    return AvailableRelease._(
      version: version,
      url: url,
      semanticVersion: semanticVersion,
    );
  }
}

/// A SemVer 2.0 precedence value. Build metadata is intentionally ignored.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion._(this.major, this.minor, this.patch, this.preRelease);

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z.-]+)?$',
  );
  static final _numericIdentifier = RegExp(r'^\d+$');

  final int major;
  final int minor;
  final int patch;
  final List<String>? preRelease;

  static SemanticVersion? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    final preRelease = match.group(4)?.split('.');
    return SemanticVersion._(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      preRelease,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final difference = pair.$1.compareTo(pair.$2);
      if (difference != 0) return difference;
    }
    final left = preRelease;
    final right = other.preRelease;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final comparison = _compareIdentifier(left[index], right[index]);
      if (comparison != 0) return comparison;
    }
    return left.length.compareTo(right.length);
  }

  static int _compareIdentifier(String left, String right) {
    final leftNumeric = _numericIdentifier.hasMatch(left);
    final rightNumeric = _numericIdentifier.hasMatch(right);
    if (leftNumeric && rightNumeric) {
      return int.parse(left).compareTo(int.parse(right));
    }
    if (leftNumeric != rightNumeric) return leftNumeric ? -1 : 1;
    return left.compareTo(right);
  }
}
