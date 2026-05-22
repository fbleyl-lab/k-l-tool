import '../models/stromkreis.dart';
import '../models/tabelle6.dart';

/// Erkennt diktierte Messwerte und trägt sie in einen Stromkreis ein.
///
/// Beispiele:
///   "B16"                         -> Charakteristik B, Sicherung 16 A
///   "Spannung 230"                -> 230 V
///   "IK L PE 243"                 -> IK L-PE 243 A
///   "IK L N 255"                  -> IK L-N 255 A
///   "FI IDN 30"                   -> FI/IΔN 30 mA
///   "Auslösestrom 21"             -> 21 mA
///   "Auslösezeit 18"              -> 18 ms
///   "Berührungsspannung 0,3"      -> UB 0,3 V
///   "RLOW 0,42" / "Schutzleiter"  -> RLOW
///   "Iso 550" / "RISO 550"        -> RISO
///   "Länge 24" / "Querschnitt 2,5"
///   "FI Typ B"                    -> FI-Typ B
class MessParser {
  static final _zahl = r'([0-9]+(?:[.,][0-9]+)?)';

  static String? _m(String t, String pattern) {
    final m = RegExp(pattern, caseSensitive: false).firstMatch(t);
    return m?.group(1);
  }

  /// Wendet erkannte Werte auf [s] an und liefert die Namen der erkannten Felder.
  static List<String> anwenden(Stromkreis s, String text) {
    // Normalisieren: Kleinbuchstaben, Ränder mit Leerzeichen.
    final t = ' ${text.toLowerCase().replaceAll('-', ' ')} ';
    final erkannt = <String>[];

    // FI-Typ
    final typ = _m(t, r'\bfi\s*typ\s*(a|b)\b') ?? _m(t, r'\btyp\s*(a|b)\b');
    if (typ != null) {
      s.fiTyp = typ.toUpperCase();
      erkannt.add('FI-Typ ${s.fiTyp}');
    }

    // Charakteristik + Sicherung kombiniert ("b16", "c 16", "gg 35")
    final cs = RegExp(r'\b(gg|b|c|d|k)\s*0*([0-9]{1,3})\s*(?:a|ampere)?\b',
            caseSensitive: false)
        .firstMatch(t);
    if (cs != null) {
      s.schutzart = SchutzartLabel.fromLabel(
          cs.group(1)!.toLowerCase() == 'gg' ? 'gG' : cs.group(1)!.toUpperCase());
      final n = int.tryParse(cs.group(2)!);
      if (n != null && Tabelle6.nennstroeme(s.schutzart).contains(n)) {
        s.vorgSicherung = n;
      }
      erkannt.add('${s.schutzart.label}${s.vorgSicherung ?? ""}');
    } else {
      final si = _m(t, r'\b(?:vor)?sicherung\s*' + _zahl);
      if (si != null) {
        final n = int.tryParse(si);
        if (n != null) {
          s.vorgSicherung = n;
          erkannt.add('Sicherung $n A');
        }
      }
    }

    // Spannung
    final u = _m(t, r'\bspannung\s*' + _zahl);
    if (u != null && (u == '230' || u == '400')) {
      s.spannung = u;
      erkannt.add('Spannung $u V');
    }

    // IK L-PE / IK L-N (spezifisch vor generisch)
    bool ikPe = false, ikN = false;
    final lpe = _m(t, r'(?:ik\s*)?l\s*pe\s*' + _zahl) ??
        _m(t, r'\bpe\s*' + _zahl);
    if (lpe != null) {
      s.ikLpe = lpe;
      erkannt.add('IK L-PE $lpe');
      ikPe = true;
    }
    final ln = _m(t, r'(?:ik\s*)?l\s*n\s*' + _zahl);
    if (ln != null) {
      s.ikLn = ln;
      erkannt.add('IK L-N $ln');
      ikN = true;
    }
    // bare "ik 240" / "kurzschluss 240" -> L-PE, sonst L-N
    if (!ikPe && !ikN) {
      final ik = _m(t, r'\b(?:ik|kurzschluss(?:strom)?)\s*' + _zahl);
      if (ik != null) {
        s.ikLpe = ik;
        erkannt.add('IK L-PE $ik');
      }
    }

    // FI / IΔN (Nennfehlerstrom)
    final idn = _m(t, r'\b(?:fi\s*i\s*d\s*n|i\s*delta\s*n|idn|nennfehlerstrom)\s*' + _zahl);
    if (idn != null) {
      s.fiIdn = idn;
      erkannt.add('FI/IΔN $idn mA');
    }

    // Auslösestrom / Auslösezeit (auch über Einheit)
    final aZeit = _m(t, r'\b(?:aus)?l[öo]se?\s*zeit\s*' + _zahl) ??
        _m(t, r'\babschaltzeit\s*' + _zahl) ??
        _m(t, '$_zahl\\s*(?:ms|millisekunden?)');
    if (aZeit != null) {
      s.ausloesezeit = aZeit;
      erkannt.add('Auslösezeit $aZeit ms');
    }
    final aStrom = _m(t, r'\b(?:aus)?l[öo]se?\s*strom\s*' + _zahl) ??
        _m(t, '$_zahl\\s*(?:ma|milliampere)');
    if (aStrom != null) {
      s.ausloesestrom = aStrom;
      erkannt.add('Auslösestrom $aStrom mA');
    }

    // UB
    final ub = _m(t, r'\b(?:ub|ber[üu]hrungsspannung)\s*' + _zahl);
    if (ub != null) {
      s.ub = ub;
      erkannt.add('UB $ub V');
    }

    // RLOW / Schutzleiter
    final rlow = _m(t, r'\b(?:rlow|r\s*low|schutzleiter|niederohm\w*|durchg\w*)\s*' + _zahl);
    if (rlow != null) {
      s.rlow = rlow;
      erkannt.add('RLOW $rlow Ω');
    }

    // RISO / Isolation
    final riso = _m(t, r'\b(?:riso|r\s*iso|iso(?:lation\w*)?)\s*' + _zahl);
    if (riso != null) {
      s.riso = riso;
      erkannt.add('RISO $riso MΩ');
    }

    // Länge / Querschnitt
    final laenge = _m(t, r'\bl[äa]nge\s*' + _zahl);
    if (laenge != null) {
      s.laenge = laenge;
      erkannt.add('Länge $laenge m');
    }
    final quer = _m(t, r'\bquerschnitt\s*' + _zahl);
    if (quer != null) {
      s.querschnitt = quer.replaceAll('.', ',');
      erkannt.add('Querschnitt $quer mm²');
    }

    return erkannt;
  }
}
