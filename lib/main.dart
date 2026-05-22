import 'package:flutter/material.dart';

import 'auth/freischaltung.dart';
import 'screens/dashboard_screen.dart';
import 'screens/freischalt_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MessprotokollApp());
}

class MessprotokollApp extends StatelessWidget {
  const MessprotokollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K&L Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Start(),
    );
  }
}

/// Entscheidet beim Start: Sperrbildschirm oder Dashboard.
class _Start extends StatefulWidget {
  const _Start();

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  bool? _frei;

  @override
  void initState() {
    super.initState();
    _pruefe();
  }

  Future<void> _pruefe() async {
    bool frei = false;
    try {
      frei = await Freischaltung.istFrei()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      frei = false; // im Zweifel Sperrbildschirm zeigen
    }
    if (mounted) setState(() => _frei = frei);
  }

  @override
  Widget build(BuildContext context) {
    if (_frei == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_frei == false) {
      return FreischaltScreen(onFrei: () => setState(() => _frei = true));
    }
    return const DashboardScreen();
  }
}
