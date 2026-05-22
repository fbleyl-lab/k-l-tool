import 'dart:math';

import 'kabel_daten.dart' show KabelDaten;

/// Anlaufverfahren eines Drehstrommotors.
enum Anlaufart { dol, sternDreieck, sanft, fu }

extension AnlaufartInfo on Anlaufart {
  String get label {
    switch (this) {
      case Anlaufart.dol:
        return 'Direktanlauf (DOL)';
      case Anlaufart.sternDreieck:
        return 'Stern-Dreieck';
      case Anlaufart.sanft:
        return 'Sanftanlauf';
      case Anlaufart.fu:
        return 'Frequenzumrichter';
    }
  }

  /// Typischer Anlaufstrom als Vielfaches von Iₙ (Richtwert).
  String get anlaufVielfaches {
    switch (this) {
      case Anlaufart.dol:
        return '6–8 × Iₙ';
      case Anlaufart.sternDreieck:
        return '2–2,5 × Iₙ';
      case Anlaufart.sanft:
        return '2–4 × Iₙ';
      case Anlaufart.fu:
        return '≈ 1–1,5 × Iₙ';
    }
  }

  /// Faustfaktor für die gG-Sicherungsgröße (so dass der Anlauf
  /// nicht zum Auslösen führt). Richtwert – Herstellertabelle beachten.
  double get gGFaktor {
    switch (this) {
      case Anlaufart.dol:
        return 2.0;
      case Anlaufart.sternDreieck:
        return 1.6;
      case Anlaufart.sanft:
        return 1.5;
      case Anlaufart.fu:
        return 1.0;
    }
  }
}

class MotorEingabe {
  final double? leistungKw; // wenn null -> inDirekt verwenden
  final double? inDirekt; // Motor-Nennstrom direkt [A]
  final int spannung; // 230 (1~) oder 400 (3~)
  final double cosPhi;
  final double wirkungsgrad; // η (0..1)
  final Anlaufart anlaufart;

  const MotorEingabe({
    this.leistungKw,
    this.inDirekt,
    this.spannung = 400,
    this.cosPhi = 0.85,
    this.wirkungsgrad = 0.87,
    this.anlaufart = Anlaufart.dol,
  });
}

class MotorErgebnis {
  final double inMotor; // Motor-Nennstrom [A]
  final int? gGSicherung; // empfohlene gG-Sicherung [A]
  final int? aMSicherung; // alternative aM-Sicherung [A]
  final String hinweis;
  const MotorErgebnis({
    required this.inMotor,
    this.gGSicherung,
    this.aMSicherung,
    this.hinweis = '',
  });
}

class MotorRechner {
  /// Motor-Nennstrom aus Leistung: 3~: P/(√3·U·cosφ·η); 1~: P/(U·cosφ·η).
  static double nennstrom(MotorEingabe e) {
    if (e.inDirekt != null && e.inDirekt! > 0) return e.inDirekt!;
    final p = (e.leistungKw ?? 0) * 1000.0; // W
    if (p <= 0) return 0;
    final nenner = e.spannung >= 400
        ? sqrt(3) * 400 * e.cosPhi * e.wirkungsgrad
        : 230 * e.cosPhi * e.wirkungsgrad;
    return nenner > 0 ? p / nenner : 0;
  }

  static int? _naechste(double wert) {
    for (final s in KabelDaten.sicherungen) {
      if (s >= wert) return s;
    }
    return null;
  }

  static MotorErgebnis berechne(MotorEingabe e) {
    final inM = nennstrom(e);
    if (inM <= 0) {
      return const MotorErgebnis(inMotor: 0, hinweis: 'Leistung oder Iₙ eingeben.');
    }
    final gG = _naechste(inM * e.anlaufart.gGFaktor);
    final aM = _naechste(inM); // aM-Sicherungen ~ Iₙ (für Motoranlauf ausgelegt)
    return MotorErgebnis(
      inMotor: inM,
      gGSicherung: gG,
      aMSicherung: aM,
    );
  }
}
