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
  final String? grafik; // optionale Schemagrafik-ID (z. B. 'badzonen')

  const WissensEintrag({
    required this.titel,
    required this.kategorie,
    required this.kurz,
    this.inhalt = const [],
    this.tabelle,
    required this.quelle,
    this.stichworte = const [],
    this.bestaetigen = false,
    this.grafik,
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
  'Grundlagen',
  'Schutzmaßnahmen',
  'FI / RCD',
  'Messen & Prüfen',
  'Leitungen',
  'Querschnitte',
  'Sicherungen',
  'Erdung',
  'Sonderbereiche',
  'Prüffristen',
  'Formeln',
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
    stichworte: ['bad', 'dusche', 'zonen', 'bereich', 'ipx', 'feuchtraum', 'grafik'],
    bestaetigen: true,
    grafik: 'badzonen',
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

  // ===================== Grundlagen =====================
  WissensEintrag(
    titel: 'Netzsysteme (TN, TT, IT)',
    kategorie: 'Grundlagen',
    kurz: 'TN-C/TN-S/TN-C-S, TT und IT – Unterschied liegt in PE-/N-Führung und Erdung.',
    inhalt: [
      'TN-C: PEN (PE und N kombiniert) – nur ≥ 10 mm² Cu, kein RCD möglich.',
      'TN-S: PE und N durchgehend getrennt – Standard in modernen Anlagen.',
      'TN-C-S: erst PEN, ab Trennstelle getrennt (typischer Hausanschluss).',
      'TT: Betriebserder beim EVU, separater Anlagenerder – RCD praktisch zwingend.',
      'IT: nicht/​hochohmig geerdet, Isolationsüberwachung; erst der 2. Fehler schaltet ab.',
    ],
    quelle: 'DIN VDE 0100-310',
    stichworte: ['netzform', 'tn', 'tt', 'it', 'pen', 'tn-c-s'],
  ),
  WissensEintrag(
    titel: 'Schutzklassen I / II / III',
    kategorie: 'Grundlagen',
    kurz: 'I = Schutzleiter, II = Schutzisolierung, III = Schutzkleinspannung.',
    inhalt: [
      'Klasse I: Körper am Schutzleiter (PE) angeschlossen.',
      'Klasse II: doppelte/verstärkte Isolierung, kein PE (Symbol: Quadrat im Quadrat).',
      'Klasse III: Betrieb nur mit SELV/PELV (Schutzkleinspannung).',
    ],
    quelle: 'DIN EN 61140 / VDE 0140-1',
    stichworte: ['schutzklasse', 'schutzisolierung', 'klasse 2', 'gerät'],
  ),
  WissensEintrag(
    titel: 'SELV / PELV / FELV',
    kategorie: 'Grundlagen',
    kurz: 'Schutzkleinspannung: ≤ 50 V AC / 120 V DC. SELV ungeerdet, PELV geerdet.',
    inhalt: [
      'SELV: sichere Trennung vom Netz, KEINE Erdung, keine Verbindung zu anderen Kreisen.',
      'PELV: wie SELV, aber Erdung/Körperverbindung zulässig.',
      'FELV: Funktionskleinspannung – nur Funktion, kein vollwertiger Schutz.',
      'Grenzen: ≤ 50 V AC bzw. ≤ 120 V DC (Effektivwert).',
    ],
    quelle: 'DIN VDE 0100-414',
    stichworte: ['selv', 'pelv', 'felv', 'kleinspannung', 'schutztrennung'],
  ),
  WissensEintrag(
    titel: 'IP-Schutzarten',
    kategorie: 'Grundlagen',
    kurz: '1. Ziffer = Fremdkörper/Berührung, 2. Ziffer = Wasserschutz.',
    inhalt: [
      'IPX4 = Spritzwasser, IPX5 = Strahlwasser, IPX7 = zeitweiliges Eintauchen.',
      'IP2X = fingersicher, IP4X = > 1 mm, IP5X = staubgeschützt, IP6X = staubdicht.',
    ],
    tabelle: [
      ['Code', 'Bedeutung'],
      ['IP20', 'fingersicher, kein Wasserschutz'],
      ['IP44', 'Fremdkörper > 1 mm, Spritzwasser'],
      ['IP54', 'staubgeschützt, Spritzwasser'],
      ['IP65', 'staubdicht, Strahlwasser'],
      ['IP67', 'staubdicht, Eintauchen'],
    ],
    quelle: 'DIN EN 60529 / VDE 0470-1',
    stichworte: ['ip', 'schutzart', 'ipx4', 'ip44', 'staub', 'wasser'],
  ),
  WissensEintrag(
    titel: 'Leiterfarben / Aderkennzeichnung',
    kategorie: 'Grundlagen',
    kurz: 'PE grün-gelb, N blau, L1 braun, L2 schwarz, L3 grau.',
    inhalt: [
      'Schutzleiter PE: ausschließlich grün-gelb.',
      'Neutralleiter N: blau.',
      'Außenleiter: L1 braun, L2 schwarz, L3 grau (empfohlen).',
      'Grün-gelb darf NUR für PE verwendet werden.',
    ],
    quelle: 'DIN VDE 0100-510 / IEC 60446',
    stichworte: ['farben', 'ader', 'pe', 'neutralleiter', 'l1', 'braun', 'blau'],
  ),

  // ===================== FI / RCD =====================
  WissensEintrag(
    titel: 'RCD 30 mA – wo Pflicht?',
    kategorie: 'FI / RCD',
    kurz: 'U. a. Steckdosen ≤ 32 A, Außenbereich, Feuchträume, Wohnungs-Beleuchtung.',
    inhalt: [
      'Steckdosen ≤ 32 A für die Benutzung durch Laien.',
      'Endstromkreise im Außenbereich ≤ 32 A.',
      'Räume mit Badewanne/Dusche, Feucht-/Nassbereiche.',
      'Beleuchtungsstromkreise in Wohnungen (seit VDE 0100-410:2018).',
      'Bemessungsfehlerströme: 10 / 30 / 100 / 300 / 500 mA (Personenschutz = 30 mA).',
    ],
    quelle: 'DIN VDE 0100-410:2018',
    stichworte: ['rcd', 'fi', '30ma', 'pflicht', 'personenschutz', 'steckdose'],
    bestaetigen: true,
  ),

  // ===================== Messen & Prüfen =====================
  WissensEintrag(
    titel: 'Erstprüfung – Ablauf',
    kategorie: 'Messen & Prüfen',
    kurz: 'Besichtigen → Erproben → Messen, dann Protokoll.',
    inhalt: [
      'Besichtigen: vor Inbetriebnahme, spannungsfrei (Beschriftung, Schutzart, Auswahl).',
      'Erproben: Funktion von Schalt-/Schutzgeräten, Drehfeld, RCD-Prüftaste.',
      'Messen: Schutzleiter (RLOW), Isolationswiderstand, Schleifenimpedanz/IK, RCD, Erdung.',
    ],
    quelle: 'DIN VDE 0100-600',
    stichworte: ['erstprüfung', 'besichtigen', 'erproben', 'messen', 'ablauf'],
  ),
  WissensEintrag(
    titel: 'Isolationswiderstand – Grenzwerte',
    kategorie: 'Messen & Prüfen',
    kurz: 'Bis 500 V: Prüfspannung 500 V, Riso ≥ 1,0 MΩ. SELV/PELV: 250 V, ≥ 0,5 MΩ.',
    tabelle: [
      ['Nennspannung', 'Prüfspannung', 'min. Riso'],
      ['SELV / PELV', '250 V', '0,5 MΩ'],
      ['≤ 500 V', '500 V', '1,0 MΩ'],
      ['> 500 V', '1000 V', '1,0 MΩ'],
    ],
    quelle: 'DIN VDE 0100-600, Tab. 6.1',
    stichworte: ['isolation', 'riso', 'megaohm', 'prüfspannung'],
  ),
  WissensEintrag(
    titel: 'Schutzleiterprüfung (RLOW / Durchgängigkeit)',
    kategorie: 'Messen & Prüfen',
    kurz: 'Niederohmige Durchgängigkeit mit Prüfstrom ≥ 200 mA messen.',
    inhalt: [
      'Prüfstrom mind. 200 mA, Leerlaufspannung 4 … 24 V (AC oder DC).',
      'Geprüft wird die Durchgängigkeit von PE und Schutzpotentialausgleich.',
      'Kein fester Normgrenzwert – Wert muss niederohmig/plausibel zur Leitungslänge sein.',
    ],
    quelle: 'DIN VDE 0100-600 / EN 61557-4',
    stichworte: ['rlow', 'durchgängigkeit', 'schutzleiter', 'niederohm'],
  ),
  WissensEintrag(
    titel: 'RCD-Prüfung (Auslösung)',
    kategorie: 'Messen & Prüfen',
    kurz: 'Auslösung spätestens bei IΔN; Zeit ≤ Netzform (TN 400 / TT 200 ms).',
    inhalt: [
      'Auslösestrom muss ≤ Bemessungsfehlerstrom IΔN sein (AC-Bereich 0,5 … 1 × IΔN).',
      'Auslösezeit bei IΔN: ≤ 0,4 s (TN) bzw. ≤ 0,2 s (TT) – Produktnorm Standard-RCD ≤ 0,3 s.',
      'Bei 5 × IΔN deutlich schneller (Fertigungs-/Personenschutzprüfung, < 40 ms).',
      'Berührungsspannung UB ≤ 50 V.',
    ],
    quelle: 'DIN VDE 0100-600 / 0664',
    stichworte: ['rcd', 'fi', 'auslösezeit', 'auslösestrom', 'prüfung'],
  ),
  WissensEintrag(
    titel: 'Drehfeld',
    kategorie: 'Messen & Prüfen',
    kurz: 'Rechtsdrehfeld L1→L2→L3 ist Standard (für Drehstrommotoren wichtig).',
    inhalt: [
      'Reihenfolge L1, L2, L3 = Rechtsdrehfeld.',
      'Falsches Drehfeld → Motor läuft verkehrt herum.',
      'Prüfung mit Drehfeld-/Phasenfolge-Messgerät.',
    ],
    quelle: 'DIN VDE 0100-600',
    stichworte: ['drehfeld', 'phasenfolge', 'rechtsdrehfeld', 'motor'],
  ),

  // ===================== Leitungen =====================
  WissensEintrag(
    titel: 'Leitungsbezeichnungen (NYM, NYY, H07V-K …)',
    kategorie: 'Leitungen',
    kurz: 'NYM = Mantelleitung innen, NYY = Erd-/Starkstromkabel, H07V-K = Einzelader flexibel.',
    inhalt: [
      'NYM-J: Mantelleitung, feste Verlegung in/auf Wand, „J" = mit grün-gelb.',
      'NYY-J: Kunststoffkabel 0,6/1 kV, auch Erdverlegung.',
      'H07V-K: flexible Einzelader (feindrähtig) für Rohr/Kanal.',
      'H07V-U: starre Einzelader (eindrähtig).',
      'NYCWY: Kabel mit konzentrischem Leiter (PEN).',
    ],
    quelle: 'DIN VDE 0281 / 0276 / HD 361',
    stichworte: ['nym', 'nyy', 'h07v', 'leitung', 'kabel', 'bezeichnung'],
  ),
  WissensEintrag(
    titel: 'Standard-Querschnitte (Cu)',
    kategorie: 'Leitungen',
    kurz: '1,5 · 2,5 · 4 · 6 · 10 · 16 · 25 · 35 · 50 · 70 · 95 · 120 · … · 240 mm².',
    inhalt: [
      'Mindestquerschnitt fest verlegt Cu: 1,5 mm².',
      'Übliche Endstromkreise: Licht 1,5 mm² / B10–B16, Steckdosen 1,5–2,5 mm² / B16.',
      'Herd/Drehstrom: 2,5–6 mm² je nach Leistung/Länge → Kabel-Tool nutzen.',
    ],
    quelle: 'DIN VDE 0100-520',
    stichworte: ['querschnitt', 'mm²', 'reihe', 'mindestquerschnitt'],
  ),

  // ===================== Sicherungen =====================
  WissensEintrag(
    titel: 'Normstromstärken Überstromschutz',
    kategorie: 'Sicherungen',
    kurz: '6 · 10 · 13 · 16 · 20 · 25 · 32 · 40 · 50 · 63 · 80 · 100 · 125 · 160 A …',
    inhalt: [
      'LS-Schalter üblich: 6, 10, 13, 16, 20, 25, 32, 40, 50, 63 A.',
      'gG/NH weiter: 80, 100, 125, 160, 200, 250, 315, 400, 500, 630 A.',
      'Bemessungsstrom In darf die Belastbarkeit Iz der Leitung nicht überschreiten (In ≤ Iz).',
    ],
    quelle: 'DIN VDE 0100-430 / 0636',
    stichworte: ['nennstrom', 'normreihe', 'sicherung', 'in'],
  ),
  WissensEintrag(
    titel: 'NH-Sicherungsgrößen',
    kategorie: 'Sicherungen',
    kurz: 'Baugrößen 000 bis 3, je nach Strombereich.',
    tabelle: [
      ['Größe', 'Strombereich (ca.)'],
      ['NH000 / 00', 'bis ~160 A'],
      ['NH1', '~80 – 250 A'],
      ['NH2', '~125 – 400 A'],
      ['NH3', '~315 – 630 A'],
    ],
    quelle: 'DIN VDE 0636-2 / DIN 43620',
    stichworte: ['nh', 'sicherung', 'baugröße', 'größe'],
    bestaetigen: true,
  ),

  // ===================== Erdung / Überspannung =====================
  WissensEintrag(
    titel: 'Fundamenterder',
    kategorie: 'Erdung',
    kurz: 'Bei Neubauten Pflicht; Ring aus Band-/Rundstahl im Fundament, an HES angeschlossen.',
    inhalt: [
      'Verbindet die Anlage niederohmig mit Erde, bildet Basis für Potentialausgleich.',
      'Material z. B. Bandstahl 30×3,5 mm verzinkt oder Edelstahl (V4A im Erdreich).',
      'Anschluss an die Haupterdungsschiene (HES); Blitzschutz-Anschlussfahnen vorsehen.',
    ],
    quelle: 'DIN 18014',
    stichworte: ['fundamenterder', 'erder', 'hes', 'ringerder'],
    bestaetigen: true,
  ),
  WissensEintrag(
    titel: 'Überspannungsschutz (SPD Typ 1/2/3)',
    kategorie: 'Erdung',
    kurz: 'Typ 1 Blitzstrom (Hauptverteiler), Typ 2 Überspannung (UV), Typ 3 Endgeräte.',
    inhalt: [
      'Typ 1 (Iimp, 10/350 µs): Blitzteilstrom-Ableiter am Gebäudeeintritt/Hauptverteilung.',
      'Typ 2 (In/Imax, 8/20 µs): in der Unterverteilung.',
      'Typ 3: feinster Schutz direkt vor empfindlichen Endgeräten.',
      'Für Neubau-Wohngebäude i. d. R. vorgeschrieben.',
    ],
    quelle: 'DIN VDE 0100-443 / -534',
    stichworte: ['überspannung', 'spd', 'ableiter', 'blitzschutz', 'typ 1'],
    bestaetigen: true,
  ),

  // ===================== Sonderbereiche =====================
  WissensEintrag(
    titel: 'Schwimmbäder / Becken (Zonen)',
    kategorie: 'Sonderbereiche',
    kurz: 'Bereich 0 im Becken, 1 bis 2 m / 2,5 m Höhe, 2 weitere 1,5 m.',
    inhalt: [
      'Bereich 0: im Becken – nur SELV ≤ 12 V AC.',
      'Bereich 1: bis 2 m horizontal um den Beckenrand, bis 2,5 m Höhe.',
      'Bereich 2: weitere 1,5 m an Bereich 1 anschließend.',
      'Hohe IP-Schutzarten, RCD 30 mA, Potentialausgleich.',
    ],
    quelle: 'DIN VDE 0100-702',
    stichworte: ['schwimmbad', 'pool', 'becken', 'zonen', 'wasser'],
    bestaetigen: true,
  ),
  WissensEintrag(
    titel: 'Baustellen',
    kategorie: 'Sonderbereiche',
    kurz: 'Speisung über Baustromverteiler; Steckdosen ≤ 32 A mit RCD 30 mA.',
    inhalt: [
      'Stromversorgung über geprüften Baustromverteiler (ACS) mit RCD.',
      'Steckdosen ≤ 32 A: RCD ≤ 30 mA; größere Verbraucher RCD ≤ 500 mA.',
      'Kurze Prüffristen für ortsveränderliche Betriebsmittel (Gefährdungsbeurteilung).',
    ],
    quelle: 'DIN VDE 0100-704',
    stichworte: ['baustelle', 'baustromverteiler', 'rcd', 'acs'],
    bestaetigen: true,
  ),

  // ===================== Formeln =====================
  WissensEintrag(
    titel: 'Grundformeln',
    kategorie: 'Formeln',
    kurz: 'Ohm, Leistung (1~/3~), Spannungsfall, Leiterwiderstand.',
    inhalt: [
      'Ohmsches Gesetz: U = R × I.',
      'Leistung (DC/1~): P = U × I × cos φ.',
      'Leistung Drehstrom: P = √3 × U × I × cos φ.',
      'Spannungsfall 1~: ΔU = (2 × L × I) / (κ × A); 3~: ΔU = (√3 × L × I × cos φ) / (κ × A).',
      'Leiterwiderstand: R = (ρ × l) / A;  κ_Cu ≈ 56, κ_Al ≈ 35 m/(Ω·mm²).',
    ],
    quelle: 'Elektrotechnik-Grundlagen',
    stichworte: ['formel', 'ohm', 'leistung', 'spannungsfall', 'kappa', 'cos phi'],
  ),
];
