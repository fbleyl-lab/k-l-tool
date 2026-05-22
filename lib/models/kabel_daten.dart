// Datenbasis für die Kabelquerschnitt-Auslegung.
//
// Quelle: DIN VDE 0298-4, Tabelle 3 (Umgebungstemperatur 25 °C, deutsche
// Praxis), Kupfer, PVC-Isolierung (70 °C), 3 belastete Adern.
// Werte je Verlegeart: Iz = Strombelastbarkeit [A], In = max. zulässiger
// Bemessungsstrom der Überstrom-Schutzeinrichtung [A] (Leitungsschutz).
// (Wiedergegeben nach ABB-Referenz 2CDC401002D0106 / DIN VDE 0298-4.)
//
// Hinweis: In Gebäudeinstallationen ist die Betriebstemperatur auf 70 °C
// begrenzt (Klemmen/Geräte), daher gelten die PVC-Werte auch für höher
// temperaturfeste Leitungen. XLPE-Tabelle wird ergänzt.

enum Leiter { cu, al }

extension LeiterInfo on Leiter {
  String get label => this == Leiter.cu ? 'Kupfer (Cu)' : 'Aluminium (Al)';
  double get kappa => this == Leiter.cu ? 56 : 35; // m/(Ω·mm²) für Spannungsfall
}

class KabelWert {
  final double iz; // Strombelastbarkeit [A]
  final int inMax; // max. zulässige Sicherung [A]
  const KabelWert(this.iz, this.inMax);
}

class Verlegeart {
  final String code;
  final String beschreibung;
  const Verlegeart(this.code, this.beschreibung);
}

class KabelDaten {
  // --- Kupfer: NYM-Gebäudeinstallation (DIN VDE 0298-4 Tab. 3) ---
  // sowie NYY-Erdverlegung (DIN VDE 0276-603).
  static const List<Verlegeart> verlegeartenCu = [
    Verlegeart('A1', 'Adern im Rohr in wärmegedämmter Wand'),
    Verlegeart('A2', 'Mehraderleitung im Rohr in wärmegedämmter Wand'),
    Verlegeart('B1', 'Adern im Rohr/Kanal auf/in Wand'),
    Verlegeart('B2', 'Mehraderleitung im Rohr/Kanal auf/in Wand'),
    Verlegeart('C', 'Leitung direkt auf/in Wand'),
    Verlegeart('E', 'Frei in Luft / Pritsche / Zugschacht'),
    Verlegeart('Erde', 'Kabel in Erde (NYY)'),
  ];

  // --- Aluminium: NAYY-Starkstromkabel, DIN VDE 0276-603 ---
  static const List<Verlegeart> verlegeartenAl = [
    Verlegeart('Erde', 'Kabel in Erde (NAYY)'),
    Verlegeart('Luft', 'Kabel in Luft (NAYY)'),
  ];

  static List<Verlegeart> verlegearten(Leiter l) =>
      l == Leiter.cu ? verlegeartenCu : verlegeartenAl;

  // Gemeinsame Querschnittsreihe für Kupfer (Gebäudearten bis 50 mm²,
  // Erdverlegung bis 240 mm²).
  static const List<double> _querschnitteCu = [
    1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240,
  ];
  static const List<double> _querschnitteAl = [
    25, 35, 50, 70, 95, 120, 150, 185, 240,
  ];

  static List<double> querschnitteFuer(Leiter l) =>
      l == Leiter.cu ? _querschnitteCu : _querschnitteAl;

  /// Gängige Sicherungs-Nennströme (LS/gG).
  static const List<int> sicherungen = [
    6, 10, 13, 16, 20, 25, 32, 35, 40, 50, 63, 80, 100, 125, 160,
  ];

