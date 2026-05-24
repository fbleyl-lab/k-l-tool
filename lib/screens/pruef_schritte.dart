import '../models/protokoll.dart' show Netzform, NetzformLabel;
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../models/wallbox_protokoll.dart';
import 'gefuehrte_pruefung_screen.dart';

double? _num(String s) =>
    s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.').trim());

Pruefstatus _leOk(double max, String v) {
  final x = _num(v);
  if (x == null) return Pruefstatus.offen;
  return x <= max ? Pruefstatus.ok : Pruefstatus.nichtOk;
}

Pruefstatus _geOk(double? min, String v) {
  final x = _num(v);
  if (x == null || min == null) return Pruefstatus.offen;
  return x >= min ? Pruefstatus.ok : Pruefstatus.nichtOk;
}

Pruefstatus _bandOk(double? idn, String v) {
  final x = _num(v);
  if (x == null || idn == null) return Pruefstatus.offen;
  return (x >= 0.5 * idn && x <= idn) ? Pruefstatus.ok : Pruefstatus.nichtOk;
}

/// Phase 1 (am Verteiler): Stammdaten ablesen – FI, Charakteristik,
/// Vorsicherung. Keine Messungen. Reihenfolge passt zum realen Workflow:
/// alles ablesen, was am Schutzorgan steht, bevor man zum Verbraucher läuft.
List<Pruefschritt> stromkreisStammdatenSchritte(Stromkreis s,
    {String prefix = ''}) {
  bool fi = s.hatFi;
  String t(String x) => prefix.isEmpty ? x : '$prefix$x';

  return [
    Pruefschritt(
      titel: t('FI/RCD vorhanden?'),
      hinweis: 'Ist dieser Stromkreis über einen FI/RCD geschützt?',
      eingabe: PruefEingabe.auswahl,
      optionen: () => const ['Ja', 'Nein'],
      wertLesen: () => fi ? 'Ja' : 'Nein',
      wertSchreiben: (v) {
        fi = v == 'Ja';
        if (!fi) {
          s.fiN = '';
          s.fiIdn = '';
          s.ausloesestrom = '';
          s.ausloesezeit = '';
          s.ausloesestromDc = '';
          s.ausloesezeitDc = '';
        }
      },
    ),
    Pruefschritt(
      titel: t('FI-Typ'),
      hinweis: 'Typ A oder B. Typ B ist zusätzlich DC-fehlerstromsensitiv.',
      eingabe: PruefEingabe.auswahl,
      optionen: () => const ['A', 'B'],
      wertLesen: () => s.fiTyp,
      wertSchreiben: (v) => s.fiTyp = v,
      sichtbar: () => fi,
    ),
    Pruefschritt(
      titel: t('FI: Nennstrom'),
      hinweis: 'Nennstrom In des FI/RCD (vom Typenschild), z. B. 40 A.',
      einheit: 'A',
      wertLesen: () => s.fiN,
      wertSchreiben: (v) => s.fiN = v,
      sichtbar: () => fi,
    ),
    Pruefschritt(
      titel: t('FI: Bemessungsfehlerstrom IΔN'),
      hinweis: 'IΔN (Nennauslösestrom) des FI/RCD, z. B. 30 mA.',
      einheit: 'mA',
      wertLesen: () => s.fiIdn,
      wertSchreiben: (v) => s.fiIdn = v,
      sichtbar: () => fi,
    ),
    Pruefschritt(
      titel: t('Charakteristik'),
      hinweis: 'Schutzorgan-Charakteristik wählen (B/C/D/K/gG).',
      eingabe: PruefEingabe.auswahl,
      optionen: () => const ['B', 'C', 'D', 'K', 'gG'],
      wertLesen: () => s.schutzart.label,
      wertSchreiben: (v) => s.schutzart = SchutzartLabel.fromLabel(v),
    ),
    Pruefschritt(
      titel: t('Vorsicherung'),
      hinweis: 'Nennstrom In der Vorsicherung. Bestimmt den erforderlichen IK '
          '(Tabelle 6).',
      eingabe: PruefEingabe.dropdown,
      einheit: 'A',
      inputLabel: 'Nennstrom',
      optionen: () =>
          Tabelle6.nennstroeme(s.schutzart).map((n) => n.toString()).toList(),
      wertLesen: () => s.vorgSicherung?.toString() ?? '',
      wertSchreiben: (v) => s.vorgSicherung = int.tryParse(v.trim()),
    ),
  ];
}

