import 'dart:convert';

import 'package:http/http.dart' as http;

/// A GitHub repó, ahol a buildek Release-ként megjelennek.
/// Ha átnevezed a repót, ezt a kettőt kell átírni.
const String kRepoOwner = 'apagyizsolt6-ship-it';
const String kRepoName = 'scorebunker-app';

/// A build száma: a workflow adja át (`--dart-define=BUILD_NUMBER=...`).
/// Helyi futtatásnál 0, ilyenkor nincs frissítés-jelzés.
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

class UpdateInfo {
  final int build;
  final String tag;
  final String pageUrl;
  final String? apkUrl;

  const UpdateInfo({
    required this.build,
    required this.tag,
    required this.pageUrl,
    required this.apkUrl,
  });

  bool get isNewer => kBuildNumber > 0 && build > kBuildNumber;
}

/// A legújabb Release lekérése. Hiba vagy privát repó esetén null.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final res = await http
        .get(
          Uri.parse(
              'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest'),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    if (j is! Map) return null;
    final tag = (j['tag_name'] ?? '').toString();
    final m = RegExp(r'(\d+)').firstMatch(tag);
    final build = int.tryParse(m?.group(1) ?? '');
    if (build == null) return null;
    String? apk;
    final assets = j['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map && (a['name'] ?? '').toString().endsWith('.apk')) {
          apk = a['browser_download_url']?.toString();
          break;
        }
      }
    }
    return UpdateInfo(
      build: build,
      tag: tag,
      pageUrl: (j['html_url'] ?? 'https://github.com/$kRepoOwner/$kRepoName/releases')
          .toString(),
      apkUrl: apk,
    );
  } catch (_) {
    return null;
  }
}
