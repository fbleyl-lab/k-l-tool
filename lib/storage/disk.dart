// Plattform-Weiche für Dateizugriffe: native (dart:io) auf Mobil/Desktop,
// Stub im Browser (dort wird stattdessen In-Memory genutzt; siehe Storages).
export 'disk_io.dart' if (dart.library.html) 'disk_web.dart';
