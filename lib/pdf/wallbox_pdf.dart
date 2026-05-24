import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/foto.dart';
import '../models/protokoll.dart' show Firma, NetzformLabel, Pruefungsart;
import '../models/stromkreis.dart';
import '../models/tabelle6.dart';
import '../models/wallbox_protokoll.dart';
import '../storage/foto_storage.dart';
import 'pdf_fonts.dart';

/// Erzeugt das Wallbox-Messprotokoll als PDF im Layout des Firmen-Musters.
class WallboxPdf {
  static final _df = DateFormat('dd.MM.yyyy');

  static Future<Uint8List> erzeuge(WallboxProtokoll p) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final datum = p.datum != null ? _df.format(p.datum!) : '';

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final sigMonteur = _decode(p.signaturMonteur);
    final sigKunde = _decode(p.signaturKunde);
    final fotoBilder = await _ladeFotos(p.fotos);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => [
          _kopf(p, datum, logo),
          pw.SizedBox(height: 8),
          _allgemeinzustand(p),
          if (p.stromkreise.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _abschnittTitel('Stromkreise / Zuleitung'),
            _tabelle(p),
          ],
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _wallboxMessungen(p)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _erprobung(p)),
            ],
          ),
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
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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

  static pw.MemoryImage? _decode(String b64) {
    if (b64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _abschnittTitel(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _kopf(WallboxProtokoll p, String datum, pw.MemoryImage? logo) {
    pw.Widget feld(String label, String wert) => pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label  ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
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
            child: pw.Text('MESSPROTOKOLL WALLBOX',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3)),
          ),
          pw.Center(
            child: pw.Text(
              'über Kurzschlußstrommessung, FI-Schutzschaltung, '
              'Isolationswiderstand, Erdung und Erprobung',
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
                    feld('Eigentümer:', p.eigentuemer),
                    pw.SizedBox(height: 3),
                    feld('Standort:', p.standort),
                    pw.SizedBox(height: 3),
                    feld('Adresse:', p.adresse),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    feld('Wallbox:', p.bezeichnung),
                    pw.SizedBox(height: 3),
                    feld('Netzform:', p.netzform.label),
                    pw.SizedBox(height: 3),
                    feld('IΔN:', p.iDn.isEmpty ? '' : '${p.iDn} mA'),
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

  static pw.Widget _allgemeinzustand(WallboxProtokoll p) {
    final ok = p.allgemeinzustandOk;
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Row(
        children: [
          pw.Text(ok ? '[X] ' : '[ ] ',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
              child: pw.Text(
                  'Allgemeinzustand der Wallbox: Beschriftung, Abdeckungen, '
                  'Einbauteile, Zuordnung, Spannung/Strom',
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Text(ok ? 'OK' : 'nicht OK',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: ok ? PdfColors.green800 : PdfColors.red800)),
        ],
      ),
    );
  }

  static const _headerStyleFontSize = 6.0;
  static const _cellFontSize = 7.0;

  static (PdfColor, PdfColor) _statusFarben(Pruefstatus s) {
    switch (s) {
      case Pruefstatus.ok:
        return (PdfColors.green100, PdfColors.green900);
      case Pruefstatus.nichtOk:
        return (PdfColors.red100, PdfColors.red900);
      case Pruefstatus.offen:
        return (PdfColors.grey200, PdfColors.grey700);
    }
  }

  static String _statusKurz(Pruefstatus s) {
    switch (s) {
      case Pruefstatus.ok:
        return 'i.O.';
      case Pruefstatus.nichtOk:
        return 'n.i.O.';
      case Pruefstatus.offen:
        return '—';
    }
  }

  static pw.Widget _tabelle(WallboxProtokoll p) {
    const spalten = [
      'Sicherung',
      'Betriebs-\nmittel',
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

    pw.Widget bc(Stromkreisbewertung b) {
      final (bg, fg) = _statusFarben(b.status);
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

    pw.Widget fiIdnCell(Stromkreis s) {
      if (!s.hatFi) return dc(s.fiIdn);
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(s.fiIdn, style: const pw.TextStyle(fontSize: _cellFontSize)),
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

    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.0), // Sicherung
      1: const pw.FlexColumnWidth(1.4), // Betriebsmittel (Zuleitung)
      2: const pw.FlexColumnWidth(0.9), // Länge
      3: const pw.FlexColumnWidth(1.0), // Querschnitt
      4: const pw.FlexColumnWidth(0.8), // Char.
      5: const pw.FlexColumnWidth(1.0), // Vorg. Sich.
      6: const pw.FlexColumnWidth(1.0), // Erf. IK
      7: const pw.FlexColumnWidth(0.9), // Spg.
      8: const pw.FlexColumnWidth(1.0), // IK L-PE
      9: const pw.FlexColumnWidth(1.0), // IK L-N
      10: const pw.FlexColumnWidth(0.9), // FI/N
      11: const pw.FlexColumnWidth(1.0), // FI/IΔN
      12: const pw.FlexColumnWidth(1.4), // Auslöse
      13: const pw.FlexColumnWidth(0.9), // UB
      14: const pw.FlexColumnWidth(1.0), // RLOW
      15: const pw.FlexColumnWidth(1.0), // RISO
      16: const pw.FlexColumnWidth(1.1), // Beurteilung
    };

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      columnWidths: widths,
      children: rows,
    );
  }

  /// Wallbox-Messwerte mit Wert, Einheit und (sofern bewertet) Beurteilung.
  static pw.Widget _wallboxMessungen(WallboxProtokoll p) {
    pw.Widget zelle(String t,
            {bool fett = false, pw.Alignment? align, PdfColor? farbe}) =>
        pw.Container(
          alignment: align ?? pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: fett ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: farbe)),
        );

    pw.Widget statusZelle(Pruefstatus? s) {
      if (s == null) {
        return zelle('erfasst', align: pw.Alignment.center);
      }
      final (bg, fg) = _statusFarben(s);
      return pw.Container(
        alignment: pw.Alignment.center,
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: pw.Text(_statusKurz(s),
            style: pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: fg)),
      );
    }

    String wert(String v, String einheit) =>
        v.trim().isEmpty ? '—' : '$v $einheit';

    pw.TableRow zeile(String label, String v, String einheit, Pruefstatus? s) =>
        pw.TableRow(children: [
          zelle(label),
          zelle(wert(v, einheit), align: pw.Alignment.centerRight),
          statusZelle(s),
        ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _abschnittTitel('Wallbox-Messungen'),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(3.2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                zelle('Messung', fett: true),
                zelle('Wert', fett: true, align: pw.Alignment.centerRight),
                zelle('Beurteilung',
                    fett: true, align: pw.Alignment.center),
              ],
            ),
            zeile('Schutzleiter Ladebuchse/Gehäuse RLO (≤ 0,3 Ω)',
                p.schutzleiterLadebuchse, 'Ω', p.schutzleiterStatus),
            zeile('Isolationswiderstand L/N–PE vor Schütz (≥ 1 MΩ)',
                p.isoVorSchuetz, 'MΩ', p.isoVorSchuetzStatus),
            zeile('Isolationswiderstand L/N–PE nach Schütz (≥ 1 MΩ)',
                p.isoNachSchuetz, 'MΩ', p.isoNachSchuetzStatus),
            zeile('RCD Abschaltzeit AC', p.rcdZeitAc, 'ms', p.rcdZeitAcStatus),
            zeile('RCD Abschaltstrom AC (0,5–1×IΔN)', p.rcdStromAc, 'mA',
                p.rcdStromAcStatus),
            zeile('RCD Abschaltzeit DC', p.rcdZeitDc, 'ms', null),
            zeile('RCD Abschaltstrom DC (≤ 6 mA)', p.rcdStromDc, 'mA',
                p.rcdStromDcStatus),
          ],
        ),
      ],
    );
  }

  static pw.Widget _erprobung(WallboxProtokoll p) {
    pw.TableRow zeile(Erprobungspunkt e) {
      final (bg, fg) = _statusFarben(e.status);
      return pw.TableRow(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(e.frage, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          color: bg,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(_statusKurz(e.status),
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: fg)),
        ),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _abschnittTitel('Erprobung (Funktionsprüfung)'),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(4.0),
            1: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: pw.Text('Funktionsprüfung',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: pw.Text('Ergebnis',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...p.erprobung.map(zeile),
          ],
        ),
      ],
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
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

  static pw.Widget _unterschriften(
      WallboxProtokoll p, pw.MemoryImage? sigMonteur, pw.MemoryImage? sigKunde) {
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
