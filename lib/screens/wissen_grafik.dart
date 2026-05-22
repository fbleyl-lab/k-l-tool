import 'dart:math';

import 'package:flutter/material.dart';

/// Liefert die passende Grafik zu einem Wissens-Eintrag (oder null).
Widget? wissensGrafik(String? id) {
  switch (id) {
    case 'badzonen':
      return const BadzonenGrafik();
    default:
      return null;
  }
}

/// Schemaskizze der Bad-Installationszonen (Bereich 0/1/2) nach DIN VDE 0100-701.
class BadzonenGrafik extends StatelessWidget {
  const BadzonenGrafik({super.key});

  static const _c0 = Color(0xFF1565C0);
  static const _c1 = Color(0xFF42A5F5);
  static const _c2 = Color(0xFF90CAF9);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.45,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1D1D6)),
            ),
            child: CustomPaint(painter: BadPainter()),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: const [
          _Legende(_c0, 'Bereich 0 – im Becken (SELV ≤ 12 V, IPX7)'),
          _Legende(_c1, 'Bereich 1 – darüber bis 2,25 m (≥ IPX4)'),
          _Legende(_c2, 'Bereich 2 – 0,60 m seitlich (≥ IPX4)'),
        ]),
        const SizedBox(height: 4),
        const Text('Schemaskizze – nicht maßstabsgetreu.',
            style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
      ],
    );
  }
}

class _Legende extends StatelessWidget {
  final Color farbe;
  final String text;
  const _Legende(this.farbe, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: farbe, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    ]);
  }
}

class BadPainter extends CustomPainter {
  void _text(Canvas c, String s, Offset o,
      {double size = 12,
      Color color = Colors.black,
      bool center = false,
      double rotate = 0,
      FontWeight weight = FontWeight.normal}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(o.dx, o.dy);
    if (rotate != 0) c.rotate(rotate);
    tp.paint(c, center ? Offset(-tp.width / 2, -tp.height / 2) : Offset.zero);
    c.restore();
  }

  void _pfeil(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    const len = 6.0;
    final ang = atan2(b.dy - a.dy, b.dx - a.dx);
    for (final end in [a, b]) {
      final dir = end == a ? ang : ang + pi;
      c.drawLine(
          end,
          Offset(end.dx + len * cos(dir + 0.4), end.dy + len * sin(dir + 0.4)),
          p);
      c.drawLine(
          end,
          Offset(end.dx + len * cos(dir - 0.4), end.dy + len * sin(dir - 0.4)),
          p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = w * 0.16, right = w * 0.9;
    final topY = h * 0.16, floorY = h * 0.80;
    final tubLeft = left, tubRight = left + (right - left) * 0.42;
    final tubTop = floorY - (floorY - topY) * 0.20;
    final z2W = (right - left) * 0.24;
    final z2Right = tubRight + z2W;

    Paint fill(Color cc) => Paint()
      ..color = cc.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Zonen (von hell nach dunkel)
    canvas.drawRect(
        Rect.fromLTRB(tubRight, topY, z2Right, floorY), fill(BadzonenGrafik._c2));
    canvas.drawRect(
        Rect.fromLTRB(tubLeft, topY, tubRight, tubTop), fill(BadzonenGrafik._c1));
    canvas.drawRect(
        Rect.fromLTRB(tubLeft, tubTop, tubRight, floorY), fill(BadzonenGrafik._c0));

    // Zonen-Beschriftung
    _text(canvas, '0', Offset((tubLeft + tubRight) / 2, (tubTop + floorY) / 2),
        size: 20, color: Colors.white, weight: FontWeight.bold, center: true);
    _text(canvas, '1', Offset((tubLeft + tubRight) / 2, (topY + tubTop) / 2),
        size: 20, color: Colors.white, weight: FontWeight.bold, center: true);
    _text(canvas, '2', Offset((tubRight + z2Right) / 2, (topY + floorY) / 2),
        size: 20, color: Colors.white, weight: FontWeight.bold, center: true);

    // Wanne andeuten
    final wanne = Paint()
      ..color = const Color(0xFF0D47A1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(tubLeft, tubTop, tubRight, floorY),
            const Radius.circular(4)),
        wanne);

    // Boden
    final boden = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.06, floorY), Offset(w * 0.96, floorY), boden);

    // Maßlinien
    final dim = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1;
    // Höhe 2,25 m
    final xDim = w * 0.09;
    _pfeil(canvas, Offset(xDim, topY), Offset(xDim, floorY), dim);
    _text(canvas, '2,25 m', Offset(xDim - 6, (topY + floorY) / 2),
        size: 11, center: true, rotate: -pi / 2);
    // Breite 0,60 m
    final yDim = floorY + h * 0.07;
    _pfeil(canvas, Offset(tubRight, yDim), Offset(z2Right, yDim), dim);
    _text(canvas, '0,60 m', Offset((tubRight + z2Right) / 2, yDim + 4),
        size: 11, center: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
