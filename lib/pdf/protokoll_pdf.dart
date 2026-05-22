import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/foto.dart';
import '../models/protokoll.dart';
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../storage/foto_storage.dart';
import 'pdf_fonts.dart';

/// Erzeugt das Messprotokoll als PDF im Layout des Excel-Musters.
class ProtokollPdf {
  static final _df = DateFormat('dd.MM.yyyy');

  static Future<Uint8List> erzeuge(Protokoll p) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final datum = p.datum != null ? _df.format(p.datum!) : '';

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    pw.MemoryImage? sigMonteur = _decode(p.signaturMonteur);
    pw.MemoryImage? sigKunde = _decode(p.signaturKunde);

    final fotoBilder = await _ladeFotos(p.fotos);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => [
          _kopf(p, datum, logo),
          pw.SizedBox(height: 8),
          _besichtigung(p),
          pw.SizedBox(height: 8),
          _tabelle(p),
          if (p.bemerkungen.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _bemerkungen(p.bemerkungen.trim()),
          ],
          pw.SizedBox(height: 12),
          _unterschriften(p, sigMonteur, sigKunde),
        ],
      ),
    );

    if (fotoBilder.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text('Fotodokumentation',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _fotoGrid(fotoBilder),
          ],
        ),
      );
    }
    return doc.save();
  }

  static Future<List<_FotoEintrag>> _ladeFotos(List<Foto> fotos) async {
    final storage = FotoStorage();
    final out = <_FotoEintrag>[];
    for (final f in fotos) {
      try {
        final b = await storage.bytes(f.dateiname);
        if (b != null) out.add(_FotoEintrag(pw.MemoryImage(b), f.bemerkung));
      } catch (_) {
        // Foto überspringen
      }
    }
    return out;
  }

  static pw.Widget _fotoGrid(List<_FotoEintrag> bilder) {
    return pw.Wrap(
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
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5)),
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

  static pw.MemoryImage? _decode(String b64) {
    if (b64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _kopf(Protokoll p, String datum, pw.MemoryImage? logo) {
    pw.Widget feld(String label, String wert) => pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label  ',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
              pw.TextSpan(text: wert, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        );

    final ist = p.pruefungsart == Pruefungsart.erstpruefung;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Column(
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
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text('MESSPROTOKOLL',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3)),
          ),
          pw.Center(
            child: pw.Text(
              'über Kurzschlußstrommessung, FI-Schutzschaltung, '
              'Isolationswiderstand und Erdung',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    feld('Geb-Name:', p.gebName),
                    pw.SizedBox(height: 3),
                    feld('Geb-Nr.:', p.gebNr),
                    pw.SizedBox(height: 3),
                    feld('Anlagenbez.:', p.anlagenbez),
                    pw.SizedBox(height: 3),
                    feld('Netzform:', p.netzform.label),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    feld('Name:', p.name),
                    pw.SizedBox(height: 3),
                    feld('Firma:', p.firma),
                    pw.SizedBox(height: 3),
                    feld('Messgerät:', p.messgeraet),
                    pw.SizedBox(height: 3),
                    feld('Datum:', datum),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${ist ? "X" : "O"}  Erstprüfung',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 3),
                    pw.Text('${ist ? "O" : "X"}  Wiederholungsprüfung',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _besichtigung(Protokoll p) {
    pw.Widget zeile(String text, bool ok) => pw.Row(
          children: [
            pw.Text(ok ? '[X] ' : '[ ] ',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 9))),
            pw.Text(ok ? 'OK' : 'nicht OK',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: ok ? PdfColors.green800 : PdfColors.red800)),
          ],
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          zeile(
              'Allgemeinzustand der Anlage: Beschriftung, Abdeckungen, '
              'Einbauteile, Zuordnung, Spannung/Strom',
              p.allgemeinzustandOk),
          pw.SizedBox(height: 3),
          zeile(
              'Drehfeld an Zuleitungen und Abgängen auf Rechts-Drehfeld geprüft',
              p.drehfeldOk),
        ],
      ),
    );
  }

  static const _headerStyleFontSize = 6.0;
  static const _cellFontSize = 7.0;

  static pw.Widget _tabelle(Protokoll p) {
    const spalten = [
      'Stromkreis / Raum',
      'Kabelname',
      'Anzahl\nBetriebsm.',
      'Länge\n[m]',
      'Quer-\nschn.\n[mm²]',
      'Char.',
      'Vorg.\nSich.\n[A]',
      'Erf. IK\n[A]',
      'Spg.\n[V]',
      'IK L-PE\n[A]',
      'IK L-N\n[A]',
      'FI/N\n[A]',
      'FI/IΔN\n[mA]',
      'Auslöse\nI[mA]/t[ms]',
      'UB\n[V]',
      'RLOW\n[Ω]',
      'RISO\n[MΩ]',
      'Beur-\nteilung',
    ];

    pw.Widget hc(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: _headerStyleFontSize,
                  fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget dc(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: _cellFontSize)),
        );

    // Farbige Beurteilungs-Zelle.
    pw.Widget bc(Stromkreisbewertung b) {
      PdfColor bg;
      PdfColor fg;
      switch (b.status) {
        case Pruefstatus.ok:
          bg = PdfColors.green100;
          fg = PdfColors.green900;
          break;
        case Pruefstatus.nichtOk:
          bg = PdfColors.red100;
          fg = PdfColors.red900;
          break;
        case Pruefstatus.offen:
          bg = PdfColors.grey200;
          fg = PdfColors.grey700;
          break;
      }
      return pw.Container(
        alignment: pw.Alignment.center,
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: pw.Text(b.kurz,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: _cellFontSize,
                fontWeight: pw.FontWeight.bold,
                color: fg)),
      );
    }

    // Auslöse-Zelle: bei Typ B zwei Zeilen (AC / DC).
    pw.Widget auslCell(Stromkreis s) {
      final acLeer = s.ausloesestrom.isEmpty && s.ausloesezeit.isEmpty;
      final dcLeer = s.ausloesestromDc.isEmpty && s.ausloesezeitDc.isEmpty;
      final lines = <pw.Widget>[];
      if (s.fiTyp == 'B') {
        if (!acLeer) {
          lines.add(pw.Text('AC ${s.ausloesestrom}/${s.ausloesezeit}',
              style: const pw.TextStyle(fontSize: _cellFontSize)));
        }
        if (!dcLeer) {
          lines.add(pw.Text('DC ${s.ausloesestromDc}/${s.ausloesezeitDc}',
              style: const pw.TextStyle(fontSize: _cellFontSize)));
        }
      } else if (!acLeer) {
        lines.add(pw.Text('${s.ausloesestrom}/${s.ausloesezeit}',
            style: const pw.TextStyle(fontSize: _cellFontSize)));
      }
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center, children: lines),
      );
    }

    // FI/IΔN-Zelle inkl. Typ-Kürzel.
    pw.Widget fiIdnCell(Stromkreis s) {
      if (!s.hatFi) return dc(s.fiIdn);
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(s.fiIdn,
                style: const pw.TextStyle(fontSize: _cellFontSize)),
            pw.Text('Typ ${s.fiTyp}',
                style: pw.TextStyle(
                    fontSize: _cellFontSize - 1,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: spalten.map(hc).toList(),
      ),
    ];

    for (final s in p.stromkreise) {
      final b = s.bewerten(maxAusloesezeitMs: p.netzform.maxAusloesezeitMs);
      rows.add(pw.TableRow(children: [
        dc(s.stromkreisRaum),
        dc(s.kabelname),
        dc(s.betriebsmittelText),
        dc(s.laenge),
        dc(s.querschnitt),
        dc(s.schutzart.label),
        dc(s.vorgSicherung?.toString() ?? ''),
        dc(s.erforderlicherIkText),
        dc(s.spannung),
        dc(s.ikLpe),
        dc(s.ikLn),
        dc(s.fiN),
        fiIdnCell(s),
        auslCell(s),
        dc(s.ub),
        dc(s.rlow),
        dc(s.riso),
        bc(b),
      ]));
    }

    // Spaltenbreiten (Flex), Summe relativ.
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.4),
      1: const pw.FlexColumnWidth(1.8),
      2: const pw.FlexColumnWidth(1.4),
      3: const pw.FlexColumnWidth(0.9),
      4: const pw.FlexColumnWidth(1.0),
      5: const pw.FlexColumnWidth(0.8),
      6: const pw.FlexColumnWidth(1.0),
      7: const pw.FlexColumnWidth(1.0),
      8: const pw.FlexColumnWidth(0.9),
      9: const pw.FlexColumnWidth(1.0),
      10: const pw.FlexColumnWidth(1.0),
      11: const pw.FlexColumnWidth(0.9),
      12: const pw.FlexColumnWidth(1.0),
      13: const pw.FlexColumnWidth(1.4),
      14: const pw.FlexColumnWidth(0.9),
      15: const pw.FlexColumnWidth(1.0),
      16: const pw.FlexColumnWidth(1.0),
      17: const pw.FlexColumnWidth(1.1),
    };

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      columnWidths: widths,
      children: rows,
    );
  }

  static pw.Widget _bemerkungen(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Bemerkungen:',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

  static pw.Widget _unterschriften(
      Protokoll p, pw.MemoryImage? sigMonteur, pw.MemoryImage? sigKunde) {
    pw.Widget block(String label, String name, pw.MemoryImage? sig) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 46,
                alignment: pw.Alignment.bottomLeft,
                child: sig != null
                    ? pw.Image(sig, fit: pw.BoxFit.contain)
                    : pw.SizedBox(),
              ),
              pw.Divider(height: 2, thickness: 0.6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
                  if (name.isNotEmpty)
                    pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        block('Unterschrift Monteur', p.unterschriftMonteur, sigMonteur),
        pw.SizedBox(width: 30),
        block('Unterschrift Kunde', p.unterschriftKunde, sigKunde),
      ],
    );
  }
}

class _FotoEintrag {
  final pw.MemoryImage bild;
  final String bemerkung;
  _FotoEintrag(this.bild, this.bemerkung);
}
