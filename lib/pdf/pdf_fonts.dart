import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Lädt die Unicode-Schrift (DejaVu Sans) für die PDF-Erzeugung, damit Zeichen
/// wie Ω und Δ korrekt dargestellt werden (Standard-PDF-Schrift kann das nicht).
class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    final base =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    _theme = pw.ThemeData.withFont(base: base, bold: bold);
    return _theme!;
  }
}
