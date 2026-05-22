/// Ein Eintrag der Wissensdatenbank.
class WissensEintrag {
  final String titel;
  final String kategorie;
  final String kurz; // Kurzantwort
  final List<String> inhalt; // Stichpunkte
  final List<List<String>>? tabelle; // erste Zeile = Kopf (optional)
  final String quelle;
  final List<String> stichworte;
  final bool bestaetigen; // true = Werte bitte gegenprüfen

  const WissensEintrag({
    required this.titel,
    required this.kategorie,
    required this.kurz,
    this.inhalt = const [],
    this.tabelle,
    required this.quelle,
    this.stichworte = const [],
    this.bestaetigen = false,
  });

  bool passtZu(String q) {
    if (q.trim().isEmpty) return true;
    final s = q.toLowerCase();
    return titel.toLowerCase().contains(s) ||
        kategorie.toLowerCase().contains(s) ||
        kurz.toLowerCase().contains(s) ||
        stichworte.any((w) => w.toLowerCase().contains(s)) ||
        inhalt.any((w) => w.toLowerCase().contains(s));
  }
}

const List<String> wissensKategorien = [
  'Schutzmaßnahmen',
  'FI / RCD',
  'Querschnitte',
  'Sicherungen',
  'Erdung',
  'Sonderbereiche',
  'Prüffristen',
];

