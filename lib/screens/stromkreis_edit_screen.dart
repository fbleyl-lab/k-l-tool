import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/protokoll.dart';
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../utils/mess_parser.dart';

/// Felder, die der geführte Sprachmodus der Reihe nach abfragt.
enum _Feld {
  charSich,
  spannung,
  fiVorhanden,
  fiTyp,
  fiIdn,
  auslI,
  auslT,
  auslIDc,
  auslTDc,
  ikLn,
  ikLpe,
  ub,
  rlow,
  riso,
}

class StromkreisEditScreen extends StatefulWidget {
  final Stromkreis stromkreis;
  final int nummer;
  final Netzform netzform;
  final Stromkreis? fiVorlage; // vorheriger Stromkreis (für FI-Übernahme)
  const StromkreisEditScreen({
    super.key,
    required this.stromkreis,
    required this.nummer,
    required this.netzform,
    this.fiVorlage,
  });

  @override
  State<StromkreisEditScreen> createState() => _StromkreisEditScreenState();
}

class _StromkreisEditScreenState extends State<StromkreisEditScreen> {
  late Stromkreis s;

  late final Map<String, TextEditingController> _c;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _hoert = false;

  // Geführter Modus
  bool _guided = false;
  bool _guidedHoert = false;
  String _guidedPrompt = '';
  int _gIndex = 0;
  bool? _fiVorhanden;
  bool _speechReady = false;
  Completer<String>? _listenCompleter;
  String _lastWords = '';

  static const List<_Feld> _reihenfolge = [
    _Feld.charSich,
    _Feld.spannung,
    _Feld.fiVorhanden,
    _Feld.fiTyp,
    _Feld.fiIdn,
    _Feld.auslI,
    _Feld.auslT,
    _Feld.auslIDc,
    _Feld.auslTDc,
    _Feld.ikLn,
    _Feld.ikLpe,
    _Feld.ub,
    _Feld.rlow,
    _Feld.riso,
  ];

