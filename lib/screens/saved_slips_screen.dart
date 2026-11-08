import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/fixture.dart';
import '../models/slip.dart';
import '../providers.dart';
import '../services/sport_api.dart';

/// Mentett szelvények: a meccsek végeredménye alapján automatikusan kiértékelve.
class SavedSlipsScreen extends ConsumerWidget {
  const SavedSlipsScreen({super.key});

  void _settle(WidgetRef ref, Map<int, Fixture> fx) {
    for (final s in ref.read(slipsProvider)) {
      if (s.settled != null) continue;
      final res = [for (final l in s.legs) evaluatePick(l.pick, fx[l.fixtureId])];
      if (res.every((r) => r != LegResult.pending)) {
        ref
            .read(slipsProvider.notifier)
            .setSettled(s.id, [for (final r in res) r.index]);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slips = ref.watch(slipsProvider);
    final fxState = ref.watch(slipFixturesProvider);
    final fx = fxState.valueOrNull ?? const <int, Fixture>{};

    ref.listen<AsyncValue<Map<int, Fixture>>>(slipFixturesProvider, (_, next) {
      final m = next.valueOrNull;
      if (m != null) _settle(ref, m);
    });

    // Egyenleg a már eldőlt szelvényekből.
    var won = 0, lost = 0, pending = 0;
    var balance = 0.0;
    final evals = <int, SlipEval>{};
    for (final s in slips) {
      final e = evaluateSlip(s, fx);
      evals[s.id] = e;
      switch (e.status) {
        case SlipStatus.won:
          won++;
          balance += e.payout(s.stake) - s.stake;
        case SlipStatus.lost:
          lost++;
          balance -= s.stake;
        case SlipStatus.pending:
          pending++;
        case SlipStatus.voided:
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentett szelvények'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Eredmények frissítése',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(slipFixturesProvider),
          ),
        ],
      ),
      body: slips.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Még nincs mentett szelvényed.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(slipFixturesProvider);
                await ref.read(slipFixturesProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat('Nyert', '$won', Colors.green),
                          _Stat('Vesztett', '$lost', Colors.red),
                          _Stat('Függő', '$pending', Colors.orange),
                          _Stat(
                            'Egyenleg',
                            '${balance > 0 ? '+' : ''}${fmtAmount(balance)}',
                            balance >= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (fxState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Az eredmények frissítése nem sikerült: '
                        '${errorText(fxState.error!)}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  for (final s in slips)
                    _SlipCard(slip: s, eval: evals[s.id]!, fixtures: fx),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _SlipCard extends ConsumerWidget {
  final Slip slip;
  final SlipEval eval;
  final Map<int, Fixture> fixtures;
  const _SlipCard({
    required this.slip,
    required this.eval,
    required this.fixtures,
  });

  (String, Color) _status() => switch (eval.status) {
        SlipStatus.won => ('Nyert', Colors.green),
        SlipStatus.lost => ('Vesztett', Colors.red),
        SlipStatus.pending => ('Függőben', Colors.orange),
        SlipStatus.voided => ('Érvénytelen', Colors.grey),
      };

  Widget _legIcon(LegResult r) => switch (r) {
        LegResult.won =>
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
        LegResult.lost => const Icon(Icons.cancel, size: 18, color: Colors.red),
        LegResult.voided =>
          const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey),
        LegResult.pending =>
          const Icon(Icons.schedule, size: 18, color: Colors.orange),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String label, Color color) = _status();
    final scheme = Theme.of(context).colorScheme;
    final money = eval.status == SlipStatus.won
        ? 'Nyeremény: ${fmtAmount(eval.payout(slip.stake))}'
        : eval.status == SlipStatus.pending
            ? 'Várható: ${fmtAmount(slip.stake * slip.totalOdds)}'
            : eval.status == SlipStatus.voided
                ? 'Tét visszajár: ${fmtAmount(slip.stake)}'
                : 'Elvesztett tét: ${fmtAmount(slip.stake)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(slip.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'Törlés',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Szelvény törlése?'),
                        content: Text(slip.name),
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
                      ref.read(slipsProvider.notifier).remove(slip.id);
                    }
                  },
                ),
              ],
            ),
            Text(
              '${DateFormat('yyyy.MM.dd HH:mm').format(slip.createdAt)} • '
              'Összodds ${fmtOdds(eval.effectiveOdds)} • Tét ${fmtAmount(slip.stake)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(money, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Divider(height: 20),
            for (var i = 0; i < slip.legs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    _legIcon(eval.legs[i]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${slip.legs[i].home} – ${slip.legs[i].away}',
                              style: const TextStyle(fontSize: 13)),
                          Text(
                            '${slip.legs[i].pick.short} @ ${fmtOdds(slip.legs[i].odds)}'
                            '${_score(slip.legs[i])}',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _score(SlipLeg l) {
    final f = fixtures[l.fixtureId];
    if (f == null || !f.isFinished || !f.hasScore) return '';
    return '  •  végeredmény ${f.homeScore}-${f.awayScore}';
  }
}
