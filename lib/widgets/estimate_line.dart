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
    // Az odds szerinti (a fogadóiroda jutalékát is tartalmazó) esély és az eltérés.
    final implied = (o == null || o <= 1.0) ? null : 1 / o;
    final diffPp = implied == null ? null : ((prob - implied) * 100).round();
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
          if (implied != null && diffPp != null)
            TextSpan(
              text: '  •  odds szerinti esély ${(implied * 100).round()}% '
                  '(eltérés ${diffPp >= 0 ? '+' : ''}$diffPp százalékpont)',
            ),
          if (diffPp != null && diffPp.abs() >= 15)
            const TextSpan(
              text: '  ⚠ nagy eltérés: ellenőrizd a körülményeket (sérülések, forma, tét)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
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
