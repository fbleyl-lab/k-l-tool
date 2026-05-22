import 'package:flutter/material.dart';

import '../auth/freischaltung.dart';
import '../theme.dart';

/// Sperrbildschirm beim ersten Start. Ruft [onFrei] nach erfolgreicher
/// Freischaltung auf.
class FreischaltScreen extends StatefulWidget {
  final VoidCallback onFrei;
  const FreischaltScreen({super.key, required this.onFrei});

  @override
  State<FreischaltScreen> createState() => _FreischaltScreenState();
}

class _FreischaltScreenState extends State<FreischaltScreen> {
  final _code = TextEditingController();
  bool _fehler = false;
  bool _pruefe = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    setState(() {
      _pruefe = true;
      _fehler = false;
    });
    final ok = await Freischaltung.pruefe(_code.text);
    if (!mounted) return;
    if (ok) {
      widget.onFrei();
    } else {
      setState(() {
        _pruefe = false;
        _fehler = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 70),
                const SizedBox(height: 24),
                const Text('K&L Tool',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Bitte Freischaltcode eingeben',
                    style: TextStyle(color: AppTheme.iosSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  autofocus: true,
                  obscureText: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _absenden(),
                  decoration: InputDecoration(
                    labelText: 'Freischaltcode',
                    errorText: _fehler ? 'Code ungültig' : null,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _pruefe ? null : _absenden,
                    child: _pruefe
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Freischalten'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Den Code erhältst du von Kirner & Lilla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.iosSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
