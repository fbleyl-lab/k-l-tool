import 'tabelle6.dart';

/// Standard-Leiterquerschnitte (mm²) für die Vorauswahl, bis 240 mm².
const List<String> querschnitte = [
  '1,5', '2,5', '4', '6', '10', '16', '25', '35', //
  '50', '70', '95', '120', '150', '185', '240',
];

/// Auswahl der Bemessungsspannung.
const List<String> spannungen = ['230', '400'];

/// Ergebnis der automatischen Beurteilung eines Stromkreises.
enum Pruefstatus { ok, nichtOk, offen }

class Stromkreisbewertung {
  final Pruefstatus status;
  final List<String> maengel; // verletzte Grenzwerte
  final List<String> fehlend; // für vollständige Beurteilung fehlende Werte
  const Stromkreisbewertung(this.status, this.maengel, this.fehlend);

  String get kurz {
    switch (status) {
      case Pruefstatus.ok:
        return 'i.O.';
      case Pruefstatus.nichtOk:
        return 'n.i.O.';
      case Pruefstatus.offen:
        return '—';
    }
  }
}

/// Ein einzelner Stromkreis (eine Zeile in der Messtabelle).
class Stromkreis {
  String stromkreisRaum;
  String kabelname;
  // Betriebsmittel: entweder Zählung (Steckdosen/Lichter) oder manueller Text.
  String betriebsmittelModus; // 'zaehlung' | 'manuell'
  int? anzahlSteckdosen;
  int? anzahlLichter;
  String anzahlBetriebsmittel; // manueller Text (Stellung 2)
  String laenge; // m
  String querschnitt; // mm²
  Schutzart schutzart; // B / C / D / K / gG
  int? vorgSicherung; // Nennstrom In [A], aus Tabelle 6
  Abschaltzeit abschaltzeit; // nur relevant für gG
  String erfIkManuell; // manueller IK, wenn kein Tabellenwert (gG > 160 A)
  // Erforderlicher IK wird aus Tabelle 6 ermittelt (read-only),
  // sonst manuell eingegeben.
  String spannung; // V
  String ikLpe; // A
  String ikLn; // A
  String fiN; // A
  String fiIdn; // mA
  String fiTyp; // 'A' oder 'B'
  String ausloesestrom; // mA (AC)
  String ausloesezeit; // ms (AC)
  String ausloesestromDc; // mA (Gleichstrom, nur Typ B)
  String ausloesezeitDc; // ms (Gleichstrom, nur Typ B)
  String ub; // V
  String rlow; // Ω
  String riso; // MΩ

  Stromkreis({
    this.stromkreisRaum = '',
    this.kabelname = '',
    this.betriebsmittelModus = 'zaehlung',
    this.anzahlSteckdosen,
    this.anzahlLichter,
    this.anzahlBetriebsmittel = '',
    this.laenge = '',
    this.querschnitt = '',
    this.schutzart = Schutzart.b,
    this.vorgSicherung,
    this.abschaltzeit = Abschaltzeit.s04,
    this.erfIkManuell = '',
    this.spannung = '230',
    this.ikLpe = '',
    this.ikLn = '',
    this.fiN = '',
    this.fiIdn = '',
    this.fiTyp = 'A',
    this.ausloesestrom = '',
    this.ausloesezeit = '',
    this.ausloesestromDc = '',
    this.ausloesezeitDc = '',
    this.ub = '',
    this.rlow = '',
    this.riso = '',
  });

  /// Wertepaar (Grenzwert/Min.Anzeige) aus Tabelle 6, oder null.
  IkWert? get ikWert {
    if (vorgSicherung == null) return null;
    return Tabelle6.lookup(schutzart, vorgSicherung!,
        abschaltzeit: abschaltzeit);
  }

  /// true, wenn ein Tabellenwert vorliegt (sonst manuelle Eingabe nötig).
  bool get hatTabellenwert => ikWert != null;

