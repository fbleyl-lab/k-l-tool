// Tabelle 6 "Kurzschlussstrom-Mindestanzeigewerte" aus dem Handbuch der
// Serie PROFITEST MASTER (GMC-I Messtechnik / Gossen Metrawatt),
// für Netze mit Nennspannung UN = 230 V.
//
// Je Schutzorgan und Nennstrom gibt es zwei Werte:
//  - grenzwert   = Abschaltstrom Ia (normativer erforderlicher Kurzschlussstrom)
//  - minAnzeige  = Mindest-Anzeigewert inkl. Betriebsmessunsicherheit des Geräts
//                  (der Wert, den das PROFITEST als erforderlichen IK anzeigt)
//
// Auslösefaktoren: B/E = 5×In, C = 10×In, D = 20×In, K = 12×In.
// gG (gL/gM) sind nicht über einen Faktor berechenbar, sondern aus der
// Sicherungskennlinie tabelliert — getrennt für Abschaltzeit 5 s und 0,4 s.

enum Schutzart { b, c, d, k, gg, mss }

extension SchutzartLabel on Schutzart {
  String get label {
    switch (this) {
      case Schutzart.b:
        return 'B';
      case Schutzart.c:
        return 'C';
      case Schutzart.d:
        return 'D';
      case Schutzart.k:
        return 'K';
      case Schutzart.gg:
        return 'gG';
      case Schutzart.mss:
        return 'MSS';
    }
  }

  static Schutzart fromLabel(String s) {
    switch (s) {
      case 'C':
        return Schutzart.c;
      case 'D':
        return Schutzart.d;
      case 'K':
        return Schutzart.k;
      case 'gG':
        return Schutzart.gg;
      case 'MSS':
        return Schutzart.mss;
      default:
        return Schutzart.b;
    }
  }
}

/// Abschaltzeit für gG-Schmelzsicherungen (bestimmt die Tabellenspalte).
enum Abschaltzeit { s04, s5 }

extension AbschaltzeitLabel on Abschaltzeit {
  String get label => this == Abschaltzeit.s04 ? '0,4 s' : '5 s';
}

/// Ein Wertepaar aus der Tabelle.
class IkWert {
  final double grenzwert; // Ia
  final double minAnzeige; // inkl. Messunsicherheit
  const IkWert(this.grenzwert, this.minAnzeige);
}

class Tabelle6 {
  /// Nennströme, für die LS-Schalter (B/C/D/K) tabelliert sind.
  static const List<int> nennstroemeLs = [
    2, 3, 4, 6, 8, 10, 13, 16, 20, 25, 32, 35, 40, 50, 63,
  ];

  /// Nennströme für gG (bis 630 A). Bis 160 A liegen Tabellenwerte vor
  /// (PROFITEST-Tabelle 6); für 200–630 A gibt es keinen Gossen-Tabellenwert
  /// → "Erforderlicher IK" wird dort manuell eingetragen.
  static const List<int> nennstroemeGg = [
    2, 3, 4, 6, 8, 10, 13, 16, 20, 25, 32, 35, 40, 50, 63, //
    80, 100, 125, 160, 200, 250, 315, 400, 500, 630,
  ];

  // gG, Abschaltzeit 5 s: In -> (Grenzwert, Min. Anzeige)
  static const Map<int, IkWert> _gg5s = {
    2: IkWert(9.2, 10),
    3: IkWert(14.1, 15),
    4: IkWert(19, 20),
    6: IkWert(27, 28),
    8: IkWert(37, 39),
    10: IkWert(47, 50),
    13: IkWert(56, 59),
    16: IkWert(65, 69),
    20: IkWert(85, 90),
    25: IkWert(110, 117),
    32: IkWert(150, 161),
    35: IkWert(173, 186),
    40: IkWert(190, 205),
    50: IkWert(260, 297),
    63: IkWert(320, 369),
    80: IkWert(440, 517),
    100: IkWert(580, 675),
    125: IkWert(750, 889),
    160: IkWert(930, 1120),
  };

  // gG, Abschaltzeit 0,4 s
  static const Map<int, IkWert> _gg04s = {
    2: IkWert(16, 17),
    3: IkWert(24, 25),
    4: IkWert(32, 34),
    6: IkWert(47, 50),
    8: IkWert(65, 69),
    10: IkWert(82, 87),
    13: IkWert(98, 104),
    16: IkWert(107, 114),
    20: IkWert(145, 155),
    25: IkWert(180, 194),
    32: IkWert(265, 303),
    35: IkWert(295, 339),
    40: IkWert(310, 357),
    50: IkWert(460, 529),
    63: IkWert(550, 639),
    80: IkWert(960, 1160),
    100: IkWert(1200, 1490),
    125: IkWert(1440, 1840),
    160: IkWert(1920, 2590),
  };

