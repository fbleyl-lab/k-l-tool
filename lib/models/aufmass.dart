import 'foto.dart';

/// Eine Position in der Aufmaß-/Materialliste.
class AufmassPosition {
  String bezeichnung;
  String menge;
  String einheit;

  AufmassPosition({
    this.bezeichnung = '',
    this.menge = '',
    this.einheit = 'Stk',
  });

  Map<String, dynamic> toJson() => {
        'bezeichnung': bezeichnung,
        'menge': menge,
        'einheit': einheit,
      };

  factory AufmassPosition.fromJson(Map<String, dynamic> j) => AufmassPosition(
        bezeichnung: j['bezeichnung'] ?? '',
        menge: j['menge'] ?? '',
        einheit: j['einheit'] ?? 'Stk',
      );

  AufmassPosition copy() => AufmassPosition.fromJson(toJson());
}

/// Gängige Einheiten für die Auswahl.
const List<String> aufmassEinheiten = [
  'Stk',
  'm',
  'm²',
  'm³',
  'h',
  'kg',
  'Pkt',
  'Pausch',
];

/// Eine Aufmaß-/Materialliste.
class Aufmass {
  String id;
  DateTime erstelltAm;
  DateTime geaendertAm;
  String titel; // Projekt/Bauvorhaben
  String kunde;
  DateTime? datum;
  List<AufmassPosition> positionen;
  List<Foto> fotos;

  Aufmass({
    required this.id,
    required this.erstelltAm,
    required this.geaendertAm,
    this.titel = '',
    this.kunde = '',
    this.datum,
    List<AufmassPosition>? positionen,
    List<Foto>? fotos,
  })  : positionen = positionen ?? [],
        fotos = fotos ?? [];

  String get anzeigeTitel => titel.trim().isEmpty ? 'Ohne Bezeichnung' : titel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'erstelltAm': erstelltAm.toIso8601String(),
        'geaendertAm': geaendertAm.toIso8601String(),
        'titel': titel,
        'kunde': kunde,
        'datum': datum?.toIso8601String(),
        'positionen': positionen.map((p) => p.toJson()).toList(),
        'fotos': fotos.map((f) => f.toJson()).toList(),
      };

  factory Aufmass.fromJson(Map<String, dynamic> j) => Aufmass(
        id: j['id'],
        erstelltAm: DateTime.parse(j['erstelltAm']),
        geaendertAm: DateTime.parse(j['geaendertAm']),
        titel: j['titel'] ?? '',
        kunde: j['kunde'] ?? '',
        datum: j['datum'] != null ? DateTime.tryParse(j['datum']) : null,
        positionen: (j['positionen'] as List? ?? [])
            .map((e) => AufmassPosition.fromJson(e))
            .toList(),
        fotos:
            (j['fotos'] as List? ?? []).map((e) => Foto.fromJson(e)).toList(),
      );
}
