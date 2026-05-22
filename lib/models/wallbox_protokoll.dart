import 'foto.dart';
import 'protokoll.dart' show Firma, Netzform, NetzformLabel, Pruefungsart;
import 'stromkreis.dart' show Pruefstatus, Stromkreis;

/// Die festen Erprobungs-Fragen (Funktionsprüfung) aus dem Wallbox-Muster.
/// Reihenfolge = Anzeige- und Druckreihenfolge.
const List<String> erprobungsFragen = [
  'Freischaltung (Schlüssel / RFID / App)',
  'Status B: Buchse hat verriegelt',
  'Status C: Ladeschütz zugeschaltet, Spannung an Ladebuchse',
  'Status E: Fehlersimulation am Auto – Ladeschütz hat abgeschaltet',
  'Status A: Buchse hat entriegelt',
  'PP Stellung N.C.: Wallbox schaltet ab',
  'CP Fahrzeugsimulation (Zustände A / B / C / E)',
];

/// Ein einzelner Erprobungspunkt mit 3-Status (offen / i.O. / n.i.O.).
class Erprobungspunkt {
  final String frage;
  Pruefstatus status;

  Erprobungspunkt(this.frage, [this.status = Pruefstatus.offen]);

  /// Standardliste aller Erprobungs-Fragen im Status „offen".
  static List<Erprobungspunkt> standardliste() =>
      erprobungsFragen.map((f) => Erprobungspunkt(f)).toList();

  Map<String, dynamic> toJson() => {'frage': frage, 'status': status.name};

  factory Erprobungspunkt.fromJson(Map<String, dynamic> j) => Erprobungspunkt(
        j['frage'] ?? '',
        Pruefstatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => Pruefstatus.offen,
        ),
      );
}

/// Ein vollständiges Wallbox-Messprotokoll (Layout nach Firmen-Muster).
///
/// Der Aufbau spiegelt das VDE-0100-600-Protokoll: gleicher Kopf, gleiche
/// Stromkreis-Tabelle (inkl. Bewertung), zusätzlich wallbox-spezifische
/// Messungen und die Erprobung (Funktionsprüfung).
class WallboxProtokoll {
  String id;
  DateTime erstelltAm;
  DateTime geaendertAm;

  // Kopfdaten
  String eigentuemer;
  String standort;
  String adresse;
  String bezeichnung; // Wallbox-Typ / Bezeichnung (für Titel & Dateiname)
  String name; // Prüfer / Gemessen von
  DateTime? datum;
  String firma;
  String messgeraet;
  Netzform netzform;
  Pruefungsart pruefungsart;
  String unterschriftMonteur;
  String unterschriftKunde;
  String signaturMonteur; // base64-PNG
  String signaturKunde;

  // Besichtigung
  bool allgemeinzustandOk;

  // Bemessungsfehlerstrom IΔN des Wallbox-RCD [mA] (für AC-Strom-Bewertung).
  String iDn;

  // Wallbox-spezifische Messwerte (Eingabe als Text mit Dezimalkomma).
  String schutzleiterLadebuchse; // Ω (Grenzwert ≤ 0,3)
  String isoVorSchuetz; // MΩ (nur erfasst)
  String isoNachSchuetz; // MΩ (nur erfasst)
  String rcdZeitAc; // ms (≤ Netzform-Grenze)
  String rcdStromAc; // mA (0,5–1×IΔN)
  String rcdZeitDc; // ms (nur erfasst)
  String rcdStromDc; // mA (≤ 6, RDC-DD nach IEC 62955)

  List<Erprobungspunkt> erprobung;
  List<Stromkreis> stromkreise;
  String bemerkungen;
  List<Foto> fotos;