  // Tabelle 3 (25 °C, Cu, PVC, 3 belastete Adern): Werte je Verlegeart
  // in der Reihenfolge von [querschnitte] (1,5 … 50 mm²).
  static const Map<String, List<KabelWert>> _pvc = {
    'A1': [
      KabelWert(14.5, 13), KabelWert(19, 16), KabelWert(25, 25),
      KabelWert(33, 32), KabelWert(45, 40), KabelWert(59, 50),
      KabelWert(77, 63), KabelWert(94, 80), KabelWert(114, 100),
    ],
    'A2': [
      KabelWert(14, 13), KabelWert(18.5, 16), KabelWert(24, 20),
      KabelWert(31, 25), KabelWert(41, 40), KabelWert(55, 50),
      KabelWert(72, 63), KabelWert(88, 80), KabelWert(105, 100),
    ],
    'B1': [
      KabelWert(16.5, 16), KabelWert(22, 20), KabelWert(30, 25),
      KabelWert(38, 35), KabelWert(53, 50), KabelWert(72, 63),
      KabelWert(94, 80), KabelWert(117, 100), KabelWert(142, 125),
    ],
    'B2': [
      KabelWert(16, 16), KabelWert(21, 20), KabelWert(29, 25),
      KabelWert(36, 35), KabelWert(50, 50), KabelWert(66, 63),
      KabelWert(85, 80), KabelWert(105, 100), KabelWert(125, 125),
    ],
    'C': [
      KabelWert(18.5, 16), KabelWert(25, 25), KabelWert(35, 35),
      KabelWert(43, 40), KabelWert(63, 63), KabelWert(81, 80),
      KabelWert(102, 100), KabelWert(126, 125), KabelWert(153, 125),
    ],
    'E': [
      KabelWert(19.5, 16), KabelWert(27, 25), KabelWert(36, 35),
      KabelWert(46, 40), KabelWert(64, 63), KabelWert(85, 80),
      KabelWert(107, 100), KabelWert(134, 125), KabelWert(162, 160),
    ],
  };

  // Kupfer NYY in Erde, 3 belastete Adern, Iz [A] (DIN VDE 0276-603),
  // in Reihenfolge von _querschnitteCu (1,5 … 240 mm²).
  static const List<double> _cuErdeIz = [
    27, 36, 47, 59, 79, 102, 133, 159, 188, 232, 280, 318, 359, 406, 473,
  ];

  // Aluminium NAYY, 3 belastete Adern, Iz [A] (DIN VDE 0276-603),
  // in Reihenfolge von _querschnitteAl (25 … 240 mm²).
  static const Map<String, List<double>> _alIz = {
    'Erde': [102, 123, 144, 179, 215, 245, 275, 313, 364],
    'Luft': [82, 100, 119, 152, 186, 216, 246, 285, 338],
  };

  /// Größte gängige Sicherung ≤ Iz (Schutzbedingung In ≤ Iz).
  static int _sicherungUnter(double iz) {
    int s = sicherungen.first;
    for (final x in sicherungen) {
      if (x <= iz) s = x;
    }
    return s;
  }

  static KabelWert? wert(Leiter leiter, String verlegeart, double querschnitt) {
    if (leiter == Leiter.cu) {
      final i = _querschnitteCu.indexOf(querschnitt);
      if (i < 0) return null;
      if (verlegeart == 'Erde') {
        if (i >= _cuErdeIz.length) return null;
        final iz = _cuErdeIz[i];
        return KabelWert(iz, _sicherungUnter(iz));
      }
      final liste = _pvc[verlegeart];
      if (liste == null || i >= liste.length) return null;
      return liste[i];
    } else {
      final liste = _alIz[verlegeart];
      final i = _querschnitteAl.indexOf(querschnitt);
      if (liste == null || i < 0 || i >= liste.length) return null;
      final iz = liste[i];
      return KabelWert(iz, _sicherungUnter(iz));
    }
  }

  /// Nächstgrößere gängige Sicherung ≥ Strom.
  static int? sicherungFuer(double strom) {
    for (final s in sicherungen) {
      if (s >= strom) return s;
    }
    return null;
  }
}
