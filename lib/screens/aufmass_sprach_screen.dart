import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/aufmass.dart';
import '../utils/sprach_parser.dart';

/// Vollbild-Sprach-Erfassung für Aufmaß-Positionen.
///
/// Mikro bleibt offen (Keep-Alive). Pro erkanntem Satz wird via
/// [SprachParser] eine [AufmassPosition] erzeugt und unten an die
/// Liste gehängt. Visuelle Bestätigung + Haptik. Steuerwörter:
///   - "zurück" / "korrektur"   → letzte Position entfernen (Undo via Snackbar)
///   - "pause"                  → Hören pausieren
///   - "weiter hören" / "weiter"→ Hören fortsetzen
///   - "fertig" / "stopp" / "ende" → Loop beenden, Liste übernehmen
class AufmassSprachScreen extends StatefulWidget {
  const AufmassSprachScreen({super.key});

  @override
  State<AufmassSprachScreen> createState() => _AufmassSprachScreenState();
}

class _AufmassSprachScreenState extends State<AufmassSprachScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechBereit = false;
  bool _aktiv = false;        // Loop läuft (vs. Pause/Beendet)
  bool _hoert = false;        // STT lauscht gerade
  bool _imSetState = false;

  final List<AufmassPosition> _positionen = [];
  String _liveText = '';      // Was STT zwischenzeitlich versteht
  String _hinweis = 'Tipp Start, um zu beginnen.';

  Completer<String>? _hoerCompleter;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('de-DE');
    _tts.awaitSpeakCompletion(true);
    // Auto-Start: direkt loslegen, dann ist der Fluss am schnellsten.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _aktiv = false;
    final c = _hoerCompleter;
    if (c != null && !c.isCompleted) c.complete('');
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ---------- Lifecycle ----------

  Future<void> _start() async {
    if (_aktiv) return;
    if (!_speechBereit) {
      _speechBereit = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {},
      );
    }
    if (!_speechBereit) {
      if (!mounted) return;
      setState(() => _hinweis = 'Spracherkennung nicht verfügbar (Mikrofon-Freigabe?)');
      return;
    }
    setState(() {
      _aktiv = true;
      _hinweis = 'Höre zu …';
    });
    await _sprich(_positionen.isEmpty
        ? 'Bitte Position diktieren. Zum Beispiel: zehn Steckdosen.'
        : 'Weiter aufnehmen.');
    _loop();
  }

  Future<void> _pause() async {
    _aktiv = false;
    final c = _hoerCompleter;
    if (c != null && !c.isCompleted) c.complete('');
    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _hoert = false;
      _hinweis = 'Pause. Tipp ▶ um weiterzumachen.';
    });
  }

  Future<void> _beenden() async {
    _aktiv = false;
    final c = _hoerCompleter;
    if (c != null && !c.isCompleted) c.complete('');
    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    Navigator.pop(context, List<AufmassPosition>.unmodifiable(_positionen));
  }

  // ---------- Loop ----------

  Future<void> _loop() async {
    while (_aktiv && mounted) {
      final words = await _hoereBisAntwort();
      if (!_aktiv || !mounted) break;
      final text = words.trim();
      if (text.isEmpty) continue;

      // 1) Steuerwort?
      final cmd = _erkenneSteuerwort(text);
      if (cmd != null) {
        await _fuehreSteuerwortAus(cmd);
        continue;
      }

      // 2) Position parsen
      final p = SprachParser.parse(text);
      if (p.menge.isEmpty && p.bezeichnung.isEmpty) {
        // nichts brauchbares, einfach weiterhören
        continue;
      }

      _positionHinzu(p);
      _vibriere();
      _setLive(text);
    }
  }

  /// Lauscht so lange neu, bis ein nicht-leeres Ergebnis kommt — oder
  /// der Modus beendet wird.
  Future<String> _hoereBisAntwort() async {
    while (_aktiv && mounted) {
      final w = await _einmalHoeren();
      if (!_aktiv) return '';
      if (w.trim().isNotEmpty) return w;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return '';
  }

  Future<String> _einmalHoeren() async {
    final c = Completer<String>();
    _hoerCompleter = c;
    if (mounted) setState(() => _hoert = true);
    await _speech.listen(
      onResult: (r) {
        if (r.recognizedWords.isNotEmpty) {
          _setLive(r.recognizedWords);
        }
        if (r.finalResult && !c.isCompleted) c.complete(r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: 'de_DE',
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    final res = await c.future;
    if (mounted) setState(() => _hoert = false);
    return res;
  }

  void _onSpeechStatus(String st) {
    if ((st == 'done' || st == 'notListening') &&
        _hoerCompleter != null &&
        !_hoerCompleter!.isCompleted) {
      _hoerCompleter!.complete('');
    }
  }

  Future<void> _sprich(String text) async {
    await _speech.stop();
    await _tts.speak(text);
  }

  // ---------- Steuerwörter ----------

  static const _zurueckSet = {'zurück', 'zurueck', 'korrektur', 'rückgängig', 'rueckgaengig', 'lösch', 'loesch'};
  static const _pauseSet = {'pause', 'stopp', 'stop', 'anhalten', 'unterbrechen'};
  static const _weiterSet = {'weiter', 'weiterhören', 'weiterhoeren'};
  static const _endeSet = {'fertig', 'ende', 'beenden', 'übernehmen', 'uebernehmen', 'speichern'};

  String? _erkenneSteuerwort(String text) {
    // Nur akzeptieren wenn der ganze Satz aus 1–2 Wörtern besteht, sonst
    // sind das eher Bezeichnungen ("LS Schalter zurück in Reserve").
    final norm = text.toLowerCase().trim();
    final woerter = norm.split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[.,!?;:]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (woerter.isEmpty || woerter.length > 3) return null;

    // 1-Wort
    if (woerter.length == 1) {
      final w = woerter.first;
      if (_zurueckSet.contains(w)) return 'zurueck';
      if (_pauseSet.contains(w)) return 'pause';
      if (_weiterSet.contains(w)) return 'weiter';
      if (_endeSet.contains(w)) return 'ende';
      return null;
    }

    // 2-/3-Wort: explizite Kombis
    final ganz = woerter.join(' ');
    if (ganz == 'weiter hören' || ganz == 'weiter hoeren') return 'weiter';
    if (ganz == 'zurück nehmen' || ganz == 'zurueck nehmen') return 'zurueck';
    if (ganz == 'aufnahme stoppen' || ganz == 'aufnahme stopp') return 'pause';
    if (ganz == 'aufnahme beenden') return 'ende';
    return null;
  }

  Future<void> _fuehreSteuerwortAus(String cmd) async {
    switch (cmd) {
      case 'zurueck':
        _undoLetzte();
        break;
      case 'pause':
        await _pause();
        break;
      case 'weiter':
        // Loop läuft schon, hier nur kurz visuell bestätigen.
        _vibriere();
        break;
      case 'ende':
        await _beenden();
        break;
    }
  }

  // ---------- Position-Verwaltung ----------

  void _positionHinzu(SprachPosition p) {
    if (!mounted) return;
    setState(() {
      _positionen.add(AufmassPosition(
        bezeichnung: p.bezeichnung,
        menge: p.menge,
        einheit: p.einheit ?? 'Stk',
      ));
      _hinweis = 'Hinzugefügt — höre weiter zu …';
    });
  }

  void _undoLetzte() {
    if (_positionen.isEmpty) return;
    final entfernt = _positionen.removeLast();
    _vibriere();
    if (!mounted) return;
    setState(() => _hinweis = 'Letzte Position entfernt: ${_kurz(entfernt)}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Entfernt: ${_kurz(entfernt)}'),
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () {
          if (!mounted) return;
          setState(() {
            _positionen.add(entfernt);
            _hinweis = 'Wiederhergestellt.';
          });
        },
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  String _kurz(AufmassPosition p) {
    final t = [
      if (p.menge.isNotEmpty) '${p.menge} ${p.einheit}',
      if (p.bezeichnung.isNotEmpty) p.bezeichnung,
    ].join(' ');
    return t.isEmpty ? '(leer)' : t;
  }

  void _setLive(String t) {
    if (!mounted || _imSetState) return;
    _imSetState = true;
    setState(() => _liveText = t);
    _imSetState = false;
  }

  void _vibriere() {
    HapticFeedback.mediumImpact();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprach-Erfassung'),
        actions: [
          IconButton(
            tooltip: 'Hilfe',
            icon: const Icon(Icons.help_outline),
            onPressed: _hilfeZeigen,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _statusKopf(),
            const Divider(height: 1),
            Expanded(child: _liste()),
            _bedienleiste(),
          ],
        ),
      ),
    );
  }

  Widget _statusKopf() {
    final t = Theme.of(context);
    final farbe = _aktiv
        ? (_hoert ? Colors.red.shade400 : t.colorScheme.primary)
        : t.disabledColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: t.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _aktiv ? Icons.mic : Icons.mic_off,
                color: farbe,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hinweis,
                  style: t.textTheme.titleSmall?.copyWith(color: farbe),
                ),
              ),
            ],
          ),
          if (_liveText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '„$_liveText"',
              style: t.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _liste() {
    if (_positionen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_list_bulleted,
                  size: 56, color: Theme.of(context).hintColor),
              const SizedBox(height: 12),
              Text(
                'Noch keine Positionen.\n\nBeispiele:\n„zehn Steckdosen"\n„fünf Meter Kabel"\n„drei Lichtauslässe"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      reverse: true, // neueste oben sichtbar
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _positionen.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        // reverse: zeige zuletzt hinzugefügte oben
        final p = _positionen[_positionen.length - 1 - i];
        final idx = _positionen.length - i;
        return ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, child: Text('$idx')),
          title: Text(p.bezeichnung.isEmpty ? '(ohne Bezeichnung)' : p.bezeichnung),
          subtitle: Text('${p.menge.isEmpty ? "-" : p.menge} ${p.einheit}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Diese Position entfernen',
            onPressed: () {
              setState(() => _positionen.remove(p));
              _vibriere();
            },
          ),
        );
      },
    );
  }

  Widget _bedienleiste() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (_aktiv)
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _pause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            )
          else
            Expanded(
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Hören'),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _positionen.isEmpty ? null : _undoLetzte,
              icon: const Icon(Icons.undo),
              label: const Text('Zurück'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _beenden,
              icon: const Icon(Icons.check),
              label: Text(_positionen.isEmpty
                  ? 'Abbrechen'
                  : 'Übernehmen (${_positionen.length})'),
            ),
          ),
        ],
      ),
    );
  }

  void _hilfeZeigen() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sprach-Erfassung'),
        content: const SingleChildScrollView(
          child: Text(
            'Sprich der Reihe nach deine Positionen — das Mikro bleibt offen.\n\n'
            'Beispiele:\n'
            '  • „zehn Steckdosen"\n'
            '  • „fünf Meter Kabel"\n'
            '  • „drei Lichtauslässe"\n'
            '  • „zwei komma fünf Meter NYM"\n'
            '  • „fünfundzwanzig Schalter"\n\n'
            'Steuerung per Sprache:\n'
            '  • „zurück" → letzte Position entfernen (Undo möglich)\n'
            '  • „pause"  → Hören pausieren\n'
            '  • „weiter" → Hören fortsetzen\n'
            '  • „fertig" → Liste übernehmen\n\n'
            'Erkennung der Einheit: „Meter" → m, „Quadratmeter" → m², '
            '„Stück" → Stk, „Stunde" → h. Sonst Standard „Stk".',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}
