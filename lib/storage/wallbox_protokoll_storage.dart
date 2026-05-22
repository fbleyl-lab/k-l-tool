import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/wallbox_protokoll.dart';
import 'disk.dart';

/// Lokale Persistenz der Wallbox-Protokolle als JSON-Dateien im App-Ordner.
/// Im Browser (kIsWeb) dient ein In-Memory-Speicher als Vorschau-Fallback.
class WallboxProtokollStorage {
  static const _ordnerName = 'wallbox_protokolle';

  static final Map<String, String> _webStore = {};

  /// Alle Protokolle laden, neueste zuerst.
  Future<List<WallboxProtokoll>> ladeAlle() async {
    final list = <WallboxProtokoll>[];
    final inhalte =
        kIsWeb ? _webStore.values.toList() : await Disk.readAllJson(_ordnerName);
    for (final s in inhalte) {
      try {
        list.add(WallboxProtokoll.fromJson(jsonDecode(s)));
      } catch (_) {
        // beschädigte Daten überspringen
      }
    }
    list.sort((a, b) => b.geaendertAm.compareTo(a.geaendertAm));
    return list;
  }

  Future<void> speichere(WallboxProtokoll p) async {
    p.geaendertAm = DateTime.now();
    final json = const JsonEncoder.withIndent('  ').convert(p.toJson());
    if (kIsWeb) {
      _webStore[p.id] = json;
    } else {
      await Disk.writeJson(_ordnerName, p.id, json);
    }
  }

  Future<void> loesche(String id) async {
    if (kIsWeb) {
      _webStore.remove(id);
    } else {
      await Disk.deleteJson(_ordnerName, id);
    }
  }

  /// Exportiert ein Protokoll als JSON-String (für Backup/Teilen).
  String exportJson(WallboxProtokoll p) =>
      const JsonEncoder.withIndent('  ').convert(p.toJson());

  /// Importiert ein Protokoll aus JSON-String.
  WallboxProtokoll importJson(String content) =>
      WallboxProtokoll.fromJson(jsonDecode(content));
}
