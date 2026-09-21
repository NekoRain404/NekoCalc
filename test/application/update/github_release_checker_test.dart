import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/update/github_release_checker.dart';

void main() {
  test('reports the newest prerelease-aware GitHub release as available',
      () async {
    final client = _FakeReleaseHttpClient(
      200,
      jsonEncode([
        {
          'tag_name': 'v1.2.0-beta.2',
          'html_url':
              'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.2.0-beta.2',
          'prerelease': true,
          'draft': false,
        },
        {
          'tag_name': 'v1.1.9',
          'html_url':
              'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.1.9',
          'prerelease': false,
          'draft': false,
        },
      ]),
    );

    final result = await GithubReleaseChecker(client: client)
        .check(currentVersion: 'v1.2.0-beta.1');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.release?.version, 'v1.2.0-beta.2');
    expect(result.release?.url,
        'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.2.0-beta.2');
    expect(client.requestedUri.path, '/repos/NekoRain404/NekoCalc/releases');
  });

  test('treats a stable release as newer than a matching prerelease', () async {
    final client = _FakeReleaseHttpClient(
      200,
      jsonEncode([
        {
          'tag_name': 'v1.2.0',
          'html_url': 'https://example.test/v1.2.0',
          'prerelease': false,
          'draft': false,
        },
      ]),
    );

    final result = await GithubReleaseChecker(client: client)
        .check(currentVersion: '1.2.0-beta.9+2009');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.release?.version, 'v1.2.0');
  });

  test('does not offer draft or malformed releases', () async {
    final client = _FakeReleaseHttpClient(
      200,
      jsonEncode([
        {
          'tag_name': 'next',
          'html_url': 'https://example.test/next',
          'draft': false,
        },
        {
          'tag_name': 'v9.0.0',
          'html_url': 'https://example.test/draft',
          'draft': true,
        },
        {
          'tag_name': 'v1.2.0-beta.1',
          'html_url': 'https://example.test/current',
          'draft': false,
        },
      ]),
    );

    final result = await GithubReleaseChecker(client: client)
        .check(currentVersion: 'v1.2.0-beta.1');

    expect(result.status, UpdateCheckStatus.upToDate);
    expect(result.release?.version, 'v1.2.0-beta.1');
  });

  test('returns an unavailable result when GitHub cannot be reached', () async {
    final checker = GithubReleaseChecker(client: _ThrowingReleaseHttpClient());

    final result = await checker.check(currentVersion: 'v1.2.0-beta.1');

    expect(result.status, UpdateCheckStatus.unavailable);
    expect(result.release, isNull);
  });
}

class _FakeReleaseHttpClient implements ReleaseHttpClient {
  _FakeReleaseHttpClient(this.statusCode, this.body);

  final int statusCode;
  final String body;
  late Uri requestedUri;

  @override
  Future<ReleaseHttpResponse> get(Uri uri) async {
    requestedUri = uri;
    return ReleaseHttpResponse(statusCode: statusCode, body: body);
  }
}

class _ThrowingReleaseHttpClient implements ReleaseHttpClient {
  @override
  Future<ReleaseHttpResponse> get(Uri uri) async => throw Exception('offline');
}
