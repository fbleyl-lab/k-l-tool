import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/aufmass.dart';
import '../models/foto.dart';
import '../models/protokoll.dart' show Firma;
import '../storage/foto_storage.dart';
import 'pdf_fonts.dart';

/// Erzeugt die Aufmaß-/Materialliste als PDF (A4 Hochformat).
class AufmassPdf {
  static final _df = DateFormat('dd.MM.yyyy');

  static Future<Uint8List> erzeuge(Aufmass a) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final datum = a.datum != null ? _df.format(a.datum!) : '';

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final fotos = await _ladeFotos(a.fotos);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _kopf(a, datum, logo),
          pw.SizedBox(height: 12),
          _tabelle(a),
          if (fotos.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Fotos',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _fotoGrid(fotos),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _kopf(Aufmass a, String datum, pw.MemoryImage? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                height: 46,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(Firma.name,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${Firma.strasse} · ${Firma.ort}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text('AUFMASS / MATERIALLISTE',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
                child: pw.Text('Projekt: ${a.titel}',
                    style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(
                child: pw.Text('Kunde: ${a.kunde}',
                    style: const pw.TextStyle(fontSize: 10))),
            pw.Text('Datum: $datum', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tabelle(Aufmass a) {
    pw.Widget hc(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(t,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        );
    pw.Widget dc(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          hc('Pos', align: pw.Alignment.center),
          hc('Bezeichnung'),
          hc('Menge', align: pw.Alignment.centerRight),
          hc('Einheit', align: pw.Alignment.center),
        ],
      ),
    ];
    for (var i = 0; i < a.positionen.length; i++) {
      final p = a.positionen[i];
      rows.add(pw.TableRow(children: [
        dc('${i + 1}', align: pw.Alignment.center),
        dc(p.bezeichnung),
        dc(p.menge, align: pw.Alignment.centerRight),
        dc(p.einheit, align: pw.Alignment.center),
      ]));
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.8),
        1: pw.FlexColumnWidth(6),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
      },
      children: rows,
    );
  }

  static Future<List<_FotoEintrag>> _ladeFotos(List<Foto> fotos) async {
    final storage = FotoStorage();
    final out = <_FotoEintrag>[];
    for (final f in fotos) {
      try {
        final b = await storage.bytes(f.dateiname);
        if (b != null) out.add(_FotoEintrag(pw.MemoryImage(b), f.bemerkung));
      } catch (_) {}
    }
    return out;
  }

  static pw.Widget _fotoGrid(List<_FotoEintrag> bilder) => pw.Wrap(
        spacing: 12,
        runSpacing: 12,
        children: bilder
            .map((e) => pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        height: 180,
                        width: 250,
                        decoration:
                            pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Image(e.bild, fit: pw.BoxFit.cover),
                      ),
                      if (e.bemerkung.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(e.bemerkung,
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                    ],
                  ),
                ))
            .toList(),
      );
}

class _FotoEintrag {
  final pw.MemoryImage bild;
  final String bemerkung;
  _FotoEintrag(this.bild, this.bemerkung);
}