  /// Erforderlicher IK = Min.-Anzeigewert (wie PROFITEST), sonst manueller Wert.
  String get erforderlicherIkText {
    final w = ikWert;
    if (w != null) return _fmt(w.minAnzeige);
    return erfIkManuell.trim();
  }

  /// Normativer Grenzwert Ia, als Text.
  String get grenzwertIkText {
    final w = ikWert;
    if (w == null) return '';
    return _fmt(w.grenzwert);
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().replaceAll('.', ',');
  }

  static double? _num(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.').trim());

  /// Erforderlicher IK als Zahl (Min.-Anzeige aus Tabelle 6 oder manueller Wert).
  double? get erforderlicherIkValue {
    final w = ikWert;
    if (w != null) return w.minAnzeige;
    return _num(erfIkManuell);
  }

  /// Wurde ein FI/RCD gemessen? (Dann ist IK L-PE nicht messbar.)
  bool get hatFi =>
      fiIdn.trim().isNotEmpty ||
      ausloesestrom.trim().isNotEmpty ||
      ausloesezeit.trim().isNotEmpty;

  /// Automatische Beurteilung des Stromkreises.
  /// [maxAusloesezeitMs] kommt aus der Netzform (TN 400 / TT 200).
  Stromkreisbewertung bewerten({
    required int maxAusloesezeitMs,
    double ubMax = 50,
    double rlowMax = 1,
  }) {
    final maengel = <String>[];
    final fehlend = <String>[];
    final erf = erforderlicherIkValue;

    // --- Abschaltbedingung (Kurzschlussstrom) ---
    if (erf == null) {
      fehlend.add('erforderlicher IK');
    } else {
      final iln = _num(ikLn);
      if (iln == null) {
        fehlend.add('IK L-N');
      } else if (iln < erf) {
        maengel.add('IK L-N < erf. IK');
      }
      if (!hatFi) {
        final ilpe = _num(ikLpe);
        if (ilpe == null) {
          fehlend.add('IK L-PE');
        } else if (ilpe < erf) {
          maengel.add('IK L-PE < erf. IK');
        }
      }
    }

    // --- FI-Schutzschalter ---
    if (hatFi) {
      final t = _num(ausloesezeit);
      if (t == null) {
        fehlend.add('Auslösezeit');
      } else if (t > maxAusloesezeitMs) {
        maengel.add('Auslösezeit > $maxAusloesezeitMs ms');
      }
      final i = _num(ausloesestrom);
      final idn = _num(fiIdn);
      if (i == null || idn == null) {
        fehlend.add('Auslösestrom/IΔN');
      } else if (i > idn || i < 0.5 * idn) {
        maengel.add('Auslösestrom außerhalb 0,5–1×IΔN');
      }

      // Typ B: zusätzlich Gleichstrom-Messung bewerten.
      if (fiTyp == 'B') {
        final tDc = _num(ausloesezeitDc);
        if (tDc == null) {
          fehlend.add('Auslösezeit DC');
        } else if (tDc > maxAusloesezeitMs) {
          maengel.add('Auslösezeit DC > $maxAusloesezeitMs ms');
        }
        final iDc = _num(ausloesestromDc);
        if (iDc == null || idn == null) {
          fehlend.add('Auslösestrom DC');
        } else if (iDc > idn || iDc < 0.5 * idn) {
          maengel.add('Auslösestrom DC außerhalb 0,5–1×IΔN');
        }
      }
    }

    // --- RLOW ---
    final r = _num(rlow);
    if (r == null) {
      fehlend.add('RLOW');
    } else if (r > rlowMax) {
      maengel.add('RLOW > ${_fmt(rlowMax)} Ω');
    }

    // --- UB ---
    final u = _num(ub);
    if (u == null) {
      fehlend.add('UB');
    } else if (u > ubMax) {
      maengel.add('UB > ${_fmt(ubMax)} V');
    }

    if (maengel.isNotEmpty) {
      return Stromkreisbewertung(Pruefstatus.nichtOk, maengel, fehlend);
    }
    if (fehlend.isNotEmpty) {
      return Stromkreisbewertung(Pruefstatus.offen, maengel, fehlend);
    }
    return Stromkreisbewertung(Pruefstatus.ok, maengel, fehlend);
  }

  /// Anzeigetext der Betriebsmittel (für Liste und PDF).
  String get betriebsmittelText {
    if (betriebsmittelModus == 'manuell') return anzahlBetriebsmittel.trim();
    final parts = <String>[];
    if ((anzahlSteckdosen ?? 0) > 0) parts.add('$anzahlSteckdosen Steckdosen');
    if ((anzahlLichter ?? 0) > 0) parts.add('$anzahlLichter Lichter');
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'stromkreisRaum': stromkreisRaum,
        'kabelname': kabelname,
        'betriebsmittelModus': betriebsmittelModus,
        'anzahlSteckdosen': anzahlSteckdosen,
        'anzahlLichter': anzahlLichter,
        'anzahlBetriebsmittel': anzahlBetriebsmittel,
        'laenge': laenge,
        'querschnitt': querschnitt,
        'schutzart': schutzart.label,
        'vorgSicherung': vorgSicherung,
        'abschaltzeit': abschaltzeit == Abschaltzeit.s5 ? '5s' : '0.4s',
        'erfIkManuell': erfIkManuell,
        'spannung': spannung,
        'ikLpe': ikLpe,
        'ikLn': ikLn,
        'fiN': fiN,
        'fiIdn': fiIdn,
        'fiTyp': fiTyp,
        'ausloesestrom': ausloesestrom,
        'ausloesezeit': ausloesezeit,
        'ausloesestromDc': ausloesestromDc,
        'ausloesezeitDc': ausloesezeitDc,
        'ub': ub,
        'rlow': rlow,
        'riso': riso,
      };

  factory Stromkreis.fromJson(Map<String, dynamic> j) => Stromkreis(
        stromkreisRaum: j['stromkreisRaum'] ?? '',
        kabelname: j['kabelname'] ?? '',
        betriebsmittelModus: j['betriebsmittelModus'] ??
            ((j['anzahlBetriebsmittel'] ?? '').toString().trim().isNotEmpty
                ? 'manuell'
                : 'zaehlung'),
        anzahlSteckdosen: j['anzahlSteckdosen'] is int
            ? j['anzahlSteckdosen']
            : int.tryParse('${j['anzahlSteckdosen'] ?? ''}'),
        anzahlLichter: j['anzahlLichter'] is int
            ? j['anzahlLichter']
            : int.tryParse('${j['anzahlLichter'] ?? ''}'),
        anzahlBetriebsmittel: j['anzahlBetriebsmittel'] ?? '',
        laenge: j['laenge'] ?? '',
        querschnitt: j['querschnitt'] ?? '',
        schutzart: SchutzartLabel.fromLabel(j['schutzart'] ?? 'B'),
        vorgSicherung: j['vorgSicherung'] is int
            ? j['vorgSicherung']
            : int.tryParse('${j['vorgSicherung'] ?? ''}'),
        abschaltzeit:
            (j['abschaltzeit'] == '5s') ? Abschaltzeit.s5 : Abschaltzeit.s04,
        erfIkManuell: j['erfIkManuell'] ?? '',
        spannung: j['spannung'] ?? '230',
        ikLpe: j['ikLpe'] ?? '',
        ikLn: j['ikLn'] ?? '',
        fiN: j['fiN'] ?? '',
        fiIdn: j['fiIdn'] ?? '',
        fiTyp: j['fiTyp'] ?? 'A',
        ausloesestrom: j['ausloesestrom'] ?? '',
        ausloesezeit: j['ausloesezeit'] ?? '',
        ausloesestromDc: j['ausloesestromDc'] ?? '',
        ausloesezeitDc: j['ausloesezeitDc'] ?? '',
        ub: j['ub'] ?? '',
        rlow: j['rlow'] ?? '',
        riso: j['riso'] ?? '',
      );

  Stromkreis copy() => Stromkreis.fromJson(toJson());
}
