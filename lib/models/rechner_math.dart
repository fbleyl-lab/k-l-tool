import 'dart:math';

/// Ergebnis der DC-Berechnung (Ohmsches Gesetz + Leistung).
class DcErgebnis {
  final double? u; // V
  final double? i; // A
  final double? r; // Ω
  final double? p; // W
  final String hinweis;
  const DcErgebnis({this.u, this.i, this.r, this.p, this.hinweis = ''});
}

/// Löst U/I/R/P, wenn genau zwei Größen gegeben sind.
DcErgebnis dcLoese(double? u, double? i, double? r, double? p) {
  bool ok(double? x) => x != null && x > 0;
  final anzahl = [u, i, r, p].where(ok).length;
  if (anzahl < 2) {
    return const DcErgebnis(hinweis: 'Mindestens 2 Werte eingeben.');
  }
  if (anzahl > 2) {
    return const DcErgebnis(hinweis: 'Bitte genau 2 Werte eingeben.');
  }
  double? uu = u, ii = i, rr = r, pp = p;
  if (ok(u) && ok(i)) {
    rr = u! / i!;
    pp = u * i;
  } else if (ok(u) && ok(r)) {
    ii = u! / r!;
    pp = u * u / r;
  } else if (ok(u) && ok(p)) {
    ii = p! / u!;
    rr = u * u / p;
  } else if (ok(i) && ok(r)) {
    uu = i! * r!;
    pp = i * i * r;
  } else if (ok(i) && ok(p)) {
    uu = p! / i!;
    rr = p / (i * i);
  } else if (ok(r) && ok(p)) {
    uu = sqrt(p! * r!);
    ii = sqrt(p / r);
  }
  return DcErgebnis(u: uu, i: ii, r: rr, p: pp);
}

/// Ergebnis der AC-Berechnung (Wirk-, Schein-, Blindleistung).
class AcErgebnis {
  final double u; // V (1~: Strangspannung, 3~: Außenleiterspannung)
  final double i; // A
  final double p; // W (Wirkleistung)
  final double s; // VA (Scheinleistung)
  final double q; // var (Blindleistung)
  final double cosPhi;
  const AcErgebnis(
      {required this.u,
      required this.i,
      required this.p,
      required this.s,
      required this.q,
      required this.cosPhi});
}

/// AC-Berechnung. [dreiphasig] = Drehstrom (Faktor √3).
/// Es muss U, cosφ und genau einer von I oder P gegeben sein.
AcErgebnis? acLoese({
  required bool dreiphasig,
  required double u,
  required double cosPhi,
  double? i,
  double? p,
}) {
  if (u <= 0 || cosPhi <= 0 || cosPhi > 1) return null;
  final f = dreiphasig ? sqrt(3) : 1.0;
  double strom, wirk, schein;
  if (i != null && i > 0) {
    strom = i;
    schein = f * u * strom;
    wirk = schein * cosPhi;
  } else if (p != null && p > 0) {
    wirk = p;
    strom = p / (f * u * cosPhi);
    schein = f * u * strom;
  } else {
    return null;
  }
  final blind = sqrt(max(0, schein * schein - wirk * wirk));
  return AcErgebnis(
      u: u, i: strom, p: wirk, s: schein, q: blind, cosPhi: cosPhi);
}
