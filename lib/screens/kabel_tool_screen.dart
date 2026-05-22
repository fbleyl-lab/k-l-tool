import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kabel_daten.dart';
import '../models/kabel_rechner.dart';
import '../theme.dart';

enum _Modus { verbraucher, sicherung }

class KabelToolScreen extends StatefulWidget {
  const KabelToolScreen({super.key});

  @override
  State<KabelToolScreen> createState() => _KabelToolScreenState();
}

class _KabelToolScreenState extends State<KabelToolScreen> {
  _Modus _modus = _Modus.verbraucher;
  Leiter _leiter = Leiter.cu;
  String _verlegeart = 'B2';
  int _spannung = 230;
  bool _ueberLeistung = false; // Modus Verbraucher: Strom oder Leistung
  double _duGrenze = 3;
  int _sicherung = 16; // Modus Sicherung

  final _strom = TextEditingController();
  final _leistung = TextEditingController();
  final _laenge = TextEditingController();

  @override
  void dispose() {
    _strom.dispose();
    _leistung.dispose();
    _laenge.dispose();
    super.dispose();
  }

  double get _ib {
    if (_ueberLeistung) {
      final p = double.tryParse(_leistung.text.replaceAll(',', '.')) ?? 0;
      if (p <= 0) return 0;
      return _spannung >= 400 ? p / (sqrt(3) * 400) : p / 230;
    }
    return double.tryParse(_strom.text.replaceAll(',', '.')) ?? 0;
  }

  double get _laengeVal => double.tryParse(_laenge.text.replaceAll(',', '.')) ?? 0;

  void _verlegeartPruefen() {
    final opts = KabelDaten.verlegearten(_leiter);
    if (!opts.any((v) => v.code == _verlegeart)) _verlegeart = opts.first.code;
  }

