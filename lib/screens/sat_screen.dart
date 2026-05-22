import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sat_math.dart';
import '../theme.dart';

class SatScreen extends StatefulWidget {
  const SatScreen({super.key});

  @override
  State<SatScreen> createState() => _SatScreenState();
}

class _SatScreenState extends State<SatScreen> {
  Satellit _sat = satelliten.first;

  final _breite = TextEditingController();
  final _laenge = TextEditingController();
  // Missweisung (geogr. - magn.). DE 2025 grob +3°. Editierbar.
  final _missweisung = TextEditingController(text: '3');

  String? _gpsHinweis;
  bool _gpsLaeuft = false;

  // Live-Sensoren
  double? _kompass; // magnetischer Kurs in Grad
  double? _neigung; // Handy-Neigung aus Horizontaler in Grad
  StreamSubscription<CompassEvent>? _kompassSub;
  StreamSubscription<AccelerometerEvent>? _accSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _starteSensoren();
      WidgetsBinding.instance.addPostFrameCallback((_) => _holeGps());
    }
  }

  @override
  void dispose() {
    _breite.dispose();
    _laenge.dispose();
    _missweisung.dispose();
    _kompassSub?.cancel();
    _accSub?.cancel();
    super.dispose();
  }

  double? _d(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _starteSensoren() {
    try {
      _kompassSub = FlutterCompass.events?.listen((e) {
        if (!mounted) return;
        setState(() => _kompass = e.heading);
      });
    } catch (_) {/* kein Kompass */}
    try {
      _accSub = accelerometerEventStream().listen((e) {
        if (!mounted) return;
        // Neigung der Handy-Rückseite aus der Horizontalen:
        // 0° = flach hingelegt, 90° = senkrecht.
        final n = atan2(sqrt(e.x * e.x + e.y * e.y), e.z) * 180 / pi;
        setState(() => _neigung = n);
      });
    } catch (_) {/* kein Sensor */}
  }

  Future<void> _holeGps() async {
    setState(() {
      _gpsLaeuft = true;
      _gpsHinweis = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Standortdienst ist aus.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        throw 'Keine Standortberechtigung.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _breite.text = pos.latitude.toStringAsFixed(5).replaceAll('.', ',');
        _laenge.text = pos.longitude.toStringAsFixed(5).replaceAll('.', ',');
      });
    } catch (e) {
      if (mounted) setState(() => _gpsHinweis = 'GPS nicht verfügbar – bitte manuell eingeben.');
    } finally {
      if (mounted) setState(() => _gpsLaeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final breite = _d(_breite);
    final laenge = _d(_laenge);
    final miss = _d(_missweisung) ?? 0;
    SatAusrichtung? a;
    if (breite != null && laenge != null) {
      a = berechneAusrichtung(
          breite: breite, laenge: laenge, satLaenge: _sat.laengengrad);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SAT-Ausrichtung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _karte([
            const Text('Satellit',
                style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<Satellit>(
              initialValue: _sat,
              isExpanded: true,
              items: [
                for (final s in satelliten)
                  DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (s) => setState(() => _sat = s ?? _sat),
            ),
          ]),
          const SizedBox(height: 16),
          _karte([
            Row(children: [
              const Expanded(
                child: Text('Standort',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
              ),
              if (!kIsWeb)
                TextButton.icon(
                  onPressed: _gpsLaeuft ? null : _holeGps,
                  icon: _gpsLaeuft
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('GPS'),
                ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _feld(_breite, 'Breite °N')),
              const SizedBox(width: 12),
              Expanded(child: _feld(_laenge, 'Länge °O')),
            ]),
            if (_gpsHinweis != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_gpsHinweis!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.iosSecondary)),
              ),
          ]),
          const SizedBox(height: 16),
          if (a == null)
            _karte([
              Row(children: const [
                Icon(Icons.info_outline, color: AppTheme.iosSecondary),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Standort eingeben oder per GPS holen.')),
              ]),
            ])
          else if (!a.sichtbar)
            _karte([
              Row(children: const [
                Icon(Icons.error_outline, color: Color(0xFFFF3B30)),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Satellit steht unter dem Horizont – von hier nicht empfangbar.')),
              ]),
            ])
          else
            ..._ergebnis(a, miss),
          const SizedBox(height: 16),
          _pegelKarte(),
        ],
      ),
    );
  }

  List<Widget> _ergebnis(SatAusrichtung a, double miss) {
    final azMagn = (a.azimut - miss) % 360;
    final skewBetrag = a.skew.abs().toStringAsFixed(1).replaceAll('.', ',');
    final skewRichtung = a.skew >= 0
        ? 'im Uhrzeigersinn (von hinten gesehen)'
        : 'gegen den Uhrzeigersinn (von hinten gesehen)';
    return [
      _karte([
        const Text('Sollwerte',
            style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
        const SizedBox(height: 8),
        _zeile('Azimut (geogr.)',
            '${a.azimut.toStringAsFixed(1).replaceAll('.', ',')}°  (${himmelsrichtung(a.azimut)})'),
        _zeile('Azimut (Kompass/magn.)',
            '${azMagn.toStringAsFixed(1).replaceAll('.', ',')}°'),
        _zeile('Elevation',
            '${a.elevation.toStringAsFixed(1).replaceAll('.', ',')}°'),
        _zeile('LNB-Skew', '$skewBetrag°'),
        const SizedBox(height: 4),
        Text('Skew: $skewRichtung.',
            style:
                const TextStyle(fontSize: 12, color: AppTheme.iosSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _feld(_missweisung, 'Missweisung °O (geogr.−magn.)')),
        ]),
        const Text(
            'Missweisung Deutschland 2025 ≈ +3° (bitte gegenprüfen). Sie korrigiert den Handy-Kompass auf geografisch Nord.',
            style: TextStyle(fontSize: 11, color: AppTheme.iosSecondary)),
      ]),
      const SizedBox(height: 16),
      _liveKarte(a, azMagn),
    ];
  }

  Widget _liveKarte(SatAusrichtung a, double azMagn) {
    if (kIsWeb) {
      return _karte([
        Row(children: const [
          Icon(Icons.phone_android, color: AppTheme.iosSecondary),
          SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Live-Kompass & Neigung nur auf dem Handy (nicht in der Web-Vorschau).')),
        ]),
      ]);
    }
    final k = _kompass;
    final n = _neigung;
    // Differenz Kompass -> Ziel (magnetisch), -180..180
    double? diff;
    if (k != null) {
      diff = ((azMagn - k + 540) % 360) - 180;
    }
    return _karte([
      const Text('Live (grob – Handy-Sensoren)',
          style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
      const SizedBox(height: 8),
      if (k == null)
        const Text('Kompass nicht verfügbar.')
      else ...[
        _zeile('Kompass aktuell',
            '${k.toStringAsFixed(0)}°  (${himmelsrichtung(k)})'),
        if (diff != null)
          Row(children: [
            Icon(
                diff.abs() < 2
                    ? Icons.check_circle
                    : (diff < 0 ? Icons.turn_left : Icons.turn_right),
                color: diff.abs() < 2
                    ? AppTheme.iosGreen
                    : AppTheme.iosBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(diff.abs() < 2
                  ? 'Azimut passt.'
                  : '${diff < 0 ? "nach links" : "nach rechts"} drehen (${diff.abs().toStringAsFixed(0)}°)'),
            ),
          ]),
      ],
      const Divider(height: 20),
      if (n == null)
        const Text('Neigungssensor nicht verfügbar.')
      else ...[
        _zeile('Handy-Neigung', '${n.toStringAsFixed(0)}°'),
        Text(
            'Handy flach an die Rückseite/den Spiegel der Schüssel halten; Neigung an Elevation ${a.elevation.toStringAsFixed(0)}° angleichen.',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.iosSecondary)),
      ],
      const SizedBox(height: 8),
      const Text(
          'Hinweis: Der Handy-Kompass ist neben Metall (Schüssel/Mast) ungenau – nur zum Voreinstellen. Feinjustage über Signalqualität am Receiver/Messgerät.',
          style: TextStyle(fontSize: 11, color: Color(0xFFFF9500))),
    ]);
  }

  Widget _pegelKarte() => _karte([
        Row(children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Pegel – Richtwerte, bitte gegenprüfen',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        _zeile('ZF-Pegel an der Dose', '47–77 dBµV'),
        _zeile('Mind. für stabilen Empfang', 'ca. 47 dBµV'),
        const SizedBox(height: 6),
        const Text(
            'Das Handy hat keinen Sat-Tuner und kann den Pegel nicht messen – Werte am Receiver oder mit einem SAT-Messgerät prüfen. Pegelgrenzen sind anlagen-/normabhängig.',
            style: TextStyle(fontSize: 11, color: AppTheme.iosSecondary)),
      ]);

  // ---------------- Bausteine ----------------
  Widget _karte(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _feld(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      );

  Widget _zeile(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text(k,
                    style: const TextStyle(color: AppTheme.iosSecondary))),
            const SizedBox(width: 12),
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      );
}
