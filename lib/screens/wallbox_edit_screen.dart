import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/protokoll.dart' show Netzform, NetzformLabel, Pruefungsart;
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../models/wallbox_protokoll.dart';
import '../pdf/wallbox_pdf.dart';
import '../storage/wallbox_protokoll_storage.dart';
import '../widgets/foto_galerie.dart';
import 'gefuehrte_pruefung_screen.dart';
import 'pruef_schritte.dart';
import 'signature_screen.dart';
import 'stromkreis_edit_screen.dart';

class WallboxEditScreen extends StatefulWidget {
  final WallboxProtokoll protokoll;
  final bool istNeu;
  const WallboxEditScreen(
      {super.key, required this.protokoll, this.istNeu = false});

  @override
  State<WallboxEditScreen> createState() => _WallboxEditScreenState();
}

class _WallboxEditScreenState extends State<WallboxEditScreen> {
  final _storage = WallboxProtokollStorage();
  final _df = DateFormat('dd.MM.yyyy');
  late WallboxProtokoll p;

  late final TextEditingController _bezeichnung;
  late final TextEditingController _eigentuemer;
  late final TextEditingController _standort;
  late final TextEditingController _adresse;
  late final TextEditingController _name;
  late final TextEditingController _firma;
  late final TextEditingController _messgeraet;
  late final TextEditingController _untMonteur;
  late final TextEditingController _untKunde;
  late final TextEditingController _bemerkungen;

  // Messwert-Felder (Controller, damit FI-Werte aus der Zuleitung
  // programmatisch übernommen werden und sofort im Feld erscheinen).
  late final TextEditingController _iDn;
  late final TextEditingController _schutzleiter;
  late final TextEditingController _isoVor;
  late final TextEditingController _isoNach;
  late final TextEditingController _rcdZeitAc;
  late final TextEditingController _rcdStromAc;
  late final TextEditingController _rcdZeitDc;
  late final TextEditingController _rcdStromDc;

  @override
  void initState() {
    super.initState();
    p = widget.protokoll;
    _bezeichnung = TextEditingController(text: p.bezeichnung);
    _eigentuemer = TextEditingController(text: p.eigentuemer);
    _standort = TextEditingController(text: p.standort);
    _adresse = TextEditingController(text: p.adresse);
    _name = TextEditingController(text: p.name);
    _firma = TextEditingController(text: p.firma);
    _messgeraet = TextEditingController(text: p.messgeraet);
    _untMonteur = TextEditingController(text: p.unterschriftMonteur);
    _untKunde = TextEditingController(text: p.unterschriftKunde);
    _bemerkungen = TextEditingController(text: p.bemerkungen);

    _iDn = TextEditingController(text: p.iDn);
    _schutzleiter = TextEditingController(text: p.schutzleiterLadebuchse);
    _isoVor = TextEditingController(text: p.isoVorSchuetz);
    _isoNach = TextEditingController(text: p.isoNachSchuetz);
    _rcdZeitAc = TextEditingController(text: p.rcdZeitAc);
    _rcdStromAc = TextEditingController(text: p.rcdStromAc);
    _rcdZeitDc = TextEditingController(text: p.rcdZeitDc);
    _rcdStromDc = TextEditingController(text: p.rcdStromDc);

    _letzterPruefer = _name.text;
    _name.addListener(_prueferUebernehmen);

    for (final c in _kopfController) {
      c.addListener(_autoSpeichern);
    }
    _bindMess(_iDn, (v) => p.iDn = v);
    _bindMess(_schutzleiter, (v) => p.schutzleiterLadebuchse = v);
    _bindMess(_isoVor, (v) => p.isoVorSchuetz = v);
    _bindMess(_isoNach, (v) => p.isoNachSchuetz = v);
    _bindMess(_rcdZeitAc, (v) => p.rcdZeitAc = v);
    _bindMess(_rcdStromAc, (v) => p.rcdStromAc = v);
    _bindMess(_rcdZeitDc, (v) => p.rcdZeitDc = v);
    _bindMess(_rcdStromDc, (v) => p.rcdStromDc = v);
  }

  /// Bindet ein Messwert-Feld: schreibt live ins Modell, aktualisiert die
  /// Ampel (setState) und speichert verzögert.
  void _bindMess(TextEditingController c, void Function(String) set) {
    c.addListener(() {
      set(c.text);
      setState(() {});
      _autoSpeichern();
    });
  }

  List<TextEditingController> get _kopfController => [
        _bezeichnung,
        _eigentuemer,
        _standort,
        _adresse,
        _name,
        _firma,
        _messgeraet,
        _untMonteur,
        _untKunde,
        _bemerkungen,
      ];

