import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Infos zu einem verfügbaren Update.
class UpdateInfo {
  final String version; // z. B. "v1.1.0"
  final String notes;
  final String apkUrl;
  const UpdateInfo(
      {required this.version, required this.notes, required this.apkUrl});
}

/// Prüft GitHub-Releases auf eine neuere Version und installiert die APK.
class Updater {
  static const _repo = 'fbleyl-lab/k-l-tool';

  static bool get _moeglich =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sucht nach einem Update. Liefert null, wenn keins vorliegt
  /// (oder Plattform nicht Android).
  static Future<UpdateInfo?> pruefe() async {
    if (!_moeglich) return null;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final r = await dio
          .get('https://api.github.com/repos/$_repo/releases/latest');
      final data = r.data as Map;
      final tag = (data['tag_name'] ?? '').toString();
      final notes = (data['body'] ?? '').toString();
      final assets = (data['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = (a['browser_download_url'] ?? '').toString();
          break;
        }
      }
      if (tag.isEmpty || apkUrl == null || apkUrl.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      if (!_istNeuer(tag, info.version)) return null;
      return UpdateInfo(version: tag, notes: notes, apkUrl: apkUrl);
    } catch (_) {
      return null; // offline o. Ä. -> kein Update anbieten
    }
  }

  /// Lädt die APK herunter und startet die Installation.
  static Future<void> installiere(
    String url, {
    void Function(double fortschritt)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final pfad = '${dir.path}/kl-tool-update.apk';
    final dio = Dio();
    await dio.download(url, pfad, onReceiveProgress: (r, t) {
      if (t > 0 && onProgress != null) onProgress(r / t);
    });
    await OpenFilex.open(pfad);
  }

  /// Vergleicht zwei Versionsstrings (z. B. "v1.1.0" > "1.0.0").
  static bool _istNeuer(String neu, String aktuell) {
    List<int> teile(String s) => s
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final a = teile(neu);
    final b = teile(aktuell);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
