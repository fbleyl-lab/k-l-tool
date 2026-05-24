import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/protokoll.dart';
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../pdf/protokoll_pdf.dart';
import '../storage/protokoll_storage.dart';
import '../widgets/foto_galerie.dart';
import 'gefuehrte_pruefung_screen.dart';
import 'pruef_schritte.dart';
import 'signature_screen.dart';
import 'stromkreis_edit_screen.dart';

class ProtokollEditScreen extends StatefulWidget {
  final Protokoll protokoll;
  final bool istNeu;
  const ProtokollEditScreen(
      {super.key, required this.protokoll, this.istNeu = false});

  @override
  State<ProtokollEditScreen> createState() => _ProtokollEditScreenState();
}

class _ProtokollEditScreenState extends State<ProtokollEditScreen> {
  final _storage = ProtokollStorage();
  final _df = DateFormat('dd.MM.yyyy');
  late Protokoll p;

  late final TextEditingController _gebName;
  late final TextEditingController _gebNr;
  late final TextEditingController _anlagenbez;
  late final TextEditingController _name;
  late final TextEditingController _firma;
  late final TextEditingController _messgeraet;
  late final TextEditingController _untMonteur;
  late final TextEditingController _untKunde;
  late final TextEditingController _bemerkungen;

  @override
  void initState() {
    super.initState();
    p = widget.protokoll;
    _gebName = TextEditingController(text: p.gebName);
    _gebNr = TextEditingController(text: p.gebNr);
    _anlagenbez = TextEditingController(text: p.anlagenbez);
    _name = TextEditingController(text: p.name);
    _firma = TextEditingController(text: p.firma);
    _messgeraet = TextEditingController(text: p.messgeraet);
    _untMonteur = TextEditingController(text: p.unterschriftMonteur);
    _untKunde = TextEditingController(text: p.unterschriftKunde);
    _bemerkungen = TextEditingController(text: p.bemerkungen);

    // Prüfer-Name automatisch als Monteur-Unterschrift übernehmen,
    // solange der Monteur-Name nicht manuell abweichend geändert wurde.
    _letzterPruefer = _name.text;
    _name.addListener(_prueferUebernehmen);

    // Auto-Speichern: jede Texteingabe wird (verzögert) gespeichert.
    for (final c in [
      _gebName,
      _gebNr,
      _anlagenbez,
      _name,
      _firma,
      _messgeraet,
      _untMonteur,
      _untKunde,
      _bemerkungen,
    ]) {
      c.addListener(_autoSpeichern);
    }
  }

