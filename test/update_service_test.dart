import 'dart:convert';

import 'package:emo/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String releaseBody({String tag = 'v1.2.0', bool withApk = true}) => jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/galaxymushi/emo/releases/tag/$tag',
      'body': 'What changed in $tag',
      'assets': [
        if (withApk)
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/galaxymushi/emo/releases/download/$tag/app-release.apk',
          },
        {'name': 'notes.txt', 'browser_download_url': 'https://example.com/n.txt'},
      ],
    });

void main() {
  test('returns a newer release with its APK link', () async {
    final service = UpdateService(
      client: MockClient((request) async {
        expect(request.url.path, '/repos/galaxymushi/emo/releases/latest');
        return http.Response(releaseBody(), 200);
      }),
    );

    final info = await service.check('1.1.3');

    expect(info?.version, '1.2.0');
    expect(info?.apkUrl, endsWith('app-release.apk'));
    expect(info?.notes, contains('What changed'));
  });

  test('ignores the version that is already installed', () async {
    final service = UpdateService(
      client: MockClient((_) async => http.Response(releaseBody(tag: 'v1.1.3'), 200)),
    );

    expect(await service.check('1.1.3'), isNull);
  });

  test('falls back to the release page when no APK asset exists', () async {
    final service = UpdateService(
      client: MockClient(
        (_) async => http.Response(releaseBody(withApk: false), 200),
      ),
    );

    final info = await service.check('1.1.3');

    expect(info?.apkUrl, contains('/releases/tag/v1.2.0'));
  });

  test('returns null when GitHub rejects the request', () async {
    final service = UpdateService(
      client: MockClient((_) async => http.Response('{}', 403)),
    );

    expect(await service.check('1.1.3'), isNull);
  });

  test('compares dotted versions numerically', () {
    expect(UpdateService.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
    expect(UpdateService.compareVersions('1.1.3', '1.2.0'), lessThan(0));
    expect(UpdateService.compareVersions('v1.2.0', '1.1.9'), greaterThan(0));
  });
}
