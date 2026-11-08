import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/backtest.dart';
import '../models/trend.dart';
import '../providers.dart';
import '../services/backtest_store.dart';
import '../widgets/common.dart';

/// Visszamérés: a naplózott trendekből és becslésekből hány jött be.
class BacktestScreen extends ConsumerWidget {
  const BacktestScreen({super.key});

  static const _trendLabels = <TrendKind, String>{
    TrendKind.over25: 'Over 2.5 gól',
    TrendKind.under25: 'Under 2.5 gól',
    TrendKind.btts: 'Mindkét csapat szerez gólt',
    TrendKind.win: 'Jó forma → győzelem',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(backtestReportProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visszamérés'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Frissítés',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(backtestReportProvider),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(backtestReportProvider),
        ),
        data: (r) => _body(context, ref, r),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Tally t, {
    bool showAvg = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text(
                t.n == 0
                    ? 'még nincs adat'
                    : '${(t.rate * 100).round()}%  (${t.hits}/${t.n})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (t.n > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: t.rate.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: t.rate >= 0.5 ? Colors.green : Colors.orange,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            if (showAvg)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Becsült átlagos esély: ${(t.avgP * 100).round()}%  •  '
                  'valós találat: ${(t.rate * 100).round()}%',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      );

  Widget _body(BuildContext context, WidgetRef ref, BacktestReport r) {
    if (r.loggedMatches == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Még nincs mit visszamérni.\n\n'
            'Nyisd meg a Trendek fület: az app naplózza a trendeket és a '
            'becsléseket, és a meccsek lejátszása után itt látod, mennyi '
            'jött be belőlük.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Trendek (szelvényre tehető fajták)', [
          for (final e in _trendLabels.entries)
            _row(context, e.value, r.trends[e.key] ?? Tally()),
        ]),
        _card('Esély-becslések', [
          _row(context, 'Legvalószínűbb kimenetel (1X2)', r.top1x2,
              showAvg: true),
          _row(context, 'Over 2.5 (becslés ≥ 60%)', r.over, showAvg: true),
          _row(context, 'Under 2.5 (becslés ≤ 40%)', r.under, showAvg: true),
          _row(context, 'Mindkét csapat lő (becslés ≥ 60%)', r.bttsYes,
              showAvg: true),
          _row(context, 'Nem lő mindkettő (becslés ≤ 40%)', r.bttsNo,
              showAvg: true),
        ]),
        Text(
          '${r.loggedMatches} naplózott meccs, ebből ${r.pending} még nem dőlt el. '
          'A napló 21 napig marad meg. Kevés meccsnél a százalékok ingadozók, '
          'ezért inkább hosszabb távon érdemes nézni őket. A kiértékelés a '
          'végeredményt használja (hosszabbításnál az API végeredményét).',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Napló törlése'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Napló törlése?'),
                content: const Text('A visszamérés adatai elvesznek.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Mégse'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Törlés'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await BacktestStore.clear();
              ref.invalidate(backtestReportProvider);
            }
          },
        ),
      ],
    );
  }
}
