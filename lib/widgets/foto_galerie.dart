import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/foto.dart';
import '../storage/foto_storage.dart';

/// Wiederverwendbarer Baustein: Fotos aufnehmen/wählen, Bemerkung je Foto,
/// löschen. Wird in allen Modulen genutzt.
class FotoGalerie extends StatefulWidget {
  final List<Foto> fotos;
  final VoidCallback onChanged;
  const FotoGalerie({super.key, required this.fotos, required this.onChanged});

  @override
  State<FotoGalerie> createState() => _FotoGalerieState();
}

class _FotoGalerieState extends State<FotoGalerie> {
  final _storage = FotoStorage();
  final _picker = ImagePicker();
  final Map<String, Uint8List?> _bilder = {}; // dateiname -> Bytes

  @override
  void initState() {
    super.initState();
    _ladeBytes();
  }

  Future<void> _ladeBytes() async {
    for (final f in widget.fotos) {
      _bilder[f.dateiname] = await _storage.bytes(f.dateiname);
    }
    if (mounted) setState(() {});
  }

  Future<void> _hinzufuegen(ImageSource quelle) async {
    final x = await _picker.pickImage(source: quelle, imageQuality: 70);
    if (x == null) return;
    final name = await _storage.importiere(x);
    _bilder[name] = await _storage.bytes(name);
    setState(() => widget.fotos.add(Foto(dateiname: name)));
    widget.onChanged();
  }

  void _quelleWaehlen() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _hinzufuegen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _hinzufuegen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bemerkungBearbeiten(Foto f) async {
    final ctrl = TextEditingController(text: f.bemerkung);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bemerkung zum Foto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'z.B. Mangel an Klemme X'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (res != null) {
      setState(() => f.bemerkung = res);
      widget.onChanged();
    }
  }

  Future<void> _loeschen(Foto f) async {
    await _storage.loesche(f.dateiname);
    setState(() => widget.fotos.remove(f));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.fotos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch keine Fotos.'),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: widget.fotos.map(_kachel).toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _quelleWaehlen,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Foto hinzufügen'),
        ),
      ],
    );
  }

  Widget _kachel(Foto f) {
    final bytes = _bilder[f.dateiname];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white),
                    iconSize: 18,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _loeschen(f),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _bemerkungBearbeiten(f),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      f.bemerkung.isEmpty ? 'Bemerkung …' : f.bemerkung,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: f.bemerkung.isEmpty ? Colors.grey : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
