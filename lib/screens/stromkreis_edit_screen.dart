import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/protokoll.dart';
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import 'gefuehrte_pruefung_screen.dart';
import 'pruef_schritte.dart';

class StromkreisEditScreen extends StatefulWidget {
  final Stromkreis stromkreis;
  final int nummer;
  final Netzform netzform;
  final Stromkreis? fiVorlage; // vorheriger Stromkreis (für FI-Übernahme)
  // Wallbox-Variante: „Stromkreis / Raum" wird zu „Sicherung", Kabelname
  // entfällt, Betriebsmittel ist fest „Zuleitung".
  final bool wallboxModus;
  const StromkreisEditScreen({
    super.key,
    required this.stromkreis,
    required this.nummer,
    required this.netzform,
    this.fiVorlage,
    this.wallboxModus = false,
  });

  @override
  State<StromkreisEditScreen> createState() => _StromkreisEditScreenState();
}

class _StromkreisEditScreenState extends State<StromkreisEditScreen> {
  late Stromkreis s;

  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    s = widget.stromkreis;
    if (widget.wallboxModus) {
      // Im Wallbox-Protokoll ist das Betriebsmittel immer die Zuleitung.
      s.betriebsmittelModus = 'manuell';
      if (s.anzahlBetriebsmittel.trim().isEmpty) {
        s.anzahlBetriebsmittel = 'Zuleitung';
      }
    }
    _c = {
      'raum': TextEditingController(text: s.stromkreisRaum),
      'kabel': TextEditingController(text: s.kabelname),
      'anzahl': TextEditingController(text: s.anzahlBetriebsmittel),
      'laenge': TextEditingController(text: s.laenge),
      'ikLpe': TextEditingController(text: s.ikLpe),
      'ikLn': TextEditingController(text: s.ikLn),
      'fiN': TextEditingController(text: s.fiN),
      'fiIdn': TextEditingController(text: s.fiIdn),
      'erfIk': TextEditingController(text: s.erfIkManuell),
      'auslI': TextEditingController(text: s.ausloesestrom),
      'auslT': TextEditingController(text: s.ausloesezeit),
      'auslIDc': TextEditingController(text: s.ausloesestromDc),
      'auslTDc': TextEditingController(text: s.ausloesezeitDc),
      'ub': TextEditingController(text: s.ub),
      'rlow': TextEditingController(text: s.rlow),
      'riso': TextEditingController(text: s.riso),
    };
    // Live-Aktualisierung der Beurteilung bei Eingabe.
    for (final key in [
      'ikLpe', 'ikLn', 'fiIdn', 'auslI', 'auslT', //
      'auslIDc', 'auslTDc', 'ub', 'rlow', 'erfIk'
    ]) {
      _c[key]!.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Schreibt die (per Sprache geänderten) Modellwerte zurück in die Textfelder.
  void _modellInControllers() {
    _c['raum']!.text = s.stromkreisRaum;
    _c['kabel']!.text = s.kabelname;
    _c['anzahl']!.text = s.anzahlBetriebsmittel;
    _c['laenge']!.text = s.laenge;
    _c['ikLpe']!.text = s.ikLpe;
    _c['ikLn']!.text = s.ikLn;
    _c['fiN']!.text = s.fiN;
    _c['fiIdn']!.text = s.fiIdn;
    _c['auslI']!.text = s.ausloesestrom;
    _c['auslT']!.text = s.ausloesezeit;
    _c['auslIDc']!.text = s.ausloesestromDc;
    _c['auslTDc']!.text = s.ausloesezeitDc;
    _c['ub']!.text = s.ub;
    _c['rlow']!.text = s.rlow;
    _c['riso']!.text = s.riso;
  }

  Future<void> _gefuehrtePruefung() async {
    _syncModel();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GefuehrtePruefungScreen(
          titel: 'Geführte Prüfung – Stromkreis ${widget.nummer}',
          schritte: stromkreisSchritte(
            s,
            widget.netzform,
            vorheriger: widget.fiVorlage,
          ),
        ),
      ),
    );
    if (mounted) setState(_modellInControllers);
  }

  void _syncModel() {
    s.stromkreisRaum = _c['raum']!.text;
    s.kabelname = _c['kabel']!.text;
    s.anzahlBetriebsmittel = _c['anzahl']!.text;
    s.laenge = _c['laenge']!.text;
    s.ikLpe = _c['ikLpe']!.text;
    s.ikLn = _c['ikLn']!.text;
    s.fiN = _c['fiN']!.text;
    s.fiIdn = _c['fiIdn']!.text;
    s.erfIkManuell = _c['erfIk']!.text;
    s.ausloesestrom = _c['auslI']!.text;
    s.ausloesezeit = _c['auslT']!.text;
    s.ausloesestromDc = _c['auslIDc']!.text;
    s.ausloesezeitDc = _c['auslTDc']!.text;
    s.ub = _c['ub']!.text;
    s.rlow = _c['rlow']!.text;
    s.riso = _c['riso']!.text;
  }

  void _speichernUndZurueck() {
    _syncModel();
    Navigator.pop(context, s);
  }

  /// Falls der aktuelle Nennstrom für die neue Schutzart nicht existiert,
  /// auf null zurücksetzen.
  void _pruefeNennstrom() {
    // Bei MSS ist Ie frei einstellbar (Freitext) – kein Reset.
    if (s.schutzart == Schutzart.mss) return;
    final liste = Tabelle6.nennstroeme(s.schutzart);
    if (s.vorgSicherung != null && !liste.contains(s.vorgSicherung)) {
      s.vorgSicherung = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncModel();
    final wert = s.ikWert;
    final nennstroeme = Tabelle6.nennstroeme(s.schutzart);
    final bewertung =
        s.bewerten(maxAusloesezeitMs: widget.netzform.maxAusloesezeitMs);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _syncModel();
          Navigator.pop(context, s);
        }
      },
      child: _buildScaffold(context, wert, nennstroeme, bewertung),
    );
  }

  Widget _buildScaffold(BuildContext context, IkWert? wert,
      List<int> nennstroeme, Stromkreisbewertung bewertung) {
    return Scaffold(
      appBar: AppBar(title: Text('Stromkreis ${widget.nummer}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _speichernUndZurueck,
        icon: const Icon(Icons.check),
        label: const Text('Übernehmen'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _gefuehrtePruefung,
              icon: const Icon(Icons.checklist),
              label: const Text('Geführte Prüfung'),
            ),
          ),
          const SizedBox(height: 16),
          _gruppe('Allgemein'),
          _feld('raum', widget.wallboxModus ? 'Sicherung' : 'Stromkreis / Raum'),
          if (!widget.wallboxModus) _feld('kabel', 'Kabelname'),
          if (!widget.wallboxModus) _betriebsmittelFeld(),
          Row(children: [
            Expanded(child: _feld('laenge', 'Länge [m]', zahl: true)),
            const SizedBox(width: 12),
            Expanded(child: _querschnittDropdown()),
          ]),

          const SizedBox(height: 20),
          _gruppe('Schutzorgan & erforderlicher IK'),
          DropdownButtonFormField<Schutzart>(
            initialValue: s.schutzart,
            decoration: const InputDecoration(labelText: 'Charakteristik'),
            items: Schutzart.values
                .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(_schutzartText(a))))
                .toList(),
            onChanged: (v) => setState(() {
              s.schutzart = v ?? Schutzart.b;
              _pruefeNennstrom();
            }),
          ),
          const SizedBox(height: 12),
          if (s.schutzart == Schutzart.mss)
            TextFormField(
              key: ValueKey('vorgSich-mss-${s.vorgSicherung ?? ''}'),
              initialValue: s.vorgSicherung?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Eingestellter Nennstrom Ie [A]',
                helperText: 'Freie Eingabe — MSS-Skala ist herstellerabhängig.',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) =>
                  setState(() => s.vorgSicherung = int.tryParse(v.trim())),
            )
          else
            DropdownButtonFormField<int?>(
              initialValue: s.vorgSicherung,
              decoration: const InputDecoration(
                  labelText: 'Vorgeschaltete Sicherung [A]'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ...nennstroeme.map((n) =>
                    DropdownMenuItem<int?>(value: n, child: Text('$n A'))),
              ],
              onChanged: (v) => setState(() => s.vorgSicherung = v),
            ),
          if (s.schutzart == Schutzart.gg) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Abschaltzeit')),
                SegmentedButton<Abschaltzeit>(
                  segments: const [
                    ButtonSegment(
                        value: Abschaltzeit.s04,
                        label: Text('0,4 s'),
                        tooltip: 'Endstromkreis ≤ 32 A'),
                    ButtonSegment(
                        value: Abschaltzeit.s5,
                        label: Text('5 s'),
                        tooltip: 'Verteiler / > 32 A'),
                  ],
                  selected: {s.abschaltzeit},
                  onSelectionChanged: (set) =>
                      setState(() => s.abschaltzeit = set.first),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _ikAnzeige(wert),

          const SizedBox(height: 20),
          _gruppe('Kurzschlußstrommessung'),
          DropdownButtonFormField<String>(
            initialValue: spannungen.contains(s.spannung) ? s.spannung : null,
            decoration: const InputDecoration(labelText: 'Spannung [V]'),
            items: spannungen
                .map((v) => DropdownMenuItem(value: v, child: Text('$v V')))
                .toList(),
            onChanged: (v) => setState(() => s.spannung = v ?? '230'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _feld('ikLpe', 'IK L-PE [A]', zahl: true)),
            const SizedBox(width: 12),
            Expanded(child: _feld('ikLn', 'IK L-N [A]', zahl: true)),
          ]),
          if (s.hatFi && _c['ikLpe']!.text.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Hinweis: Bei FI-Messung ist IK L-PE nicht messbar – Feld sollte leer bleiben.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _gruppe('FI-Schutzschalter')),
              if (_fiVorlageVorhanden)
                TextButton.icon(
                  onPressed: _fiUebernehmen,
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('FI-Werte übernehmen'),
                ),
            ],
          ),
          Row(children: [
            Expanded(child: _feld('fiN', 'FI / N [A]', zahl: true)),
            const SizedBox(width: 12),
            Expanded(child: _feld('fiIdn', 'FI / IΔN [mA]', zahl: true)),
          ]),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Text('FI-Typ')),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'A', label: Text('Typ A')),
                  ButtonSegment(
                      value: 'B',
                      label: Text('Typ B'),
                      tooltip: 'allstromsensitiv (DC-Messung nötig)'),
                ],
                selected: {s.fiTyp == 'B' ? 'B' : 'A'},
                onSelectionChanged: (set) =>
                    setState(() => s.fiTyp = set.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Auslöseprüfung Wechselstrom (AC)',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _feld('auslI', 'Auslösestrom [mA]', zahl: true)),
            const SizedBox(width: 12),
            Expanded(child: _feld('auslT', 'Auslösezeit [ms]', zahl: true)),
          ]),
          if (s.fiTyp == 'B') ...[
            Text('Auslöseprüfung Gleichstrom (DC) – Typ B',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: _feld('auslIDc', 'Auslösestrom DC [mA]', zahl: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _feld('auslTDc', 'Auslösezeit DC [ms]', zahl: true)),
            ]),
          ],
          _feld('ub', 'UB – Berührungsspannung [V]', zahl: true),

          const SizedBox(height: 20),
          _gruppe('Erdung & Isolation'),
          Row(children: [
            Expanded(child: _feld('rlow', 'RLOW [Ω]', zahl: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _feld('riso', 'RISO [MΩ]', zahl: true, groesser: true)),
          ]),

          const SizedBox(height: 20),
          _beurteilung(bewertung),
        ],
      ),
    );
  }

  Widget _beurteilung(Stromkreisbewertung b) {
    Color bg;
    Color fg;
    IconData icon;
    String titel;
    switch (b.status) {
      case Pruefstatus.ok:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        icon = Icons.check_circle;
        titel = 'Beurteilung: i.O.';
        break;
      case Pruefstatus.nichtOk:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        icon = Icons.cancel;
        titel = 'Beurteilung: n.i.O.';
        break;
      case Pruefstatus.offen:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        icon = Icons.help_outline;
        titel = 'Beurteilung: noch offen';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: fg),
            const SizedBox(width: 8),
            Text(titel,
                style: TextStyle(
                    color: fg, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          if (b.maengel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Mängel:',
                style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
            ...b.maengel.map((m) => Text('• $m', style: TextStyle(color: fg))),
          ],
          if (b.fehlend.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Fehlende Werte: ${b.fehlend.join(", ")}',
                style: TextStyle(color: fg, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _ikAnzeige(IkWert? wert) {
    final cs = Theme.of(context).colorScheme;
    // Manuelle Eingabe nötig: gG > 160 A (kein Gossen-Tabellenwert).
    final braucthtManuell =
        wert == null && s.vorgSicherung != null && s.schutzart == Schutzart.gg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: wert != null ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Erforderlicher IK',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (wert != null) ...[
            Text('Min. Anzeige: ${s.erforderlicherIkText} A',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Grenzwert Ia: ${s.grenzwertIkText} A  ·  Tabelle 6 (PROFITEST)',
                style: const TextStyle(fontSize: 13)),
          ] else if (braucthtManuell) ...[
            const Text(
              'Für gG > 160 A liegt kein Gossen-Tabellenwert vor. '
              'Wert aus der Sicherungs-Kennlinie eintragen:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _c['erfIk'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: const InputDecoration(
                labelText: 'Erforderlicher IK [A]',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ] else
            const Text('Charakteristik und Sicherung wählen.'),
        ],
      ),
    );
  }

  String _schutzartText(Schutzart a) {
    switch (a) {
      case Schutzart.b:
        return 'B  (LS, 5×In)';
      case Schutzart.c:
        return 'C  (LS, 10×In)';
      case Schutzart.d:
        return 'D  (LS, 20×In)';
      case Schutzart.k:
        return 'K  (LS, 12×In)';
      case Schutzart.gg:
        return 'gG  (Schmelzsicherung)';
      case Schutzart.mss:
        return 'MSS  (Motorschutzschalter, 13×Ie)';
    }
  }

  bool get _fiVorlageVorhanden {
    final v = widget.fiVorlage;
    if (v == null) return false;
    return v.fiN.isNotEmpty ||
        v.fiIdn.isNotEmpty ||
        v.ausloesestrom.isNotEmpty ||
        v.ausloesezeit.isNotEmpty;
  }

  void _fiUebernehmen() {
    final v = widget.fiVorlage;
    if (v == null) return;
    _c['fiN']!.text = v.fiN;
    _c['fiIdn']!.text = v.fiIdn;
    _c['auslI']!.text = v.ausloesestrom;
    _c['auslT']!.text = v.ausloesezeit;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FI-Werte vom vorherigen Stromkreis übernommen')),
    );
  }

  Widget _querschnittDropdown() {
    final aktuell = s.querschnitt;
    final werte = [
      ...querschnitte,
      if (aktuell.isNotEmpty && !querschnitte.contains(aktuell)) aktuell,
    ];
    return DropdownButtonFormField<String>(
      initialValue: aktuell.isEmpty ? null : aktuell,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Querschnitt [mm²]'),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('—')),
        ...werte.map((q) => DropdownMenuItem(value: q, child: Text(q))),
      ],
      onChanged: (v) => setState(() => s.querschnitt = v ?? ''),
    );
  }

  Widget _betriebsmittelFeld() {
    final zaehlung = s.betriebsmittelModus != 'manuell';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text('Betriebsmittel',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Steckdosen/Lichter')),
                ButtonSegment(value: false, label: Text('Manuell')),
              ],
              selected: {zaehlung},
              onSelectionChanged: (set) => setState(
                  () => s.betriebsmittelModus = set.first ? 'zaehlung' : 'manuell'),
            ),
          ),
          const SizedBox(height: 12),
          if (zaehlung)
            Row(children: [
              Expanded(
                child: _anzahlDropdown('Steckdosen', s.anzahlSteckdosen,
                    (v) => setState(() => s.anzahlSteckdosen = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _anzahlDropdown('Lichter', s.anzahlLichter,
                    (v) => setState(() => s.anzahlLichter = v)),
              ),
            ])
          else
            _feld('anzahl', 'Bezeichnung (z. B. Kompressor, Herd, Boiler)'),
        ],
      ),
    );
  }

  Widget _anzahlDropdown(String label, int? value, ValueChanged<int?> onCh) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('—')),
        ...List.generate(31, (i) => i)
            .map((n) => DropdownMenuItem<int?>(value: n, child: Text('$n'))),
      ],
      onChanged: onCh,
    );
  }

  Widget _gruppe(String titel) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(titel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  // [groesser]: erlaubt zusätzlich das „>"-Zeichen (z. B. Iso-Überlauf „>999")
  // und nutzt dafür die Texttastatur, da die Zahlentastatur kein „>" hat.
  Widget _feld(String key, String label,
          {bool zahl = false, bool groesser = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[key],
          decoration: InputDecoration(labelText: label),
          keyboardType: (zahl && !groesser)
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: groesser
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,>]'))]
              : zahl
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : null,
        ),
      );
}