/// Phase 2 (am Verbraucher): Messungen mit dem Messgerät. RLOW/RISO
/// spannungsfrei, dann unter Spannung IK/FI/UB. Sichtbarkeit der
/// FI-/IK-L-PE-Schritte ergibt sich aus [Stromkreis.hatFi] – also aus den
/// in Phase 1 erfassten Stammdaten.
List<Pruefschritt> stromkreisMessSchritte(Stromkreis s, Netzform netz,
    {String prefix = ''}) {
  final maxT = netz.maxAusloesezeitMs.toDouble();
  String t(String x) => prefix.isEmpty ? x : '$prefix$x';

  return [
    Pruefschritt(
      titel: t('Durchgängigkeit Schutzleiter (RLOW)'),
      hinweis: 'Niederohmige Durchgängigkeit. Grenzwert ≤ 1 Ω. '
          'Anlage spannungsfrei messen!',
      einheit: 'Ω',
      wertLesen: () => s.rlow,
      wertSchreiben: (v) => s.rlow = v,
      ampel: () => _leOk(1, s.rlow),
    ),
    Pruefschritt(
      titel: t('Isolationswiderstand (RISO)'),
      hinweis: '500 V DC zwischen L/N und PE. Grenzwert ≥ 1 MΩ. '
          'Anlage spannungsfrei!',
      einheit: 'MΩ',
      groesserErlaubt: true,
      schnellWert: '>500',
      wertLesen: () => s.riso,
      wertSchreiben: (v) => s.riso = v,
    ),
    Pruefschritt(
      titel: t('Spannung'),
      hinweis: 'Gemessene Spannung.',
      einheit: 'V',
      wertLesen: () => s.spannung,
      wertSchreiben: (v) => s.spannung = v,
    ),
    Pruefschritt(
      titel: t('Kurzschlussstrom IK L-N'),
      hinweis: 'Muss ≥ erforderlicher IK (Tabelle 6) sein.',
      einheit: 'A',
      wertLesen: () => s.ikLn,
      wertSchreiben: (v) => s.ikLn = v,
      ampel: () => _geOk(s.erforderlicherIkValue, s.ikLn),
    ),
    Pruefschritt(
      titel: t('Kurzschlussstrom IK L-PE'),
      hinweis: 'Muss ≥ erforderlicher IK sein. Bei FI entfällt diese Messung.',
      einheit: 'A',
      wertLesen: () => s.ikLpe,
      wertSchreiben: (v) => s.ikLpe = v,
      ampel: () => _geOk(s.erforderlicherIkValue, s.ikLpe),
      sichtbar: () => !s.hatFi,
    ),
    Pruefschritt(
      titel: t('FI: Auslösezeit AC'),
      hinweis: 'Auslösezeit bei IΔN. Grenzwert: TN ≤ 400 ms, TT ≤ 200 ms.',
      einheit: 'ms',
      wertLesen: () => s.ausloesezeit,
      wertSchreiben: (v) => s.ausloesezeit = v,
      ampel: () => _leOk(maxT, s.ausloesezeit),
      sichtbar: () => s.hatFi,
    ),
    Pruefschritt(
      titel: t('FI: Auslösestrom AC'),
      hinweis: 'Muss zwischen 0,5×IΔN und 1×IΔN liegen.',
      einheit: 'mA',
      wertLesen: () => s.ausloesestrom,
      wertSchreiben: (v) => s.ausloesestrom = v,
      ampel: () => _bandOk(_num(s.fiIdn), s.ausloesestrom),
      sichtbar: () => s.hatFi,
    ),
    Pruefschritt(
      titel: t('FI Typ B: Auslösestrom DC'),
      hinweis: 'Nur Typ B: DC-Auslösestrom (0,5–1×IΔN).',
      einheit: 'mA',
      wertLesen: () => s.ausloesestromDc,
      wertSchreiben: (v) => s.ausloesestromDc = v,
      ampel: () => _bandOk(_num(s.fiIdn), s.ausloesestromDc),
      sichtbar: () => s.hatFi && s.fiTyp == 'B',
    ),
    Pruefschritt(
      titel: t('FI Typ B: Auslösezeit DC'),
      hinweis: 'Nur Typ B: DC-Auslösezeit. Grenzwert wie AC.',
      einheit: 'ms',
      wertLesen: () => s.ausloesezeitDc,
      wertSchreiben: (v) => s.ausloesezeitDc = v,
      ampel: () => _leOk(maxT, s.ausloesezeitDc),
      sichtbar: () => s.hatFi && s.fiTyp == 'B',
    ),
    Pruefschritt(
      titel: t('Berührungsspannung UB'),
      hinweis: 'Grenzwert ≤ 50 V.',
      einheit: 'V',
      wertLesen: () => s.ub,
      wertSchreiben: (v) => s.ub = v,
      ampel: () => _leOk(50, s.ub),
    ),
  ];
}