  @override
  void initState() {
    super.initState();
    s = widget.stromkreis;
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
    _guided = false;
    _speech.stop();
    _tts.stop();
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

  Future<void> _messungDiktieren() async {
    if (_hoert) {
      await _speech.stop();
      setState(() => _hoert = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (st) {
        if ((st == 'done' || st == 'notListening') && mounted) {
          setState(() => _hoert = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _hoert = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Spracherkennung nicht verfügbar (Mikrofon-Freigabe?)')));
      }
      return;
    }
    setState(() => _hoert = true);
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: false, localeId: 'de_DE'),
      onResult: (r) {
        if (!r.finalResult) return;
        _syncModel(); // aktuelle Feldwerte ins Modell
        final erkannt = MessParser.anwenden(s, r.recognizedWords);
        _modellInControllers(); // geänderte Werte zurück in die Felder
        setState(() => _hoert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erkannt.isEmpty
              ? 'Nichts erkannt: „${r.recognizedWords}"'
              : 'Erkannt: ${erkannt.join(", ")}'),
        ));
      },
    );
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
          _diktierKarte(),
          const SizedBox(height: 16),
          _gruppe('Allgemein'),
          _feld('raum', 'Stromkreis / Raum'),
          _feld('kabel', 'Kabelname'),
          _betriebsmittelFeld(),
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
          DropdownButtonFormField<int?>(
            initialValue: s.vorgSicherung,
            decoration:
                const InputDecoration(labelText: 'Vorgeschaltete Sicherung [A]'),
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
            Expanded(child: _feld('riso', 'RISO [MΩ]', zahl: true)),
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

  // ---------- Geführter Sprachmodus ----------

  void _onSpeechStatus(String st) {
    if ((st == 'notListening' || st == 'done') &&
        _listenCompleter != null &&
        !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete(_lastWords);
    }
    if (mounted && !_guided) setState(() => _hoert = false);
  }

  Future<String> _listenOnce() async {
    _lastWords = '';
    _listenCompleter = Completer<String>();
    if (mounted) setState(() => _guidedHoert = true);
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: 'de_DE'),
      onResult: (r) {
        _lastWords = r.recognizedWords;
        if (r.finalResult && !_listenCompleter!.isCompleted) {
          _listenCompleter!.complete(r.recognizedWords);
        }
      },
    );
    final res = await _listenCompleter!.future;
    if (mounted) setState(() => _guidedHoert = false);
    return res;
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  Future<void> _startGuided() async {
    _speechReady = await _speech.initialize(onStatus: _onSpeechStatus);
    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Spracherkennung nicht verfügbar (Mikrofon-Freigabe?)')));
      }
      return;
    }
    setState(() {
      _guided = true;
      _gIndex = 0;
      _fiVorhanden = null;
    });
    await _guidedLoop();
  }

  Future<void> _stopGuided() async {
    _guided = false;
    await _speech.stop();
    await _tts.stop();
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete('');
    }
    if (mounted) setState(() => _guidedPrompt = '');
  }

  bool _istAktiv(_Feld f) {
    switch (f) {
      case _Feld.fiTyp:
      case _Feld.fiIdn:
      case _Feld.auslI:
      case _Feld.auslT:
        return _fiVorhanden == true;
      case _Feld.auslIDc:
      case _Feld.auslTDc:
        return _fiVorhanden == true && s.fiTyp == 'B';
      case _Feld.ikLpe:
        return _fiVorhanden == false; // bei FI nicht messbar
      default:
        return true;
    }
  }

  Future<void> _guidedLoop() async {
    while (_guided && _gIndex < _reihenfolge.length) {
      final f = _reihenfolge[_gIndex];
      if (!_istAktiv(f)) {
        _gIndex++;
        continue;
      }
      setState(() => _guidedPrompt = _kurzPrompt(f));
      await _speak(_ttsPrompt(f));
      if (!_guided || !mounted) break;
      final words = await _listenOnce();
      if (!_guided || !mounted) break;
      final cmd = _navBefehl(words);
      if (cmd == 'stopp') break;
      if (cmd == 'zurueck') {
        _gIndex = _vorherigerAktiver(_gIndex);
        continue;
      }
      if (cmd == 'weiter') {
        _gIndex++;
        continue;
      }
      if (cmd == 'wiederholen') continue;
      final ok = _applyValue(f, words);
      _modellInControllers();
      setState(() {});
      if (ok) {
        _gIndex++;
      } else {
        await _speak('Nicht verstanden.');
      }
    }
    if (_guided) {
      await _speak('Fertig.');
    }
    if (mounted) {
      setState(() {
        _guided = false;
        _guidedPrompt = '';
      });
    }
  }

  int _vorherigerAktiver(int von) {
    for (var i = von - 1; i >= 0; i--) {
      if (_istAktiv(_reihenfolge[i])) return i;
    }
    return von;
  }

  String _navBefehl(String w) {
    final t = w.toLowerCase();
    if (RegExp(r'\b(stopp|stop|fertig|abbrechen|ende|beenden)\b').hasMatch(t)) {
      return 'stopp';
    }
    if (RegExp(r'\b(zur[üu]ck|korrektur)\b').hasMatch(t)) return 'zurueck';
    if (RegExp(r'\b(weiter|[üu]berspringen|n[äa]chstes|leer)\b').hasMatch(t)) {
      return 'weiter';
    }
    if (RegExp(r'\b(wiederholen|nochmal)\b').hasMatch(t)) return 'wiederholen';
    return '';
  }

  String? _ersteZahl(String w) {
    final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(w);
    return m?.group(1);
  }

  /// Trägt den gesprochenen Wert ins aktuelle Feld ein. true = erkannt.
  bool _applyValue(_Feld f, String w) {
    final t = w.toLowerCase();
    switch (f) {
      case _Feld.charSich:
        final m = RegExp(r'\b(gg|b|c|d|k)\s*0*([0-9]{1,3})\b').firstMatch(t);
        if (m == null) return false;
        s.schutzart = SchutzartLabel.fromLabel(
            m.group(1) == 'gg' ? 'gG' : m.group(1)!.toUpperCase());
        final n = int.tryParse(m.group(2)!);
        if (n != null && Tabelle6.nennstroeme(s.schutzart).contains(n)) {
          s.vorgSicherung = n;
        }
        return true;
      case _Feld.spannung:
        if (t.contains('400')) {
          s.spannung = '400';
          return true;
        }
        if (t.contains('230')) {
          s.spannung = '230';
          return true;
        }
        return false;
      case _Feld.fiVorhanden:
        if (RegExp(r'\b(ja|vorhanden|fi)\b').hasMatch(t)) {
          _fiVorhanden = true;
          return true;
        }
        if (RegExp(r'\b(nein|kein|keine|nicht|ohne)\b').hasMatch(t)) {
          _fiVorhanden = false;
          return true;
        }
        return false;
      case _Feld.fiTyp:
        if (RegExp(r'\bb\b').hasMatch(t) || t.contains('typ b')) {
          s.fiTyp = 'B';
          return true;
        }
        if (RegExp(r'\ba\b').hasMatch(t) || t.contains('typ a')) {
          s.fiTyp = 'A';
          return true;
        }
        return false;
      default:
        final z = _ersteZahl(w);
        if (z == null) return false;
        switch (f) {
          case _Feld.fiIdn:
            s.fiIdn = z;
            break;
          case _Feld.auslI:
            s.ausloesestrom = z;
            break;
          case _Feld.auslT:
            s.ausloesezeit = z;
            break;
          case _Feld.auslIDc:
            s.ausloesestromDc = z;
            break;
          case _Feld.auslTDc:
            s.ausloesezeitDc = z;
            break;
          case _Feld.ikLn:
            s.ikLn = z;
            break;
          case _Feld.ikLpe:
            s.ikLpe = z;
            break;
          case _Feld.ub:
            s.ub = z;
            break;
          case _Feld.rlow:
            s.rlow = z;
            break;
          case _Feld.riso:
            s.riso = z;
            break;
          default:
            return false;
        }
        return true;
    }
  }

  String _ttsPrompt(_Feld f) {
    switch (f) {
      case _Feld.charSich:
        return 'Charakteristik und Sicherung?';
      case _Feld.spannung:
        return 'Spannung?';
      case _Feld.fiVorhanden:
        return 'F I vorhanden? Ja oder nein.';
      case _Feld.fiTyp:
        return 'F I Typ? A oder B.';
      case _Feld.fiIdn:
        return 'Bemessungsfehlerstrom in Milliampere?';
      case _Feld.auslI:
        return 'Auslösestrom?';
      case _Feld.auslT:
        return 'Auslösezeit?';
      case _Feld.auslIDc:
        return 'Auslösestrom Gleichstrom?';
      case _Feld.auslTDc:
        return 'Auslösezeit Gleichstrom?';
      case _Feld.ikLn:
        return 'I K L N?';
      case _Feld.ikLpe:
        return 'I K L P E?';
      case _Feld.ub:
        return 'Berührungsspannung?';
      case _Feld.rlow:
        return 'Schutzleiterwiderstand R LOW?';
      case _Feld.riso:
        return 'Isolationswiderstand?';
    }
  }

  String _kurzPrompt(_Feld f) {
    switch (f) {
      case _Feld.charSich:
        return 'Charakteristik + Sicherung (z. B. „B16")';
      case _Feld.spannung:
        return 'Spannung (230 / 400)';
      case _Feld.fiVorhanden:
        return 'FI vorhanden? („ja"/„nein")';
      case _Feld.fiTyp:
        return 'FI-Typ („A"/„B")';
      case _Feld.fiIdn:
        return 'FI / IΔN [mA]';
      case _Feld.auslI:
        return 'Auslösestrom [mA]';
      case _Feld.auslT:
        return 'Auslösezeit [ms]';
      case _Feld.auslIDc:
        return 'Auslösestrom DC [mA]';
      case _Feld.auslTDc:
        return 'Auslösezeit DC [ms]';
      case _Feld.ikLn:
        return 'IK L-N [A]';
      case _Feld.ikLpe:
        return 'IK L-PE [A]';
      case _Feld.ub:
        return 'UB [V]';
      case _Feld.rlow:
        return 'RLOW [Ω]';
      case _Feld.riso:
        return 'RISO [MΩ]';
    }
  }

  Widget _diktierKarte() {
    final cs = Theme.of(context).colorScheme;

    if (_guided) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _guidedHoert ? Colors.red.shade50 : cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_guidedHoert ? Icons.mic : Icons.volume_up,
                  color: _guidedHoert ? Colors.red : cs.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Geführte Messung',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              OutlinedButton.icon(
                onPressed: _stopGuided,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stopp'),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Aktuell: $_guidedPrompt',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _guidedHoert ? 'Höre zu …' : 'Ansage läuft …',
              style: const TextStyle(fontSize: 12),
            ),
            const Text(
              'Befehle: „weiter" (überspringen) · „zurück" · „stopp"',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _hoert ? Colors.red.shade50 : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hände-frei: Messwerte per Sprache',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _startGuided,
                  icon: const Icon(Icons.assistant_navigation),
                  label: const Text('Geführt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _messungDiktieren,
                  icon: Icon(_hoert ? Icons.stop : Icons.mic),
                  label: Text(_hoert ? 'Stopp' : 'Frei diktieren'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '„Geführt": App fragt Feld für Feld ab und sagt sie an. '
            '„Frei diktieren": alles am Stück, z. B. „B16, IK L-PE 243, RLOW 0,42".',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
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

  Widget _feld(String key, String label, {bool zahl = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[key],
          decoration: InputDecoration(labelText: label),
          keyboardType: zahl
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: zahl
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
        ),
      );
}
