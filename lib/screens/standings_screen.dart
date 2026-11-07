import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/standing.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Teljes bajnoki tabella. A `highlight` csapatok ki vannak emelve.
class StandingsScreen extends ConsumerWidget {
  final int leagueId;
  final String title;
  final Set<int> highlight;

  const StandingsScreen({
    super.key,
    required this.leagueId,
    required this.title,
    this.highlight = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(standingsProvider(leagueId));
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: table.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(standingsProvider(leagueId)),
        ),
        data: (t) {
          if (t.rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ehhez a bajnoksághoz nincs elérhető tabella.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final groups = t.byGroup;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(standingsProvider(leagueId));
              await ref.read(standingsProvider(leagueId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                if (t.season.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Szezon: ${t.season}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final e in groups.entries) ...[
                  if (e.key.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 4),
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  const _HeaderRow(),
                  for (final r in e.value)
                    _TableRow(row: r, highlighted: highlight.contains(r.teamId)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

const double _wNum = 26;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    Widget c(String t, double w) => SizedBox(
          width: w,
          child: Text(t, textAlign: TextAlign.center, style: style),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          c('#', 24),
          const SizedBox(width: 6),
          Expanded(child: Text('Csapat', style: style)),
          c('M', _wNum),
          c('Gy', _wNum),
          c('D', _wNum),
          c('V', _wNum),
          c('+/-', 34),
          c('P', 30),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final TeamRow row;
  final bool highlighted;
  const _TableRow({required this.row, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget c(String t, double w, {bool bold = false}) => SizedBox(
          width: w,
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        );
    final gd = row.goalDiff >= 0 ? '+${row.goalDiff}' : '${row.goalDiff}';
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          c('${row.position}', 24, bold: true),
          const SizedBox(width: 6),
          TeamLogo(teamId: row.teamId, size: 16, padRight: false),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
          c('${row.played}', _wNum),
          c('${row.won}', _wNum),
          c('${row.draw}', _wNum),
          c('${row.lost}', _wNum),
          c(gd, 34),
          c('${row.points}', 30, bold: true),
        ],
      ),
    );
  }
}