const List<WissensEintrag> wissensEintraege = [
  // ---- Verifiziert ----
  WissensEintrag(
    titel: 'Maximale Abschaltzeiten',
    kategorie: 'Schutzmaßnahmen',
    kurz: 'TN: 0,4 s (Endstromkreis ≤32 A) bzw. 5 s (Verteiler). TT: 0,2 s bzw. 1 s.',
    inhalt: [
      'Gilt für Schutz durch automatische Abschaltung (230/400 V AC).',
      'Endstromkreise ≤ 32 A: kürzere Zeit; Verteiler-/Hauptstromkreise: längere Zeit.',
      'TT-Netz: Schutz i. d. R. über RCD.',
    ],
    tabelle: [
      ['Netz', 'Endstromkreis ≤32 A', 'Verteiler / >32 A'],
      ['TN', '0,4 s', '5 s'],
      ['TT', '0,2 s', '1 s'],
      ['IT (2. Fehler)', 'wie TN', 'wie TN'],
    ],
    quelle: 'DIN VDE 0100-410, Tab. 41.1',
    stichworte: ['abschaltzeit', 'tn', 'tt', 'it', '0,4', '5s', 'schleife'],
  ),
  WissensEintrag(
    titel: 'FI/RCD-Typen (AC, A, F, B, B+)',
    kategorie: 'FI / RCD',
    kurz: 'Typ A ist Wohnbau-Standard; Typ B (allstromsensitiv) für Drehstrom-FU, Wallbox, PV.',
    inhalt: [
      'Typ AC: nur sinusförmige Wechselfehlerströme (in DE meist nicht mehr ausreichend).',
      'Typ A: + pulsierende Gleichfehlerströme – Standard im Wohnbereich.',
      'Typ F: Typ A + Mischfrequenzen (z. B. einphasige Frequenzumrichter).',
      'Typ B: allstromsensitiv, auch glatte Gleichfehlerströme (Drehstrom-FU, Wallbox, PV).',
      'Typ B+: wie B mit erweitertem Frequenzbereich (vorbeugender Brandschutz).',
    ],
    quelle: 'DIN VDE 0100-530 / Gerätenormen VDE 0664',
    stichworte: ['fi', 'rcd', 'typ a', 'typ b', 'typ f', 'allstromsensitiv', 'wallbox'],
  ),
  WissensEintrag(
    titel: 'LS-Charakteristiken & gG',
    kategorie: 'Sicherungen',
    kurz: 'Magnetische Schnellauslösung: B 3–5×Iₙ, C 5–10×Iₙ, D 10–20×Iₙ.',
    inhalt: [
      'B: für allgemeine Stromkreise (Steckdosen, Licht).',
      'C: für höhere Einschaltströme (Leuchtengruppen, kleine Motoren).',
      'D: für hohe Stoßströme (Transformatoren, Motoren).',
      'gG: NH-/Schmelzsicherung, Leitungs- und Anlagenschutz – Abschaltstrom aus der Kennlinie.',
    ],
    tabelle: [
      ['Charakteristik', 'magn. Auslösung (oberer Wert)'],
      ['B', '5 × Iₙ'],
      ['C', '10 × Iₙ'],
      ['D', '20 × Iₙ'],
    ],
    quelle: 'DIN EN 60898 / DIN VDE 0636 (gG)',
    stichworte: ['ls', 'b', 'c', 'd', 'gg', 'charakteristik', 'auslösung'],
  ),
  WissensEintrag(
    titel: 'Erforderlicher IK (PROFITEST / Min.-Anzeige)',
    kategorie: 'Schutzmaßnahmen',
    kurz: 'Gemessener IK muss ≥ Min.-Anzeigewert sein (Ia + Messunsicherheit). B16 → 85 A.',
    inhalt: [
      'Ia = oberer magnetischer Auslösewert (B 5×, C 10×, D 20× Iₙ).',
      'Das Messgerät zeigt zusätzlich eine Mindestanzeige inkl. Betriebsmessunsicherheit.',
      'gG: kein Faktor – Wert aus der Sicherungskennlinie (0,4 s / 5 s).',
    ],
    quelle: 'Gossen Metrawatt PROFITEST MASTER, Tab. 6',
    stichworte: ['ik', 'kurzschlussstrom', 'profitest', 'min anzeige', 'gossen'],
  ),
  WissensEintrag(
    titel: 'Strombelastbarkeit (Auszug Cu/PVC)',
    kategorie: 'Querschnitte',
    kurz: 'NYM Cu, 3 belastete Adern, Verlegeart B2 (Auszug).',
    inhalt: [
      'Werte = Strombelastbarkeit Iz; zulässige Sicherung In ≤ Iz.',
      'Für andere Verlegearten/Material das Kabel-Tool nutzen.',
    ],
    tabelle: [
      ['mm²', 'Iz (B2)', 'Sicherung'],
      ['1,5', '16 A', '16 A'],
      ['2,5', '21 A', '20 A'],
      ['4', '29 A', '25 A'],
      ['6', '36 A', '35 A'],
      ['10', '50 A', '50 A'],
    ],
    quelle: 'DIN VDE 0298-4, Tab. 3 (25 °C)',
    stichworte: ['querschnitt', 'strombelastbarkeit', 'nym', 'verlegeart', 'iz'],
  ),
  WissensEintrag(
    titel: 'Spannungsfall-Grenzwerte',
    kategorie: 'Querschnitte',
    kurz: 'Üblich: 3 % für Beleuchtung, 5 % für übrige Stromkreise.',
    inhalt: [
      'Bezogen auf den Verbraucher (ab Übergabepunkt).',
      'ΔU = (2·L·I)/(κ·A·U) (1~) bzw. (√3·L·I)/(κ·A·U) (3~); κ_Cu=56, κ_Al=35.',
    ],
    quelle: 'DIN 18015-1 (Empfehlung)',
    stichworte: ['spannungsfall', '3%', '5%', 'leitungslänge'],
  ),
  // ---- Bitte bestätigen ----
  WissensEintrag(
    titel: 'Prüffristen (DGUV V3)',
    kategorie: 'Prüffristen',
    kurz: 'Richtwerte – je nach Gefährdung/Nutzung; vom Unternehmer festzulegen.',
    inhalt: [
      'Ortsveränderliche Betriebsmittel: Richtwert 6–24 Monate (Baustelle ~3 Monate).',
      'Ortsfeste elektrische Anlagen: Richtwert alle 4 Jahre.',
      'Schutzeinrichtungen (RCD) in nicht stationären Anlagen: arbeitstäglich/monatlich prüfen.',
      'Fristen sind Richtwerte und per Gefährdungsbeurteilung anzupassen.',
    ],
    quelle: 'DGUV Vorschrift 3 / TRBS 1201',
    stichworte: ['prüffrist', 'dguv', 'wiederholungsprüfung', 'fristen'],
    bestaetigen: true,
  ),
  WissensEintrag(
    titel: 'Bad-Installationszonen (Bereiche 0/1/2)',
    kategorie: 'Sonderbereiche',
    kurz: 'Bereich 0 = in der Wanne, 1 = darüber bis 2,25 m, 2 = 0,6 m seitlich.',
    inhalt: [
      'Bereich 0: nur SELV ≤ 12 V AC / 30 V DC, Betriebsmittel ≥ IPX7.',
      'Bereich 1: SELV oder fest installierte, geeignete Betriebsmittel; ≥ IPX4 (Strahlwasser IPX5).',
      'Bereich 2: ≥ IPX4; Steckdosen nur mit RCD und Mindestabstand.',
      'Generell: RCD 30 mA, zusätzlicher Schutzpotentialausgleich.',
    ],
    quelle: 'DIN VDE 0100-701',
    stichworte: ['bad', 'dusche', 'zonen', 'bereich', 'ipx', 'feuchtraum'],
    bestaetigen: true,
  ),
  WissensEintrag(
    titel: 'Erdung & Potentialausgleich (Querschnitte)',
    kategorie: 'Erdung',
    kurz: 'Schutzpotentialausgleich min. 6 mm² Cu; zusätzlicher PA 2,5/4 mm².',
    inhalt: [
      'Haupt-Schutzpotentialausgleichsleiter: ≥ 6 mm² Cu (halber PE-Querschnitt, max. 25 mm²).',
      'Zusätzlicher Schutzpotentialausgleich: 2,5 mm² (geschützt verlegt) / 4 mm² (ungeschützt).',
      'Erdungsleiter: je nach Korrosions-/mech. Schutz (z. B. 16/25 mm² Cu).',
    ],
    quelle: 'DIN VDE 0100-540',
    stichworte: ['erdung', 'potentialausgleich', 'pa', ' peschiene', 'querschnitt'],
    bestaetigen: true,
  ),
];
