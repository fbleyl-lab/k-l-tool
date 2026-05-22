import 'dart:math';

/// Geostationärer Satellit (Längengrad in Grad Ost, West = negativ).
class Satellit {
  final String name;
  final double laengengrad;
  const Satellit(this.name, this.laengengrad);
}

/// Gängige Satelliten für den deutschen Markt.
const satelliten = <Satellit>[
  Satellit('Astra 1 – 19,2° Ost', 19.2), // ARD/ZDF/RTL/Sat.1/ProSieben …
  Satellit('Hotbird – 13,0° Ost', 13.0), // Eutelsat
  Satellit('Astra 3 – 23,5° Ost', 23.5),
  Satellit('Astra 2 – 28,2° Ost', 28.2), // UK (Sky/Freesat)
];

/// Ergebnis der Antennen-Ausrichtung.
class SatAusrichtung {
  /// Azimut bezogen auf **geografisch** Nord, 0–360°.
  final double azimut;

  /// Elevation (Neigung) in Grad. Negativ = Satellit unter dem Horizont.
  final double elevation;

  /// LNB-Skew (Polarisationsdrehung) in Grad.
  final double skew;

  /// Ob der Satellit über dem Horizont steht (Elevation > 0).
  bool get sichtbar => elevation > 0;

  const SatAusrichtung(
      {required this.azimut, required this.elevation, required this.skew});
}

const double _grad = 180.0 / pi;
const double _rad = pi / 180.0;
const double _reKm = 6378.137; // Erdradius (WGS84-Äquator)
const double _rsKm = 42164.0; // geostationärer Bahnradius

/// Berechnet Azimut (geogr.), Elevation und LNB-Skew für einen
/// geostationären Satelliten – exakt per ENU-Vektormethode (Kugelmodell).
///
/// [breite]/[laenge] = Standort in Grad (Nord/Ost positiv),
/// [satLaenge] = Orbitalposition in Grad Ost.
SatAusrichtung berechneAusrichtung({
  required double breite,
  required double laenge,
  required double satLaenge,
}) {
  final phi = breite * _rad;
  final lam = laenge * _rad;
  final lamS = satLaenge * _rad;

  final cphi = cos(phi), sphi = sin(phi), clam = cos(lam), slam = sin(lam);

  // Standort im ECEF (Kugel, Radius Re)
  final sx = _reKm * cphi * clam;
  final sy = _reKm * cphi * slam;
  final sz = _reKm * sphi;

  // Satellit im ECEF (Äquatorebene, Radius Rs)
  final satx = _rsKm * cos(lamS);
  final saty = _rsKm * sin(lamS);

  // Sichtvektor Standort -> Satellit
  final dx = satx - sx, dy = saty - sy, dz = -sz; // satz = 0

  // In lokales East-North-Up am Standort drehen
  final e = -slam * dx + clam * dy;
  final n = -sphi * clam * dx - sphi * slam * dy + cphi * dz;
  final u = cphi * clam * dx + cphi * slam * dy + sphi * dz;

  var az = atan2(e, n) * _grad;
  if (az < 0) az += 360;
  final el = atan2(u, sqrt(e * e + n * n)) * _grad;

  // LNB-Skew (Polarisation)
  final dLam = (satLaenge - laenge) * _rad;
  final skew = atan2(sin(dLam), tan(phi)) * _grad;

  return SatAusrichtung(azimut: az, elevation: el, skew: skew);
}

/// Kompassrichtung als Wort (16-teilig), z. B. „SSO".
String himmelsrichtung(double azimut) {
  const r = [
    'N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO', //
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
  ];
  final i = ((azimut % 360) / 22.5).round() % 16;
  return r[i];
}
