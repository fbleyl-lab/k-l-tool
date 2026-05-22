import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/protokoll.dart';
import 'disk.dart';

/// Lokale Persistenz der Protokolle als JSON-Dateien im App-Dokumentordner.
/// Im Browser (kIsWeb) wird ein In-Memory-Speicher als Vorschau-Fallback genutzt.
class ProtokollStorage {
  static const _ordnerName = 'protokolle';

  // In-Memory-Fallback für Web-Vorschau (id -> JSON).
  static final Map<String, String> _webStore = {};

  /// Alle Protokolle laden, neueste zuerst.
  Future<List<Protokoll>> ladeAlle() async {
    final list = <Protokoll>[];
    final inhalte =
        kIsWeb ? _webStore.values.toList() : await Disk.readAllJson(_ordnerName);
    for (final s in inhalte) {
      try {
        list.add(Protokoll.fromJson(jsonDecode(s)));
      } catch (_) {
        // beschädigte Daten überspringen
      }
    }
    list.sort((a, b) => b.geaendertAm.compareTo(a.geaendertAm));
    return list;
  }

  Future<void> speichere(Protokoll p) async {
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
  String exportJson(Protokoll p) =>
      const JsonEncoder.withIndent('  ').convert(p.toJson());

  /// Importiert ein Protokoll aus JSON-String.
  Protokoll importJson(String content) =>
      Protokoll.fromJson(jsonDecode(content));
}
