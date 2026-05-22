import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Vollbild-Unterschriftsfeld. Gibt die Unterschrift als base64-PNG zurück
/// (leerer String = gelöscht/keine Unterschrift).
class SignatureScreen extends StatefulWidget {
  final String titel;
  final String? vorhanden; // bestehende base64-PNG (optional)
  const SignatureScreen({super.key, required this.titel, this.vorhanden});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_controller.isEmpty) {
      Navigator.pop(context, '');
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (!mounted) return;
    Navigator.pop(context, bytes != null ? base64Encode(bytes) : '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        actions: [
          TextButton(
            onPressed: () => _controller.clear(),
            child: const Text('Löschen'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Bitte im Feld unterschreiben.'),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _speichern,
                    icon: const Icon(Icons.check),
                    label: const Text('Übernehmen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
