/// Ergebnis der Sprach-Analyse einer Aufmaß-Position.
class SprachPosition {
  final String menge;
  final String bezeichnung;
  final String? einheit; // null = unverändert lassen
  const SprachPosition(this.menge, this.bezeichnung, this.einheit);
}

/// Wandelt diktierten Text in Menge + Bezeichnung (+ ggf. Einheit) um.
/// Beispiele:
///   "zehn Steckdosen"           -> 10 / Steckdosen
///   "5 Meter Kabel"             -> 5  / Kabel        (Einheit m)
///   "drei Lichtauslässe"        -> 3  / Lichtauslässe
///   "fünfundzwanzig Schalter"   -> 25 / Schalter
///   "zwei komma fünf Meter NYM" -> 2,5/ NYM          (Einheit m)
class SprachParser {
  // Einer & spezielle Werte
  static const Map<String, int> _basisZahlen = {
    'null': 0,
    'ein': 1, 'eine': 1, 'einen': 1, 'eins': 1,
    'zwei': 2, 'drei': 3, 'vier': 4, 'fünf': 5, 'fuenf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9, 'zehn': 10,
    'elf': 11, 'zwölf': 12, 'zwoelf': 12, 'dreizehn': 13,
    'vierzehn': 14, 'fünfzehn': 15, 'fuenfzehn': 15, 'sechzehn': 16,
    'siebzehn': 17, 'achtzehn': 18, 'neunzehn': 19, 'zwanzig': 20,
    'dreißig': 30, 'dreissig': 30, 'vierzig': 40, 'fünfzig': 50,
    'fuenfzig': 50, 'sechzig': 60, 'siebzig': 70, 'achtzig': 80,
    'neunzig': 90, 'hundert': 100, 'tausend': 1000,
  };

  // Vollständige Liste 0–99 inkl. zusammengesetzter Formen wie
  // "einundzwanzig" (Google STT liefert die oft als ein Wort).
  static final Map<String, int> _zahlwoerter = _baueZahlwoerter();

  static Map<String, int> _baueZahlwoerter() {
    final m = <String, int>{..._basisZahlen};
    const einer = {
      'ein': 1, 'eins': 1,
      'zwei': 2, 'drei': 3, 'vier': 4, 'fünf': 5, 'fuenf': 5,
      'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9,
    };
    const zehner = {
      'zwanzig': 20, 'dreißig': 30, 'dreissig': 30, 'vierzig': 40,
      'fünfzig': 50, 'fuenfzig': 50, 'sechzig': 60, 'siebzig': 70,
      'achtzig': 80, 'neunzig': 90,
    };
    for (final z in zehner.entries) {
      for (final e in einer.entries) {
        m['${e.key}und${z.key}'] = z.value + e.value;
      }
    }
    return m;
  }

  // Einheiten-Schlüsselwörter -> Einheit (siehe aufmassEinheiten)
  static const Map<String, String> _einheiten = {
    'meter': 'm', 'metern': 'm', 'm': 'm',
    'quadratmeter': 'm²', 'quadratmetern': 'm²', 'qm': 'm²',
    'kubikmeter': 'm³', 'kubikmetern': 'm³',
    'stück': 'Stk', 'stücke': 'Stk', 'stueck': 'Stk', 'stk': 'Stk',
    'stunde': 'h', 'stunden': 'h',
    'kilogramm': 'kg', 'kilo': 'kg', 'kg': 'kg',
    'punkt': 'Pkt', 'punkte': 'Pkt',
    'pauschal': 'Pausch', 'pauschale': 'Pausch',
  };

  /// Versucht, eine Menge vom Anfang des Textes zu lesen. Liefert
  /// (mengeAlsString, restText) oder ('', text) wenn nichts erkannt.
  static (String, String) _leseMenge(String text) {
    var rest = text.trim();
    if (rest.isEmpty) return ('', rest);

    // 1) Führende Ziffer (auch Dezimal: "1,5" / "2.5" / "10x")
    final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*x?\b').firstMatch(rest);
    if (m != null) {
      return (m.group(1)!.replaceAll('.', ','), rest.substring(m.end).trim());
    }

    // 2) Führendes Zahlwort, optional gefolgt von "komma" + weiterem Zahlwort
    //    für Dezimalzahlen wie "zwei komma fünf".
    final wlist = rest.split(RegExp(r'\s+'));
    final erst = _norm(wlist.first);
    final n1 = _zahlwoerter[erst];
    if (n1 == null) return ('', rest);

    // Schau auf "<Zahl> komma <Zahl>"
    if (wlist.length >= 3 && _norm(wlist[1]) == 'komma') {
      final n2 = _zahlwoerter[_norm(wlist[2])];
      if (n2 != null) {
        final menge = '$n1,$n2';
        final r = wlist.skip(3).join(' ').trim();
        return (menge, r);
      }
    }

    return (n1.toString(), wlist.skip(1).join(' ').trim());
  }

  static String _norm(String w) =>
      w.toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '');

  static SprachPosition parse(String text) {
    final eingabe = text.trim();
    if (eingabe.isEmpty) return const SprachPosition('', '', null);

    final (menge, ohneMenge) = _leseMenge(eingabe);
    var rest = ohneMenge;

    // 3) Einheit aus dem verbleibenden Text erkennen (erstes Treffer-Wort).
    String? einheit;
    final restWoerter = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    for (var i = 0; i < restWoerter.length; i++) {
      final w = _norm(restWoerter[i]);
      if (_einheiten.containsKey(w)) {
        einheit = _einheiten[w];
        restWoerter.removeAt(i);
        break;
      }
    }
    rest = restWoerter.join(' ').trim();

    // Bezeichnung: ersten Buchstaben groß
    if (rest.isNotEmpty) {
      rest = rest[0].toUpperCase() + rest.substring(1);
    }

    return SprachPosition(menge, rest, einheit);
  }
}
