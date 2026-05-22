import 'foto.dart';
import 'stromkreis.dart';

enum Pruefungsart { erstpruefung, wiederholungspruefung }

enum Netzform { tn, tt, it }

extension NetzformLabel on Netzform {
  String get label {
    switch (this) {
      case Netzform.tn:
        return 'TN';
      case Netzform.tt:
        return 'TT';
      case Netzform.it:
        return 'IT';
    }
  }

  static Netzform fromLabel(String s) {
    switch (s) {
      case 'TT':
        return Netzform.tt;
      case 'IT':
        return Netzform.it;
      default:
        return Netzform.tn;
    }
  }

  /// Maximale FI-Auslösezeit für die Beurteilung: TT 200 ms, sonst 400 ms.
  int get maxAusloesezeitMs => this == Netzform.tt ? 200 : 400;
}

/// Feste Firmendaten (erscheinen im PDF-Kopf neben dem Logo).
class Firma {
  static const String name = 'Kirner & Lilla Elektrofachbetrieb GmbH';
  static const String strasse = 'Am Sportplatz 19';
  static const String ort = '86672 Thierhaupten';
}

/// Ein vollständiges Messprotokoll nach VDE 0100-600.
class Protokoll {
  String id;
  DateTime erstelltAm;
  DateTime geaendertAm;

  // Kopfdaten
  String gebName;
  String gebNr;
  String name; // Prüfer / Gemessen von
  DateTime? datum;
  String anlagenbez;
  String firma;
  String unterschriftMonteur; // Name in Druckschrift
  String unterschriftKunde;
  String signaturMonteur; // base64-PNG der gezeichneten Unterschrift
  String signaturKunde;
  Pruefungsart pruefungsart;
  String messgeraet;
  Netzform netzform;

  // Besichtigung
  bool allgemeinzustandOk;
  bool drehfeldOk;

  // Freie Bemerkungen zum Protokoll
  String bemerkungen;

  List<Stromkreis> stromkreise;
  List<Foto> fotos;

  Protokoll({
    required this.id,
    required this.erstelltAm,
    required this.geaendertAm,
    this.gebName = '',
    this.gebNr = '',
    this.name = '',
    this.datum,
    this.anlagenbez = '',
    this.firma = Firma.name,
    this.unterschriftMonteur = '',
    this.unterschriftKunde = '',
    this.signaturMonteur = '',
    this.signaturKunde = '',
    this.pruefungsart = Pruefungsart.erstpruefung,
    this.messgeraet = 'Gossen Metrawatt MXTRA',
    this.netzform = Netzform.tn,
    this.allgemeinzustandOk = true,
    this.drehfeldOk = true,
    this.bemerkungen = '',
    List<Stromkreis>? stromkreise,
    List<Foto>? fotos,
  })  : stromkreise = stromkreise ?? [],
        fotos = fotos ?? [];

  /// Anzeigetitel für Listen.
  String get titel {
    final parts = [anlagenbez, gebName].where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? 'Ohne Bezeichnung' : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'erstelltAm': erstelltAm.toIso8601String(),
        'geaendertAm': geaendertAm.toIso8601String(),
        'gebName': gebName,
        'gebNr': gebNr,
        'name': name,
        'datum': datum?.toIso8601String(),
        'anlagenbez': anlagenbez,
        'firma': firma,
        'unterschriftMonteur': unterschriftMonteur,
        'unterschriftKunde': unterschriftKunde,
        'signaturMonteur': signaturMonteur,
        'signaturKunde': signaturKunde,
        'pruefungsart': pruefungsart == Pruefungsart.wiederholungspruefung
            ? 'wiederholung'
            : 'erst',
        'messgeraet': messgeraet,
        'netzform': netzform.label,
        'allgemeinzustandOk': allgemeinzustandOk,
        'drehfeldOk': drehfeldOk,
        'bemerkungen': bemerkungen,
        'stromkreise': stromkreise.map((s) => s.toJson()).toList(),
        'fotos': fotos.map((f) => f.toJson()).toList(),
      };

  factory Protokoll.fromJson(Map<String, dynamic> j) => Protokoll(
        id: j['id'],
        erstelltAm: DateTime.parse(j['erstelltAm']),
        geaendertAm: DateTime.parse(j['geaendertAm']),
        gebName: j['gebName'] ?? '',
        gebNr: j['gebNr'] ?? '',
        name: j['name'] ?? '',
        datum: j['datum'] != null ? DateTime.tryParse(j['datum']) : null,
        anlagenbez: j['anlagenbez'] ?? '',
        firma: j['firma'] ?? Firma.name,
        unterschriftMonteur: j['unterschriftMonteur'] ?? '',
        unterschriftKunde: j['unterschriftKunde'] ?? '',
        signaturMonteur: j['signaturMonteur'] ?? '',
        signaturKunde: j['signaturKunde'] ?? '',
        pruefungsart: j['pruefungsart'] == 'wiederholung'
            ? Pruefungsart.wiederholungspruefung
            : Pruefungsart.erstpruefung,
        messgeraet: j['messgeraet'] ?? 'Gossen Metrawatt MXTRA',
        netzform: NetzformLabel.fromLabel(j['netzform'] ?? 'TN'),
        allgemeinzustandOk: j['allgemeinzustandOk'] ?? true,
        drehfeldOk: j['drehfeldOk'] ?? true,
        bemerkungen: j['bemerkungen'] ?? '',
        stromkreise: (j['stromkreise'] as List? ?? [])
            .map((e) => Stromkreis.fromJson(e))
            .toList(),
        fotos: (j['fotos'] as List? ?? [])
            .map((e) => Foto.fromJson(e))
            .toList(),
      );
}
