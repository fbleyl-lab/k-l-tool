import 'package:flutter/material.dart';

import '../models/protokoll.dart' show Firma;
import '../theme.dart';
import 'aufmass_list_screen.dart';
import 'home_screen.dart';
import 'kabel_tool_screen.dart';
import 'motor_screen.dart';
import 'wissen_screen.dart';

/// Startbildschirm mit Modulauswahl im iOS-Stil. Erweiterbar um weitere Module.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        titel: 'Wissensdatenbank',
        untertitel: 'Normen, Fristen, Zonen …',
        icon: Icons.menu_book_outlined,
        farbe: const Color(0xFF5856D6),
        ziel: () => const WissenScreen(),
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
      appBar: AppBar(title: const Text('K&L Tool')),
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
