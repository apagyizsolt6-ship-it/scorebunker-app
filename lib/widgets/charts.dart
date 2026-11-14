import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/backtest.dart';
import '../services/estimator.dart';

void _text(Canvas c, String s, Offset o, Color color,
    {double size = 9, bool center = false, bool right = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)),
    textDirection: TextDirection.ltr,
  )..layout();
  var dx = o.dx;
  if (center) dx -= tp.width / 2;
  if (right) dx -= tp.width;
  tp.paint(c, Offset(dx, o.dy - tp.height / 2));
}

// ==================== ÉLŐ ESÉLY-GRAFIKON ====================
/// Hazai / döntetlen / vendég esély alakulása percről percre, a gólokkal jelölve.
class ProbChart extends StatelessWidget {
  final LiveSeries series;
  final String homeLabel;
  final String awayLabel;
  final double height;

  const ProbChart({
    super.key,
    required this.series,
    required this.homeLabel,
    required this.awayLabel,
    this.height = 170,
  });

  Widget _legend(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 3, color: c),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homeC = scheme.primary;
    const drawC = Colors.grey;
    final awayC = scheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ProbPainter(
              series: series,
              homeC: homeC,
              drawC: drawC,
              awayC: awayC,
              textC: scheme.onSurfaceVariant,
              gridC: scheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 14,
          children: [
            _legend(homeC, homeLabel),
            _legend(drawC, 'Döntetlen'),
            _legend(awayC, awayLabel),
          ],
        ),
      ],
    );
  }
}

class _ProbPainter extends CustomPainter {
  final LiveSeries series;
  final Color homeC;
  final Color drawC;
  final Color awayC;
  final Color textC;
  final Color gridC;

  const _ProbPainter({
    required this.series,
    required this.homeC,
    required this.drawC,
    required this.awayC,
    required this.textC,
    required this.gridC,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const right = 8.0;
    const top = 6.0;
    const bottom = 18.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final pts = series.points;
    if (pts.isEmpty || w <= 0 || h <= 0) return;

    final maxMin = math.max(90, pts.last.minute).toDouble();
    Offset pt(num minute, double p) =>
        Offset(left + w * minute / maxMin, top + h * (1 - p));

    final grid = Paint()
      ..color = gridC
      ..strokeWidth = 0.7;
    for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = top + h * (1 - v);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      _text(canvas, '${(v * 100).round()}%', Offset(left - 4, y), textC,
          right: true);
    }
    for (var m = 0; m <= maxMin; m += 15) {
      _text(canvas, "$m'", Offset(left + w * m / maxMin, top + h + 10), textC,
          center: true);
    }

    // Gólok: függőleges jelzés.
    for (final g in series.goals) {
      final x = left + w * g.$1 / maxMin;
      final p = Paint()
        ..color = (g.$2 ? homeC : awayC).withValues(alpha: 0.55)
        ..strokeWidth = 1;
      var y = top;
      while (y < top + h) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 4, top + h)), p);
        y += 7;
      }
      canvas.drawCircle(Offset(x, top + 3), 3, Paint()..color = g.$2 ? homeC : awayC);
    }

    void line(List<Offset> o, Color c) {
      if (o.length < 2) return;
      final path = Path()..moveTo(o.first.dx, o.first.dy);
      for (final p in o.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line([for (final s in pts) pt(s.minute, s.est.home)], homeC);
    line([for (final s in pts) pt(s.minute, s.est.draw)], drawC);
    line([for (final s in pts) pt(s.minute, s.est.away)], awayC);
  }

  @override
  bool shouldRepaint(covariant _ProbPainter old) => old.series != series;
}

// ==================== NAPI TALÁLATI ARÁNY ====================
/// Oszlopdiagram: naponta a modell három fő tippjének találati aránya.
class DailyBars extends StatelessWidget {
  final List<DayStat> days;
  const DailyBars({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const barArea = 90.0;
    return SizedBox(
      height: barArea + 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final d in days)
            SizedBox(
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${(d.rate * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Container(
                    width: 22,
                    height: math.max(3, barArea * d.rate),
                    decoration: BoxDecoration(
                      color: d.rate >= 0.6
                          ? Colors.green
                          : (d.rate >= 0.5 ? Colors.orange : scheme.error),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(d.date.length >= 10 ? d.date.substring(5) : d.date,
                      style: TextStyle(
                          fontSize: 9, color: scheme.onSurfaceVariant)),
                  Text('${d.matches} m',
                      style: TextStyle(
                          fontSize: 9, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== KALIBRÁCIÓS GÖRBE ====================
/// Becsült esély (x) és valós gyakoriság (y). Az átló a tökéletes kalibráció.
class CalibrationCurve extends StatelessWidget {
  /// (becsült esély, valós gyakoriság, minták száma)
  final List<(double, double, int)> points;
  final double size;
  const CalibrationCurve({super.key, required this.points, this.size = 220});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CalibPainter(
            points: points,
            lineC: scheme.primary,
            textC: scheme.onSurfaceVariant,
            gridC: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _CalibPainter extends CustomPainter {
  final List<(double, double, int)> points;
  final Color lineC;
  final Color textC;
  final Color gridC;

  const _CalibPainter({
    required this.points,
    required this.lineC,
    required this.textC,
    required this.gridC,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 26.0;
    final w = size.width - pad - 6;
    final h = size.height - pad - 6;
    Offset pt(double x, double y) =>
        Offset(pad + w * x, 6 + h * (1 - y));

    final grid = Paint()
      ..color = gridC
      ..strokeWidth = 0.7;
    for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      canvas.drawLine(pt(0, v), pt(1, v), grid);
      canvas.drawLine(pt(v, 0), pt(v, 1), grid);
      _text(canvas, '${(v * 100).round()}', Offset(pad - 4, pt(0, v).dy), textC,
          right: true);
      _text(canvas, '${(v * 100).round()}', Offset(pt(v, 0).dx, 6 + h + 10),
          textC, center: true);
    }
    // Tökéletes kalibráció: az átló.
    canvas.drawLine(
      pt(0, 0),
      pt(1, 1),
      Paint()
        ..color = textC.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
    if (points.isEmpty) return;

    final sorted = [...points]..sort((a, b) => a.$1.compareTo(b.$1));
    final path = Path();
    for (var i = 0; i < sorted.length; i++) {
      final o = pt(sorted[i].$1, sorted[i].$2);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineC
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final maxN = sorted.map((e) => e.$3).reduce(math.max);
    for (final p in sorted) {
      final r = 3 + 4 * (p.$3 / maxN);
      canvas.drawCircle(pt(p.$1, p.$2), r, Paint()..color = lineC);
    }
  }

  @override
  bool shouldRepaint(covariant _CalibPainter old) => old.points != points;
}
