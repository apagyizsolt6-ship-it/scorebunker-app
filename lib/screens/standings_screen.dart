import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leaders.dart';
import '../models/standing.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'projection_tab.dart';
import 'team_screen.dart';

/// Bajnokság képernyő: tabella + góllövők + gólpasszok + lapok + előrejelzés.
/// A `highlight` csapatok a tabellán ki vannak emelve.
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
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Tabella'),
              Tab(text: 'Góllövők'),
              Tab(text: 'Gólpasszok'),
              Tab(text: 'Lapok'),
              Tab(text: 'Előrejelzés'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TableTab(leagueId: leagueId, highlight: highlight),
            _LeadersTab(leagueId: leagueId, kind: LeaderKind.scorers),
            _LeadersTab(leagueId: leagueId, kind: LeaderKind.assists),
            _LeadersTab(leagueId: leagueId, kind: LeaderKind.cards),
            ProjectionTab(leagueId: leagueId),
          ],
        ),
      ),
    );
  }
}

// ==================== TABELLA ====================
enum _View { full, form, home, away }

/// A csapat mutatói csak a megadott nézet meccseiből (az utolsó 6 meccs
/// `form` adataiból), a helyezés nélkül.
TeamRow _derive(TeamRow r, _View v) {
  if (v == _View.full) return r;
  final ms = r.form.where((m) {
    if (!m.hasScore) return false;
    return switch (v) {
      _View.form => true,
      _View.home => m.isHome,
      _View.away => !m.isHome,
      _View.full => true,
    };
  }).toList();
  var w = 0, d = 0, l = 0, gf = 0, ga = 0;
  for (final m in ms) {
    gf += m.goalsFor ?? 0;
    ga += m.goalsAgainst ?? 0;
    if (m.result == 'W') {
      w++;
    } else if (m.result == 'D') {
      d++;
    } else {
      l++;
    }
  }
  return TeamRow(
    position: 0,
    teamId: r.teamId,
    name: r.name,
    shortName: r.shortName,
    played: ms.length,
    won: w,
    draw: d,
    lost: l,
    goalsFor: gf,
    goalsAgainst: ga,
    goalDiff: gf - ga,
    points: w * 3 + d,
    group: r.group,
    form: r.form,
  );
}

/// Pont, gólkülönbség, lőtt gól szerint rendez, és kiosztja a helyezéseket.
List<TeamRow> _rank(List<TeamRow> rows) {
  final l = [...rows]..sort((a, b) {
      final c = b.points.compareTo(a.points);
      if (c != 0) return c;
      final g = b.goalDiff.compareTo(a.goalDiff);
      if (g != 0) return g;
      return b.goalsFor.compareTo(a.goalsFor);
    });
  return [
    for (var i = 0; i < l.length; i++)
      TeamRow(
        position: i + 1,
        teamId: l[i].teamId,
        name: l[i].name,
        shortName: l[i].shortName,
        played: l[i].played,
        won: l[i].won,
        draw: l[i].draw,
        lost: l[i].lost,
        goalsFor: l[i].goalsFor,
        goalsAgainst: l[i].goalsAgainst,
        goalDiff: l[i].goalDiff,
        points: l[i].points,
        group: l[i].group,
        form: l[i].form,
      ),
  ];
}

class _TableTab extends ConsumerStatefulWidget {
  final int leagueId;
  final Set<int> highlight;
  const _TableTab({required this.leagueId, required this.highlight});

  @override
  ConsumerState<_TableTab> createState() => _TableTabState();
}

class _TableTabState extends ConsumerState<_TableTab> {
  _View _view = _View.full;

  @override
  Widget build(BuildContext context) {
    final leagueId = widget.leagueId;
    final highlight = widget.highlight;
    final table = ref.watch(standingsProvider(leagueId));
    return table.when(
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
        var groups = t.byGroup;
        if (_view != _View.full) {
          groups = {
            for (final e in groups.entries)
              e.key: _rank([for (final r in e.value) _derive(r, _view)]),
          };
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(standingsProvider(leagueId));
            await ref.read(standingsProvider(leagueId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              SegmentedButton<_View>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _View.full, label: Text('Teljes')),
                  ButtonSegment(value: _View.form, label: Text('Forma')),
                  ButtonSegment(value: _View.home, label: Text('Hazai')),
                  ButtonSegment(value: _View.away, label: Text('Idegen')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  _view == _View.full
                      ? (t.season.isEmpty ? '' : 'Szezon: ${t.season}')
                      : 'Az utolsó 6 meccs alapján'
                          '${_view == _View.home ? ', csak a hazai meccsek' : (_view == _View.away ? ', csak az idegenbeli meccsek' : '')}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final e in groups.entries) ...[
                if (e.key.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 4, top: 12, bottom: 4),
                    child: Text(
                      e.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                const _HeaderRow(),
                for (final r in e.value)
                  _TableRow(
                    row: r,
                    highlighted: highlight.contains(r.teamId),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TeamScreen(teamId: r.teamId, name: r.name),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
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
  final VoidCallback onTap;
  const _TableRow({
    required this.row,
    required this.highlighted,
    required this.onTap,
  });

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
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
                        fontWeight:
                            highlighted ? FontWeight.w800 : FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}

// ==================== GÓLLÖVŐK / GÓLPASSZOK / LAPOK ====================
class _LeadersTab extends ConsumerWidget {
  final int leagueId;
  final LeaderKind kind;
  const _LeadersTab({required this.leagueId, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (leagueId, kind);
    final data = ref.watch(leadersProvider(key));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(leadersProvider(key)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ehhez a bajnoksághoz nincs elérhető ${kind.title.toLowerCase()} lista.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leadersProvider(key));
            await ref.read(leadersProvider(key).future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                dense: true,
                leading: SizedBox(
                  width: 28,
                  child: Text(
                    '${r.rank}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(r.player,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  r.extra.isEmpty ? r.team : '${r.team} • ${r.extra}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r.value}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(kind.unit, style: const TextStyle(fontSize: 10)),
                  ],
                ),
                onTap: r.teamId == 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeamScreen(teamId: r.teamId, name: r.team),
                          ),
                        ),
              );
            },
          ),
        );
      },
    );
  }
}
