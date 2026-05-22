import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/wissen.dart';
import '../theme.dart';
import 'wissen_grafik.dart';

class WissenScreen extends StatefulWidget {
  const WissenScreen({super.key});

  @override
  State<WissenScreen> createState() => _WissenScreenState();
}

class _WissenScreenState extends State<WissenScreen> {
  final _such = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _hoert = false;
  String? _kategorie;

  @override
  void dispose() {
    _speech.stop();
    _such.dispose();
    super.dispose();
  }

  Future<void> _sprachsuche() async {
    if (_hoert) {
      await _speech.stop();
      setState(() => _hoert = false);
      return;
    }
    final ok = await _speech.initialize();
    if (!ok) return;
    setState(() => _hoert = true);
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: 'de_DE'),
      onResult: (r) {
        setState(() => _such.text = r.recognizedWords);
        if (r.finalResult) setState(() => _hoert = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _such.text;
    final treffer = wissensEintraege
        .where((e) => (_kategorie == null || e.kategorie == _kategorie))
        .where((e) => e.passtZu(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Wissensdatenbank')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _such,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Suchen … (z. B. „Bad", „Prüffrist", „Typ B")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(_hoert ? Icons.mic : Icons.mic_none,
                      color: _hoert ? Colors.red : null),
                  onPressed: _sprachsuche,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Alle', _kategorie == null, () => setState(() => _kategorie = null)),
                ...wissensKategorien.map((k) =>
                    _chip(k, _kategorie == k, () => setState(() => _kategorie = k))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: treffer.isEmpty
                ? const Center(child: Text('Keine Treffer.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: treffer.length,
                    itemBuilder: (_, i) => _eintragKachel(treffer[i]),
                    separatorBuilder: (_, i) => const SizedBox(height: 10),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _eintragKachel(WissensEintrag e) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => _WissenDetail(eintrag: e))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(e.titel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.iosSecondary),
                ]),
                const SizedBox(height: 2),
                Text(e.kategorie,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.iosBlue)),
                const SizedBox(height: 6),
                Text(e.kurz, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      );
}

class _WissenDetail extends StatelessWidget {
  final WissensEintrag eintrag;
  const _WissenDetail({required this.eintrag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(eintrag.titel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (eintrag.bestaetigen)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Richtwerte – bitte gegenprüfen / an Norm & '
                        'Gefährdungsbeurteilung anpassen.',
                        style: TextStyle(fontSize: 12))),
              ]),
            ),
          Text(eintrag.kurz,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...eintrag.inhalt.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(z)),
                ]),
              )),
          if (eintrag.tabelle != null) ...[
            const SizedBox(height: 8),
            _tabelle(eintrag.tabelle!),
          ],
          if (wissensGrafik(eintrag.grafik) != null) ...[
            const SizedBox(height: 14),
            wissensGrafik(eintrag.grafik)!,
          ],
          const SizedBox(height: 16),
          Text('Quelle: ${eintrag.quelle}',
              style: const TextStyle(fontSize: 12, color: AppTheme.iosSecondary)),
        ],
      ),
    );
  }

  Widget _tabelle(List<List<String>> rows) => Table(
        border: TableBorder.all(color: const Color(0xFFD1D1D6), width: 0.5),
        children: [
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: i == 0
                  ? const BoxDecoration(color: Color(0xFFF2F2F7))
                  : null,
              children: rows[i]
                  .map((c) => Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(c,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: i == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ))
                  .toList(),
            ),
        ],
      );
}