/// Voller Stromkreis-Wizard: Phase 1 (Stammdaten) + Phase 2 (Messung).
/// Wird vom per-Stromkreis-Editor und vom Wallbox-Wizard für die Zuleitung
/// verwendet.
List<Pruefschritt> stromkreisSchritte(Stromkreis s, Netzform netz,
    {String prefix = ''}) {
  return [
    ...stromkreisStammdatenSchritte(s, prefix: prefix),
    ...stromkreisMessSchritte(s, netz, prefix: prefix),
  ];
}

/// Erzeugt einen lesbaren Präfix-Namen für die Schritt-Titel im
/// Komplett-Durchgang („Stromkreis 3 · Steckdosen Küche · B16 · ").
String _stromkreisPrefix(Stromkreis s, int index1) {
  final raum = s.stromkreisRaum.trim();
  final sich = s.vorgSicherung != null
      ? '${s.schutzart.label} ${s.vorgSicherung}A'
      : s.schutzart.label;
  final label = raum.isNotEmpty ? '$raum · $sich' : sich;
  return 'Stromkreis $index1 · $label · ';
}

/// Phase 1 des Komplett-Durchgangs: Stammdaten aller Stromkreise am
/// Verteiler ablesen. Wird in der Praxis stromkreisweise aufgerufen –
/// siehe ProtokollEditScreen, das nach jedem Stromkreis fragt
/// „Noch einen?".
List<Pruefschritt> protokollStammdatenSchritte(List<Stromkreis> stromkreise) {
  final out = <Pruefschritt>[];
  for (var i = 0; i < stromkreise.length; i++) {
    out.addAll(stromkreisStammdatenSchritte(
      stromkreise[i],
      prefix: _stromkreisPrefix(stromkreise[i], i + 1),
    ));
  }
  return out;
}

/// Phase 2 des Komplett-Durchgangs: pro Stromkreis alle Messungen am
/// Verbrauchspunkt; danach zum nächsten Stromkreis.
List<Pruefschritt> protokollMessSchritte(
    List<Stromkreis> stromkreise, Netzform netz) {
  final out = <Pruefschritt>[];
  for (var i = 0; i < stromkreise.length; i++) {
    out.addAll(stromkreisMessSchritte(
      stromkreise[i],
      netz,
      prefix: _stromkreisPrefix(stromkreise[i], i + 1),
    ));
  }
  return out;
}

