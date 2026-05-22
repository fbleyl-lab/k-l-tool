import 'package:flutter_test/flutter_test.dart';
import 'package:messprotokoll/models/stromkreis.dart';
import 'package:messprotokoll/models/protokoll.dart';
import 'package:messprotokoll/models/wallbox_protokoll.dart';
import 'package:messprotokoll/models/tabelle6.dart';
import 'package:messprotokoll/screens/gefuehrte_pruefung_screen.dart';
import 'package:messprotokoll/screens/pruef_schritte.dart';
import 'package:messprotokoll/models/kabel_daten.dart';
import 'package:messprotokoll/models/kabel_rechner.dart';
import 'package:messprotokoll/auth/freischaltung.dart';
import 'package:messprotokoll/models/motor_rechner.dart';
import 'package:messprotokoll/models/rechner_math.dart';
import 'package:messprotokoll/models/sat_math.dart';
import 'package:messprotokoll/models/wissen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:messprotokoll/utils/mess_parser.dart';
import 'package:messprotokoll/utils/sprach_parser.dart';

void main() {
  group('Tabelle 6 – erforderlicher IK', () {
    test('B16: Min.Anzeige 85 A, Grenzwert 80 A', () {
      final s = Stromkreis(schutzart: Schutzart.b, vorgSicherung: 16);
      expect(s.erforderlicherIkText, '85');
      expect(s.grenzwertIkText, '80');
    });

    test('C16: Min.Anzeige 172 A', () {
      final s = Stromkreis(schutzart: Schutzart.c, vorgSicherung: 16);
      expect(s.erforderlicherIkText, '172');
    });

    test('gG16 bei 0,4 s = 114 A, bei 5 s = 69 A', () {
      final s = Stromkreis(
          schutzart: Schutzart.gg,
          vorgSicherung: 16,
          abschaltzeit: Abschaltzeit.s04);
      expect(s.erforderlicherIkText, '114');
      s.abschaltzeit = Abschaltzeit.s5;
      expect(s.erforderlicherIkText, '69');
    });

    test('Nicht tabellierter Nennstrom liefert leer', () {
      final s = Stromkreis(schutzart: Schutzart.b, vorgSicherung: 99);
      expect(s.erforderlicherIkText, '');
    });

    test('gG 400 A: kein Tabellenwert, manueller IK greift', () {
      final s = Stromkreis(schutzart: Schutzart.gg, vorgSicherung: 400);
      expect(s.hatTabellenwert, isFalse);
      expect(s.erforderlicherIkText, '');
      s.erfIkManuell = '2840';
      expect(s.erforderlicherIkText, '2840');
    });

    test('Bewertung i.O.: Nicht-FI-Kreis, alle Werte gut', () {
      final s = Stromkreis(
        schutzart: Schutzart.b,
        vorgSicherung: 16, // erf = 85
        ikLpe: '243',
        ikLn: '255',
        rlow: '0,42',
        ub: '0,3',
      );
      final b = s.bewerten(maxAusloesezeitMs: 400);
      expect(b.status, Pruefstatus.ok);
    });

    test('Bewertung n.i.O.: IK L-PE zu klein', () {
      final s = Stromkreis(
        schutzart: Schutzart.b,
        vorgSicherung: 16, // erf = 85
        ikLpe: '70',
        ikLn: '255',
        rlow: '0,4',
        ub: '0,3',
      );
      final b = s.bewerten(maxAusloesezeitMs: 400);
      expect(b.status, Pruefstatus.nichtOk);
      expect(b.maengel.any((m) => m.contains('IK L-PE')), isTrue);
    });

    test('FI-Kreis: IK L-PE wird übersprungen, FI-Werte bewertet', () {
      final s = Stromkreis(
        schutzart: Schutzart.c,
        vorgSicherung: 16, // erf = 172
        ikLn: '200',
        fiIdn: '30',
        ausloesestrom: '21', // zwischen 15 und 30
        ausloesezeit: '18',
        rlow: '0,3',
        ub: '0,2',
      );
      final b = s.bewerten(maxAusloesezeitMs: 400);
      expect(b.status, Pruefstatus.ok);
    });

    test('FI n.i.O.: Auslösezeit über TT-Grenze 200 ms', () {
      final s = Stromkreis(
        schutzart: Schutzart.c,
        vorgSicherung: 16,
        ikLn: '200',
        fiIdn: '30',
        ausloesestrom: '21',
        ausloesezeit: '250',
        rlow: '0,3',
        ub: '0,2',
      );
      final b = s.bewerten(maxAusloesezeitMs: 200);
      expect(b.status, Pruefstatus.nichtOk);
    });

    test('Bewertung offen bei fehlenden Werten', () {
      final s = Stromkreis(schutzart: Schutzart.b, vorgSicherung: 16);
      final b = s.bewerten(maxAusloesezeitMs: 400);
      expect(b.status, Pruefstatus.offen);
    });

    test('Sprach-Parser: Zahlwort + Bezeichnung', () {
      final p = SprachParser.parse('zehn Steckdosen');
      expect(p.menge, '10');
      expect(p.bezeichnung, 'Steckdosen');
    });

    test('Sprach-Parser: Ziffer + Einheit + Bezeichnung', () {
      final p = SprachParser.parse('5 Meter Kabel');
      expect(p.menge, '5');
      expect(p.einheit, 'm');
      expect(p.bezeichnung, 'Kabel');
    });

    test('Sprach-Parser: Dezimal', () {
      final p = SprachParser.parse('2,5 Quadratmeter Putz');
      expect(p.menge, '2,5');
      expect(p.einheit, 'm²');
      expect(p.bezeichnung, 'Putz');
    });

    test('Sprach-Parser: ohne Menge', () {
      final p = SprachParser.parse('Verteilerschrank');
      expect(p.menge, '');
      expect(p.bezeichnung, 'Verteilerschrank');
    });

    test('FI Typ B: DC-Werte werden bewertet', () {
      final s = Stromkreis(
        schutzart: Schutzart.b,
        vorgSicherung: 16,
        ikLn: '255',
        fiIdn: '30',
        fiTyp: 'B',
        ausloesestrom: '21',
        ausloesezeit: '18',
        ausloesestromDc: '25',
        ausloesezeitDc: '300', // > 200 ms
        rlow: '0,3',
        ub: '0,2',
      );
      // TT-Grenze 200 ms -> DC-Zeit verletzt
      expect(s.bewerten(maxAusloesezeitMs: 200).status, Pruefstatus.nichtOk);
      // TN-Grenze 400 ms -> i.O.
      expect(s.bewerten(maxAusloesezeitMs: 400).status, Pruefstatus.ok);
    });

    test('Kabel: 16 A, B2, kurz -> 1,5 mm² (Iz=16, Sicherung 16)', () {
      final e = KabelRechner.berechne(const KabelEingabe(
        verlegeart: 'B2',
        strom: 16,
        laenge: 10,
        spannung: 230,
        duGrenzeProzent: 3,
      ));
      expect(e.querschnitt, 1.5);
      expect(e.sicherung, 16);
    });

    test('Kabel: 20 A, B2 -> 2,5 mm²', () {
      final e = KabelRechner.berechne(const KabelEingabe(
        verlegeart: 'B2',
        strom: 20,
        laenge: 10,
        spannung: 230,
        duGrenzeProzent: 3,
      ));
      expect(e.querschnitt, 2.5); // Iz 1,5=16<20, 2,5=21>=20
    });

    test('Kabel: langer Weg erzwingt größeren Querschnitt (Spannungsfall)', () {
      final kurz = KabelRechner.berechne(const KabelEingabe(
          verlegeart: 'B2', strom: 16, laenge: 10, spannung: 230, duGrenzeProzent: 3));
      final lang = KabelRechner.berechne(const KabelEingabe(
          verlegeart: 'B2', strom: 16, laenge: 60, spannung: 230, duGrenzeProzent: 3));
      expect(lang.querschnitt! > kurz.querschnitt!, isTrue);
    });

    test('Kabel Aluminium: 100 A, Erde -> 25 mm²', () {
      final e = KabelRechner.berechne(const KabelEingabe(
        leiter: Leiter.al,
        verlegeart: 'Erde',
        strom: 100,
        laenge: 30,
        spannung: 400,
        duGrenzeProzent: 3,
      ));
      expect(e.querschnitt, 25);
      expect(e.iz, 102);
    });

    test('Kabel: nur Sicherung (Hensel) -> Querschnitt', () {
      final e = KabelRechner.berechne(const KabelEingabe(
        verlegeart: 'B2',
        strom: 0,
        laenge: 0,
        spannung: 230,
        duGrenzeProzent: 3,
        sicherung: 25,
      ));
      // B2: 25 A Sicherung schützt erst 4 mm² (inMax 1,5=16 / 2,5=20 / 4=25)
      expect(e.querschnitt, 4);
    });

    test('Kabel Kupfer Erde: 120 A -> 25 mm²', () {
      final e = KabelRechner.berechne(const KabelEingabe(
        verlegeart: 'Erde',
        strom: 120,
        laenge: 0,
        spannung: 400,
        duGrenzeProzent: 3,
      ));
      expect(e.querschnitt, 25);
    });

    test('MessParser: B16 + Messwerte', () {
      final s = Stromkreis();
      final erk = MessParser.anwenden(
          s, 'B16 Spannung 230 IK L PE 243 IK L N 255 RLOW 0,42 Iso 550 UB 0,3');
      expect(s.schutzart, Schutzart.b);
      expect(s.vorgSicherung, 16);
      expect(s.spannung, '230');
      expect(s.ikLpe, '243');
      expect(s.ikLn, '255');
      expect(s.rlow, '0,42');
      expect(s.riso, '550');
      expect(s.ub, '0,3');
      expect(erk, isNotEmpty);
    });

    test('MessParser: FI Werte und Typ', () {
      final s = Stromkreis();
      MessParser.anwenden(
          s, 'FI Typ B FI IDN 30 Auslösestrom 21 Auslösezeit 18');
      expect(s.fiTyp, 'B');
      expect(s.fiIdn, '30');
      expect(s.ausloesestrom, '21');
      expect(s.ausloesezeit, '18');
    });

    test('Betriebsmittel: Zählung vs. manuell', () {
      final z = Stromkreis(
          betriebsmittelModus: 'zaehlung',
          anzahlSteckdosen: 6,
          anzahlLichter: 2);
      expect(z.betriebsmittelText, '6 Steckdosen, 2 Lichter');
      final m = Stromkreis(
          betriebsmittelModus: 'manuell', anzahlBetriebsmittel: 'Kompressor');
      expect(m.betriebsmittelText, 'Kompressor');
      // Backward-Compat: alter Datensatz mit Text -> manuell
      final alt = Stromkreis.fromJson({'anzahlBetriebsmittel': 'Herd'});
      expect(alt.betriebsmittelText, 'Herd');
    });

    test('Motor: 7,5 kW DOL -> Iₙ ~15 A, gG anlauffest größer', () {
      final e = MotorRechner.berechne(const MotorEingabe(
        leistungKw: 7.5,
        spannung: 400,
        cosPhi: 0.85,
        wirkungsgrad: 0.87,
        anlaufart: Anlaufart.dol,
      ));
      expect(e.inMotor, greaterThan(13));
      expect(e.inMotor, lessThan(17));
      // gG (Faktor 2.0) deutlich über Iₙ
      expect(e.gGSicherung! >= 25, isTrue);
    });

    test('Motor: Stern-Dreieck kleiner als DOL', () {
      final dol = MotorRechner.berechne(const MotorEingabe(
          leistungKw: 7.5, anlaufart: Anlaufart.dol));
      final yd = MotorRechner.berechne(const MotorEingabe(
          leistungKw: 7.5, anlaufart: Anlaufart.sternDreieck));
      expect(yd.gGSicherung! <= dol.gGSicherung!, isTrue);
    });

    test('Wissensdatenbank: Suche findet Einträge', () {
      expect(wissensEintraege.where((w) => w.passtZu('bad')).isNotEmpty, isTrue);
      expect(
          wissensEintraege.where((w) => w.passtZu('prüffrist')).isNotEmpty, isTrue);
      expect(wissensEintraege.where((w) => w.passtZu('typ b')).isNotEmpty, isTrue);
    });

    test('Freischaltung: richtiger Code frei, falscher nicht', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await Freischaltung.istFrei(), isFalse);
      expect(await Freischaltung.pruefe('falsch'), isFalse);
      expect(await Freischaltung.pruefe('26081990!'), isTrue);
      expect(await Freischaltung.istFrei(), isTrue);
    });

    test('DC: U=230, R=23 -> I=10, P=2300', () {
      final e = dcLoese(230, null, 23, null);
      expect(e.i!.round(), 10);
      expect(e.p!.round(), 2300);
    });

    test('DC: I=16, P=3680 -> U=230, R≈14,4', () {
      final e = dcLoese(null, 16, null, 3680);
      expect(e.u!.round(), 230);
      expect((e.r! * 10).round(), 144);
    });

    test('DC: zu wenige Werte -> Hinweis', () {
      expect(dcLoese(230, null, null, null).hinweis.isNotEmpty, isTrue);
    });

    test('AC 3~: 400 V, 16 A, cosφ=1 -> P≈11085 W', () {
      final e = acLoese(dreiphasig: true, u: 400, cosPhi: 1, i: 16)!;
      expect(e.p.round(), 11085);
    });

    test('AC 1~: 230 V, P=2300, cosφ=1 -> I=10 A', () {
      final e = acLoese(dreiphasig: false, u: 230, cosPhi: 1, p: 2300)!;
      expect(e.i.round(), 10);
    });

    test('JSON-Roundtrip erhält Werte', () {
      final s = Stromkreis(
        stromkreisRaum: 'Küche',
        schutzart: Schutzart.c,
        vorgSicherung: 16,
        ikLpe: '350',
      );
      final back = Stromkreis.fromJson(s.toJson());
      expect(back.stromkreisRaum, 'Küche');
      expect(back.schutzart, Schutzart.c);
      expect(back.vorgSicherung, 16);
      expect(back.erforderlicherIkText, '172');
    });
  });

  group('SAT-Ausrichtung', () {
    test('Astra 19,2° aus Süddeutschland: Az ~170°, El ~34°, Skew ~+7°', () {
      final a = berechneAusrichtung(
          breite: 48.14, laenge: 11.58, satLaenge: 19.2);
      expect(a.sichtbar, isTrue);
      expect(a.azimut, closeTo(169.8, 1.0));
      expect(a.elevation, closeTo(34.2, 1.0));
      expect(a.skew, closeTo(6.8, 1.0));
    });

    test('Satellit genau im Süden, wenn Längengrad gleich', () {
      final a =
          berechneAusrichtung(breite: 50.0, laenge: 13.0, satLaenge: 13.0);
      expect(a.azimut, closeTo(180.0, 0.5));
      expect(a.skew, closeTo(0.0, 0.5));
    });

    test('Westlicher Satellit -> Azimut > 180° (Richtung SW)', () {
      final a =
          berechneAusrichtung(breite: 50.0, laenge: 13.0, satLaenge: 5.0);
      expect(a.azimut, greaterThan(180));
      expect(a.skew, lessThan(0)); // Skew kehrt sich um
    });

    test('Unerreichbar nahe Nordpol (Satellit unter Horizont)', () {
      final a =
          berechneAusrichtung(breite: 82.0, laenge: 10.0, satLaenge: 19.2);
      expect(a.sichtbar, isFalse);
    });

    test('himmelsrichtung liefert plausible Kürzel', () {
      expect(himmelsrichtung(0), 'N');
      expect(himmelsrichtung(180), 'S');
      expect(himmelsrichtung(170), 'S');
      expect(himmelsrichtung(90), 'O');
    });
  });

  group('Wallbox-Messprotokoll', () {
    WallboxProtokoll wb({
      Netzform netzform = Netzform.tn,
      String iDn = '30',
      String schutzleiter = '',
      String rcdZeitAc = '',
      String rcdStromAc = '',
      String rcdStromDc = '',
    }) =>
        WallboxProtokoll(
          id: 't',
          erstelltAm: DateTime(2026, 1, 1),
          geaendertAm: DateTime(2026, 1, 1),
          netzform: netzform,
          iDn: iDn,
          schutzleiterLadebuchse: schutzleiter,
          rcdZeitAc: rcdZeitAc,
          rcdStromAc: rcdStromAc,
          rcdStromDc: rcdStromDc,
        );

    test('Schutzleiter: ≤0,3 Ω i.O., darüber n.i.O., leer offen', () {
      expect(wb(schutzleiter: '0,3').schutzleiterStatus, Pruefstatus.ok);
      expect(wb(schutzleiter: '0,35').schutzleiterStatus, Pruefstatus.nichtOk);
      expect(wb().schutzleiterStatus, Pruefstatus.offen);
    });

    test('RCD Abschaltzeit AC gegen Netzform-Grenze (TN 400 / TT 200)', () {
      expect(wb(rcdZeitAc: '180').rcdZeitAcStatus, Pruefstatus.ok);
      expect(wb(netzform: Netzform.tt, rcdZeitAc: '250').rcdZeitAcStatus,
          Pruefstatus.nichtOk);
      expect(wb(netzform: Netzform.tt, rcdZeitAc: '180').rcdZeitAcStatus,
          Pruefstatus.ok);
    });

    test('RCD Abschaltstrom AC im Band 0,5–1×IΔN (30 mA)', () {
      expect(wb(rcdStromAc: '21').rcdStromAcStatus, Pruefstatus.ok);
      expect(wb(rcdStromAc: '10').rcdStromAcStatus, Pruefstatus.nichtOk);
      expect(wb(rcdStromAc: '35').rcdStromAcStatus, Pruefstatus.nichtOk);
    });

    test('AC-Band folgt eingegebenem IΔN (300 mA → 150–300)', () {
      expect(
          wb(iDn: '300', rcdStromAc: '200').rcdStromAcStatus, Pruefstatus.ok);
      expect(wb(iDn: '300', rcdStromAc: '100').rcdStromAcStatus,
          Pruefstatus.nichtOk);
    });

    test('RCD Abschaltstrom DC: ≤6 mA i.O., darüber n.i.O.', () {
      expect(wb(rcdStromDc: '5').rcdStromDcStatus, Pruefstatus.ok);
      expect(wb(rcdStromDc: '8').rcdStromDcStatus, Pruefstatus.nichtOk);
    });

    test('hatMangel erkennt n.i.O.-Messwert', () {
      expect(wb(schutzleiter: '0,2').hatMangel, isFalse);
      expect(wb(schutzleiter: '0,9').hatMangel, isTrue);
    });

    test('JSON-Roundtrip erhält Mess- und Erprobungswerte', () {
      final p = wb(schutzleiter: '0,2', rcdStromDc: '4');
      p.isoVorSchuetz = '550';
      p.isoNachSchuetz = '480';
      p.erprobung[0].status = Pruefstatus.ok;
      p.erprobung[1].status = Pruefstatus.nichtOk;
      final back = WallboxProtokoll.fromJson(p.toJson());
      expect(back.schutzleiterLadebuchse, '0,2');
      expect(back.isoVorSchuetz, '550');
      expect(back.isoNachSchuetz, '480');
      expect(back.rcdStromDc, '4');
      expect(back.erprobung[0].status, Pruefstatus.ok);
      expect(back.erprobung[1].status, Pruefstatus.nichtOk);
      expect(back.erprobung.length, erprobungsFragen.length);
    });
  });

  group('Geführter Prüfmodus', () {
    Pruefschritt byTitle(List<Pruefschritt> l, String contains) =>
        l.firstWhere((s) => s.titel.contains(contains));

    test('Stromkreis: IK L-PE entfällt bei FI, FI-Schritte erscheinen', () {
      final s = Stromkreis(
        schutzart: Schutzart.b,
        vorgSicherung: 16,
        fiIdn: '30',
        ausloesestrom: '21',
        ausloesezeit: '30',
      );
      final steps = stromkreisSchritte(s, Netzform.tn);
      expect(byTitle(steps, 'IK L-PE').sichtbar(), isFalse);
      expect(byTitle(steps, 'IΔN').sichtbar(), isTrue);
      expect(byTitle(steps, 'Auslösezeit AC').sichtbar(), isTrue);
    });

    test('Stromkreis: ohne FI ist IK L-PE sichtbar, FI-Schritte nicht', () {
      final s = Stromkreis(schutzart: Schutzart.b, vorgSicherung: 16);
      final steps = stromkreisSchritte(s, Netzform.tn);
      expect(byTitle(steps, 'IK L-PE').sichtbar(), isTrue);
      expect(byTitle(steps, 'IΔN').sichtbar(), isFalse);
    });

    test('Stromkreis: RLOW-Ampel ≤ 1 Ω', () {
      final s = Stromkreis();
      final rlow = byTitle(stromkreisSchritte(s, Netzform.tn), 'RLOW');
      s.rlow = '0,4';
      expect(rlow.ampel!(), Pruefstatus.ok);
      s.rlow = '1,5';
      expect(rlow.ampel!(), Pruefstatus.nichtOk);
    });

    test('Wallbox: Zuleitung zuerst + FI-Übernahme in den Block (Typ A: kein DC)',
        () {
      final p = WallboxProtokoll(
          id: 't', erstelltAm: DateTime(2026), geaendertAm: DateTime(2026));
      final z = Stromkreis(
        fiIdn: '30',
        fiTyp: 'A',
        ausloesestrom: '22',
        ausloesezeit: '28',
      );
      final steps = wallboxSchritte(p, z);
      expect(steps.first.titel.startsWith('Zuleitung'), isTrue);
      byTitle(steps, 'Schutzleiter Ladebuchse').vorAnzeige!();
      expect(p.iDn, '30');
      expect(p.rcdStromAc, '22');
      expect(p.rcdZeitAc, '28');
      expect(p.rcdStromDc, ''); // Typ A -> DC separat messen
    });

    test('Stromkreis: Vorsicherung ist Dropdown mit Nenngrößen', () {
      final s = Stromkreis(schutzart: Schutzart.b);
      final vor = byTitle(stromkreisSchritte(s, Netzform.tn), 'Vorsicherung');
      expect(vor.eingabe, PruefEingabe.dropdown);
      expect(vor.inputLabel, 'Nennstrom');
      expect(vor.optionen(), contains('16'));
    });
  });
}
