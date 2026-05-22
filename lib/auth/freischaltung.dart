import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Einfache Geräte-Freischaltung über einen Code (Weg 3).
/// Der Code wird nicht im Klartext gespeichert, sondern als SHA-256-Hash
/// verglichen. Nach erfolgreicher Eingabe bleibt das Gerät dauerhaft frei.
class Freischaltung {
  static const _key = 'freigeschaltet';

  // Erlaubte Codes als SHA-256-Hash (Klartext steht nicht in der App).
  static const Set<String> _erlaubteHashes = {
    // "26081990!"
    'd5b45c48ca0ee6399d930c56b1fea86bdb76a5614f078a6e8b8bd0edd06344d4',
  };

  static String _hash(String code) =>
      sha256.convert(utf8.encode(code.trim())).toString();

  static const _timeout = Duration(seconds: 2);

  /// Ist das Gerät bereits freigeschaltet?
  static Future<bool> istFrei() async {
    try {
      final prefs =
          await SharedPreferences.getInstance().timeout(_timeout);
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prüft den Code; bei Erfolg wird das Gerät (best effort) dauerhaft
  /// freigeschaltet. Schlägt das Speichern fehl (z. B. Browser), wird die
  /// App trotzdem freigeschaltet – sie fragt dann ggf. erneut.
  static Future<bool> pruefe(String code) async {
    if (!_erlaubteHashes.contains(_hash(code))) return false;
    try {
      final prefs =
          await SharedPreferences.getInstance().timeout(_timeout);
      await prefs.setBool(_key, true).timeout(_timeout);
    } catch (_) {
      // Speichern nicht möglich – Freischaltung trotzdem zulassen.
    }
    return true;
  }

  /// Freischaltung zurücksetzen (z. B. für Tests).
  static Future<void> zuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
