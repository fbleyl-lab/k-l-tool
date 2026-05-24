import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/stromkreis.dart' show Pruefstatus;

/// Eingabeart eines Prüfschritts im geführten Prüfmodus.
enum PruefEingabe { zahl, text, jaNein, auswahl, dropdown, info }

/// Ein einzelner Schritt im geführten Prüfablauf. Die Werte werden über
/// Closures direkt aus dem Zielobjekt (Stromkreis / WallboxProtokoll) gelesen
/// und geschrieben – der Wizard kennt das Modell nicht.
class Pruefschritt {
  final String titel;
  final String hinweis; // Norm-/Sicherheitshinweis + Grenzwert
  final PruefEingabe eingabe;
  final String einheit;
  final String inputLabel; // Label des Eingabefelds (Default „Messwert")
  final bool groesserErlaubt; // „>" erlauben (Iso-Überlauf)
  final String? schnellWert; // optional: Schnell-Eintrag-Button (z. B. „>500")
  final List<String> Function() optionen; // auswahl/dropdown (dynamisch)
  final String Function() wertLesen;
  final void Function(String) wertSchreiben;
  final Pruefstatus? Function()? ampel; // Live-Bewertung (zahl/auswahl)
  final Pruefstatus Function()? statusLesen; // jaNein
  final void Function(Pruefstatus)? statusSchreiben; // jaNein
  final bool Function() sichtbar; // bedingt einblenden
  final void Function()? vorAnzeige; // einmal beim Betreten (z. B. FI-Übernahme)

  Pruefschritt({
    required this.titel,
    this.hinweis = '',
    this.eingabe = PruefEingabe.zahl,
    this.einheit = '',
    this.inputLabel = 'Messwert',
    this.groesserErlaubt = false,
    this.schnellWert,
    List<String> Function()? optionen,
    String Function()? wertLesen,
    void Function(String)? wertSchreiben,
    this.ampel,
    this.statusLesen,
    this.statusSchreiben,
    bool Function()? sichtbar,
    this.vorAnzeige,
  })  : optionen = optionen ?? (() => const []),
        wertLesen = wertLesen ?? (() => ''),
        wertSchreiben = wertSchreiben ?? ((_) {}),
        sichtbar = sichtbar ?? (() => true);
}

/// Vollbild-Assistent: führt Schritt für Schritt durch den Prüfablauf.
class GefuehrtePruefungScreen extends StatefulWidget {
  final String titel;
  final List<Pruefschritt> schritte;
  final Future<void> Function()? onSpeichern;
  const GefuehrtePruefungScreen({
    super.key,
    required this.titel,
    required this.schritte,
    this.onSpeichern,
  });

  @override
  State<GefuehrtePruefungScreen> createState() =>
      _GefuehrtePruefungScreenState();
}

class _GefuehrtePruefungScreenState extends State<GefuehrtePruefungScreen> {
  final _ctrl = TextEditingController();
  int _i = 0;
  bool _laden = false; // true, während _ctrl programmatisch befüllt wird

