import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:uuid/uuid.dart';

import 'disk.dart';

/// Verwaltet die Bilddateien im App-Ordner "fotos".
/// Im Browser (kIsWeb) werden die Bytes als Vorschau im Speicher gehalten.
class FotoStorage {
  static const _ordnerName = 'fotos';

  // Web-Vorschau: dateiname -> Bytes
  static final Map<String, Uint8List> _webBytes = {};

  /// Kopiert ein aufgenommenes/gewähltes Bild in den Foto-Ordner (mobil)
  /// bzw. legt die Bytes im Web-Speicher ab. Liefert den Dateinamen.
  Future<String> importiere(XFile x) async {
    final ext = x.path.contains('.')
        ? x.path.substring(x.path.lastIndexOf('.'))
        : '.jpg';
    final name = '${const Uuid().v4()}$ext';
    if (kIsWeb) {
      _webBytes[name] = await x.readAsBytes();
    } else {
      await Disk.copyFile(_ordnerName, x.path, name);
    }
    return name;
  }

  /// Bytes für ein Foto (Web-Vorschau oder Datei lesen).
  Future<Uint8List?> bytes(String dateiname) async {
    if (kIsWeb) return _webBytes[dateiname];
    return Disk.readBytes(_ordnerName, dateiname);
  }

  Future<void> loesche(String dateiname) async {
    if (kIsWeb) {
      _webBytes.remove(dateiname);
    } else {
      await Disk.deleteFile(_ordnerName, dateiname);
    }
  }
}
