import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../models/slip.dart';
import '../models/trend.dart';
import '../providers.dart';
import '../services/estimator.dart';
import '../widgets/common.dart';
import 'backtest_screen.dart';
import 'match_detail_screen.dart';

enum _Group { all, result, goals, btts }

class _Cand {
  final Fixture fixture;
  final Pick pick;
  final double p;
  final MatchEstimate est;
  final _Group group;
  const _Cand(this.fixture, this.pick, this.p, this.est, this.group);
}

/// A nap meccseinek legvalószínűbb kimenetelei a becslés szerint
/// (1X2, gólok, mindkét csapat szerez gólt), a fair odds-szal.
class BestPicksTab extends ConsumerStatefulWidget {
  const BestPicksTab({super.key});

  @override
  ConsumerState<BestPicksTab> createState() => _BestPicksTabState();
}

class _BestPicksTabState extends ConsumerState<BestPicksTab> {
  double _min = 0.60;
  _Group _group = _Group.all;

  List<_Cand> _candidates(List<FixtureEstimate> list) {
    final out = <_Cand>[];
    for (final fe in list) {
      final e = fe.est;

      final r = [
        (Pick.home, e.home),
        (Pick.draw, e.draw),
        (Pick.away, e.away),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      out.add(_Cand(fe.fixture, r.first.$1, r.first.$2, e, _Group.result));

      final g = e.over25 >= e.under25
          ? (Pick.over25, e.over25)
          : (Pick.under25, e.under25);
      out.add(_Cand(fe.fixture, g.$1, g.$2, e, _Group.goals));

      final b = e.bttsYes >= e.bttsNo
          ? (Pick.bttsYes, e.bttsYes)
          : (Pick.bttsNo, e.bttsNo);
      out.add(_Cand(fe.fixture, b.$1, b.$2, e, _Group.btts));
    }
    return out;
  }

  String _label(_Cand c) {
    final f = c.fixture;
    return switch (c.pick) {
      Pick.home => '${f.homeLabel} nyer',
      Pick.away => '${f.awayLabel} nyer',
      _ => c.pick.long,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(trendsProvider);

    return result.when(
      loading: () {
        final p = ref.watch(trendsProgressProvider);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  p.$2 > 0
                      ? 'Tabellák betöltése: ${p.$1} / ${p.$2} bajnokság'
                      : 'Esélyek számítása…',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(trendsProvider),
      ),
      data: (r) {
        final all = _candidates(r.estimates);
        final shown = [
          for (final c in all)
            if (c.p >= _min && (_group == _Group.all || c.group == _group)) c,
        ]..sort((a, b) => b.p.compareTo(a.p));
        final capped = shown.take(80).toList();

        Widget chip(String label, _Group g) => ChoiceChip(
              label: Text(label),
              selected: _group == g,
              onSelected: (_) => setState(() => _group = g),
            );

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  chip('Mind', _Group.all),
                  const SizedBox(width: 8),
                  chip('Kimenetel', _Group.result),
                  const SizedBox(width: 8),
                  chip('Gólok', _Group.goals),
                  const SizedBox(width: 8),
                  chip('BTTS', _Group.btts),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Text('Minimum esély: ${(_min * 100).round()}%',
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _min,
                      min: 0.45,
                      max: 0.85,
                      divisions: 8,
                      label: '${(_min * 100).round()}%',
                      onChanged: (v) => setState(() => _min = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: capped.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${shown.length} tipp ${r.matches} meccsből'
                        '${shown.length > capped.length ? ' (az első ${capped.length} látszik)' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  if (i == capped.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          Text(
                            capped.isEmpty
                                ? 'Nincs a küszöböt elérő esély. Csökkentsd a minimum esélyt.'
                                : 'Alapmodell: szezon-átlag, hazai/idegenbeli forma és hazai előny. '
                                    'A meccs részleteiben az egymás elleni meccsek is beleszámítanak. '
                                    'Becslés, nem garancia és nem ajánlás.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.fact_check_outlined, size: 18),
                            label: const Text('Mennyire vált be eddig?'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BacktestScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _PickCard(cand: capped[i - 1], label: _label(capped[i - 1]));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PickCard extends ConsumerWidget {
  final _Cand cand;
  final String label;
  const _PickCard({required this.cand, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = cand.fixture;
    final scheme = Theme.of(context).colorScheme;
    final inSlip = ref.watch(draftProvider)[f.id]?.pick == cand.pick;
    final pct = (cand.p * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${f.homeTeam} – ${f.awayTeam}  •  ${f.timeLabel}',
                        style: const TextStyle(fontSize: 13)),
                    Text(leagueHu(f.leagueName),
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: cand.p.clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        color: cand.p >= 0.7 ? Colors.green : scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Várható gólok: ${cand.est.lambdaHome.toStringAsFixed(2)} – '
                      '${cand.est.lambdaAway.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text('$pct%',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('fair ${fairOdds(cand.p).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11)),
                  IconButton(
                    tooltip: inSlip
                        ? 'Már a szelvényen van'
                        : 'Szelvényre (${cand.pick.short})',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      inSlip ? Icons.check_circle : Icons.add_circle_outline,
                      color: inSlip ? Colors.green : null,
                    ),
                    onPressed: inSlip
                        ? null
                        : () {
                            ref
                                .read(draftProvider.notifier)
                                .set(f, cand.pick, null);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                content: Text(
                                    '${cand.pick.short} a szelvényre került – az oddsot a Szelvény fülön add meg.'),
                              ));
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
