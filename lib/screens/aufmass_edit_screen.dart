import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/aufmass.dart';
import '../pdf/aufmass_pdf.dart';
import '../storage/aufmass_storage.dart';
import '../utils/sprach_parser.dart';
import '../widgets/foto_galerie.dart';

class AufmassEditScreen extends StatefulWidget {
  final Aufmass aufmass;
  final bool istNeu;
  const AufmassEditScreen({super.key, required this.aufmass, this.istNeu = false});

  @override
  State<AufmassEditScreen> createState() => _AufmassEditScreenState();
}

class _AufmassEditScreenState extends State<AufmassEditScreen> {
  final _storage = AufmassStorage();
  final _df = DateFormat('dd.MM.yyyy');
  late Aufmass a;

  late final TextEditingController _titel;
  late final TextEditingController _kunde;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    a = widget.aufmass;
    _titel = TextEditingController(text: a.titel);
    _kunde = TextEditingController(text: a.kunde);
    _titel.addListener(_autoSpeichern);
    _kunde.addListener(_autoSpeichern);
  }

  void _autoSpeichern() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _speichernStill);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titel.dispose();
    _kunde.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    a.titel = _titel.text;
    a.kunde = _kunde.text;
  }

  Future<void> _speichernStill() async {
    _uebernehmen();
    await _storage.speichere(a);
  }

  Future<void> _pdfTeilen() async {
    await _speichernStill();
    final bytes = await AufmassPdf.erzeuge(a);
    final name =
        'Aufmass_${a.anzeigeTitel}_${a.datum != null ? _df.format(a.datum!) : ""}.pdf'
            .replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜß _.-]'), '')
            .replaceAll(' ', '_');
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  Future<void> _pdfVorschau() async {
    _uebernehmen();
    await Printing.layoutPdf(onLayout: (_) => AufmassPdf.erzeuge(a));
  }

  Future<void> _datumWaehlen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: a.datum ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => a.datum = d);
      _speichernStill();
    }
  }

  void _positionHinzufuegen() {
    setState(() => a.positionen.add(AufmassPosition()));
    _speichernStill();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _speichernStill(),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.istNeu ? 'Neue Liste' : 'Aufmaß'),
        actions: [
          IconButton(
            tooltip: 'PDF-Vorschau',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _pdfVorschau,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pdfTeilen,
        icon: const Icon(Icons.email_outlined),
        label: const Text('PDF per E-Mail'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
              controller: _titel,
              decoration: const InputDecoration(labelText: 'Projekt / Bauvorhaben')),
          const SizedBox(height: 12),
          TextField(
              controller: _kunde,
              decoration: const InputDecoration(labelText: 'Kunde')),
          const SizedBox(height: 12),
          InkWell(
            onTap: _datumWaehlen,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Datum'),
              child: Text(a.datum != null ? _df.format(a.datum!) : '—'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Positionen (${a.positionen.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              FilledButton.tonalIcon(
                onPressed: _positionHinzufuegen,
                icon: const Icon(Icons.add),
                label: const Text('Position'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...a.positionen.asMap().entries.map((e) => _PositionCard(
                key: ValueKey(e.value),
                index: e.key,
                position: e.value,
                onChanged: _speichernStill,
                onDelete: () {
                  setState(() => a.positionen.removeAt(e.key));
                  _speichernStill();
                },
              )),

          const SizedBox(height: 24),
          Text('Fotos & Bemerkungen',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FotoGalerie(fotos: a.fotos, onChanged: _speichernStill),
        ],
      ),
    );
  }
}

class _PositionCard extends StatefulWidget {
  final int index;
  final AufmassPosition position;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _PositionCard({
    super.key,
    required this.index,
    required this.position,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<_PositionCard> {
  late final TextEditingController _bez;
  late final TextEditingController _menge;
  final SpeechToText _speech = SpeechToText();
  bool _hoert = false;

  @override
  void initState() {
    super.initState();
    _bez = TextEditingController(text: widget.position.bezeichnung);
    _menge = TextEditingController(text: widget.position.menge);
  }

  @override
  void dispose() {
    _speech.stop();
    _bez.dispose();
    _menge.dispose();
    super.dispose();
  }

  Future<void> _diktieren() async {
    if (_hoert) {
      await _speech.stop();
      setState(() => _hoert = false);
      return;
    }
    final ok = await _speech.initialize(onStatus: (s) {
      if (s == 'done' || s == 'notListening') {
        if (mounted) setState(() => _hoert = false);
      }
    }, onError: (_) {
      if (mounted) setState(() => _hoert = false);
    });
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
        if (r.finalResult) _verarbeite(r.recognizedWords);
      },
    );
  }

  void _verarbeite(String text) {
    final p = SprachParser.parse(text);
    setState(() {
      if (p.menge.isNotEmpty) {
        _menge.text = p.menge;
        widget.position.menge = p.menge;
      }
      if (p.bezeichnung.isNotEmpty) {
        _bez.text = p.bezeichnung;
        widget.position.bezeichnung = p.bezeichnung;
      }
      if (p.einheit != null) widget.position.einheit = p.einheit!;
      _hoert = false;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${widget.index + 1}')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bez,
                    decoration: const InputDecoration(labelText: 'Bezeichnung'),
                    onChanged: (v) {
                      widget.position.bezeichnung = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: _hoert ? 'Stopp' : 'Diktieren („zehn Steckdosen")',
                  icon: Icon(_hoert ? Icons.mic : Icons.mic_none,
                      color: _hoert ? Colors.red : null),
                  onPressed: _diktieren,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _menge,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    decoration: const InputDecoration(labelText: 'Menge'),
                    onChanged: (v) {
                      widget.position.menge = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: aufmassEinheiten.contains(widget.position.einheit)
                        ? widget.position.einheit
                        : aufmassEinheiten.first,
                    decoration: const InputDecoration(labelText: 'Einheit'),
                    items: aufmassEinheiten
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      widget.position.einheit = v ?? 'Stk';
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
