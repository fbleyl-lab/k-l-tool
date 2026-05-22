import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/aufmass.dart';
import '../storage/aufmass_storage.dart';
import 'aufmass_edit_screen.dart';

class AufmassListScreen extends StatefulWidget {
  const AufmassListScreen({super.key});

  @override
  State<AufmassListScreen> createState() => _AufmassListScreenState();
}

class _AufmassListScreenState extends State<AufmassListScreen> {
  final _storage = AufmassStorage();
  final _df = DateFormat('dd.MM.yyyy HH:mm');
  List<Aufmass> _liste = [];
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _lade();
  }

  Future<void> _lade() async {
    setState(() => _laedt = true);
    final l = await _storage.ladeAlle();
    if (!mounted) return;
    setState(() {
      _liste = l;
      _laedt = false;
    });
  }

  Future<void> _neu() async {
    final now = DateTime.now();
    final a = Aufmass(
        id: const Uuid().v4(),
        erstelltAm: now,
        geaendertAm: now,
        datum: now);
    await _oeffne(a, neu: true);
  }

  Future<void> _oeffne(Aufmass a, {bool neu = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AufmassEditScreen(aufmass: a, istNeu: neu)),
    );
    _lade();
  }

  Future<void> _loeschen(Aufmass a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aufmaß löschen?'),
        content: Text('"${a.anzeigeTitel}" wird gelöscht.'),
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
      await _storage.loesche(a.id);
      _lade();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufmaß / Materiallisten'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _neu,
        icon: const Icon(Icons.add),
        label: const Text('Neue Liste'),
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
              ? const Center(child: Text('Noch keine Aufmaß-Listen.'))
              : ListView.separated(
                  itemCount: _liste.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = _liste[i];
                    return ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.list_alt_outlined)),
                      title: Text(a.anzeigeTitel,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${a.positionen.length} Position(en) · '
                          'geändert ${_df.format(a.geaendertAm)}'),
                      onTap: () => _oeffne(a),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _loeschen(a),
                      ),
                    );
                  },
                ),
    );
  }
}
