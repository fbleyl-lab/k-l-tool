import 'dart:typed_data';

/// Web-Stub (kein dart:io). Wird zur Laufzeit nicht aufgerufen, weil die
/// Storages im Browser auf In-Memory umschalten – existiert nur fürs Kompilieren.
class Disk {
  static Future<List<String>> readAllJson(String folder) async => const [];
  static Future<void> writeJson(String folder, String id, String json) async {}
  static Future<void> deleteJson(String folder, String id) async {}
  static Future<void> copyFile(
      String folder, String srcPath, String zielName) async {}
  static Future<Uint8List?> readBytes(String folder, String name) async => null;
  static Future<void> deleteFile(String folder, String name) async {}
}