  WallboxProtokoll({
    required this.id,
    required this.erstelltAm,
    required this.geaendertAm,
    this.eigentuemer = '',
    this.standort = '',
    this.adresse = '',
    this.bezeichnung = '',
    this.name = '',
    this.datum,
    this.firma = Firma.name,
    this.messgeraet = 'Gossen Metrawatt MXTRA',
    this.netzform = Netzform.tn,
    this.pruefungsart = Pruefungsart.erstpruefung,
    this.unterschriftMonteur = '',
    this.unterschriftKunde = '',
    this.signaturMonteur = '',
    this.signaturKunde = '',
    this.allgemeinzustandOk = true,
    this.iDn = '30',
    this.schutzleiterLadebuchse = '',
    this.isoVorSchuetz = '',
    this.isoNachSchuetz = '',
    this.rcdZeitAc = '',
    this.rcdStromAc = '',
    this.rcdZeitDc = '',
    this.rcdStromDc = '',
    List<Erprobungspunkt>? erprobung,
    List<Stromkreis>? stromkreise,
    this.bemerkungen = '',
    List<Foto>? fotos,
  })  : erprobung = erprobung ?? Erprobungspunkt.standardliste(),
        stromkreise = stromkreise ?? [],
        fotos = fotos ?? [];

  /// Anzeigetitel für Listen.
  String get titel {
    final parts = [bezeichnung, eigentuemer, standort]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Wallbox ohne Bezeichnung' : parts.take(2).join(' · ');
  }

