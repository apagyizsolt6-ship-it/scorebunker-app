import 'package:flutter/material.dart';

import '../services/estimator.dart';

/// Egysoros összegzés egy tipp becsült esélyéről: esély, fair odds és – ha
/// az odds ismert – a várható érték (p * odds - 1).
class EstimateLine extends StatelessWidget {
  final double prob;
  final double? odds;
  final double fontSize;

  const EstimateLine({
    super.key,
    required this.prob,
    this.odds,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final o = odds;
    final ev = (o == null || o <= 1.0) ? null : expectedValue(prob, o);
    final base = TextStyle(
      fontSize: fontSize,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: 'Becsült esély ${(prob * 100).round()}%'),
          TextSpan(text: '  •  fair odds ${fairOdds(prob).toStringAsFixed(2)}'),
          if (ev != null)
            TextSpan(
              text: '  •  várható érték '
                  '${ev >= 0 ? '+' : ''}${(ev * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ev >= 0 ? Colors.green : Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}
