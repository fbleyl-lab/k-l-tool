import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/aufmass.dart';
import 'disk.dart';

/// Lokale Persistenz der Aufmaß-Listen als JSON-Dateien.
/// Im Browser (kIsWeb) In-Memory-Fallback für die Vorschau.
class AufmassStorage {
  static const _ordnerName = 'aufmass';

  static final Map<String, String> _webStore = {};

  Future<List<Aufmass>> ladeAlle() async {
    final list = <Aufmass>[];
    final inhalte =
        kIsWeb ? _webStore.values.toList() : await Disk.readAllJson(_ordnerName);
    for (final s in inhalte) {
      try {
        list.add(Aufmass.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    list.sort((a, b) => b.geaendertAm.compareTo(a.geaendertAm));
    return list;
  }

  Future<void> speichere(Aufmass a) async {
    a.geaendertAm = DateTime.now();
    final json = const JsonEncoder.withIndent('  ').convert(a.toJson());
    if (kIsWeb) {
      _webStore[a.id] = json;
    } else {
      await Disk.writeJson(_ordnerName, a.id, json);
    }
  }

  Future<void> loesche(String id) async {
    if (kIsWeb) {
      _webStore.remove(id);
    } else {
      await Disk.deleteJson(_ordnerName, id);
    }
  }
}
