/// Ein Foto mit Bemerkung. Das Bild liegt als Datei im App-Ordner "fotos";
/// hier wird nur der Dateiname referenziert (klein im JSON-Backup).
class Foto {
  String dateiname; // z.B. "a1b2c3.jpg" im fotos-Ordner
  String bemerkung;

  Foto({required this.dateiname, this.bemerkung = ''});

  Map<String, dynamic> toJson() => {
        'dateiname': dateiname,
        'bemerkung': bemerkung,
      };

  factory Foto.fromJson(Map<String, dynamic> j) => Foto(
        dateiname: j['dateiname'] ?? '',
        bemerkung: j['bemerkung'] ?? '',
      );
}