  // Freihandmodus (Sprache): ansagen -> warten bis Antwort -> nächster Schritt.
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _freihand = false;
  bool _speechBereit = false;
  bool _hoert = false;
  String _lastWords = '';
  Completer<String>? _hoerCompleter;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_laden) return;
      final s = widget.schritte[_i];
      if (s.eingabe == PruefEingabe.zahl || s.eingabe == PruefEingabe.text) {
        s.wertSchreiben(_ctrl.text);
        setState(() {});
      }
    });
    _tts.setLanguage('de-DE');
    _tts.awaitSpeakCompletion(true);
    _i = _erster();
    _ladeSchritt();
  }

  @override
  void dispose() {
    _freihand = false;
    if (_hoerCompleter != null && !_hoerCompleter!.isCompleted) {
      _hoerCompleter!.complete('');
    }
    _speech.stop();
    _tts.stop();
    _ctrl.dispose();
    super.dispose();
  }

  int _erster() {
    for (int j = 0; j < widget.schritte.length; j++) {
      if (widget.schritte[j].sichtbar()) return j;
    }
    return 0;
  }

  int? _naechster() {
    for (int j = _i + 1; j < widget.schritte.length; j++) {
      if (widget.schritte[j].sichtbar()) return j;
    }
    return null;
  }

  int? _vorheriger() {
    for (int j = _i - 1; j >= 0; j--) {
      if (widget.schritte[j].sichtbar()) return j;
    }
    return null;
  }

  List<int> get _sichtbar => [
        for (int j = 0; j < widget.schritte.length; j++)
          if (widget.schritte[j].sichtbar()) j
      ];

  void _ladeSchritt() {
    final s = widget.schritte[_i];
    s.vorAnzeige?.call();
    if (s.eingabe == PruefEingabe.zahl || s.eingabe == PruefEingabe.text) {
      _laden = true;
      _ctrl.text = s.wertLesen();
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      _laden = false;
    }
  }

  Future<void> _weiter() async {
    final n = _naechster();
    if (n == null) {
      await widget.onSpeichern?.call();
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() {
      _i = n;
      _ladeSchritt();
    });
  }

  void _zurueck() {
    final p = _vorheriger();
    if (p == null) return;
    setState(() {
      _i = p;
      _ladeSchritt();
    });
  }

  // ---------- Freihandmodus (Sprache) ----------

  Future<void> _freihandUmschalten() async {
    if (_freihand) {
      await _freihandAus();
      return;
    }
    if (!_speechBereit) {
      _speechBereit =
          await _speech.initialize(onStatus: _onSpeechStatus, onError: (_) {});
    }
    if (!_speechBereit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Spracherkennung nicht verfügbar (Mikrofon-Freigabe?)')));
      }
      return;
    }
    setState(() => _freihand = true);
    _freihandLoop();
  }

  Future<void> _freihandAus() async {
    _freihand = false;
    if (_hoerCompleter != null && !_hoerCompleter!.isCompleted) {
      _hoerCompleter!.complete('');
    }
    await _speech.stop();
    await _tts.stop();
    if (mounted) setState(() => _hoert = false);
  }

  void _onSpeechStatus(String st) {
    if ((st == 'done' || st == 'notListening') &&
        _hoerCompleter != null &&
        !_hoerCompleter!.isCompleted) {
      _hoerCompleter!.complete(_lastWords);
    }
  }

  /// Sagt jeden Schritt an und wartet (Keep-Alive) bis ein Messwert oder
  /// Befehl gesprochen wird – erst dann geht es weiter.
  Future<void> _freihandLoop() async {
    int? angesagt;
    while (_freihand && mounted) {
      if (angesagt != _i) {
        setState(_ladeSchritt);
        await _ansagen(widget.schritte[_i]);
        angesagt = _i;
        if (!_freihand || !mounted) break;
      }
      final words = await _hoereBisAntwort();
      if (!_freihand || !mounted) break;
      final cmd = _navBefehl(words);
      if (cmd == 'stopp') {
        await _freihandAus();
        break;
      }
      if (cmd == 'zurueck') {
        final p = _vorheriger();
        if (p != null) _i = p;
        angesagt = null;
        continue;
      }
      if (cmd == 'wiederholen') {
        angesagt = null;
        continue;
      }
      if (cmd == 'weiter') {
        final n = _naechster();
        if (n == null) {
          await _abschluss();
          break;
        }
        _i = n;
        continue;
      }
      final ok = await _wertSetzen(widget.schritte[_i], words);
      if (ok) {
        final n = _naechster();
        if (n == null) {
          await _abschluss();
          break;
        }
        _i = n;
      } else {
        await _sprich('Nicht verstanden. Bitte den Messwert wiederholen.');
      }
    }
  }

  /// Lauscht so lange (immer wieder neu), bis ein nicht-leeres Ergebnis kommt.
  Future<String> _hoereBisAntwort() async {
    while (_freihand && mounted) {
      final w = await _einmalHoeren();
      if (!_freihand) return '';
      if (w.trim().isNotEmpty) return w;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return '';
  }

  Future<String> _einmalHoeren() async {
    _lastWords = '';
    final c = Completer<String>();
    _hoerCompleter = c;
    if (mounted) setState(() => _hoert = true);
    await _speech.listen(
      onResult: (r) {
        _lastWords = r.recognizedWords;
        if (r.finalResult && !c.isCompleted) c.complete(r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: false,
        localeId: 'de_DE',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 6),
      ),
    );
    final res = await c.future;
    if (mounted) setState(() => _hoert = false);
    return res;
  }

  Future<void> _ansagen(Pruefschritt s) async {
    final teile = <String>[s.titel, if (s.hinweis.isNotEmpty) s.hinweis];
    await _sprich(teile.join('. '));
  }

  Future<void> _sprich(String text) async {
    await _speech.stop();
    await _tts.speak(text);
  }

  Future<bool> _wertSetzen(Pruefschritt s, String words) async {
    switch (s.eingabe) {
      case PruefEingabe.zahl:
        final z = _ersteZahl(words);
        if (z == null) return false;
        s.wertSchreiben(z);
        _laden = true;
        _ctrl.text = z;
        _laden = false;
        setState(() {});
        await _sprich('$z ${s.einheit}'.trim());
        return true;
      case PruefEingabe.jaNein:
        final st = _jaNein(words);
        if (st == null) return false;
        s.statusSchreiben?.call(st);
        setState(() {});
        await _sprich(
            st == Pruefstatus.ok ? 'in Ordnung' : 'nicht in Ordnung');
        return true;
      case PruefEingabe.auswahl:
        final o = _matchOption(words, s.optionen());
        if (o == null) return false;
        s.wertSchreiben(o);
        setState(() {});
        await _sprich(o);
        return true;
      case PruefEingabe.dropdown:
        final opts = s.optionen();
        final z = _ersteZahl(words);
        final treffer =
            (z != null && opts.contains(z)) ? z : _matchOption(words, opts);
        if (treffer == null) return false;
        s.wertSchreiben(treffer);
        setState(() {});
        await _sprich(treffer);
        return true;
      case PruefEingabe.text:
        final t = words.trim();
        if (t.isEmpty) return false;
        s.wertSchreiben(t);
        _laden = true;
        _ctrl.text = t;
        _laden = false;
        setState(() {});
        await _sprich(t);
        return true;
      case PruefEingabe.info:
        return false;
    }
  }

  Future<void> _abschluss() async {
    await _sprich('Prüfung abgeschlossen.');
    await _freihandAus();
    await widget.onSpeichern?.call();
    if (mounted) Navigator.pop(context, true);
  }

  String _navBefehl(String w) {
    final t = w.toLowerCase();
    if (RegExp(r'\b(stopp|stop|beenden|ende|abbrechen)\b').hasMatch(t)) {
      return 'stopp';
    }
    if (RegExp(r'\b(zur[üu]ck|korrektur)\b').hasMatch(t)) return 'zurueck';
    if (RegExp(r'\b(wiederholen|wiederhole|nochmal)\b').hasMatch(t)) {
      return 'wiederholen';
    }
    if (RegExp(r'\b(weiter|[üu]berspringen|n[äa]chstes|n[äa]chster)\b')
        .hasMatch(t)) {
      return 'weiter';
    }
    return '';
  }

  String? _ersteZahl(String w) =>
      RegExp(r'[0-9]+(?:[.,][0-9]+)?').firstMatch(w)?.group(0);

  Pruefstatus? _jaNein(String w) {
    final t = w.toLowerCase();
    if (RegExp(r'(nicht|durchgefallen|fehlerhaft|negativ|\bnein\b)')
        .hasMatch(t)) {
      return Pruefstatus.nichtOk;
    }
    if (RegExp(r'(in ordnung|okay|\bok\b|passt|bestanden|positiv|\bja\b|gut)')
        .hasMatch(t)) {
      return Pruefstatus.ok;
    }
    return null;
  }

  String? _matchOption(String w, List<String> optionen) {
    final t = w.toLowerCase().replaceAll(' ', '');
    for (final o in optionen) {
      if (t.contains(o.toLowerCase())) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schritte[_i];
    final sichtbar = _sichtbar;
    final pos = sichtbar.indexOf(_i) + 1;
    final total = sichtbar.length;
    final letzter = _naechster() == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        actions: [
          IconButton(
            tooltip: 'Freihandmodus (Sprache)',
            icon: Icon(_freihand ? Icons.mic : Icons.mic_none),
            color: _freihand ? Colors.red : null,
            onPressed: _freihandUmschalten,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: total == 0 ? 0 : pos / total),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schritt $pos von $total',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(s.titel,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (s.hinweis.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.hinweis)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _freihand ? _freihandPanel(s) : _eingabe(s),
                ),
              ),
              if (_freihand)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _freihandAus,
                    icon: const Icon(Icons.stop),
                    label: const Text('Freihand beenden'),
                  ),
                )
              else
                Row(
                  children: [
                    if (_vorheriger() != null)
                      OutlinedButton.icon(
                        onPressed: _zurueck,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Zurück'),
                      ),
                    const Spacer(),
                    TextButton(
                        onPressed: _weiter,
                        child: const Text('Überspringen')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _weiter,
                      icon: Icon(letzter ? Icons.check : Icons.arrow_forward),
                      label: Text(letzter ? 'Fertig' : 'Weiter'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eingabe(Pruefschritt s) {
    switch (s.eingabe) {
      case PruefEingabe.info:
        return const SizedBox.shrink();
      case PruefEingabe.text:
        return TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: s.inputLabel,
            border: const OutlineInputBorder(),
          ),
        );
      case PruefEingabe.zahl:
        final st = s.ampel?.call();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: s.groesserErlaubt
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(s.groesserErlaubt ? r'[0-9.,>]' : r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: s.inputLabel,
                suffixText: s.einheit,
                border: const OutlineInputBorder(),
              ),
            ),
            if (s.schnellWert != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _ctrl.text = s.schnellWert!,
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: Text(s.schnellWert!),
                ),
              ),
            if (st != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ampelChip(st),
              ),
          ],
        );
      case PruefEingabe.auswahl:
        final aktuell = s.wertLesen();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: s.optionen()
              .map((o) => ChoiceChip(
                    label: Text(o),
                    selected: o == aktuell,
                    onSelected: (_) => setState(() => s.wertSchreiben(o)),
                  ))
              .toList(),
        );
      case PruefEingabe.dropdown:
        final opts = s.optionen();
        final aktuell = s.wertLesen();
        return DropdownButtonFormField<String>(
          initialValue: opts.contains(aktuell) ? aktuell : null,
          decoration: InputDecoration(
            labelText: s.inputLabel,
            suffixText: s.einheit,
            border: const OutlineInputBorder(),
          ),
          items: opts
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => s.wertSchreiben(v));
          },
        );
      case PruefEingabe.jaNein:
        final st = s.statusLesen?.call() ?? Pruefstatus.offen;
        return SegmentedButton<Pruefstatus>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Pruefstatus.offen, label: Text('—')),
            ButtonSegment(value: Pruefstatus.ok, label: Text('i.O.')),
            ButtonSegment(value: Pruefstatus.nichtOk, label: Text('n.i.O.')),
          ],
          selected: {st},
          onSelectionChanged: (sel) =>
              setState(() => s.statusSchreiben?.call(sel.first)),
        );
    }
  }

  Widget _freihandPanel(Pruefschritt s) {
    final st = s.eingabe == PruefEingabe.jaNein
        ? s.statusLesen?.call()
        : s.ampel?.call();
    final wert = (s.eingabe == PruefEingabe.zahl ||
            s.eingabe == PruefEingabe.text)
        ? _ctrl.text
        : (s.eingabe == PruefEingabe.auswahl ||
                s.eingabe == PruefEingabe.dropdown
            ? s.wertLesen()
            : '');
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_hoert ? Icons.mic : Icons.volume_up,
                color: _hoert ? Colors.red : cs.primary),
            const SizedBox(width: 8),
            Text(_hoert ? 'Höre zu …' : 'Ansage läuft …',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        if (wert.trim().isNotEmpty)
          Text('Aktueller Wert: $wert ${s.einheit}'.trim(),
              style: Theme.of(context).textTheme.titleLarge),
        if (st != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ampelChip(st),
          ),
        const SizedBox(height: 20),
        Text(
          'Sprich den Messwert – oder „weiter", „zurück", „wiederholen", „stopp".',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _ampelChip(Pruefstatus s) {
    late final Color farbe;
    late final String text;
    switch (s) {
      case Pruefstatus.ok:
        farbe = Colors.green;
        text = 'i.O.';
        break;
      case Pruefstatus.nichtOk:
        farbe = Colors.red;
        text = 'n.i.O.';
        break;
      case Pruefstatus.offen:
        farbe = Colors.grey;
        text = 'noch offen';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: farbe),
      ),
      child: Text('Beurteilung: $text',
          style: TextStyle(color: farbe, fontWeight: FontWeight.bold)),
    );
  }
}