  List<TextEditingController> get _messController => [
        _iDn,
        _schutzleiter,
        _isoVor,
        _isoNach,
        _rcdZeitAc,
        _rcdStromAc,
        _rcdZeitDc,
        _rcdStromDc,
      ];

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
    for (final c in [..._kopfController, ..._messController]) {
      c.dispose();
    }
    super.dispose();
  }

  void _uebernehmen() {
    p.bezeichnung = _bezeichnung.text;
    p.eigentuemer = _eigentuemer.text;
    p.standort = _standort.text;
    p.adresse = _adresse.text;
    p.name = _name.text;
    p.firma = _firma.text;
    p.messgeraet = _messgeraet.text;
    p.unterschriftMonteur = _untMonteur.text;
    p.unterschriftKunde = _untKunde.text;
    p.bemerkungen = _bemerkungen.text;
  }

  Future<void> _speichernStill() async {
    _uebernehmen();
    await _storage.speichere(p);
  }

  Future<void> _speichern() async {
    await _speichernStill();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gespeichert')));
    }
  }

  Future<void> _pdfTeilen() async {
    await _speichernStill();
    final bytes = await WallboxPdf.erzeuge(p);
    await Printing.sharePdf(bytes: bytes, filename: _dateiname('pdf'));
  }

  Future<void> _pdfVorschau() async {
    _uebernehmen();
    await Printing.layoutPdf(
      onLayout: (_) => WallboxPdf.erzeuge(p),
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
        text: 'Wallbox-Protokoll-Backup',
      ),
    );
  }

  String _dateiname(String ext) {
    final base = p.titel.replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜß _-]'), '');
    final datum = p.datum != null ? _df.format(p.datum!) : '';
    return 'Wallbox-Messprotokoll_${base}_$datum.$ext'.replaceAll(' ', '_');
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
    final vorIndex = index != null ? index - 1 : p.stromkreise.length - 1;
    final fiVorlage = (vorIndex >= 0 && vorIndex < p.stromkreise.length)
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
          wallboxModus: true,
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
      // FI sitzt in der Zuleitung -> Messwerte in den Wallbox-Block übernehmen.
      if (ergebnis.hatFi) {
        _fiAusZuleitung(ergebnis);
        if (mounted) {
          final dc = ergebnis.fiTyp == 'A'
              ? ' DC bei Typ A separat unten messen.'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'FI-Werte aus der Zuleitung übernommen.$dc'),
          ));
        }
      }
      await _speichernStill();
    }
  }

  /// Übernimmt die FI-Messwerte einer Zuleitung in den Wallbox-Block.
  /// AC immer; DC nur bei Typ B (bei Typ A wird DC separat im Block gemessen).
  void _fiAusZuleitung(Stromkreis s) {
    if (s.fiIdn.trim().isNotEmpty) _iDn.text = s.fiIdn.trim();
    _rcdStromAc.text = s.ausloesestrom;
    _rcdZeitAc.text = s.ausloesezeit;
    if (s.fiTyp == 'B') {
      _rcdStromDc.text = s.ausloesestromDc;
      _rcdZeitDc.text = s.ausloesezeitDc;
    }
  }

  /// Setzt die Mess-Controller aus dem Modell (nach dem geführten Prüfmodus,
  /// der direkt ins Modell schreibt).
  void _messInControllers() {
    _iDn.text = p.iDn;
    _schutzleiter.text = p.schutzleiterLadebuchse;
    _isoVor.text = p.isoVorSchuetz;
    _isoNach.text = p.isoNachSchuetz;
    _rcdZeitAc.text = p.rcdZeitAc;
    _rcdStromAc.text = p.rcdStromAc;
    _rcdZeitDc.text = p.rcdZeitDc;
    _rcdStromDc.text = p.rcdStromDc;
  }

  Future<void> _gefuehrtePruefung() async {
    if (p.stromkreise.isEmpty) {
      p.stromkreise.add(Stromkreis(
        betriebsmittelModus: 'manuell',
        anzahlBetriebsmittel: 'Zuleitung',
      ));
    }
    final zuleitung = p.stromkreise.first;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GefuehrtePruefungScreen(
          titel: 'Geführte Prüfung – Wallbox',
          schritte: wallboxSchritte(p, zuleitung),
          onSpeichern: _speichernStill,
        ),
      ),
    );
    if (mounted) {
      _messInControllers();
      setState(() {});
      await _speichernStill();
    }
  }

  void _stromkreisLoeschen(int index) {
    setState(() => p.stromkreise.removeAt(index));
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
        title: Text(widget.istNeu ? 'Neue Wallbox-Messung' : 'Wallbox-Messung'),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _gefuehrtePruefung,
              icon: const Icon(Icons.checklist),
              label: const Text('Geführte Prüfung (kompletter Ablauf)'),
            ),
          ),
          const SizedBox(height: 16),
          _abschnitt('Kopfdaten'),
          TextField(
              controller: _bezeichnung,
              decoration: const InputDecoration(
                  labelText: 'Wallbox / Bezeichnung (Typ)')),
          const SizedBox(height: 12),
          TextField(
              controller: _eigentuemer,
              decoration: const InputDecoration(labelText: 'Eigentümer')),
          const SizedBox(height: 12),
          TextField(
              controller: _standort,
              decoration: const InputDecoration(labelText: 'Standort')),
          const SizedBox(height: 12),
          TextField(
              controller: _adresse,
              decoration: const InputDecoration(labelText: 'Adresse')),
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
              setState(() => p.pruefungsart = v ?? Pruefungsart.erstpruefung);
              _speichernStill();
            },
          ),

          const SizedBox(height: 24),
          _abschnitt('Allgemeinzustand der Wallbox'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allgemeinzustand in Ordnung'),
            subtitle: const Text(
                'Beschriftung, Abdeckungen, Einbauteile, Zuordnung, Spannung/Strom'),
            value: p.allgemeinzustandOk,
            onChanged: (v) {
              setState(() => p.allgemeinzustandOk = v);
              _speichernStill();
            },
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _abschnitt(
                      'Stromkreise / Zuleitung (${p.stromkreise.length})')),
              FilledButton.tonalIcon(
                onPressed: () => _stromkreisBearbeiten(null),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.stromkreise.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine Stromkreise / Zuleitung erfasst.'),
            ),
          ...p.stromkreise.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(s.stromkreisRaum.isEmpty
                    ? 'Zuleitung ${i + 1}'
                    : s.stromkreisRaum),
                subtitle: Text([
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
          _abschnitt('Wallbox-Messungen'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'FI in der Zuleitung: AC-Werte werden beim Speichern der '
              'Zuleitung hierher übernommen. FI in der Wallbox integriert: '
              'Werte hier eintragen. Typ A: DC immer hier messen (≤ 6 mA).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _messFeld(
            label: 'IΔN (Bemessungsfehlerstrom RCD)',
            einheit: 'mA',
            controller: _iDn,
            hinweis: 'Basis für AC-Auslösestrom-Band (0,5–1×IΔN)',
          ),
          _messFeld(
            label: 'Schutzleiter Ladebuchse / Gehäuse (RLO)',
            einheit: 'Ω',
            controller: _schutzleiter,
            status: p.schutzleiterStatus,
          ),
          _messFeld(
            label: 'Isolationswiderstand L/N–PE vor Schütz',
            einheit: 'MΩ',
            controller: _isoVor,
            groesserErlaubt: true,
            status: p.isoVorSchuetzStatus,
          ),
          _messFeld(
            label: 'Isolationswiderstand L/N–PE nach Schütz',
            einheit: 'MΩ',
            controller: _isoNach,
            groesserErlaubt: true,
            status: p.isoNachSchuetzStatus,
          ),
          _messFeld(
            label: 'RCD Abschaltzeit AC',
            einheit: 'ms',
            controller: _rcdZeitAc,
            status: p.rcdZeitAcStatus,
          ),
          _messFeld(
            label: 'RCD Abschaltstrom AC',
            einheit: 'mA',
            controller: _rcdStromAc,
            status: p.rcdStromAcStatus,
          ),
          _messFeld(
            label: 'RCD Abschaltzeit DC',
            einheit: 'ms',
            controller: _rcdZeitDc,
          ),
          _messFeld(
            label: 'RCD Abschaltstrom DC',
            einheit: 'mA',
            controller: _rcdStromDc,
            status: p.rcdStromDcStatus,
            hinweis: 'Grenzwert ≤ 6 mA (RDC-DD nach IEC 62955)',
          ),

          const SizedBox(height: 24),
          _abschnitt('Erprobung (Funktionsprüfung)'),
          ...p.erprobung.map(_erprobungZeile),

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

  Widget _messFeld({
    required String label,
    required String einheit,
    required TextEditingController controller,
    Pruefstatus? status,
    String? hinweis,
    bool groesserErlaubt = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              // „>" (Iso-Überlauf) braucht die Texttastatur; die Zahlentastatur
              // hat kein „>". Sonst Dezimaltastatur.
              keyboardType: groesserErlaubt
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(groesserErlaubt ? r'[0-9.,>]' : r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: label,
                suffixText: einheit,
                helperText: hinweis,
                helperMaxLines: 2,
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: _ampel(status),
            ),
        ],
      ),
    );
  }

  Widget _ampel(Pruefstatus s) {
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
        text = '—';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: farbe),
      ),
      child: Text(text,
          style: TextStyle(color: farbe, fontWeight: FontWeight.bold)),
    );
  }

  Widget _erprobungZeile(Erprobungspunkt punkt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(punkt.frage),
          const SizedBox(height: 6),
          SegmentedButton<Pruefstatus>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Pruefstatus.offen, label: Text('—')),
              ButtonSegment(value: Pruefstatus.ok, label: Text('i.O.')),
              ButtonSegment(value: Pruefstatus.nichtOk, label: Text('n.i.O.')),
            ],
            selected: {punkt.status},
            onSelectionChanged: (sel) {
              setState(() => punkt.status = sel.first);
              _speichernStill();
            },
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
                builder: (_) => SignatureScreen(titel: label, vorhanden: data),
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
                    child:
                        Image.memory(base64Decode(data), fit: BoxFit.contain),
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
