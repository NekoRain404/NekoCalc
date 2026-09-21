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
      return const UpdateCheckResult.unavailable('当前版本号无法识别。');
    }

    try {
      final response = await _client.get(releasesUri);
      if (response.statusCode != HttpStatus.ok) {
        return UpdateCheckResult.unavailable(
          'GitHub 返回了 HTTP ${response.statusCode}，请稍后再试。',
        );
      }
      final releases = _decodeReleases(response.body);
      if (releases.isEmpty) {
        return const UpdateCheckResult.unavailable('未找到可用的公开发布版本。');
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
      return const UpdateCheckResult.unavailable('无法连接 GitHub，请检查网络后重试。');
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

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    required this.message,
    this.release,
  });

  UpdateCheckResult.updateAvailable(AvailableRelease release)
      : this._(
          status: UpdateCheckStatus.updateAvailable,
          message: '发现新版本 ${release.version}。',
          release: release,
        );

  const UpdateCheckResult.upToDate(AvailableRelease release)
      : this._(
          status: UpdateCheckStatus.upToDate,
          message: '当前已是最新版本。',
          release: release,
        );

  const UpdateCheckResult.unavailable(String message)
      : this._(status: UpdateCheckStatus.unavailable, message: message);

  final UpdateCheckStatus status;
  final String message;
  final AvailableRelease? release;
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
