import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/rechner_math.dart';
import '../theme.dart';

enum _Modus { dc, ac1, ac3 }

class RechnerScreen extends StatefulWidget {
  const RechnerScreen({super.key});

  @override
  State<RechnerScreen> createState() => _RechnerScreenState();
}

class _RechnerScreenState extends State<RechnerScreen> {
  _Modus _modus = _Modus.dc;

  // DC
  final _u = TextEditingController();
  final _i = TextEditingController();
  final _r = TextEditingController();
  final _p = TextEditingController();

  // AC
  final _acU = TextEditingController(text: '230');
  final _acCos = TextEditingController(text: '0,95');
  final _acWert = TextEditingController(); // I oder P
  bool _acStromBekannt = true; // true = Strom, false = Leistung

  @override
  void dispose() {
    for (final c in [_u, _i, _r, _p, _acU, _acCos, _acWert]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static String fmt(double? v, String einheit) {
    if (v == null) return '–';
    final a = v.abs();
    final dez = a >= 100 ? 0 : (a >= 10 ? 1 : (a >= 1 ? 2 : 3));
    return '${v.toStringAsFixed(dez).replaceAll('.', ',')} $einheit';
  }

  void _dcReset() {
    for (final c in [_u, _i, _r, _p]) {
      c.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elektro-Rechner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Modus>(
              segments: const [
                ButtonSegment(value: _Modus.dc, label: Text('DC')),
                ButtonSegment(value: _Modus.ac1, label: Text('230 V (1~)')),
                ButtonSegment(value: _Modus.ac3, label: Text('400 V (3~)')),
              ],
              selected: {_modus},
              onSelectionChanged: (s) => setState(() {
                _modus = s.first;
                if (_modus == _Modus.ac1) _acU.text = '230';
                if (_modus == _Modus.ac3) _acU.text = '400';
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (_modus == _Modus.dc) ..._dc() else ..._ac(),
        ],
      ),
    );
  }

  // ---------------- DC ----------------
  List<Widget> _dc() {
    final e = dcLoese(_d(_u), _d(_i), _d(_r), _d(_p));
    return [
      _karte([
        Row(children: [
          const Expanded(
            child: Text('Genau 2 Werte eingeben – Rest wird berechnet.',
                style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
          ),
          TextButton(onPressed: _dcReset, child: const Text('Leeren')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _feld(_u, 'Spannung U [V]')),
          const SizedBox(width: 12),
          Expanded(child: _feld(_i, 'Strom I [A]')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _feld(_r, 'Widerstand R [Ω]')),
          const SizedBox(width: 12),
          Expanded(child: _feld(_p, 'Leistung P [W]')),
        ]),
      ]),
      const SizedBox(height: 16),
      if (e.hinweis.isNotEmpty)
        _karte([
          Row(children: [
            const Icon(Icons.info_outline, color: AppTheme.iosSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(e.hinweis)),
          ]),
        ])
      else
        _karte([
          const Text('Ergebnis',
              style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
          const SizedBox(height: 8),
          _zeile('Spannung U', fmt(e.u, 'V')),
          _zeile('Strom I', fmt(e.i, 'A')),
          _zeile('Widerstand R', fmt(e.r, 'Ω')),
          _zeile('Leistung P', fmt(e.p, 'W')),
        ]),
      const SizedBox(height: 12),
      const Text(
        'Formeln: U=R·I · P=U·I · P=I²·R · P=U²/R',
        style: TextStyle(fontSize: 11, color: AppTheme.iosSecondary),
      ),
    ];
  }

  // ---------------- AC ----------------
  List<Widget> _ac() {
    final dreiphasig = _modus == _Modus.ac3;
    final e = acLoese(
      dreiphasig: dreiphasig,
      u: _d(_acU) ?? 0,
      cosPhi: _d(_acCos) ?? 0,
      i: _acStromBekannt ? _d(_acWert) : null,
      p: _acStromBekannt ? null : _d(_acWert),
    );
    return [
      _karte([
        Row(children: [
          Expanded(
              child: _feld(
                  _acU, dreiphasig ? 'Spannung U (L-L) [V]' : 'Spannung U [V]')),
          const SizedBox(width: 12),
          Expanded(child: _feld(_acCos, 'cos φ')),
        ]),
        const SizedBox(height: 14),
        const Text('Bekannt:',
            style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Strom [A]')),
            ButtonSegment(value: false, label: Text('Leistung [W]')),
          ],
          selected: {_acStromBekannt},
          onSelectionChanged: (s) => setState(() => _acStromBekannt = s.first),
        ),
        const SizedBox(height: 12),
        _feld(_acWert, _acStromBekannt ? 'Strom I [A]' : 'Wirkleistung P [W]'),
      ]),
      const SizedBox(height: 16),
      if (e == null)
        _karte([
          Row(children: const [
            Icon(Icons.info_outline, color: AppTheme.iosSecondary),
            SizedBox(width: 8),
            Expanded(
                child: Text('U, cos φ und Strom bzw. Leistung eingeben.')),
          ]),
        ])
      else
        _karte([
          const Text('Ergebnis',
              style: TextStyle(fontSize: 13, color: AppTheme.iosSecondary)),
          const SizedBox(height: 8),
          _zeile('Spannung U', fmt(e.u, 'V')),
          _zeile('Strom I', fmt(e.i, 'A')),
          _zeile('Wirkleistung P', fmt(e.p, 'W')),
          _zeile('Scheinleistung S', fmt(e.s, 'VA')),
          _zeile('Blindleistung Q', fmt(e.q, 'var')),
          _zeile('cos φ', e.cosPhi.toStringAsFixed(2).replaceAll('.', ',')),
        ]),
      const SizedBox(height: 12),
      Text(
        dreiphasig
            ? 'Formel: P = √3 · U · I · cos φ  (U = Außenleiterspannung)'
            : 'Formel: P = U · I · cos φ',
        style: const TextStyle(fontSize: 11, color: AppTheme.iosSecondary),
      ),
    ];
  }

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
            Text(v,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      );
}