/// Kompletter Wallbox-Prüfablauf: zuerst Zuleitung/FI (Stromkreis), dann die
/// wallbox-spezifischen Messungen und zuletzt die Erprobung (Funktionsprüfung).
/// Hat die Zuleitung einen FI, werden dessen Werte vor dem RCD-Block in den
/// Wallbox-Block übernommen (Typ A: DC bleibt zur separaten Messung).
List<Pruefschritt> wallboxSchritte(WallboxProtokoll p, Stromkreis zuleitung) {
  bool uebernommen = false;

  final block = <Pruefschritt>[
    Pruefschritt(
      titel: 'Sichtprüfung Allgemeinzustand',
      hinweis: 'Beschriftung, Abdeckungen, Einbauteile, Zuordnung, '
          'Spannung/Strom.',
      eingabe: PruefEingabe.jaNein,
      statusLesen: () =>
          p.allgemeinzustandOk ? Pruefstatus.ok : Pruefstatus.nichtOk,
      statusSchreiben: (st) => p.allgemeinzustandOk = st != Pruefstatus.nichtOk,
    ),
    Pruefschritt(
      titel: 'Schutzleiter Ladebuchse / Gehäuse (RLO)',
      hinweis: 'Grenzwert ≤ 0,3 Ω. Anlage spannungsfrei!',
      einheit: 'Ω',
      wertLesen: () => p.schutzleiterLadebuchse,
      wertSchreiben: (v) => p.schutzleiterLadebuchse = v,
      ampel: () => p.schutzleiterStatus,
      vorAnzeige: () {
        if (!uebernommen && zuleitung.hatFi) {
          if (zuleitung.fiIdn.trim().isNotEmpty) p.iDn = zuleitung.fiIdn.trim();
          p.rcdStromAc = zuleitung.ausloesestrom;
          p.rcdZeitAc = zuleitung.ausloesezeit;
          if (zuleitung.fiTyp == 'B') {
            p.rcdStromDc = zuleitung.ausloesestromDc;
            p.rcdZeitDc = zuleitung.ausloesezeitDc;
          }
          uebernommen = true;
        }
      },
    ),
    Pruefschritt(
      titel: 'Isolationswiderstand L/N–PE vor Schütz',
      hinweis: '500 V DC. Grenzwert ≥ 1 MΩ. Anlage spannungsfrei!',
      einheit: 'MΩ',
      groesserErlaubt: true,
      schnellWert: '>500',
      wertLesen: () => p.isoVorSchuetz,
      wertSchreiben: (v) => p.isoVorSchuetz = v,
    ),
    Pruefschritt(
      titel: 'Isolationswiderstand L/N–PE nach Schütz',
      hinweis: 'Messung am Prüfadapter. Grenzwert ≥ 1 MΩ.',
      einheit: 'MΩ',
      groesserErlaubt: true,
      schnellWert: '>500',
      wertLesen: () => p.isoNachSchuetz,
      wertSchreiben: (v) => p.isoNachSchuetz = v,
    ),
    Pruefschritt(
      titel: 'IΔN (RCD der Wallbox)',
      hinweis: 'Bemessungsfehlerstrom, z. B. 30 mA. Basis für das AC-Band.',
      einheit: 'mA',
      wertLesen: () => p.iDn,
      wertSchreiben: (v) => p.iDn = v,
    ),
    Pruefschritt(
      titel: 'RCD Abschaltzeit AC',
      hinweis: 'Grenzwert: TN ≤ 400 ms, TT ≤ 200 ms.',
      einheit: 'ms',
      wertLesen: () => p.rcdZeitAc,
      wertSchreiben: (v) => p.rcdZeitAc = v,
      ampel: () => p.rcdZeitAcStatus,
    ),
    Pruefschritt(
      titel: 'RCD Abschaltstrom AC',
      hinweis: 'Muss zwischen 0,5×IΔN und 1×IΔN liegen.',
      einheit: 'mA',
      wertLesen: () => p.rcdStromAc,
      wertSchreiben: (v) => p.rcdStromAc = v,
      ampel: () => p.rcdStromAcStatus,
    ),
    Pruefschritt(
      titel: 'RCD Abschaltstrom DC',
      hinweis: 'Grenzwert ≤ 6 mA (RDC-DD nach IEC 62955). '
          'Bei Typ-A-FI in der Zuleitung hier separat messen.',
      einheit: 'mA',
      wertLesen: () => p.rcdStromDc,
      wertSchreiben: (v) => p.rcdStromDc = v,
      ampel: () => p.rcdStromDcStatus,
    ),
    Pruefschritt(
      titel: 'RCD Abschaltzeit DC',
      hinweis: 'Nur erfassen (kein fester ms-Grenzwert).',
      einheit: 'ms',
      wertLesen: () => p.rcdZeitDc,
      wertSchreiben: (v) => p.rcdZeitDc = v,
    ),
  ];

  final erprobung = p.erprobung
      .map((e) => Pruefschritt(
            titel: 'Erprobung: ${e.frage}',
            hinweis: 'Funktionsprüfung über Prüfadapter. Ergebnis i.O. / n.i.O.',
            eingabe: PruefEingabe.jaNein,
            statusLesen: () => e.status,
            statusSchreiben: (st) => e.status = st,
          ))
      .toList();

  return [
    ...stromkreisSchritte(zuleitung, p.netzform, prefix: 'Zuleitung – '),
    ...block,
    ...erprobung,
  ];
}
