import 'package:flutter/material.dart';

import '../models/protokoll.dart' show Firma;
import '../theme.dart';
import '../update/updater.dart';
import 'aufmass_list_screen.dart';
import 'home_screen.dart';
import 'kabel_tool_screen.dart';
import 'motor_screen.dart';
import 'rechner_screen.dart';
import 'sat_screen.dart';
import 'wissen_screen.dart';

/// Startbildschirm mit Modulauswahl im iOS-Stil. Erweiterbar um weitere Module.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Beim Start still nach Updates suchen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate(false));
  }

  Future<void> _checkUpdate(bool manuell) async {
    final e = await Updater.pruefe();
    if (!mounted) return;
    if (e.hatUpdate) {
      _zeigeUpdate(e.info!);
      return;
    }
    if (manuell) {
      final msg = e.fehler != null
          ? 'Update-Prüfung fehlgeschlagen: ${e.fehler}'
          : 'Du hast die aktuelle Version'
              '${e.aktuelleVersion.isEmpty ? '' : ' (${e.aktuelleVersion})'}.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _zeigeUpdate(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Update ${info.version} verfügbar'),
        content: SingleChildScrollView(
          child: Text(info.notes.trim().isEmpty
              ? 'Eine neue Version steht bereit.'
              : info.notes.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Später')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _installiere(info);
            },
            child: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _installiere(UpdateInfo info) async {
    final fortschritt = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Update wird geladen …'),
        content: ValueListenableBuilder<double>(
          valueListenable: fortschritt,
          builder: (ctx, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v > 0 ? v : null),
              const SizedBox(height: 8),
              Text('${(v * 100).toStringAsFixed(0)} %'),
            ],
          ),
        ),
      ),
    );
    try {
      await Updater.installiere(info.apkUrl,
          onProgress: (v) => fortschritt.value = v);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download fehlgeschlagen.')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      fortschritt.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = <_Modul>[
      _Modul(
        titel: 'Messprotokoll',
        untertitel: 'VDE 0100-600',
        icon: Icons.electrical_services_outlined,
        farbe: AppTheme.iosBlue,
        ziel: () => const HomeScreen(),
      ),
      _Modul(
        titel: 'Kabelquerschnitt',
        untertitel: 'Auslegung & Verlegeart',
        icon: Icons.cable_outlined,
        farbe: const Color(0xFFFF9500),
        ziel: () => const KabelToolScreen(),
      ),
      _Modul(
        titel: 'Aufmaß / Materialliste',
        untertitel: 'mit Spracheingabe',
        icon: Icons.list_alt_outlined,
        farbe: const Color(0xFFAF52DE),
        ziel: () => const AufmassListScreen(),
      ),
      _Modul(
        titel: 'Motorabsicherung',
        untertitel: 'nach Anlaufverfahren',
        icon: Icons.settings_outlined,
        farbe: const Color(0xFFFF3B30),
        ziel: () => const MotorScreen(),
      ),
      _Modul(
        titel: 'Elektro-Rechner',
        untertitel: 'U · I · R · P (DC / 1~ / 3~)',
        icon: Icons.calculate_outlined,
        farbe: const Color(0xFF00897B),
        ziel: () => const RechnerScreen(),
      ),
      _Modul(
        titel: 'Wissensdatenbank',
        untertitel: 'Normen, Fristen, Zonen …',
        icon: Icons.menu_book_outlined,
        farbe: const Color(0xFF5856D6),
        ziel: () => const WissenScreen(),
      ),
      _Modul(
        titel: 'SAT-Ausrichtung',
        untertitel: 'Azimut · Elevation · LNB-Skew',
        icon: Icons.satellite_alt_outlined,
        farbe: const Color(0xFF0A84C2),
        ziel: () => const SatScreen(),
      ),
      _Modul(
        titel: 'Wallbox-Messprotokoll',
        untertitel: 'Vorlage folgt',
        icon: Icons.ev_station_outlined,
        farbe: AppTheme.iosGreen,
        ziel: null,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('K&L Tool'),
        actions: [
          IconButton(
            tooltip: 'Nach Updates suchen',
            icon: const Icon(Icons.system_update_alt),
            onPressed: () => _checkUpdate(true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Firmenlogo dezent oben
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Image.asset('assets/logo.png', height: 54),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              Firma.name,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.iosSecondary),
            ),
          ),
          ...module.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModulKachel(modul: m),
              )),
        ],
      ),
    );
  }
}

class _Modul {
  final String titel;
  final String untertitel;
  final IconData icon;
  final Color farbe;
  final Widget Function()? ziel;
  _Modul({
    required this.titel,
    required this.untertitel,
    required this.icon,
    required this.farbe,
    required this.ziel,
  });
}

class _ModulKachel extends StatelessWidget {
  final _Modul modul;
  const _ModulKachel({required this.modul});

  @override
  Widget build(BuildContext context) {
    final aktiv = modul.ziel != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aktiv
            ? () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => modul.ziel!()))
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Modul folgt – Vorlage ausstehend.')),
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: aktiv ? modul.farbe : AppTheme.iosSecondary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(modul.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modul.titel,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.iosLabel)),
                    Text(modul.untertitel,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.iosSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.iosSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
