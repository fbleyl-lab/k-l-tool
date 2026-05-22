import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Infos zu einem verfügbaren Update.
class UpdateInfo {
  final String version; // z. B. "v1.2.1"
  final String notes;
  final String apkUrl;
  const UpdateInfo(
      {required this.version, required this.notes, required this.apkUrl});
}

/// Ergebnis einer Update-Prüfung – mit Grund, falls nichts angeboten wird.
class PruefErgebnis {
  /// Gesetzt, wenn ein neueres Release vorliegt.
  final UpdateInfo? info;

  /// Gesetzt, wenn die Prüfung fehlschlug (Netzwerk/HTTP/Format).
  final String? fehler;

  /// Aktuell installierte Version (für die Anzeige).
  final String aktuelleVersion;

  const PruefErgebnis(
      {this.info, this.fehler, this.aktuelleVersion = ''});

  bool get hatUpdate => info != null;
}

/// Prüft GitHub-Releases auf eine neuere Version und installiert die APK.
class Updater {
  static const _repo = 'fbleyl-lab/k-l-tool';

  static bool get _moeglich =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sucht nach einem Update. Liefert immer ein [PruefErgebnis]:
  /// - [PruefErgebnis.info] gesetzt → Update vorhanden
  /// - [PruefErgebnis.fehler] gesetzt → Prüfung fehlgeschlagen
  /// - beides null → bereits aktuell
  static Future<PruefErgebnis> pruefe() async {
    String aktuell = '';
    try {
      aktuell = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* egal */}

    if (!_moeglich) return PruefErgebnis(aktuelleVersion: aktuell);

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        // GitHub weist Anfragen OHNE User-Agent mit HTTP 403 ab!
        headers: const {
          'User-Agent': 'KL-Tool-Updater',
          'Accept': 'application/vnd.github+json',
        },
        // Nicht bei 4xx werfen, damit wir den Status melden können.
        validateStatus: (s) => s != null && s < 500,
      ));
      final r = await dio
          .get('https://api.github.com/repos/$_repo/releases/latest');
      if (r.statusCode != 200) {
        return PruefErgebnis(
            aktuelleVersion: aktuell,
            fehler: 'GitHub antwortete mit HTTP ${r.statusCode}.');
      }

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
      if (tag.isEmpty || apkUrl == null || apkUrl.isEmpty) {
        return PruefErgebnis(
            aktuelleVersion: aktuell,
            fehler: 'Kein APK-Download im neuesten Release gefunden.');
      }

      if (!_istNeuer(tag, aktuell)) {
        return PruefErgebnis(aktuelleVersion: aktuell);
      }
      return PruefErgebnis(
        aktuelleVersion: aktuell,
        info: UpdateInfo(version: tag, notes: notes, apkUrl: apkUrl),
      );
    } on DioException catch (e) {
      return PruefErgebnis(
          aktuelleVersion: aktuell,
          fehler: 'Netzwerkproblem (${e.type.name}).');
    } catch (e) {
      return PruefErgebnis(
          aktuelleVersion: aktuell, fehler: 'Fehler: $e');
    }
  }

  /// Lädt die APK herunter und startet die Installation.
  static Future<void> installiere(
    String url, {
    void Function(double fortschritt)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final pfad = '${dir.path}/kl-tool-update.apk';
    final dio = Dio(BaseOptions(
      headers: const {'User-Agent': 'KL-Tool-Updater'},
    ));
    await dio.download(url, pfad, onReceiveProgress: (r, t) {
      if (t > 0 && onProgress != null) onProgress(r / t);
    });
    await OpenFilex.open(pfad);
  }

  /// Vergleicht zwei Versionsstrings (z. B. "v1.2.1" > "1.1.0").
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