  static double? _num(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.').trim());

  double? get iDnValue => _num(iDn);

  /// Schutzleiter an Ladebuchse/Gehäuse: RLO ≤ 0,3 Ω.
  Pruefstatus get schutzleiterStatus {
    final r = _num(schutzleiterLadebuchse);
    if (r == null) return Pruefstatus.offen;
    return r <= 0.3 ? Pruefstatus.ok : Pruefstatus.nichtOk;
  }

  /// RCD-Abschaltzeit AC: ≤ Netzform-Grenze (TN 400 ms / TT 200 ms).
  Pruefstatus get rcdZeitAcStatus {
    final t = _num(rcdZeitAc);
    if (t == null) return Pruefstatus.offen;
    return t <= netzform.maxAusloesezeitMs
        ? Pruefstatus.ok
        : Pruefstatus.nichtOk;
  }

  /// RCD-Abschaltstrom AC: zwischen 0,5×IΔN und 1×IΔN.
  Pruefstatus get rcdStromAcStatus {
    final i = _num(rcdStromAc);
    final idn = iDnValue;
    if (i == null || idn == null) return Pruefstatus.offen;
    return (i >= 0.5 * idn && i <= idn)
        ? Pruefstatus.ok
        : Pruefstatus.nichtOk;
  }

  /// RCD-Abschaltstrom DC: ≤ 6 mA (RDC-DD nach IEC 62955).
  Pruefstatus get rcdStromDcStatus {
    final i = _num(rcdStromDc);
    if (i == null) return Pruefstatus.offen;
    return i <= 6 ? Pruefstatus.ok : Pruefstatus.nichtOk;
  }

  /// Liste der bewerteten Messwerte (Label, Status) – für Anzeige und PDF.
  /// rcdZeitDc, isoVorSchuetz, isoNachSchuetz werden bewusst nur erfasst.
  List<MapEntry<String, Pruefstatus>> get bewerteteMesswerte => [
        MapEntry('Schutzleiter ≤ 0,3 Ω', schutzleiterStatus),
        MapEntry('RCD Abschaltzeit AC', rcdZeitAcStatus),
        MapEntry('RCD Abschaltstrom AC (0,5–1×IΔN)', rcdStromAcStatus),
        MapEntry('RCD Abschaltstrom DC ≤ 6 mA', rcdStromDcStatus),
      ];

  /// true, wenn irgendein bewerteter Punkt n.i.O. ist (Mess- oder Funktion).
  bool get hatMangel {
    final messNok =
        bewerteteMesswerte.any((e) => e.value == Pruefstatus.nichtOk);
    final erprobNok = erprobung.any((e) => e.status == Pruefstatus.nichtOk);
    final kreisNok = stromkreise.any((s) =>
        s.bewerten(maxAusloesezeitMs: netzform.maxAusloesezeitMs).status ==
        Pruefstatus.nichtOk);
    return messNok || erprobNok || kreisNok || !allgemeinzustandOk;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'erstelltAm': erstelltAm.toIso8601String(),
        'geaendertAm': geaendertAm.toIso8601String(),
        'eigentuemer': eigentuemer,
        'standort': standort,
        'adresse': adresse,
        'bezeichnung': bezeichnung,
        'name': name,
        'datum': datum?.toIso8601String(),
        'firma': firma,
        'messgeraet': messgeraet,
        'netzform': netzform.label,
        'pruefungsart': pruefungsart == Pruefungsart.wiederholungspruefung
            ? 'wiederholung'
            : 'erst',
        'unterschriftMonteur': unterschriftMonteur,
        'unterschriftKunde': unterschriftKunde,
        'signaturMonteur': signaturMonteur,
        'signaturKunde': signaturKunde,
        'allgemeinzustandOk': allgemeinzustandOk,
        'iDn': iDn,
        'schutzleiterLadebuchse': schutzleiterLadebuchse,
        'isoVorSchuetz': isoVorSchuetz,
        'isoNachSchuetz': isoNachSchuetz,
        'rcdZeitAc': rcdZeitAc,
        'rcdStromAc': rcdStromAc,
        'rcdZeitDc': rcdZeitDc,
        'rcdStromDc': rcdStromDc,
        'erprobung': erprobung.map((e) => e.toJson()).toList(),
        'stromkreise': stromkreise.map((s) => s.toJson()).toList(),
        'bemerkungen': bemerkungen,
        'fotos': fotos.map((f) => f.toJson()).toList(),
      };

  factory WallboxProtokoll.fromJson(Map<String, dynamic> j) {
    final erprobListe = (j['erprobung'] as List? ?? [])
        .map((e) => Erprobungspunkt.fromJson(e))
        .toList();
    return WallboxProtokoll(
      id: j['id'],
      erstelltAm: DateTime.parse(j['erstelltAm']),
      geaendertAm: DateTime.parse(j['geaendertAm']),
      eigentuemer: j['eigentuemer'] ?? '',
      standort: j['standort'] ?? '',
      adresse: j['adresse'] ?? '',
      bezeichnung: j['bezeichnung'] ?? '',
      name: j['name'] ?? '',
      datum: j['datum'] != null ? DateTime.tryParse(j['datum']) : null,
      firma: j['firma'] ?? Firma.name,
      messgeraet: j['messgeraet'] ?? 'Gossen Metrawatt MXTRA',
      netzform: NetzformLabel.fromLabel(j['netzform'] ?? 'TN'),
      pruefungsart: j['pruefungsart'] == 'wiederholung'
          ? Pruefungsart.wiederholungspruefung
          : Pruefungsart.erstpruefung,
      unterschriftMonteur: j['unterschriftMonteur'] ?? '',
      unterschriftKunde: j['unterschriftKunde'] ?? '',
      signaturMonteur: j['signaturMonteur'] ?? '',
      signaturKunde: j['signaturKunde'] ?? '',
      allgemeinzustandOk: j['allgemeinzustandOk'] ?? true,
      iDn: (j['iDn'] ?? '30').toString(),
      schutzleiterLadebuchse: j['schutzleiterLadebuchse'] ?? '',
      isoVorSchuetz: j['isoVorSchuetz'] ?? '',
      isoNachSchuetz: j['isoNachSchuetz'] ?? '',
      rcdZeitAc: j['rcdZeitAc'] ?? '',
      rcdStromAc: j['rcdStromAc'] ?? '',
      rcdZeitDc: j['rcdZeitDc'] ?? '',
      rcdStromDc: j['rcdStromDc'] ?? '',
      erprobung:
          erprobListe.isEmpty ? Erprobungspunkt.standardliste() : erprobListe,
      stromkreise: (j['stromkreise'] as List? ?? [])
          .map((e) => Stromkreis.fromJson(e))
          .toList(),
      bemerkungen: j['bemerkungen'] ?? '',
      fotos: (j['fotos'] as List? ?? []).map((e) => Foto.fromJson(e)).toList(),
    );
  }
}