  Timer? _debounce;
  void _autoSpeichern() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _speichernStill);
  }

  String _letzterPruefer = '';

  void _prueferUebernehmen() {
    final neu = _name.text;
    if (_untMonteur.text == _letzterPruefer) {
      _untMonteur.text = neu;
      p.unterschriftMonteur = neu;
    }
    _letzterPruefer = neu;
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _gebName,
      _gebNr,
      _anlagenbez,
      _name,
      _firma,
      _messgeraet,
      _untMonteur,
      _untKunde,
      _bemerkungen
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _uebernehmen() {
    p.gebName = _gebName.text;
    p.gebNr = _gebNr.text;
    p.anlagenbez = _anlagenbez.text;
    p.name = _name.text;
    p.firma = _firma.text;
    p.messgeraet = _messgeraet.text;
    p.unterschriftMonteur = _untMonteur.text;
    p.unterschriftKunde = _untKunde.text;
    p.bemerkungen = _bemerkungen.text;
  }

  Future<void> _speichern() async {
    _uebernehmen();
    await _storage.speichere(p);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gespeichert')),
      );
    }
  }

  Future<void> _pdfTeilen() async {
    _uebernehmen();
    await _storage.speichere(p);
    final bytes = await ProtokollPdf.erzeuge(p);
    final name = _dateiname('pdf');
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  Future<void> _pdfVorschau() async {
    _uebernehmen();
    await Printing.layoutPdf(
      onLayout: (_) => ProtokollPdf.erzeuge(p),
      name: _dateiname('pdf'),
    );
  }

  Future<void> _jsonExport() async {
    _uebernehmen();
    final bytes = utf8.encode(_storage.exportJson(p));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes,
              name: _dateiname('json'), mimeType: 'application/json')
        ],
        text: 'Protokoll-Backup',
      ),
    );
  }

  String _dateiname(String ext) {
    final base = p.titel.replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜß _-]'), '');
    final datum = p.datum != null ? _df.format(p.datum!) : '';
    return 'Messprotokoll_${base}_$datum.$ext'.replaceAll(' ', '_');
  }

  Future<void> _datumWaehlen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: p.datum ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => p.datum = d);
      _speichernStill();
    }
  }

  Future<void> _stromkreisBearbeiten(int? index) async {
    final vorlage = index != null ? p.stromkreise[index].copy() : Stromkreis();
    // Vorheriger Stromkreis für FI-Werte-Übernahme:
    final vorIndex = index != null ? index - 1 : p.stromkreise.length - 1;
    final fiVorlage =
        (vorIndex >= 0 && vorIndex < p.stromkreise.length)
            ? p.stromkreise[vorIndex]
            : null;
    final ergebnis = await Navigator.push<Stromkreis>(
      context,
      MaterialPageRoute(
        builder: (_) => StromkreisEditScreen(
          stromkreis: vorlage,
          nummer: (index ?? p.stromkreise.length) + 1,
          netzform: p.netzform,
          fiVorlage: fiVorlage,
        ),
      ),
    );
    if (ergebnis != null) {
      setState(() {
        if (index != null) {
          p.stromkreise[index] = ergebnis;
        } else {
          p.stromkreise.add(ergebnis);
        }
      });
      await _speichernStill();
    }
  }

  Future<void> _speichernStill() async {
    _uebernehmen();
    await _storage.speichere(p);
  }

  void _stromkreisLoeschen(int index) {
    setState(() => p.stromkreise.removeAt(index));
    _speichernStill();
  }

  // ---------- Geführter Komplett-Durchgang ----------

  Future<void> _komplettStarten() async {
    final phase = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geführter Komplett-Durchgang'),
        content: const Text(
          'Phase 1 (am Verteiler): Stammdaten aller Stromkreise erfassen — '
          'FI, Charakteristik, Vorsicherung. Nach jedem Stromkreis fragt die '
          'App „Noch einen?".\n\n'
          'Phase 2 (an den Verbrauchsstellen): pro Stromkreis alle Messungen '
          '(RLOW, RISO, IK, FI-Test, UB).\n\n'
          'Die Phasen sind unabhängig — Phase 2 kannst du auch später machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('Phase 1'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Text('Phase 2'),
          ),
        ],
      ),
    );
    if (phase == 1) await _phase1Stammdaten();
    if (phase == 2) await _phase2Messdurchgang();
  }

  /// Phase 1: für jeden neuen Stromkreis nur die Stammdaten-Schritte;
  /// nach dem Wizard fragt ein Dialog „Noch einen?".
  Future<void> _phase1Stammdaten() async {
    while (true) {
      if (!mounted) return;
      final s = Stromkreis();
      final vorheriger =
          p.stromkreise.isEmpty ? null : p.stromkreise.last;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GefuehrtePruefungScreen(
            titel: 'Stammdaten – Stromkreis ${p.stromkreise.length + 1}',
            schritte: stromkreisStammdatenSchritte(s, vorheriger: vorheriger),
          ),
        ),
      );
      if (ok != true || !mounted) return; // Abbruch
      setState(() {
        p.stromkreise.add(s);
        propagateFiKette(p.stromkreise);
      });
      await _speichernStill();

      if (!mounted) return;
      final noch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stammdaten gespeichert'),
          content: Text(
            'Stromkreis ${p.stromkreise.length} ist erfasst.\n'
            'Noch einen Stromkreis am Verteiler ablesen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Fertig'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Noch einen'),
            ),
          ],
        ),
      );
      if (noch != true) return;
    }
  }

  /// Phase 2: ein einziger großer Wizard, der pro Stromkreis alle Messungen
  /// hintereinander abarbeitet (RLOW → RISO → … → UB), dann zum nächsten.
  Future<void> _phase2Messdurchgang() async {
    if (p.stromkreise.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Keine Stromkreise erfasst – zuerst Phase 1 durchführen.'),
        ));
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GefuehrtePruefungScreen(
          titel: 'Messdurchgang (${p.stromkreise.length} Stromkreise)',
          schritte: protokollMessSchritte(p.stromkreise, p.netzform),
          onSpeichern: _speichernStill,
        ),
      ),
    );
    if (mounted) {
      setState(() => propagateFiKette(p.stromkreise));
      await _speichernStill();
    }
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
        title: Text(widget.istNeu ? 'Neues Protokoll' : 'Protokoll'),
        actions: [
          IconButton(
            tooltip: 'PDF-Vorschau',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _pdfVorschau,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'json') _jsonExport();
              if (v == 'save') _speichern();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('Speichern')),
              PopupMenuItem(value: 'json', child: Text('JSON-Backup teilen')),
            ],
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
          _abschnitt('Kopfdaten'),
          TextField(
              controller: _anlagenbez,
              decoration: const InputDecoration(labelText: 'Anlagenbezeichnung')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _gebName,
                    decoration:
                        const InputDecoration(labelText: 'Gebäude-Name'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _gebNr,
                    decoration:
                        const InputDecoration(labelText: 'Gebäude-Nr.'))),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name (Prüfer)')),
          const SizedBox(height: 12),
          TextField(
              controller: _firma,
              decoration: const InputDecoration(labelText: 'Firma')),
          const SizedBox(height: 12),
          TextField(
              controller: _messgeraet,
              decoration: const InputDecoration(labelText: 'Messgerät')),
          const SizedBox(height: 12),
          InkWell(
            onTap: _datumWaehlen,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Datum'),
              child: Text(p.datum != null ? _df.format(p.datum!) : '—'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Netzform>(
            initialValue: p.netzform,
            decoration: const InputDecoration(labelText: 'Netzform'),
            items: Netzform.values
                .map((n) =>
                    DropdownMenuItem(value: n, child: Text('${n.label}-Netz')))
                .toList(),
            onChanged: (v) {
              setState(() => p.netzform = v ?? Netzform.tn);
              _speichernStill();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Pruefungsart>(
            initialValue: p.pruefungsart,
            decoration: const InputDecoration(labelText: 'Prüfungsart'),
            items: const [
              DropdownMenuItem(
                  value: Pruefungsart.erstpruefung, child: Text('Erstprüfung')),
              DropdownMenuItem(
                  value: Pruefungsart.wiederholungspruefung,
                  child: Text('Wiederholungsprüfung')),
            ],
            onChanged: (v) {
              setState(
                  () => p.pruefungsart = v ?? Pruefungsart.erstpruefung);
              _speichernStill();
            },
          ),

          const SizedBox(height: 24),
          _abschnitt('Besichtigung / Erproben'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allgemeinzustand der Anlage in Ordnung'),
            subtitle: const Text(
                'Beschriftung, Abdeckungen, Einbauteile, Zuordnung, Spannung/Strom'),
            value: p.allgemeinzustandOk,
            onChanged: (v) {
              setState(() => p.allgemeinzustandOk = v);
              _speichernStill();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rechts-Drehfeld geprüft / in Ordnung'),
            subtitle:
                const Text('Zuleitungen und Abgänge auf Rechts-Drehfeld'),
            value: p.drehfeldOk,
            onChanged: (v) {
              setState(() => p.drehfeldOk = v);
              _speichernStill();
            },
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _abschnitt('Stromkreise (${p.stromkreise.length})')),
              FilledButton.tonalIcon(
                onPressed: () => _stromkreisBearbeiten(null),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _komplettStarten,
              icon: const Icon(Icons.checklist),
              label: const Text('Geführter Komplett-Durchgang'),
            ),
          ),
          const SizedBox(height: 8),
          if (p.stromkreise.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine Stromkreise erfasst.'),
            ),
          ...p.stromkreise.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(
                    s.stromkreisRaum.isEmpty ? 'Stromkreis ${i + 1}' : s.stromkreisRaum),
                subtitle: Text([
                  if (s.kabelname.isNotEmpty) s.kabelname,
                  '${s.schutzart.label}${s.vorgSicherung != null ? " ${s.vorgSicherung}A" : ""}',
                  if (s.erforderlicherIkText.isNotEmpty)
                    'erf. IK ${s.erforderlicherIkText} A',
                ].join(' · ')),
                onTap: () => _stromkreisBearbeiten(i),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _stromkreisLoeschen(i),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          _abschnitt('Bemerkungen'),
          TextField(
            controller: _bemerkungen,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Bemerkungen / Hinweise',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          _abschnitt('Fotos'),
          FotoGalerie(fotos: p.fotos, onChanged: _speichernStill),

          const SizedBox(height: 24),
          _abschnitt('Unterschriften'),
          TextField(
              controller: _untMonteur,
              decoration: const InputDecoration(labelText: 'Monteur (Name)')),
          const SizedBox(height: 8),
          _signaturFeld(
            label: 'Unterschrift Monteur',
            data: p.signaturMonteur,
            onChanged: (v) => setState(() => p.signaturMonteur = v),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _untKunde,
              decoration: const InputDecoration(labelText: 'Kunde (Name)')),
          const SizedBox(height: 8),
          _signaturFeld(
            label: 'Unterschrift Kunde',
            data: p.signaturKunde,
            onChanged: (v) => setState(() => p.signaturKunde = v),
          ),
        ],
      ),
    );
  }

  Widget _signaturFeld({
    required String label,
    required String data,
    required ValueChanged<String> onChanged,
  }) {
    final hat = data.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final res = await Navigator.push<String?>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SignatureScreen(titel: label, vorhanden: data),
              ),
            );
            if (res != null) {
              onChanged(res);
              await _speichernStill();
            }
          },
          child: Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: hat
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.memory(base64Decode(data), fit: BoxFit.contain),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.draw_outlined, color: Colors.grey),
                      Text('$label – tippen zum Unterschreiben',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
          ),
        ),
        if (hat)
          TextButton.icon(
            onPressed: () {
              onChanged('');
              _speichernStill();
            },
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Unterschrift entfernen'),
          ),
      ],
    );
  }

  Widget _abschnitt(String titel) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(titel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}
