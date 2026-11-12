import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Letölti az APK-t az app saját mappájába. A haladást 0..1 között jelzi.
/// Hiba esetén null.
Future<String?> downloadApk(
  String url,
  void Function(double progress) onProgress,
) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url));
    final res = await client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/apiscores-update.apk');
    if (await file.exists()) await file.delete();

    final sink = file.openWrite();
    final total = res.contentLength ?? 0;
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
    return file.path;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Megnyitja az Android csomagtelepítőt a letöltött APK-val.
Future<bool> openInstaller(String path) async {
  try {
    final r = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    return r.type == ResultType.done;
  } catch (_) {
    return false;
  }
}
