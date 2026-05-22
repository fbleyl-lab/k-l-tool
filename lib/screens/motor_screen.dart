import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/motor_rechner.dart';
import '../theme.dart';

class MotorScreen extends StatefulWidget {
  const MotorScreen({super.key});

  @override
  State<MotorScreen> createState() => _MotorScreenState();
}

class _MotorScreenState extends State<MotorScreen> {
  int _spannung = 400;
  bool _ueberStrom = false; // false = Leistung, true = Iₙ direkt
  Anlaufart _anlauf = Anlaufart.dol;
  final _leistung = TextEditingController();
  final _inDirekt = TextEditingController();
  final _cosPhi = TextEditingController(text: '0,85');
  final _eta = TextEditingController(text: '0,87');

  @override
  void dispose() {
    _leistung.dispose();
    _inDirekt.dispose();
    _cosPhi.dispose();
    _eta.dispose();
    super.dispose();
  }

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final eingabe = MotorEingabe(
      leistungKw: _ueberStrom ? null : _d(_leistung, 0),
      inDirekt: _ueberStrom ? _d(_inDirekt, 0) : null,
      spannung: _spannung,
      cosPhi: _d(_cosPhi, 0.85),
      wirkungsgrad: _d(_eta, 0.87),
      anlaufart: _anlauf,
    );
    final e = MotorRechner.berechne(eingabe);

    return Scaffold(
      appBar: AppBar(title: const Text('Motorabsicherung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _karte([
            _label('Spannung / System'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 400, label: Text('400 V (3~)')),
                ButtonSegment(value: 230, label: Text('230 V (1~)')),
              ],
              selected: {_spannung},
              onSelectionChanged: (s) => setState(() => _spannung = s.first),
            ),
            const SizedBox(height: 16),
            _label('Vorgabe über'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Leistung [kW]')),
                ButtonSegment(value: true, label: Text('Nennstrom Iₙ [A]')),
              ],
              selected: {_ueberStrom},
              onSelectionChanged: (s) => setState(() => _ueberStrom = s.first),
            ),
            const SizedBox(height: 12),
            if (_ueberStrom)
              _feld(_inDirekt, 'Motor-Nennstrom Iₙ [A]')
            else ...[
              _feld(_leistung, 'Motorleistung [kW]'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _feld(_cosPhi, 'cos φ')),
                const SizedBox(width: 12),
                Expanded(child: _feld(_eta, 'Wirkungsgrad η')),
              ]),
            ],
            const SizedBox(height: 16),
            _label('Anlaufverfahren'),
            DropdownButtonFormField<Anlaufart>(
              initialValue: _anlauf,
              isExpanded: true,
              items: Anlaufart.values
                  .map((a) => DropdownMenuItem(
                      value: a, child: Text(a.label)))
                  .toList(),
              onChanged: (v) => setState(() => _anlauf = v ?? Anlaufart.dol),
            ),
          ]),
          const SizedBox(height: 16),
          _ergebnis(e),
          const SizedBox(height: 12),
          const Text(
            'Richtwerte. Überlastschutz immer auf Iₙ einstellen. '
            'Sicherungsgröße für den Anlauf gegen die Koordinationstabelle des '
            'Herstellers (z. B. Siemens/ABB) prüfen. Leitungsquerschnitt separat '
            'im Kabel-Tool auslegen.',
            style: TextStyle(fontSize: 11, color: AppTheme.iosSecondary),
          ),
        ],
      ),
    );
  }

  Widget _ergebnis(MotorErgebnis e) {
    if (e.inMotor <= 0) {
      return _karte([
        Row(children: [
          const Icon(Icons.info_outline, color: AppTheme.iosSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(e.hinweis)),
        ]),
      ]);
    }
    return _karte([
      const Text('Motor-Nennstrom Iₙ',
          style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
      const SizedBox(height: 4),
      Text('${e.inMotor.toStringAsFixed(1)} A',
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.iosBlue)),
      const Divider(height: 22),
      _zeile('Überlast-Einstellung', '${e.inMotor.toStringAsFixed(1)} A (= Iₙ)'),
      _zeile('Anlaufart', _anlauf.label),
      _zeile('Anlaufstrom (ca.)', _anlauf.anlaufVielfaches),
      const SizedBox(height: 10),
      const Text('Kurzschlussschutz (anlauffest):',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      _zeile('gG-Sicherung', e.gGSicherung != null ? '${e.gGSicherung} A' : '–'),
      _zeile('alt. aM-Sicherung (Motor)',
          e.aMSicherung != null ? '${e.aMSicherung} A' : '–'),
      const SizedBox(height: 6),
      const Text(
        'Empfehlung: Motorschutzschalter (Überlast + Kurzschluss) auf Iₙ '
        'eingestellt, oder aM-Sicherung. gG nur, wenn anlauffest dimensioniert.',
        style: TextStyle(fontSize: 12),
      ),
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
            Expanded(child: Text(k, style: const TextStyle(color: AppTheme.iosSecondary))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
