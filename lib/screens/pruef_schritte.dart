import '../models/protokoll.dart' show Netzform, NetzformLabel;
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../models/wallbox_protokoll.dart';
import 'gefuehrte_pruefung_screen.dart';

double? _num(String s) =>
    s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.').trim());

/// Prüfschritte für einen Stromkreis nach VDE 0100-600, in normgerechter
/// Reihenfolge: erst spannungsfrei (Durchgängigkeit, Isolation), dann unter
/// Spannung (Kurzschlussstrom, FI), zuletzt Berührungsspannung.
List<Pruefschritt> stromkreisSchritte(Stromkreis s, Netzform netz,
    {String prefix = ''}) {
  bool fi = s.hatFi;

  Pruefstatus leOk(String v, double max) {
    final x = _num(v);
    if (x == null) return Pruefstatus.offen;
    return x <= max ? Pruefstatus.ok : Pruefstatus.nichtOk;
  }

  Pruefstatus geOk(String v, double? min) {
    final x = _num(v);
    if (x == null || min == null) return Pruefstatus.offen;
    return x >= min ? Pruefstatus.ok : Pruefstatus.nichtOk;
  }

  Pruefstatus bandOk(String v) {
    final x = _num(v);
    final idn = _num(s.fiIdn);
    if (x == null || idn == null) return Pruefstatus.offen;
    return (x >= 0.5 * idn && x <= idn) ? Pruefstatus.ok : Pruefstatus.nichtOk;
  }

  final maxT = netz.maxAusloesezeitMs.toDouble();
  String t(String x) => prefix.isEmpty ? x : '$prefix$x';

  return [
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
    Pruefschritt(
      titel: t('Durchgängigkeit Schutzleiter (RLOW)'),
      hinweis: 'Niederohmige Durchgängigkeit. Grenzwert ≤ 1 Ω. '
          'Anlage spannungsfrei messen!',
      einheit: 'Ω',
      wertLesen: () => s.rlow,
      wertSchreiben: (v) => s.rlow = v,
      ampel: () => leOk(s.rlow, 1),
    ),
    Pruefschritt(
      titel: t('Isolationswiderstand (RISO)'),
      hinweis: '500 V DC zwischen L/N und PE. Grenzwert ≥ 1 MΩ. '
          'Anlage spannungsfrei!',
      einheit: 'MΩ',
      groesserErlaubt: true,
      wertLesen: () => s.riso,
      wertSchreiben: (v) => s.riso = v,
    ),
    Pruefschritt(
      titel: t('FI/RCD vorhanden?'),
      hinweis: 'Ist dieser Stromkreis über einen FI/RCD geschützt?',
      eingabe: PruefEingabe.auswahl,
      optionen: () => const ['Ja', 'Nein'],
      wertLesen: () => fi ? 'Ja' : 'Nein',
      wertSchreiben: (v) {
        fi = v == 'Ja';
        if (!fi) {
          s.fiIdn = '';
          s.ausloesestrom = '';
          s.ausloesezeit = '';
          s.ausloesestromDc = '';
          s.ausloesezeitDc = '';
        }
      },
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
      ampel: () => geOk(s.ikLn, s.erforderlicherIkValue),
    ),
    Pruefschritt(
      titel: t('Kurzschlussstrom IK L-PE'),
      hinweis: 'Muss ≥ erforderlicher IK sein. Bei FI entfällt diese Messung.',
      einheit: 'A',
      wertLesen: () => s.ikLpe,
      wertSchreiben: (v) => s.ikLpe = v,
      ampel: () => geOk(s.ikLpe, s.erforderlicherIkValue),
      sichtbar: () => !fi,
    ),
    Pruefschritt(
      titel: t('FI: Bemessungsfehlerstrom IΔN'),
      hinweis: 'IΔN des FI/RCD, z. B. 30 mA.',
      einheit: 'mA',
      wertLesen: () => s.fiIdn,
      wertSchreiben: (v) => s.fiIdn = v,
      sichtbar: () => fi,
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
      titel: t('FI: Auslösezeit AC'),
      hinweis: 'Auslösezeit bei IΔN. Grenzwert: TN ≤ 400 ms, TT ≤ 200 ms.',
      einheit: 'ms',
      wertLesen: () => s.ausloesezeit,
      wertSchreiben: (v) => s.ausloesezeit = v,
      ampel: () => leOk(s.ausloesezeit, maxT),
      sichtbar: () => fi,
    ),
    Pruefschritt(
      titel: t('FI: Auslösestrom AC'),
      hinweis: 'Muss zwischen 0,5×IΔN und 1×IΔN liegen.',
      einheit: 'mA',
      wertLesen: () => s.ausloesestrom,
      wertSchreiben: (v) => s.ausloesestrom = v,
      ampel: () => bandOk(s.ausloesestrom),
      sichtbar: () => fi,
    ),
    Pruefschritt(
      titel: t('FI Typ B: Auslösestrom DC'),
      hinweis: 'Nur Typ B: DC-Auslösestrom (0,5–1×IΔN).',
      einheit: 'mA',
      wertLesen: () => s.ausloesestromDc,
      wertSchreiben: (v) => s.ausloesestromDc = v,
      ampel: () => bandOk(s.ausloesestromDc),
      sichtbar: () => fi && s.fiTyp == 'B',
    ),
    Pruefschritt(
      titel: t('FI Typ B: Auslösezeit DC'),
      hinweis: 'Nur Typ B: DC-Auslösezeit. Grenzwert wie AC.',
      einheit: 'ms',
      wertLesen: () => s.ausloesezeitDc,
      wertSchreiben: (v) => s.ausloesezeitDc = v,
      ampel: () => leOk(s.ausloesezeitDc, maxT),
      sichtbar: () => fi && s.fiTyp == 'B',
    ),
    Pruefschritt(
      titel: t('Berührungsspannung UB'),
      hinweis: 'Grenzwert ≤ 50 V.',
      einheit: 'V',
      wertLesen: () => s.ub,
      wertSchreiben: (v) => s.ub = v,
      ampel: () => leOk(s.ub, 50),
    ),
  ];
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
      wertLesen: () => p.isoVorSchuetz,
      wertSchreiben: (v) => p.isoVorSchuetz = v,
    ),
    Pruefschritt(
      titel: 'Isolationswiderstand L/N–PE nach Schütz',
      hinweis: 'Messung am Prüfadapter. Grenzwert ≥ 1 MΩ.',
      einheit: 'MΩ',
      groesserErlaubt: true,
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
