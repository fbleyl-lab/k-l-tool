import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Native Dateizugriffe (Mobil/Desktop). Wird über disk.dart eingebunden.
class Disk {
  static Future<Directory> _dir(String folder) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Inhalte aller *.json-Dateien im Ordner.
  static Future<List<String>> readAllJson(String folder) async {
    final dir = await _dir(folder);
    final out = <String>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          out.add(await e.readAsString());
        } catch (_) {}
      }
    }
    return out;
  }

  static Future<void> writeJson(String folder, String id, String json) async {
    final dir = await _dir(folder);
    await File('${dir.path}/$id.json').writeAsString(json);
  }

  static Future<void> deleteJson(String folder, String id) async {
    final dir = await _dir(folder);
    final f = File('${dir.path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  /// Kopiert ein Bild in den Ordner unter dem Zielnamen.
  static Future<void> copyFile(
      String folder, String srcPath, String zielName) async {
    final dir = await _dir(folder);
    await File(srcPath).copy('${dir.path}/$zielName');
  }

  static Future<Uint8List?> readBytes(String folder, String name) async {
    final dir = await _dir(folder);
    final f = File('${dir.path}/$name');
    if (await f.exists()) return f.readAsBytes();
    return null;
  }

  static Future<void> deleteFile(String folder, String name) async {
    final dir = await _dir(folder);
    final f = File('${dir.path}/$name');
    if (await f.exists()) await f.delete();
  }
}
