import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../models/slip.dart';
import '../models/trend.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'match_detail_screen.dart';

/// Valódi trendek a nap összes közelgő meccsére, a bajnoki tabellák
/// `form` adataiból (a csapatok utolsó 6 meccse) számolva.
class TrendsPage extends ConsumerWidget {
  const TrendsPage({super.key});

  void _refresh(WidgetRef ref) {
    ref.read(standingsCacheProvider).clear();
    ref.invalidate(fixturesProvider);
    ref.invalidate(trendsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyState = ref.watch(apiKeyProvider);
    final date = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trendek'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Újraszámolás',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: keyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (k) {
          if (k == null || k.isEmpty) return const NoKeyView();
          final fixtures = ref.watch(fixturesProvider);
          return fixtures.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(fixturesProvider),
            ),
            data: (list) {
              final scheduled = list.where((m) => m.isScheduled).toList();
              if (scheduled.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ezen a napon nincs közelgő meccs.\n'
                      'A Meccsek fülön válassz másik napot.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final totalLeagues = {
                for (final m in scheduled)
                  if (m.leagueId != 0) m.leagueId,
              }.length;
              return Column(
                children: [
                  _Header(date: date, totalLeagues: totalLeagues),
                  Expanded(child: _Body(totalLeagues: totalLeagues)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final DateTime date;
  final int totalLeagues;
  const _Header({required this.date, required this.totalLeagues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(trendGroupFilterProvider);
    final topOnly = ref.watch(trendsTopOnlyProvider);

    Widget chip(String label, TrendGroup? g) => ChoiceChip(
          label: Text(label),
          selected: group == g,
          onSelected: (_) =>
              ref.read(trendGroupFilterProvider.notifier).state = g,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Nap: ${DateFormat('yyyy.MM.dd').format(date)} '
            '(a Meccsek fülön váltható)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              chip('Mind', null),
              const SizedBox(width: 8),
              chip('Gólok', TrendGroup.goals),
              const SizedBox(width: 8),
              chip('BTTS', TrendGroup.btts),
              const SizedBox(width: 8),
              chip('Forma', TrendGroup.form),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Csak top + kedvencek'),
                selected: topOnly,
                onSelected: (v) =>
                    ref.read(trendsTopOnlyProvider.notifier).state = v,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  final int totalLeagues;
  const _Body({required this.totalLeagues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(trendsProvider);
    final group = ref.watch(trendGroupFilterProvider);

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
                      : 'Trendek számítása…',
                  textAlign: TextAlign.center,
                ),
                if (p.$2 > 20) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Az első betöltés sok kérést igényel, utána a tabellák '
                    'a munkamenet alatt gyorsítótárban maradnak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
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
        final shown = [
          for (final t in r.trends)
            if (group == null || t.group == group) t,
        ];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: shown.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${r.matches} meccs elemezve, ${r.leagues} bajnokság '
                  'tabellája alapján • ${shown.length} trend'
                  '${r.failed > 0 ? ' • ${r.failed} tabella nem töltődött be' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            if (index == shown.length + 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  shown.isEmpty
                      ? 'Nincs elég erős trend ezen a napon a kiválasztott szűrővel.'
                      : 'A trendek a csapatok utolsó (legfeljebb 6) meccséből '
                          'készülnek, nem tippek vagy ajánlások.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }
            return _TrendCard(trend: shown[index - 1]);
          },
        );
      },
    );
  }
}

class _TrendCard extends ConsumerWidget {
  final Trend trend;
  const _TrendCard({required this.trend});

  Color _color(BuildContext context, int s) {
    if (s >= 9) return Colors.green;
    if (s >= 7) return Theme.of(context).colorScheme.primary;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trend;
    final f = t.fixture;
    final draft = ref.watch(draftProvider);
    final pick = t.pick;
    final inSlip = pick != null && draft[f.id]?.pick == pick;
    final scheme = Theme.of(context).colorScheme;

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
                    Text(t.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '${f.homeTeam} – ${f.awayTeam}  •  ${f.timeLabel}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      leagueHu(f.leagueName),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(t.detail, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        _color(context, t.strength).withValues(alpha: 0.18),
                    child: Text(
                      '${t.strength}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _color(context, t.strength),
                      ),
                    ),
                  ),
                  if (pick != null)
                    IconButton(
                      tooltip: inSlip
                          ? 'Már a szelvényen van'
                          : 'Szelvényre (${pick.short})',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        inSlip
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: inSlip ? Colors.green : null,
                      ),
                      onPressed: inSlip
                          ? null
                          : () {
                              final old = draft[f.id];
                              ref.read(draftProvider.notifier).set(
                                    f,
                                    pick,
                                    old != null && old.pick == pick
                                        ? old.odds
                                        : null,
                                  );
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                  content: Text(
                                      '${pick.short} a szelvényre került – az oddsot a Szelvény fülön add meg.'),
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
