import 'dart:math';

import 'kabel_daten.dart';

/// Eingabeparameter für die Auslegung.
class KabelEingabe {
  final Leiter leiter;
  final String verlegeart;
  final double strom; // Betriebsstrom Ib [A]
  final double laenge; // einfache Länge [m]
  final int spannung; // 230 oder 400
  final double duGrenzeProzent; // zulässiger Spannungsfall [%]
  final int? sicherung; // optional vorgegebene Sicherung [A]

  const KabelEingabe({
    this.leiter = Leiter.cu,
    required this.verlegeart,
    required this.strom,
    required this.laenge,
    required this.spannung,
    required this.duGrenzeProzent,
    this.sicherung,
  });
}

class KabelErgebnis {
  final double? querschnitt; // empfohlener Querschnitt [mm²] (null = >50)
  final double? minStrom; // nach Strombelastbarkeit
  final double? minSicherung; // nach Sicherungsschutz
  final double? minDu; // nach Spannungsfall
  final int? sicherung; // verwendete Sicherung [A]
  final double? iz; // Iz beim Ergebnis-Querschnitt
  final double? duProzent; // Spannungsfall beim Ergebnis-Querschnitt
  final String hinweis;

  const KabelErgebnis({
    this.querschnitt,
    this.minStrom,
    this.minSicherung,
    this.minDu,
    this.sicherung,
    this.iz,
    this.duProzent,
    this.hinweis = '',
  });
}

class KabelRechner {
  /// Spannungsfall in % für einen Querschnitt.
  static double spannungsfallProzent({
    required double laenge,
    required double strom,
    required double querschnitt,
    required int spannung,
    double kappa = 56,
  }) {
    // 1-phasig (230 V): Hin- und Rückleiter -> Faktor 2
    // 3-phasig (400 V): Faktor √3
    final faktor = spannung >= 400 ? sqrt(3) : 2.0;
    final du = faktor * laenge * strom / (kappa * querschnitt);
    return du / spannung * 100;
  }

  static KabelErgebnis berechne(KabelEingabe e) {
    // Sicherung bestimmen: vorgegeben oder aus dem Strom abgeleitet.
    final sicherung = e.sicherung ?? KabelDaten.sicherungFuer(e.strom);
    if (e.strom <= 0 && sicherung == null) {
      return const KabelErgebnis(hinweis: 'Bitte Strom/Leistung oder Sicherung eingeben.');
    }
    if (sicherung == null) {
      return const KabelErgebnis(hinweis: 'Strom zu hoch für die Tabelle.');
    }
    final kappa = e.leiter.kappa;
    // Nur Sicherung gegeben (Hensel-Prinzip): Strom für Spannungsfall
    // konservativ = Sicherungs-Nennstrom.
    final nurSicherung = e.strom <= 0;
    final ibDu = nurSicherung ? sicherung.toDouble() : e.strom;

    double? minStrom, minSicherung, minDu;

    for (final q in KabelDaten.querschnitteFuer(e.leiter)) {
      final w = KabelDaten.wert(e.leiter, e.verlegeart, q);
      if (w == null) continue;
      // 1) Strombelastbarkeit: Iz >= Ib (nur wenn Strom bekannt)
      if (!nurSicherung) minStrom ??= (w.iz >= e.strom) ? q : null;
      // 2) Sicherungsschutz: gewählte Sicherung <= zulässige In des Querschnitts
      minSicherung ??= (sicherung <= w.inMax) ? q : null;
      // 3) Spannungsfall (nur wenn Länge angegeben)
      if (e.laenge > 0) {
        final du = spannungsfallProzent(
            laenge: e.laenge,
            strom: ibDu,
            querschnitt: q,
            spannung: e.spannung,
            kappa: kappa);
        minDu ??= (du <= e.duGrenzeProzent) ? q : null;
      }
    }

    // Ergebnis = größter der relevanten Mindestquerschnitte.
    final kandidaten = [minStrom, minSicherung, minDu].whereType<double>();
    final ausreichend =
        minSicherung != null && (nurSicherung || minStrom != null);
    if (kandidaten.isEmpty || !ausreichend) {
      return KabelErgebnis(
        minStrom: minStrom,
        minSicherung: minSicherung,
        minDu: minDu,
        sicherung: sicherung,
        hinweis: 'Kein Querschnitt im Bereich ausreichend – größere '
            'Dimension/andere Verlegeart nötig.',
      );
    }
    final ergebnis = kandidaten.reduce(max);
    final w = KabelDaten.wert(e.leiter, e.verlegeart, ergebnis)!;
    final du = spannungsfallProzent(
        laenge: e.laenge,
        strom: ibDu,
        querschnitt: ergebnis,
        spannung: e.spannung,
        kappa: kappa);

    return KabelErgebnis(
      querschnitt: ergebnis,
      minStrom: minStrom,
      minSicherung: minSicherung,
      minDu: minDu,
      sicherung: sicherung,
      iz: w.iz,
      duProzent: du,
    );
  }
}
