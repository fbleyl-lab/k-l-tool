import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/wallbox_protokoll.dart';
import '../storage/wallbox_protokoll_storage.dart';
import 'wallbox_edit_screen.dart';

class WallboxListScreen extends StatefulWidget {
  const WallboxListScreen({super.key});

  @override
  State<WallboxListScreen> createState() => _WallboxListScreenState();
}

class _WallboxListScreenState extends State<WallboxListScreen> {
  final _storage = WallboxProtokollStorage();
  final _df = DateFormat('dd.MM.yyyy HH:mm');
  List<WallboxProtokoll> _protokolle = [];
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _lade();
  }

  Future<void> _lade() async {
    setState(() => _laedt = true);
    final list = await _storage.ladeAlle();
    if (!mounted) return;
    setState(() {
      _protokolle = list;
      _laedt = false;
    });
  }

  Future<void> _neu() async {
    final now = DateTime.now();
    final p = WallboxProtokoll(
      id: const Uuid().v4(),
      erstelltAm: now,
      geaendertAm: now,
      datum: now,
    );
    await _oeffne(p, neu: true);
  }

  Future<void> _oeffne(WallboxProtokoll p, {bool neu = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WallboxEditScreen(protokoll: p, istNeu: neu),
      ),
    );
    _lade();
  }

  Future<void> _loeschen(WallboxProtokoll p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Protokoll löschen?'),
        content: Text('"${p.titel}" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok == true) {
      await _storage.loesche(p.id);
      _lade();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallbox-Messprotokolle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _neu,
        icon: const Icon(Icons.add),
        label: const Text('Neues Protokoll'),
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : _protokolle.isEmpty
              ? const _LeerHinweis()
              : RefreshIndicator(
                  onRefresh: _lade,
                  child: ListView.separated(
                    itemCount: _protokolle.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _protokolle[i];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.ev_station_outlined)),
                        title: Text(p.titel,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${p.stromkreise.length} Stromkreis(e) · '
                            'geändert ${_df.format(p.geaendertAm)}'),
                        onTap: () => _oeffne(p),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _loeschen(p),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LeerHinweis extends StatelessWidget {
  const _LeerHinweis();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ev_station_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Noch keine Wallbox-Protokolle.',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Tippe auf „Neues Protokoll", um eine Wallbox-Messung anzulegen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