  KabelErgebnis _berechne() {
    if (_modus == _Modus.verbraucher) {
      return KabelRechner.berechne(KabelEingabe(
        leiter: _leiter,
        verlegeart: _verlegeart,
        strom: _ib,
        laenge: _laengeVal,
        spannung: _spannung,
        duGrenzeProzent: _duGrenze,
      ));
    } else {
      return KabelRechner.berechne(KabelEingabe(
        leiter: _leiter,
        verlegeart: _verlegeart,
        strom: 0,
        laenge: _laengeVal,
        spannung: _spannung,
        duGrenzeProzent: _duGrenze,
        sicherung: _sicherung,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _berechne();
    return Scaffold(
      appBar: AppBar(title: const Text('Kabelquerschnitt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Modus-Wahlschalter
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Modus>(
              segments: const [
                ButtonSegment(
                    value: _Modus.verbraucher, label: Text('Nach Verbraucher')),
                ButtonSegment(
                    value: _Modus.sicherung, label: Text('Nach Sicherung')),
              ],
              selected: {_modus},
              onSelectionChanged: (s) => setState(() => _modus = s.first),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _modus == _Modus.verbraucher
                ? 'Verbraucher bekannt → Querschnitt + passende Sicherung.'
                : 'Sicherung bekannt (Hensel) → zulässiger Mindestquerschnitt.',
            style: const TextStyle(fontSize: 12, color: AppTheme.iosSecondary),
          ),
          const SizedBox(height: 16),

          _karte([
            _label('Leitermaterial'),
            SegmentedButton<Leiter>(
              segments: const [
                ButtonSegment(value: Leiter.cu, label: Text('Kupfer')),
                ButtonSegment(value: Leiter.al, label: Text('Aluminium')),
              ],
              selected: {_leiter},
              onSelectionChanged: (s) => setState(() {
                _leiter = s.first;
                _verlegeartPruefen();
              }),
            ),
            const SizedBox(height: 16),
            _label('Verlegeart'),
            DropdownButtonFormField<String>(
              initialValue: _verlegeart,
              isExpanded: true,
              items: KabelDaten.verlegearten(_leiter)
                  .map((v) => DropdownMenuItem(
                        value: v.code,
                        child: Text('${v.code} – ${v.beschreibung}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() =>
                  _verlegeart = v ?? KabelDaten.verlegearten(_leiter).first.code),
            ),
            const SizedBox(height: 16),
            if (_modus == _Modus.verbraucher) ..._verbraucherInputs(),
            if (_modus == _Modus.sicherung) ..._sicherungInputs(),
          ]),
          const SizedBox(height: 16),
          _ergebnisKarte(e),
          const SizedBox(height: 12),
          Text(
            _leiter == Leiter.cu
                ? 'Datenbasis Kupfer: DIN VDE 0298-4 Tab. 3 (PVC, 3 belastete Adern); '
                    'Erde: DIN VDE 0276-603. κ = 56, cos φ = 1.'
                : 'Datenbasis Aluminium: DIN VDE 0276-603 (NAYY, PVC). κ = 35, cos φ = 1.',
            style: const TextStyle(fontSize: 11, color: AppTheme.iosSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ohne Häufungs-/Temperaturabminderung. Angaben ohne Gewähr – '
            'fachliche Prüfung erforderlich.',
            style: TextStyle(fontSize: 11, color: AppTheme.iosSecondary),
          ),
        ],
      ),
    );
  }

  List<Widget> _verbraucherInputs() => [
        _label('Spannung / System'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 230, label: Text('230 V (1~)')),
            ButtonSegment(value: 400, label: Text('400 V (3~)')),
          ],
          selected: {_spannung},
          onSelectionChanged: (s) => setState(() => _spannung = s.first),
        ),
        const SizedBox(height: 16),
        _label('Vorgabe über'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Strom [A]')),
            ButtonSegment(value: true, label: Text('Leistung [W]')),
          ],
          selected: {_ueberLeistung},
          onSelectionChanged: (s) => setState(() => _ueberLeistung = s.first),
        ),
        const SizedBox(height: 12),
        if (_ueberLeistung)
          _feld(_leistung, 'Leistung [W]')
        else
          _feld(_strom, 'Betriebsstrom Ib [A]'),
        if (_ueberLeistung && _ib > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('≈ ${_ib.toStringAsFixed(1)} A',
                style: const TextStyle(color: AppTheme.iosSecondary)),
          ),
        const SizedBox(height: 12),
        _feld(_laenge, 'Leitungslänge [m]'),
        const SizedBox(height: 16),
        _label('Zulässiger Spannungsfall'),
        _duSchalter(),
      ];

  List<Widget> _sicherungInputs() => [
        _label('Vorhandene / gewählte Sicherung'),
        DropdownButtonFormField<int>(
          initialValue: _sicherung,
          items: KabelDaten.sicherungen
              .map((s) => DropdownMenuItem(value: s, child: Text('$s A')))
              .toList(),
          onChanged: (v) => setState(() => _sicherung = v ?? 16),
        ),
        const SizedBox(height: 16),
        _label('Spannungsfall prüfen (optional)'),
        const Text('Länge angeben → wird zusätzlich geprüft. Strom = Sicherung.',
            style: TextStyle(fontSize: 12, color: AppTheme.iosSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _feld(_laenge, 'Leitungslänge [m] (optional)')),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 230, label: Text('230')),
                ButtonSegment(value: 400, label: Text('400')),
              ],
              selected: {_spannung},
              onSelectionChanged: (s) => setState(() => _spannung = s.first),
            ),
          ),
        ]),
        if (_laengeVal > 0) ...[
          const SizedBox(height: 12),
          _label('Zulässiger Spannungsfall'),
          _duSchalter(),
        ],
      ];

  Widget _duSchalter() => SegmentedButton<double>(
        segments: const [
          ButtonSegment(value: 3, label: Text('3 %')),
          ButtonSegment(value: 5, label: Text('5 %')),
        ],
        selected: {_duGrenze},
        onSelectionChanged: (s) => setState(() => _duGrenze = s.first),
      );

  Widget _ergebnisKarte(KabelErgebnis e) {
    final verbraucher = _modus == _Modus.verbraucher;
    if (e.querschnitt == null) {
      return _karte([
        Row(children: [
          const Icon(Icons.info_outline, color: AppTheme.iosSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(e.hinweis.isEmpty
                  ? (verbraucher
                      ? 'Strom oder Leistung eingeben.'
                      : 'Sicherung wählen.')
                  : e.hinweis)),
        ]),
      ]);
    }
    String fmtQ(double? q) => q == null
        ? '–'
        : (q == q.roundToDouble() ? '${q.toInt()}' : '$q').replaceAll('.', ',');

    return _karte([
      Text(verbraucher ? 'Empfohlener Querschnitt' : 'Mindestquerschnitt',
          style: const TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
      const SizedBox(height: 4),
      Text('${fmtQ(e.querschnitt)} mm²',
          style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.iosBlue)),
      const SizedBox(height: 12),
      if (verbraucher) ...[
        _zeile('Betriebsstrom Ib', '${_ib.toStringAsFixed(1)} A'),
        _zeile('Empfohlene Sicherung',
            e.sicherung != null ? '${e.sicherung} A' : '–'),
      ] else
        _zeile('Sicherung (Vorgabe)', '$_sicherung A'),
      _zeile('Strombelastbarkeit Iz', e.iz != null ? '${e.iz} A' : '–'),
      if (e.duProzent != null && _laengeVal > 0)
        _zeile('Spannungsfall', '${e.duProzent!.toStringAsFixed(2)} %'),
      const Divider(height: 20),
      const Text('Mindestquerschnitt je Kriterium:',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      if (verbraucher) _zeile('Strombelastbarkeit', '${fmtQ(e.minStrom)} mm²'),
      _zeile('Sicherungsschutz', '${fmtQ(e.minSicherung)} mm²'),
      if (_laengeVal > 0) _zeile('Spannungsfall', '${fmtQ(e.minDu)} mm²'),
    ]);
  }

  Widget _karte(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.iosSecondary)),
      );

  Widget _feld(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      );

  Widget _zeile(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: AppTheme.iosSecondary)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
