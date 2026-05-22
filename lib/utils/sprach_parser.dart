/// Ergebnis der Sprach-Analyse einer Aufmaß-Position.
class SprachPosition {
  final String menge;
  final String bezeichnung;
  final String? einheit; // null = unverändert lassen
  const SprachPosition(this.menge, this.bezeichnung, this.einheit);
}

/// Wandelt diktierten Text in Menge + Bezeichnung (+ ggf. Einheit) um.
/// Beispiele:
///   "zehn Steckdosen"      -> 10 / Steckdosen
///   "5 Meter Kabel"        -> 5 / Kabel (Einheit m)
///   "drei Lichtauslässe"   -> 3 / Lichtauslässe
class SprachParser {
  static const Map<String, int> _zahlwoerter = {
    'null': 0,
    'ein': 1, 'eine': 1, 'einen': 1, 'eins': 1,
    'zwei': 2, 'drei': 3, 'vier': 4, 'fünf': 5, 'fuenf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9, 'zehn': 10,
    'elf': 11, 'zwölf': 12, 'zwoelf': 12, 'dreizehn': 13,
    'vierzehn': 14, 'fünfzehn': 15, 'fuenfzehn': 15, 'sechzehn': 16,
    'siebzehn': 17, 'achtzehn': 18, 'neunzehn': 19, 'zwanzig': 20,
    'dreißig': 30, 'dreissig': 30, 'vierzig': 40, 'fünfzig': 50,
    'fuenfzig': 50, 'sechzig': 60, 'siebzig': 70, 'achtzig': 80,
    'neunzig': 90, 'hundert': 100,
  };

  // Einheiten-Schlüsselwörter -> Einheit (siehe aufmassEinheiten)
  static const Map<String, String> _einheiten = {
    'meter': 'm', 'metern': 'm',
    'quadratmeter': 'm²', 'quadratmetern': 'm²',
    'kubikmeter': 'm³',
    'stück': 'Stk', 'stücke': 'Stk', 'stueck': 'Stk', 'stk': 'Stk',
    'stunde': 'h', 'stunden': 'h',
    'kilogramm': 'kg', 'kilo': 'kg',
    'punkt': 'Pkt', 'punkte': 'Pkt',
  };

  static SprachPosition parse(String text) {
    var rest = text.trim();
    if (rest.isEmpty) return const SprachPosition('', '', null);

    String menge = '';
    final woerter = rest.split(RegExp(r'\s+'));

    // 1) Führende Ziffer (auch Dezimal: "1,5" / "2.5" / "10x")
    final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*x?\b').firstMatch(rest);
    if (m != null) {
      menge = m.group(1)!.replaceAll('.', ',');
      rest = rest.substring(m.end).trim();
    } else if (woerter.isNotEmpty) {
      // 2) Führendes Zahlwort
      final erst = woerter.first.toLowerCase().replaceAll(RegExp(r'[.,]'), '');
      if (_zahlwoerter.containsKey(erst)) {
        menge = _zahlwoerter[erst]!.toString();
        rest = woerter.skip(1).join(' ').trim();
      }
    }

    // 3) Einheit aus dem verbleibenden Text erkennen
    String? einheit;
    final restWoerter = rest.split(RegExp(r'\s+'));
    for (var i = 0; i < restWoerter.length; i++) {
      final w = restWoerter[i].toLowerCase().replaceAll(RegExp(r'[.,]'), '');
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
