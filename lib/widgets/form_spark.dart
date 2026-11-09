import 'package:flutter/material.dart';

import '../models/standing.dart';

/// Kis oszlopdiagram az utolsó meccsek gólkülönbségéről (régebbi → újabb).
/// Zöld: győzelem, szürke: döntetlen, piros: vereség.
class FormSpark extends StatelessWidget {
  final List<FormMatch> form;
  final double height;

  const FormSpark({super.key, required this.form, this.height = 36});

  @override
  Widget build(BuildContext context) {
    final ms = form.where((m) => m.hasScore).toList();
    if (ms.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparkPainter(
          values: [for (final m in ms) (m.goalsFor ?? 0) - (m.goalsAgainst ?? 0)],
          results: [for (final m in ms) m.result],
          axis: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<int> values;
  final List<String> results;
  final Color axis;

  const _SparkPainter({
    required this.values,
    required this.results,
    required this.axis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    var maxAbs = 1;
    for (final v in values) {
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    if (maxAbs < 3) maxAbs = 3;

    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    final slot = size.width / n;
    final barW = slot * 0.62;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final r = results[i];
      final color = r == 'W'
          ? Colors.green
          : (r == 'D' ? Colors.grey : Colors.red);
      var h = (v.abs() / maxAbs) * (mid - 2);
      if (v == 0) h = 2;
      final x = i * slot + (slot - barW) / 2;
      final rect = v >= 0
          ? Rect.fromLTWH(x, mid - h, barW, h)
          : Rect.fromLTWH(x, mid, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.results != results;
}