  // Charakteristik B/E (5×In)
  static const Map<int, IkWert> _b = {
    2: IkWert(10, 11),
    3: IkWert(15, 16),
    4: IkWert(20, 21),
    6: IkWert(30, 32),
    8: IkWert(40, 42),
    10: IkWert(50, 53),
    13: IkWert(65, 69),
    16: IkWert(80, 85),
    20: IkWert(100, 106),
    25: IkWert(125, 134),
    32: IkWert(160, 172),
    35: IkWert(175, 188),
    40: IkWert(200, 216),
    50: IkWert(250, 285),
    63: IkWert(315, 363),
  };

  // Charakteristik C (10×In)
  static const Map<int, IkWert> _c = {
    2: IkWert(20, 21),
    3: IkWert(30, 32),
    4: IkWert(40, 42),
    6: IkWert(60, 64),
    8: IkWert(80, 85),
    10: IkWert(100, 106),
    13: IkWert(130, 139),
    16: IkWert(160, 172),
    20: IkWert(200, 216),
    25: IkWert(250, 285),
    32: IkWert(320, 369),
    35: IkWert(350, 405),
    40: IkWert(400, 467),
    50: IkWert(500, 578),
    63: IkWert(630, 737),
  };

  // Charakteristik D (20×In)
  static const Map<int, IkWert> _d = {
    2: IkWert(40, 42),
    3: IkWert(60, 64),
    4: IkWert(80, 85),
    6: IkWert(120, 128),
    8: IkWert(160, 172),
    10: IkWert(200, 216),
    13: IkWert(260, 297),
    16: IkWert(320, 369),
    20: IkWert(400, 467),
    25: IkWert(500, 578),
    32: IkWert(640, 750),
    35: IkWert(700, 825),
    40: IkWert(800, 953),
    50: IkWert(1000, 1220),
    63: IkWert(1260, 1580),
  };

  // Charakteristik K (12×In)
  static const Map<int, IkWert> _k = {
    2: IkWert(24, 25),
    3: IkWert(36, 38),
    4: IkWert(48, 51),
    6: IkWert(72, 76),
    8: IkWert(96, 102),
    10: IkWert(120, 128),
    13: IkWert(156, 167),
    16: IkWert(192, 207),
    20: IkWert(240, 273),
    25: IkWert(300, 345),
    32: IkWert(384, 447),
    35: IkWert(420, 492),
    40: IkWert(480, 553),
    50: IkWert(600, 700),
    63: IkWert(756, 896),
  };

  /// Liefert das Wertepaar (Grenzwert/Min.Anzeige) oder null, wenn der
  /// Nennstrom für die gewählte Schutzart nicht tabelliert ist.
  static IkWert? lookup(Schutzart art, int nennstrom,
      {Abschaltzeit abschaltzeit = Abschaltzeit.s04}) {
    switch (art) {
      case Schutzart.b:
        return _b[nennstrom];
      case Schutzart.c:
        return _c[nennstrom];
      case Schutzart.d:
        return _d[nennstrom];
      case Schutzart.k:
        return _k[nennstrom];
      case Schutzart.gg:
        return abschaltzeit == Abschaltzeit.s5
            ? _gg5s[nennstrom]
            : _gg04s[nennstrom];
      case Schutzart.mss:
        // Motorschutzschalter: magnetische Schnellauslösung typ. 13×Ie
        // (EN 60947-2 / IEC 60947-4-1; herstellerabhängig — ABB MS, Siemens
        // 3RV, Schneider GV alle 13×, Eaton PKZM teilweise 14×). Mindest-
        // anzeige rechnerisch mit ~7,5 % Messunsicherheit (vgl. C-LS).
        final grenzwert = 13.0 * nennstrom;
        final minAnzeige = (grenzwert * 1.075).ceilToDouble();
        return IkWert(grenzwert, minAnzeige);
    }
  }

  /// Verfügbare Nennströme je Schutzart. Für MSS ist der eingestellte Ie
  /// frei wählbar — UI nutzt Freitext statt Dropdown; die Liste hier dient
  /// nur als Fallback (gleiche LS-Nennstrom-Skala).
  static List<int> nennstroeme(Schutzart art) =>
      art == Schutzart.gg ? nennstroemeGg : nennstroemeLs;
}
