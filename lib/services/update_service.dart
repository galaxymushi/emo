import 'dart:convert';

import 'package:http/http.dart' as http;

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseUrl,
    required this.notes,
  });

  final String version;
  final String apkUrl;
  final String releaseUrl;
  final String notes;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const repository = 'galaxymushi/emo';
  static const _latestUrl =
      'https://api.github.com/repos/galaxymushi/emo/releases/latest';

  /// Returns the newest release when it is newer than [currentVersion].
  Future<UpdateInfo?> check(String currentVersion) async {
    final response = await _client.get(
      Uri.parse(_latestUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Emo-Android',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final tag = decoded['tag_name'];
    if (tag is! String) return null;
    final version = tag.replaceFirst(RegExp(r'^[vV]'), '').trim();
    if (version.isEmpty || compareVersions(version, currentVersion) <= 0) {
      return null;
    }

    var apkUrl = '';
    final assets = decoded['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.apk')) continue;
        apkUrl = asset['browser_download_url'] as String? ?? '';
        if (apkUrl.isNotEmpty) break;
      }
    }
    final releaseUrl = decoded['html_url'] as String? ?? '';
    final notes = (decoded['body'] as String? ?? '').trim();
    return UpdateInfo(
      version: version,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : releaseUrl,
      releaseUrl: releaseUrl,
      notes: notes.length > 500 ? notes.substring(0, 500) : notes,
    );
  }

  static int compareVersions(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final core = version.split('+').first;
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  void close() => _client.close();
}
